SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

USE QL_CHUYENBAY;
GO

-- TG1: Đồng bộ số ghế còn trống khi thêm, đổi trạng thái, đổi chuyến hoặc xóa vé.
CREATE OR ALTER TRIGGER dbo.TG1_CapNhatSoGheTrong
ON dbo.VEBAY
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- Sơ đồ demo quy ước mỗi hàng có các ghế A-F, số hàng bắt đầu từ 01.
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN dbo.CHUYENBAY cb ON cb.MaChuyenBay = i.MaChuyenBay
        JOIN dbo.MAYBAY mb ON mb.MaMayBay = cb.MaMayBay
        CROSS APPLY (VALUES (
            TRY_CONVERT(INT, LEFT(i.SoGhe, CASE WHEN LEN(i.SoGhe) > 1 THEN LEN(i.SoGhe) - 1 ELSE 0 END)),
            UPPER(RIGHT(i.SoGhe, 1))
        )) AS seat(SoHang, Cot)
        WHERE i.TrangThaiVe <> N'Đã hủy'
          AND (LEN(i.SoGhe) < 2 OR seat.SoHang IS NULL OR seat.SoHang < 1
               OR seat.Cot NOT LIKE '[A-F]'
               OR ((seat.SoHang - 1) * 6 + ASCII(seat.Cot) - ASCII('A') + 1) > mb.SoGhe)
    )
        THROW 51001, N'TG1: Số ghế không tồn tại trên máy bay của chuyến bay.', 1;

    DECLARE @Delta TABLE (MaChuyenBay VARCHAR(5) PRIMARY KEY, SoGheBanThem INT NOT NULL);

    INSERT INTO @Delta (MaChuyenBay, SoGheBanThem)
    SELECT x.MaChuyenBay, SUM(x.Delta)
    FROM (
        SELECT i.MaChuyenBay, 1 AS Delta
        FROM inserted i
        WHERE i.TrangThaiVe <> N'Đã hủy'
        UNION ALL
        SELECT d.MaChuyenBay, -1 AS Delta
        FROM deleted d
        WHERE d.TrangThaiVe <> N'Đã hủy'
    ) AS x
    GROUP BY x.MaChuyenBay
    HAVING SUM(x.Delta) <> 0;

    -- Khóa hàng tồn kho trong giao dịch hiện tại để tránh bán vượt ghế khi ghi đồng thời.
    IF EXISTS (
        SELECT 1
        FROM @Delta d
        JOIN dbo.CHUYENBAY cb WITH (UPDLOCK, HOLDLOCK) ON cb.MaChuyenBay = d.MaChuyenBay
        JOIN dbo.MAYBAY mb ON mb.MaMayBay = cb.MaMayBay
        WHERE (d.SoGheBanThem > 0 AND cb.SoGheTrong < d.SoGheBanThem)
           OR (d.SoGheBanThem < 0 AND cb.SoGheTrong - d.SoGheBanThem > mb.SoGhe)
    )
        THROW 51002, N'TG1: Không đủ ghế trống hoặc số ghế hoàn lại vượt sức chứa.', 1;

    UPDATE cb
       SET cb.SoGheTrong = cb.SoGheTrong - d.SoGheBanThem
    FROM dbo.CHUYENBAY cb
    JOIN @Delta d ON d.MaChuyenBay = cb.MaChuyenBay;
END;
GO

-- TG2: Không cho chuyển trạng thái sang hủy khi còn dưới 24 giờ tới giờ khởi hành.
CREATE OR ALTER TRIGGER dbo.TG2_ChanHuyChuyenBayDuoi24h
ON dbo.CHUYENBAY
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF UPDATE(TrangThai) AND EXISTS (
        SELECT 1
        FROM inserted i
        JOIN deleted d ON d.MaChuyenBay = i.MaChuyenBay
        WHERE i.TrangThai = N'Đã hủy'
          AND d.TrangThai <> N'Đã hủy'
          AND i.GioKhoiHanhDK < DATEADD(HOUR, 24, SYSUTCDATETIME())
    )
        THROW 51003, N'TG2: Không thể hủy chuyến bay khi còn dưới 24 giờ tới giờ khởi hành.', 1;
END;
GO

