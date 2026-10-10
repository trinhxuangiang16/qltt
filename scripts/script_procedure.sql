SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

USE QL_CHUYENBAY;
GO

/* Nghiệp vụ: khách đặt chỗ và mua vé; nhân viên điều phối lịch bay/tổ bay;
   quản lý cập nhật Delay/Hủy; bộ phận báo cáo theo dõi doanh thu và khai thác. */

-- SP1: Tiếp nhận đặt chỗ, định giá vé theo hạng và để TG1 kiểm tra/giữ ghế.
CREATE OR ALTER PROCEDURE dbo.SP1_DATCHO_TAOVE
    @MaVe VARCHAR(20),
    @MaChuyenBay VARCHAR(5),
    @MaHanhKhach VARCHAR(10),
    @MaDatCho VARCHAR(20),
    @SoGhe VARCHAR(5),
    @HangGhe NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @HangGhe IS NULL OR @HangGhe NOT IN (N'Phổ thông', N'Thương gia')
        THROW 51101, N'SP1: Hạng ghế phải là Phổ thông hoặc Thương gia.', 1;

    DECLARE @GiaVe DECIMAL(12,2), @GioKhoiHanh DATETIME2(0), @TrangThai NVARCHAR(30), @SoGheTrong INT;
    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @GiaVe = CASE WHEN @HangGhe = N'Thương gia' THEN GiaVeThuongGia ELSE GiaVePhoThong END,
               @GioKhoiHanh = GioKhoiHanhDK,
               @TrangThai = TrangThai,
               @SoGheTrong = SoGheTrong
        FROM dbo.CHUYENBAY WITH (UPDLOCK, HOLDLOCK)
        WHERE MaChuyenBay = @MaChuyenBay;

        IF @GiaVe IS NULL
            THROW 51102, N'SP1: Không tìm thấy chuyến bay.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.HANHKHACH WHERE MaHanhKhach = @MaHanhKhach)
            THROW 51103, N'SP1: Không tìm thấy hành khách.', 1;
        IF @TrangThai IN (N'Đã hủy', N'Đã bay') OR @GioKhoiHanh <= SYSUTCDATETIME()
            THROW 51104, N'SP1: Chuyến bay đã hủy/khởi hành hoặc không còn nhận đặt chỗ.', 1;
        IF @SoGheTrong <= 0
            THROW 51105, N'SP1: Chuyến bay đã hết ghế trống.', 1;

        INSERT INTO dbo.VEBAY
            (MaVe, MaChuyenBay, MaHanhKhach, MaDatCho, SoGhe, HangGhe, GiaVe, NgayDat, TrangThaiVe)
        VALUES
            (@MaVe, @MaChuyenBay, @MaHanhKhach, @MaDatCho, @SoGhe, @HangGhe, @GiaVe, SYSDATETIME(), N'Chờ check-in');

        COMMIT TRANSACTION;
        SELECT @MaVe AS MaVe, @MaDatCho AS MaDatCho, @GiaVe AS GiaVe, N'Chờ check-in' AS TrangThaiVe;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- SP2: Đổi trạng thái Delay/Hủy, lưu lý do; hủy vé và ghi nhận hoàn tiền cùng giao dịch.
CREATE OR ALTER PROCEDURE dbo.SP2_DELAY_HUY
    @MaChuyenBay VARCHAR(5),
    @TrangThaiMoi NVARCHAR(30),
    @LyDo NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @TrangThaiMoi IS NULL OR @TrangThaiMoi NOT IN (N'Delay', N'Đã hủy')
        THROW 51110, N'SP2: Trạng thái mới chỉ được là Delay hoặc Đã hủy.', 1;
    IF @LyDo IS NULL OR NULLIF(LTRIM(RTRIM(@LyDo)), N'') IS NULL
        THROW 51111, N'SP2: Phải ghi lý do cập nhật trạng thái.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE dbo.CHUYENBAY
        SET TrangThai = @TrangThaiMoi, LyDoTrangThai = @LyDo
        WHERE MaChuyenBay = @MaChuyenBay;
        IF @@ROWCOUNT = 0 THROW 51112, N'SP2: Không tìm thấy chuyến bay.', 1;

        IF @TrangThaiMoi = N'Đã hủy'
        BEGIN
            UPDATE dbo.VEBAY
            SET TrangThaiVe = N'Đã hủy'
            WHERE MaChuyenBay = @MaChuyenBay AND TrangThaiVe <> N'Đã hủy';

            UPDATE hd
            SET TrangThaiThanhToan = N'Đã hoàn tiền'
            FROM dbo.HOADON hd
            JOIN dbo.VEBAY vb ON vb.MaVe = hd.MaVe
            WHERE vb.MaChuyenBay = @MaChuyenBay
              AND hd.TrangThaiThanhToan = N'Thành công';
        END;

        COMMIT TRANSACTION;
        SELECT MaChuyenBay, TrangThai, LyDoTrangThai
        FROM dbo.CHUYENBAY WHERE MaChuyenBay = @MaChuyenBay;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- SP3: Doanh thu theo chặng bay, tính khoảng ngày đóng [Từ ngày, Đến ngày].
CREATE OR ALTER PROCEDURE dbo.SP3_TINHDOANHTHU
    @TuNgay DATE,
    @DenNgay DATE
AS
BEGIN
    SET NOCOUNT ON;
    IF @TuNgay IS NULL OR @DenNgay IS NULL OR @TuNgay > @DenNgay
        THROW 51120, N'SP3: Khoảng ngày không hợp lệ.', 1;

    SELECT db.MaDuongBay, sbdi.MaSanBay AS MaSanBayDi, sbden.MaSanBay AS MaSanBayDen,
           SUM(hd.SoTien) AS TongDoanhThu, COUNT_BIG(*) AS SoVeThanhToan
    FROM dbo.HOADON hd
    JOIN dbo.VEBAY vb ON vb.MaVe = hd.MaVe
    JOIN dbo.CHUYENBAY cb ON cb.MaChuyenBay = vb.MaChuyenBay
    JOIN dbo.DUONGBAY db ON db.MaDuongBay = cb.MaDuongBay
    JOIN dbo.SANBAY sbdi ON sbdi.MaSanBay = db.MaSanBayDi
    JOIN dbo.SANBAY sbden ON sbden.MaSanBay = db.MaSanBayDen
    WHERE hd.TrangThaiThanhToan = N'Thành công'
      AND vb.TrangThaiVe <> N'Đã hủy'
      AND hd.NgayThanhToan >= @TuNgay
      AND hd.NgayThanhToan < DATEADD(DAY, 1, CONVERT(DATETIME2(0), @DenNgay))
    GROUP BY db.MaDuongBay, sbdi.MaSanBay, sbden.MaSanBay
    ORDER BY db.MaDuongBay;
END;
GO

-- SP4: Tra cứu chuyến theo sân bay đi/đến và ngày khởi hành.
CREATE OR ALTER PROCEDURE dbo.SP4_TRACUUDANHSACH
    @MaSanBayDi CHAR(3),
    @MaSanBayDen CHAR(3),
    @NgayBay DATE
AS
BEGIN
    SET NOCOUNT ON;
    IF @NgayBay IS NULL OR @MaSanBayDi IS NULL OR @MaSanBayDen IS NULL OR @MaSanBayDi = @MaSanBayDen
        THROW 51130, N'SP4: Sân bay hoặc ngày tra cứu không hợp lệ.', 1;

    SELECT cb.MaChuyenBay, cb.MaDuongBay, db.MaSanBayDi, sbdi.TenSanBay AS SanBayDi,
           db.MaSanBayDen, sbden.TenSanBay AS SanBayDen, cb.MaMayBay,
           cb.GioKhoiHanhDK, cb.GioHaCanhDK, cb.GiaVePhoThong, cb.GiaVeThuongGia,
           cb.SoGheTrong, cb.TrangThai
    FROM dbo.CHUYENBAY cb
    JOIN dbo.DUONGBAY db ON db.MaDuongBay = cb.MaDuongBay
    JOIN dbo.SANBAY sbdi ON sbdi.MaSanBay = db.MaSanBayDi
    JOIN dbo.SANBAY sbden ON sbden.MaSanBay = db.MaSanBayDen
    WHERE db.MaSanBayDi = @MaSanBayDi
      AND db.MaSanBayDen = @MaSanBayDen
      AND cb.GioKhoiHanhDK >= @NgayBay
      AND cb.GioKhoiHanhDK < DATEADD(DAY, 1, CONVERT(DATETIME2(0), @NgayBay))
    ORDER BY cb.GioKhoiHanhDK;
END;
GO