-- TG3: Giới hạn tổng thời gian phân công của phi công/tiếp viên ở 30 giờ mỗi tuần.
CREATE OR ALTER TRIGGER dbo.TG3_KiemTraDinhMucGioBayTuan
ON dbo.PHANCONG
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TuanAnhHuong TABLE (MaNV VARCHAR(10), NgayDauTuan DATE, PRIMARY KEY (MaNV, NgayDauTuan));
    INSERT INTO @TuanAnhHuong (MaNV, NgayDauTuan)
    SELECT DISTINCT i.MaNV,
           DATEADD(DAY, -(DATEDIFF(DAY, CONVERT(DATE, '19000101', 112), CONVERT(DATE, i.GioBatDau)) % 7), CONVERT(DATE, i.GioBatDau))
    FROM inserted i;

    IF EXISTS (
        SELECT 1
        FROM @TuanAnhHuong a
        JOIN dbo.PHANCONG pc ON pc.MaNV = a.MaNV
        CROSS APPLY (VALUES (
            DATEADD(DAY, -(DATEDIFF(DAY, CONVERT(DATE, '19000101', 112), CONVERT(DATE, pc.GioBatDau)) % 7), CONVERT(DATE, pc.GioBatDau))
        )) AS w(NgayDauTuan)
        WHERE w.NgayDauTuan = a.NgayDauTuan
        GROUP BY a.MaNV, a.NgayDauTuan
        HAVING SUM(DATEDIFF(MINUTE, pc.GioBatDau, pc.GioKetThuc)) > 30 * 60
    )
        THROW 51004, N'TG3: Tổng giờ phân công trong tuần vượt mức tối đa 30 giờ.', 1;
END;
GO

-- TG4: Bảo vệ quy tắc giá vé Thương gia phải cao hơn Phổ thông.
CREATE OR ALTER TRIGGER dbo.TG4_KiemTraGiaVeThuongGia
ON dbo.CHUYENBAY
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted WHERE GiaVeThuongGia <= GiaVePhoThong)
        THROW 51005, N'TG4: Giá vé Thương gia phải lớn hơn giá vé Phổ thông trên cùng chuyến bay.', 1;
END;
GO

-- TG5: Chặn xóa máy bay đang được dùng trong lịch bay tương lai; không xóa lịch sử.
CREATE OR ALTER TRIGGER dbo.TG5_ChanXoaMayBayCoLichTuongLai
ON dbo.MAYBAY
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM deleted d
        JOIN dbo.CHUYENBAY cb ON cb.MaMayBay = d.MaMayBay
        WHERE cb.GioKhoiHanhDK > SYSUTCDATETIME()
          AND cb.TrangThai <> N'Đã hủy'
    )
        THROW 51006, N'TG5: Không thể xóa máy bay đang có chuyến bay trong lịch tương lai.', 1;

    IF EXISTS (
        SELECT 1
        FROM deleted d
        JOIN dbo.CHUYENBAY cb ON cb.MaMayBay = d.MaMayBay
    )
        THROW 51007, N'TG5: Máy bay có lịch sử chuyến bay; hãy ngừng khai thác thay vì xóa dữ liệu.', 1;

    DELETE mb
    FROM dbo.MAYBAY mb
    JOIN deleted d ON d.MaMayBay = mb.MaMayBay;
END;
GO