-- SP5: Phân công tổ bay, xác thực vai trò và tối thiểu 8 giờ nghỉ giữa hai ca.
CREATE OR ALTER PROCEDURE dbo.SP5_PHANCONGTOBAY
    @MaChuyenBay VARCHAR(5),
    @MaNV VARCHAR(10),
    @VaiTro NVARCHAR(30),
    @GioBatDauMoi DATETIME2(0),
    @GioKetThucMoi DATETIME2(0)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @GioBatDauMoi IS NULL OR @GioKetThucMoi IS NULL OR @GioKetThucMoi <= @GioBatDauMoi
        THROW 51140, N'SP5: Khoảng thời gian phân công không hợp lệ.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS (
            SELECT 1 FROM dbo.NHANVIEN WITH (UPDLOCK, HOLDLOCK)
            WHERE MaNV = @MaNV AND TrangThai = N'Đang làm việc' AND ChucVu = @VaiTro
        )
            THROW 51141, N'SP5: Nhân viên không hoạt động hoặc chức vụ không khớp vai trò.', 1;

        IF NOT EXISTS (
            SELECT 1 FROM dbo.CHUYENBAY
            WHERE MaChuyenBay = @MaChuyenBay AND TrangThai <> N'Đã hủy'
              AND @GioBatDauMoi >= DATEADD(HOUR, -3, GioKhoiHanhDK)
              AND @GioKetThucMoi <= DATEADD(HOUR, 3, GioHaCanhDK)
        )
            THROW 51142, N'SP5: Không tìm thấy chuyến bay hoặc ca trực không khớp thời gian chuyến bay.', 1;

        IF EXISTS (
            SELECT 1 FROM dbo.PHANCONG WITH (UPDLOCK, HOLDLOCK)
            WHERE MaNV = @MaNV
              AND GioBatDau < @GioKetThucMoi AND GioKetThuc > @GioBatDauMoi
        )
            THROW 51143, N'SP5: Ca trực bị trùng với một phân công khác.', 1;

        IF EXISTS (
            SELECT 1 FROM dbo.PHANCONG WITH (UPDLOCK, HOLDLOCK)
            WHERE MaNV = @MaNV AND GioKetThuc <= @GioBatDauMoi
              AND DATEDIFF(MINUTE, GioKetThuc, @GioBatDauMoi) < 480
        ) OR EXISTS (
            SELECT 1 FROM dbo.PHANCONG WITH (UPDLOCK, HOLDLOCK)
            WHERE MaNV = @MaNV AND GioBatDau >= @GioKetThucMoi
              AND DATEDIFF(MINUTE, @GioKetThucMoi, GioBatDau) < 480
        )
            THROW 51144, N'SP5: Thời gian nghỉ giữa hai ca phải tối thiểu 8 giờ.', 1;

        INSERT INTO dbo.PHANCONG (MaChuyenBay, MaNV, VaiTro, GioBatDau, GioKetThuc)
        VALUES (@MaChuyenBay, @MaNV, @VaiTro, @GioBatDauMoi, @GioKetThucMoi);

        COMMIT TRANSACTION;
        SELECT MaChuyenBay, MaNV, VaiTro, GioBatDau, GioKetThuc
        FROM dbo.PHANCONG WHERE MaChuyenBay = @MaChuyenBay AND MaNV = @MaNV;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- FN1 (Scalar): cộng chi tiêu vé đã thanh toán, chưa hoàn/hủy để xếp hạng hội viên.
-- Ngưỡng demo: Bạc từ 5 triệu; Vàng từ 20 triệu; Kim Cương từ 50 triệu đồng.
CREATE OR ALTER FUNCTION dbo.FN1_HangHoiVien(@MaHanhKhach VARCHAR(10))
RETURNS NVARCHAR(20)
AS
BEGIN
    DECLARE @TongChi DECIMAL(18,2) = 0;
    SELECT @TongChi = COALESCE(SUM(hd.SoTien), 0)
    FROM dbo.HOADON hd
    JOIN dbo.VEBAY vb ON vb.MaVe = hd.MaVe
    WHERE vb.MaHanhKhach = @MaHanhKhach
      AND vb.TrangThaiVe <> N'Đã hủy'
      AND hd.TrangThaiThanhToan = N'Thành công';

    RETURN CASE
        WHEN @TongChi >= 50000000 THEN N'Kim Cương'
        WHEN @TongChi >= 20000000 THEN N'Vàng'
        WHEN @TongChi >= 5000000 THEN N'Bạc'
        ELSE N'Chưa xếp hạng'
    END;
END;
GO