/*
  Kịch bản kiểm thử thủ công (không tự chạy khi nạp trigger):
  1. TG1: gọi SP1 với chuyến còn ghế; kiểm tra SoGheTrong giảm 1; hủy vé và kiểm tra tăng 1.
     Thử chọn cùng ghế hai lần hoặc ghế ngoài sức chứa; thao tác thứ hai phải bị từ chối.
  2. TG2: cập nhật một chuyến khởi hành trong 23 giờ tới sang N'Đã hủy'; phải nhận lỗi 51003.
  3. TG3: thêm các ca phân công trong cùng tuần vượt tổng 30 giờ; giao dịch phải bị từ chối.
  4. TG4: cập nhật GiaVeThuongGia bằng/nhỏ hơn GiaVePhoThong; phải nhận lỗi 51005.
  5. TG5: xóa máy bay có chuyến bay tương lai; phải nhận lỗi 51006.
  Sau mỗi phép thử, SELECT lại các hàng liên quan để ghi nhận kết quả và chụp ảnh trong SQL Server.

  Script chạy thủ công bên dưới dùng transaction/rollback để dữ liệu demo được giữ nguyên.
  Bỏ dấu comment của cả khối khi chạy trên database đã nạp script_insert_data.sql.
  -- BEGIN TRY
  --   BEGIN TRANSACTION;
  --   DECLARE @GioThu DATETIME2(0) = DATEADD(HOUR, 36, SYSUTCDATETIME());
  --   DECLARE @GheThu VARCHAR(5);
  --   UPDATE dbo.CHUYENBAY SET GioKhoiHanhDK = @GioThu,
  --          GioHaCanhDK = DATEADD(MINUTE, 80, @GioThu), GioCatCanhTT = NULL, GioHaCanhTT = NULL
  --   WHERE MaChuyenBay = 'VN716';
  --   SELECT TOP (1) @GheThu = SoGhe FROM dbo.FN2_DanhSachGheTrong('VN716') ORDER BY SoGhe;
  --   EXEC dbo.SP1_DATCHO_TAOVE 'TSTVE01', 'VN716', 'HK01', 'TSTPNR01', @GheThu, N'Phổ thông';
  --   SELECT MaChuyenBay, SoGheTrong FROM dbo.CHUYENBAY WHERE MaChuyenBay = 'VN716'; -- TG1 giảm 1
  --   UPDATE dbo.VEBAY SET TrangThaiVe = N'Đã hủy' WHERE MaVe = 'TSTVE01';
  --   SELECT MaChuyenBay, SoGheTrong FROM dbo.CHUYENBAY WHERE MaChuyenBay = 'VN716'; -- TG1 hoàn 1
  --   ROLLBACK TRANSACTION;
  -- END TRY
  -- BEGIN CATCH
  --   IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
  --   SELECT ERROR_NUMBER() AS MaLoi, ERROR_MESSAGE() AS KetQuaTestTG1;
  -- END CATCH;

  -- TG2: cập nhật giờ bay trong 12 giờ tới, rồi thử hủy; kết quả mong đợi là lỗi 51003.
  -- BEGIN TRANSACTION;
  -- DECLARE @GioGan DATETIME2(0) = DATEADD(HOUR, 12, SYSUTCDATETIME());
  -- UPDATE dbo.CHUYENBAY SET GioKhoiHanhDK = @GioGan,
  --        GioHaCanhDK = DATEADD(MINUTE, 80, @GioGan), GioCatCanhTT = NULL, GioHaCanhTT = NULL
  -- WHERE MaChuyenBay = 'VN716';
  -- BEGIN TRY UPDATE dbo.CHUYENBAY SET TrangThai = N'Đã hủy' WHERE MaChuyenBay = 'VN716'; END TRY
  -- BEGIN CATCH SELECT ERROR_NUMBER() AS MaLoi, ERROR_MESSAGE() AS KetQuaTestTG2; END CATCH;
  -- IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;

  -- TG3: các phân công mới cộng với VU118 vượt 30 giờ trong tuần; mong đợi lỗi 51004.
  -- BEGIN TRY
  --   BEGIN TRANSACTION;
  --   INSERT INTO dbo.PHANCONG (MaChuyenBay, MaNV, VaiTro, GioBatDau, GioKetThuc) VALUES
  --   ('QH156', 'NV01', N'Cơ trưởng', '2026-10-15 00:00:00', '2026-10-15 08:00:00'),
  --   ('QH312', 'NV01', N'Cơ trưởng', '2026-10-16 00:00:00', '2026-10-16 08:00:00'),
  --   ('QH402', 'NV01', N'Cơ trưởng', '2026-10-16 09:00:00', '2026-10-16 17:00:00'),
  --   ('QH510', 'NV01', N'Cơ trưởng', '2026-10-17 00:00:00', '2026-10-17 08:00:00');
  --   ROLLBACK TRANSACTION;
  -- END TRY
  -- BEGIN CATCH
  --   IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
  --   SELECT ERROR_NUMBER() AS MaLoi, ERROR_MESSAGE() AS KetQuaTestTG3;
  -- END CATCH;

  -- TG4: giảm giá Thương gia xuống bằng giá Phổ thông; mong đợi lỗi 51005.
  -- BEGIN TRY
  --   BEGIN TRANSACTION;
  --   UPDATE dbo.CHUYENBAY SET GiaVeThuongGia = GiaVePhoThong WHERE MaChuyenBay = 'VN716';
  -- END TRY
  -- BEGIN CATCH
  --   SELECT ERROR_NUMBER() AS MaLoi, ERROR_MESSAGE() AS KetQuaTestTG4;
  -- END CATCH;
  -- IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;

  -- TG5: tạm đưa chuyến VN716 về tương lai rồi xóa máy bay MB04; mong đợi lỗi 51006.
  -- BEGIN TRANSACTION;
  -- DECLARE @GioTuongLai DATETIME2(0) = DATEADD(DAY, 2, SYSUTCDATETIME());
  -- UPDATE dbo.CHUYENBAY SET GioKhoiHanhDK = @GioTuongLai,
  --        GioHaCanhDK = DATEADD(MINUTE, 80, @GioTuongLai), GioCatCanhTT = NULL, GioHaCanhTT = NULL
  -- WHERE MaChuyenBay = 'VN716';
  -- BEGIN TRY DELETE dbo.MAYBAY WHERE MaMayBay = 'MB04'; END TRY
  -- BEGIN CATCH SELECT ERROR_NUMBER() AS MaLoi, ERROR_MESSAGE() AS KetQuaTestTG5; END CATCH;
  -- IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
*/