-- FN2 (Inline table-valued): danh sách ghế trống theo sơ đồ hàng 01..n và cột A-F.
CREATE OR ALTER FUNCTION dbo.FN2_DanhSachGheTrong(@MaChuyenBay VARCHAR(5))
RETURNS TABLE
AS
RETURN
(
    SELECT RIGHT('00' + CONVERT(VARCHAR(10), ((n.SoThuTu - 1) / 6) + 1), 2)
           + CHAR(65 + ((n.SoThuTu - 1) % 6)) AS SoGhe
    FROM dbo.CHUYENBAY cb
    JOIN dbo.MAYBAY mb ON mb.MaMayBay = cb.MaMayBay
    CROSS APPLY (
        SELECT TOP (mb.SoGhe) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS SoThuTu
        FROM sys.all_objects a CROSS JOIN sys.all_objects b
    ) n
    WHERE cb.MaChuyenBay = @MaChuyenBay
      AND cb.TrangThai NOT IN (N'Đã hủy', N'Đã bay')
      AND NOT EXISTS (
          SELECT 1 FROM dbo.VEBAY vb
          WHERE vb.MaChuyenBay = cb.MaChuyenBay
            AND vb.SoGhe = RIGHT('00' + CONVERT(VARCHAR(10), ((n.SoThuTu - 1) / 6) + 1), 2)
                          + CHAR(65 + ((n.SoThuTu - 1) % 6))
            AND vb.TrangThaiVe <> N'Đã hủy'
      )
);
GO

-- FN3 (Inline table-valued): số chuyến và giờ khai thác lũy kế của máy bay trong tháng.
CREATE OR ALTER FUNCTION dbo.FN3_ThongKeMayBayTheoThang
    (@MaMayBay VARCHAR(10), @Nam INT, @Thang INT)
RETURNS TABLE
AS
RETURN
(
    SELECT mb.MaMayBay, mb.SoHieu,
           COUNT_BIG(cb.MaChuyenBay) AS TanSuatChuyenBay,
           CONVERT(DECIMAL(12,2), COALESCE(SUM(
               DATEDIFF(MINUTE,
                   COALESCE(cb.GioCatCanhTT, cb.GioKhoiHanhDK),
                   COALESCE(cb.GioHaCanhTT, cb.GioHaCanhDK)) / 60.0
           ), 0)) AS TongGioBay
    FROM dbo.MAYBAY mb
    LEFT JOIN dbo.CHUYENBAY cb
      ON cb.MaMayBay = mb.MaMayBay
     AND cb.TrangThai <> N'Đã hủy'
     AND cb.GioKhoiHanhDK >= DATEFROMPARTS(@Nam, @Thang, 1)
     AND cb.GioKhoiHanhDK < DATEADD(MONTH, 1, DATEFROMPARTS(@Nam, @Thang, 1))
    WHERE mb.MaMayBay = @MaMayBay AND @Thang BETWEEN 1 AND 12
    GROUP BY mb.MaMayBay, mb.SoHieu
);
GO

-- CS1: Cursor duyệt chuyến Delay, tính mức bồi thường theo phút trễ và số vé còn hiệu lực.
CREATE OR ALTER PROCEDURE dbo.CS1_TinhBoiThuongChuyenBayDelay
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MaChuyenBay VARCHAR(5), @SoPhutTre INT, @SoHanhKhach INT;
    DECLARE @MucMoiKhach DECIMAL(12,2);
    DECLARE @KetQua TABLE (
        MaChuyenBay VARCHAR(5), SoPhutTre INT, SoHanhKhach INT,
        BoiThuongMoiKhach DECIMAL(12,2), TongBoiThuong DECIMAL(18,2)
    );

    DECLARE curDelay CURSOR LOCAL FAST_FORWARD FOR
        SELECT MaChuyenBay,
               CASE WHEN GioCatCanhTT IS NOT NULL
                          THEN CASE WHEN DATEDIFF(MINUTE, GioKhoiHanhDK, GioCatCanhTT) > 0
                                    THEN DATEDIFF(MINUTE, GioKhoiHanhDK, GioCatCanhTT) ELSE 0 END
                    ELSE SoPhutTre END
        FROM dbo.CHUYENBAY
        WHERE TrangThai = N'Delay';

    OPEN curDelay;
    FETCH NEXT FROM curDelay INTO @MaChuyenBay, @SoPhutTre;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT @SoHanhKhach = COUNT(*)
        FROM dbo.VEBAY
        WHERE MaChuyenBay = @MaChuyenBay AND TrangThaiVe <> N'Đã hủy';

        SET @MucMoiKhach = CASE
            WHEN @SoPhutTre >= 240 THEN 1000000
            WHEN @SoPhutTre >= 120 THEN 500000
            WHEN @SoPhutTre >= 60 THEN 200000
            WHEN @SoPhutTre >= 30 THEN 100000
            ELSE 0 END;

        INSERT INTO @KetQua
        VALUES (@MaChuyenBay, @SoPhutTre, @SoHanhKhach, @MucMoiKhach, @MucMoiKhach * @SoHanhKhach);
        FETCH NEXT FROM curDelay INTO @MaChuyenBay, @SoPhutTre;
    END;
    CLOSE curDelay;
    DEALLOCATE curDelay;

    SELECT MaChuyenBay, SoPhutTre, SoHanhKhach, BoiThuongMoiKhach, TongBoiThuong
    FROM @KetQua ORDER BY MaChuyenBay;
END;
GO

-- CS2: Cursor tổng hợp công nhật và phụ cấp theo nhân viên/ngày/loại vai trò.
-- Đơn giá/định mức phụ cấp bên dưới là giả định minh họa, cần thay theo chính sách hãng bay.
CREATE OR ALTER PROCEDURE dbo.CS2_TongHopCongNhatPhuCap
    @TuNgay DATE,
    @DenNgay DATE
AS
BEGIN
    SET NOCOUNT ON;
    IF @TuNgay IS NULL OR @DenNgay IS NULL OR @TuNgay > @DenNgay
        THROW 51150, N'CS2: Khoảng ngày không hợp lệ.', 1;

    DECLARE @MaNV VARCHAR(10), @HoTen NVARCHAR(100), @NgayCong DATE, @VaiTro NVARCHAR(30);
    DECLARE @SoChuyen INT, @SoGio DECIMAL(10,2), @DonGiaGio DECIMAL(12,2), @PhuCapMoiChuyen DECIMAL(12,2);
    DECLARE @KetQua TABLE (
        MaNV VARCHAR(10), HoTen NVARCHAR(100), NgayCong DATE, VaiTro NVARCHAR(30),
        SoChuyen INT, SoGio DECIMAL(10,2), CongNhat DECIMAL(18,2), PhuCap DECIMAL(18,2), TongThanhToan DECIMAL(18,2)
    );

    DECLARE curCrew CURSOR LOCAL FAST_FORWARD FOR
        SELECT pc.MaNV, nv.HoTen, CONVERT(DATE, pc.GioBatDau), pc.VaiTro,
               COUNT(*), CONVERT(DECIMAL(10,2), SUM(DATEDIFF(MINUTE, pc.GioBatDau, pc.GioKetThuc) / 60.0))
        FROM dbo.PHANCONG pc
        JOIN dbo.NHANVIEN nv ON nv.MaNV = pc.MaNV
        WHERE pc.GioBatDau >= @TuNgay
          AND pc.GioBatDau < DATEADD(DAY, 1, CONVERT(DATETIME2(0), @DenNgay))
        GROUP BY pc.MaNV, nv.HoTen, CONVERT(DATE, pc.GioBatDau), pc.VaiTro
        ORDER BY CONVERT(DATE, pc.GioBatDau), pc.MaNV;

    OPEN curCrew;
    FETCH NEXT FROM curCrew INTO @MaNV, @HoTen, @NgayCong, @VaiTro, @SoChuyen, @SoGio;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @DonGiaGio = CASE
            WHEN @VaiTro IN (N'Cơ trưởng', N'Cơ phó') THEN 300000
            WHEN @VaiTro = N'Tiếp viên trưởng' THEN 180000
            ELSE 150000 END;
        SET @PhuCapMoiChuyen = CASE
            WHEN @VaiTro IN (N'Cơ trưởng', N'Cơ phó') THEN 500000
            WHEN @VaiTro = N'Tiếp viên trưởng' THEN 300000
            ELSE 200000 END;

        INSERT INTO @KetQua
        VALUES (@MaNV, @HoTen, @NgayCong, @VaiTro, @SoChuyen, @SoGio,
                @SoGio * @DonGiaGio, @SoChuyen * @PhuCapMoiChuyen,
                (@SoGio * @DonGiaGio) + (@SoChuyen * @PhuCapMoiChuyen));
        FETCH NEXT FROM curCrew INTO @MaNV, @HoTen, @NgayCong, @VaiTro, @SoChuyen, @SoGio;
    END;
    CLOSE curCrew;
    DEALLOCATE curCrew;

    SELECT MaNV, HoTen, NgayCong, VaiTro, SoChuyen, SoGio, CongNhat, PhuCap, TongThanhToan
    FROM @KetQua ORDER BY NgayCong, MaNV;
END;
GO

/* Ví dụ sử dụng functions/cursors:
   SELECT dbo.FN1_HangHoiVien('HK01') AS HangHoiVien;
   SELECT * FROM dbo.FN2_DanhSachGheTrong('VN716') ORDER BY SoGhe;
   SELECT * FROM dbo.FN3_ThongKeMayBayTheoThang('MB01', 2026, 10);
   EXEC dbo.CS1_TinhBoiThuongChuyenBayDelay;
   EXEC dbo.CS2_TongHopCongNhatPhuCap '2026-10-01', '2026-10-31';
*/

/* REPORTS 1-5: mỗi báo cáo trả Header, Detail, Footer để đưa vào Report Designer.
   Bố cục 5 vùng khi dựng report: Report Header, Page Header, Detail, Page Footer, Report Footer.
   Page Header/Footer (tiêu đề cột, số trang, phân trang) do Report Designer kết xuất.
*/

-- Report 1: Vé điện tử (E-ticket).
DECLARE @R1_MaVe VARCHAR(20) = 'VE01';
SELECT N'HEADER' AS Phan, N'Vé điện tử (giờ UTC)' AS TieuDe, vb.MaVe, vb.MaDatCho, cb.MaChuyenBay
FROM dbo.VEBAY vb JOIN dbo.CHUYENBAY cb ON cb.MaChuyenBay = vb.MaChuyenBay
WHERE vb.MaVe = @R1_MaVe;
SELECT N'DETAIL' AS Phan, hk.HoTen, hk.SoGiayTo, vb.SoGhe, vb.HangGhe, vb.GiaVe,
       cb.GioKhoiHanhDK, cb.GioHaCanhDK, sbdi.MaSanBay AS SanBayDi, sbden.MaSanBay AS SanBayDen
FROM dbo.VEBAY vb
JOIN dbo.HANHKHACH hk ON hk.MaHanhKhach = vb.MaHanhKhach
JOIN dbo.CHUYENBAY cb ON cb.MaChuyenBay = vb.MaChuyenBay
JOIN dbo.DUONGBAY db ON db.MaDuongBay = cb.MaDuongBay
JOIN dbo.SANBAY sbdi ON sbdi.MaSanBay = db.MaSanBayDi
JOIN dbo.SANBAY sbden ON sbden.MaSanBay = db.MaSanBayDen
WHERE vb.MaVe = @R1_MaVe;
SELECT N'FOOTER' AS Phan, vb.TrangThaiVe, hd.TrangThaiThanhToan, hd.NgayThanhToan, hd.SoTien
FROM dbo.VEBAY vb LEFT JOIN dbo.HOADON hd ON hd.MaVe = vb.MaVe
WHERE vb.MaVe = @R1_MaVe;
GO

-- Report 2: Danh sách hành khách chuyến bay (Passenger Manifest).
DECLARE @R2_MaChuyenBay VARCHAR(5) = 'VN214';
SELECT N'HEADER' AS Phan, N'Passenger Manifest (giờ UTC)' AS TieuDe, cb.MaChuyenBay,
       db.MaSanBayDi, db.MaSanBayDen, cb.GioKhoiHanhDK
FROM dbo.CHUYENBAY cb JOIN dbo.DUONGBAY db ON db.MaDuongBay = cb.MaDuongBay
WHERE cb.MaChuyenBay = @R2_MaChuyenBay;
SELECT N'DETAIL' AS Phan, vb.MaVe, vb.SoGhe, vb.HangGhe, vb.TrangThaiVe,
       hk.HoTen, hk.NgaySinh, hk.SoGiayTo, hk.QuocTich, hk.SoDienThoai
FROM dbo.VEBAY vb JOIN dbo.HANHKHACH hk ON hk.MaHanhKhach = vb.MaHanhKhach
WHERE vb.MaChuyenBay = @R2_MaChuyenBay AND vb.TrangThaiVe <> N'Đã hủy'
ORDER BY vb.SoGhe;
SELECT N'FOOTER' AS Phan, COUNT(*) AS TongHanhKhach,
       SUM(CASE WHEN TrangThaiVe = N'Đã check-in' THEN 1 ELSE 0 END) AS DaCheckIn
FROM dbo.VEBAY WHERE MaChuyenBay = @R2_MaChuyenBay AND TrangThaiVe <> N'Đã hủy';
GO

-- Report 3: Bảng phân công phi hành đoàn theo ngày.
DECLARE @R3_Ngay DATE = '2026-10-14';
SELECT N'HEADER' AS Phan, N'Phân công phi hành đoàn (giờ UTC)' AS TieuDe, @R3_Ngay AS NgayBaoCao;
SELECT N'DETAIL' AS Phan, pc.MaChuyenBay, cb.GioKhoiHanhDK, pc.MaNV, nv.HoTen,
       pc.VaiTro, pc.GioBatDau, pc.GioKetThuc,
       CONVERT(DECIMAL(10,2), DATEDIFF(MINUTE, pc.GioBatDau, pc.GioKetThuc) / 60.0) AS SoGio
FROM dbo.PHANCONG pc JOIN dbo.NHANVIEN nv ON nv.MaNV = pc.MaNV
JOIN dbo.CHUYENBAY cb ON cb.MaChuyenBay = pc.MaChuyenBay
WHERE CONVERT(DATE, pc.GioBatDau) = @R3_Ngay
ORDER BY pc.GioBatDau, pc.MaChuyenBay;
SELECT N'FOOTER' AS Phan, COUNT(*) AS SoPhanCong, COUNT(DISTINCT MaChuyenBay) AS SoChuyenBay,
       CONVERT(DECIMAL(10,2), COALESCE(SUM(DATEDIFF(MINUTE, GioBatDau, GioKetThuc)) / 60.0, 0)) AS TongGioCong
FROM dbo.PHANCONG WHERE CONVERT(DATE, GioBatDau) = @R3_Ngay;
GO

-- Report 4: Báo cáo doanh số theo đường bay trong khoảng ngày.
DECLARE @R4_TuNgay DATE = '2026-10-01', @R4_DenNgay DATE = '2026-10-31';
SELECT N'HEADER' AS Phan, N'Doanh số theo đường bay' AS TieuDe, @R4_TuNgay AS TuNgay, @R4_DenNgay AS DenNgay;
SELECT N'DETAIL' AS Phan, db.MaDuongBay, db.MaSanBayDi, db.MaSanBayDen,
       COUNT(hd.MaHoaDon) AS SoGiaoDich, COALESCE(SUM(hd.SoTien), 0) AS DoanhThu
FROM dbo.DUONGBAY db
LEFT JOIN dbo.CHUYENBAY cb ON cb.MaDuongBay = db.MaDuongBay
LEFT JOIN dbo.VEBAY vb ON vb.MaChuyenBay = cb.MaChuyenBay AND vb.TrangThaiVe <> N'Đã hủy'
LEFT JOIN dbo.HOADON hd ON hd.MaVe = vb.MaVe AND hd.TrangThaiThanhToan = N'Thành công'
                         AND hd.NgayThanhToan >= @R4_TuNgay
                         AND hd.NgayThanhToan < DATEADD(DAY, 1, CONVERT(DATETIME2(0), @R4_DenNgay))
GROUP BY db.MaDuongBay, db.MaSanBayDi, db.MaSanBayDen
ORDER BY db.MaDuongBay;
SELECT N'FOOTER' AS Phan, COUNT(*) AS SoHoaDon, COALESCE(SUM(hd.SoTien), 0) AS TongDoanhThu
FROM dbo.HOADON hd
JOIN dbo.VEBAY vb ON vb.MaVe = hd.MaVe
WHERE hd.TrangThaiThanhToan = N'Thành công'
  AND vb.TrangThaiVe <> N'Đã hủy'
  AND hd.NgayThanhToan >= @R4_TuNgay
  AND hd.NgayThanhToan < DATEADD(DAY, 1, CONVERT(DATETIME2(0), @R4_DenNgay));
GO

-- Report 5: Hiệu suất khai thác theo trạng thái đúng giờ, hoãn, hủy.
DECLARE @R5_TuNgay DATE = '2026-10-01', @R5_DenNgay DATE = '2026-10-31';
SELECT N'HEADER' AS Phan, N'Hiệu suất khai thác' AS TieuDe, @R5_TuNgay AS TuNgay, @R5_DenNgay AS DenNgay;
SELECT N'DETAIL' AS Phan, TrangThai, COUNT(*) AS SoChuyenBay,
       CONVERT(DECIMAL(6,2), 100.0 * COUNT(*) / NULLIF(SUM(COUNT(*)) OVER (), 0)) AS TyLePhanTram
FROM dbo.CHUYENBAY
WHERE GioKhoiHanhDK >= @R5_TuNgay
  AND GioKhoiHanhDK < DATEADD(DAY, 1, CONVERT(DATETIME2(0), @R5_DenNgay))
GROUP BY TrangThai
ORDER BY TrangThai;
SELECT N'FOOTER' AS Phan, COUNT(*) AS TongChuyenBay,
       SUM(CASE WHEN TrangThai = N'Đúng giờ' OR
                     (TrangThai = N'Đã bay' AND GioCatCanhTT IS NOT NULL
                      AND DATEDIFF(MINUTE, GioKhoiHanhDK, GioCatCanhTT) <= 15)
                THEN 1 ELSE 0 END) AS DungGio,
       SUM(CASE WHEN TrangThai = N'Delay' OR
                     (GioCatCanhTT IS NOT NULL AND DATEDIFF(MINUTE, GioKhoiHanhDK, GioCatCanhTT) > 15)
                THEN 1 ELSE 0 END) AS Hoan,
       SUM(CASE WHEN TrangThai = N'Đã hủy' THEN 1 ELSE 0 END) AS Huy
FROM dbo.CHUYENBAY
WHERE GioKhoiHanhDK >= @R5_TuNgay
  AND GioKhoiHanhDK < DATEADD(DAY, 1, CONVERT(DATETIME2(0), @R5_DenNgay));
GO

-- Bảo mật theo vai trò; quản trị viên gán user/login của đơn vị vào các role này.
IF DATABASE_PRINCIPAL_ID(N'QLCB_QuanTri') IS NULL CREATE ROLE QLCB_QuanTri;
IF DATABASE_PRINCIPAL_ID(N'QLCB_BanVe') IS NULL CREATE ROLE QLCB_BanVe;
IF DATABASE_PRINCIPAL_ID(N'QLCB_DieuPhoi') IS NULL CREATE ROLE QLCB_DieuPhoi;
IF DATABASE_PRINCIPAL_ID(N'QLCB_BaoCao') IS NULL CREATE ROLE QLCB_BaoCao;
GO
GRANT CONTROL ON DATABASE::QL_CHUYENBAY TO QLCB_QuanTri;
GRANT EXECUTE ON OBJECT::dbo.SP1_DATCHO_TAOVE TO QLCB_BanVe;
GRANT EXECUTE ON OBJECT::dbo.SP4_TRACUUDANHSACH TO QLCB_BanVe;
GRANT SELECT ON OBJECT::dbo.FN2_DanhSachGheTrong TO QLCB_BanVe;
GRANT EXECUTE ON OBJECT::dbo.SP2_DELAY_HUY TO QLCB_DieuPhoi;
GRANT EXECUTE ON OBJECT::dbo.SP5_PHANCONGTOBAY TO QLCB_DieuPhoi;
GRANT EXECUTE ON OBJECT::dbo.CS1_TinhBoiThuongChuyenBayDelay TO QLCB_DieuPhoi;
GRANT EXECUTE ON OBJECT::dbo.CS2_TongHopCongNhatPhuCap TO QLCB_DieuPhoi;
GRANT SELECT ON SCHEMA::dbo TO QLCB_BaoCao;
GRANT EXECUTE ON OBJECT::dbo.SP3_TINHDOANHTHU TO QLCB_BaoCao;
GRANT EXECUTE ON OBJECT::dbo.FN1_HangHoiVien TO QLCB_BaoCao;
GRANT SELECT ON OBJECT::dbo.FN3_ThongKeMayBayTheoThang TO QLCB_BaoCao;
GO

/*
  Gán người dùng (thay [TenUser] bằng database user đã được DBA tạo):
  ALTER ROLE QLCB_BanVe ADD MEMBER [TenUser];
  ALTER ROLE QLCB_DieuPhoi ADD MEMBER [TenUser];
  ALTER ROLE QLCB_BaoCao ADD MEMBER [TenUser];

  Import CSV into SQL Server Docker (copy the file into the container first):
  docker cp HANHKHACH.csv sqlserver_qlcb:/var/opt/mssql/data/HANHKHACH.csv
  BULK INSERT dbo.HANHKHACH
  FROM '/var/opt/mssql/data/HANHKHACH.csv'
  WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', TABLOCK);

  Export CSV from the host (requires bcp; replace the password and output folder):
  bcp "SELECT MaChuyenBay, GioKhoiHanhDK, TrangThai FROM QL_CHUYENBAY.dbo.CHUYENBAY" queryout "C:\Data\CHUYENBAY.csv" -c -C 65001 -t, -S localhost,1433 -U sa -P "<SA_PASSWORD>"

  Backup/restore in SQL Server Docker (backup file stays in the mssql_data Docker volume):
  BACKUP DATABASE QL_CHUYENBAY TO DISK = N'/var/opt/mssql/data/QL_CHUYENBAY.bak' WITH INIT, CHECKSUM;
  RESTORE VERIFYONLY FROM DISK = N'/var/opt/mssql/data/QL_CHUYENBAY.bak' WITH CHECKSUM;
  -- Restore the same database only when needed; connect to master and stop app connections first:
  -- USE master;
  -- ALTER DATABASE QL_CHUYENBAY SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
  -- RESTORE DATABASE QL_CHUYENBAY FROM DISK = N'/var/opt/mssql/data/QL_CHUYENBAY.bak' WITH REPLACE, CHECKSUM;
  -- ALTER DATABASE QL_CHUYENBAY SET MULTI_USER;
*/
