/*
  DEMO QUAN LY CHUYEN BAY - SQL Server 2017+
  Chạy một lần bằng SSMS/sqlcmd trên database mới.
  Thứ tự: DDL -> trigger -> dữ liệu mẫu -> SP/function/cursor/report/security.
  Có 9 bảng, 5 stored procedures, 5 triggers,
  3 functions, 2 cursors và 5 bộ truy vấn báo cáo Header/Detail/Footer.
*/
-- BEGIN scripts/script_create_db.sql
/*
  QL_CHUYENBAY - DDL / data dictionary
  Chạy script này trước. Chín quan hệ chính:
    SANBAY 1--N DUONGBAY (đi và đến); DUONGBAY 1--N CHUYENBAY;
    MAYBAY 1--N CHUYENBAY; CHUYENBAY N--N NHANVIEN qua PHANCONG;
    CHUYENBAY 1--N VEBAY; HANHKHACH 1--N VEBAY; VEBAY 1--0..1 HOADON.
  MaSanBay lưu mã IATA 3 ký tự; MaChuyenBay dùng mã hãng 2 ký tự + 3 chữ số.
  Các cột ngày giờ chuyến bay/tổ bay lưu theo UTC; MuiGio là metadata để ứng dụng hiển thị giờ địa phương.
  Mục tiêu: quản lý sân bay, đội bay, lịch/chặng bay, đặt vé, hóa đơn và phân công tổ bay.
  Đối tượng: khách đặt vé; nhân viên bán vé; điều phối viên; kế toán/báo cáo; quản trị CSDL.
  Quy trình chính: tra cứu chuyến -> đặt chỗ/xuất vé -> thanh toán/check-in -> khai thác,
  cập nhật Delay/Hủy -> hoàn vé/ghế -> tổng hợp doanh thu, công nhật và hiệu suất.
  ERD (Mermaid):
    erDiagram
      SANBAY ||--o{ DUONGBAY : diem_di_hoac_den
      DUONGBAY ||--o{ CHUYENBAY : khai_thac
      MAYBAY ||--o{ CHUYENBAY : phuc_vu
      CHUYENBAY ||--o{ PHANCONG : co
      NHANVIEN ||--o{ PHANCONG : duoc_phan_cong
      CHUYENBAY ||--o{ VEBAY : phat_hanh
      HANHKHACH ||--o{ VEBAY : so_huu
      VEBAY ||--o| HOADON : thanh_toan
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
GO

IF DB_ID(N'QL_CHUYENBAY') IS NULL
    EXEC(N'CREATE DATABASE QL_CHUYENBAY');
GO

USE QL_CHUYENBAY;
GO

CREATE TABLE dbo.SANBAY (
    MaSanBay CHAR(3) NOT NULL,
    TenSanBay NVARCHAR(120) NOT NULL,
    ThanhPho NVARCHAR(80) NOT NULL,
    QuocGia NVARCHAR(80) NOT NULL,
    MuiGio VARCHAR(40) NOT NULL,
    ViDo DECIMAL(9,6) NULL,
    KinhDo DECIMAL(9,6) NULL,
    CONSTRAINT PK_SANBAY PRIMARY KEY (MaSanBay),
    CONSTRAINT CK_SANBAY_MaIATA CHECK (MaSanBay LIKE '[A-Z][A-Z][A-Z]'),
    CONSTRAINT CK_SANBAY_ViDo CHECK (ViDo IS NULL OR ViDo BETWEEN -90 AND 90),
    CONSTRAINT CK_SANBAY_KinhDo CHECK (KinhDo IS NULL OR KinhDo BETWEEN -180 AND 180)
);
GO

CREATE TABLE dbo.DUONGBAY (
    MaDuongBay VARCHAR(10) NOT NULL,
    MaSanBayDi CHAR(3) NOT NULL,
    MaSanBayDen CHAR(3) NOT NULL,
    ThoiGianBayDuKien INT NOT NULL, -- phút bay thực tế, không gồm chênh lệch múi giờ
    CONSTRAINT PK_DUONGBAY PRIMARY KEY (MaDuongBay),
    CONSTRAINT FK_DUONGBAY_SanBayDi FOREIGN KEY (MaSanBayDi) REFERENCES dbo.SANBAY(MaSanBay),
    CONSTRAINT FK_DUONGBAY_SanBayDen FOREIGN KEY (MaSanBayDen) REFERENCES dbo.SANBAY(MaSanBay),
    CONSTRAINT UQ_DUONGBAY_CapSanBay UNIQUE (MaSanBayDi, MaSanBayDen),
    CONSTRAINT CK_DUONGBAY_ThoiGianBay CHECK (ThoiGianBayDuKien BETWEEN 1 AND 1440),
    CONSTRAINT CK_DUONGBAY_SanBayKhacNhau CHECK (MaSanBayDi <> MaSanBayDen)
);
GO

CREATE TABLE dbo.MAYBAY (
    MaMayBay VARCHAR(10) NOT NULL,
    SoHieu VARCHAR(20) NOT NULL,
    LoaiMayBay NVARCHAR(60) NOT NULL,
    SoGhe INT NOT NULL,
    TrangThai NVARCHAR(30) NOT NULL,
    CONSTRAINT PK_MAYBAY PRIMARY KEY (MaMayBay),
    CONSTRAINT UQ_MAYBAY_SoHieu UNIQUE (SoHieu),
    CONSTRAINT CK_MAYBAY_SoGhe CHECK (SoGhe > 0),
    CONSTRAINT CK_MAYBAY_TrangThai CHECK (TrangThai IN (N'Sẵn sàng khai thác', N'Bảo dưỡng định kỳ'))
);
GO

CREATE TABLE dbo.CHUYENBAY (
    MaChuyenBay VARCHAR(5) NOT NULL,
    MaDuongBay VARCHAR(10) NOT NULL,
    MaMayBay VARCHAR(10) NOT NULL,
    GioKhoiHanhDK DATETIME2(0) NOT NULL,
    GioHaCanhDK DATETIME2(0) NOT NULL,
    GioCatCanhTT DATETIME2(0) NULL,
    GioHaCanhTT DATETIME2(0) NULL,
    GiaVePhoThong DECIMAL(12,2) NOT NULL,
    GiaVeThuongGia DECIMAL(12,2) NOT NULL,
    SoGheTrong INT NOT NULL,
    TrangThai NVARCHAR(30) NOT NULL,
    LyDoTrangThai NVARCHAR(500) NULL,
    SoPhutTre INT NOT NULL CONSTRAINT DF_CHUYENBAY_SoPhutTre DEFAULT (0),
    CONSTRAINT PK_CHUYENBAY PRIMARY KEY (MaChuyenBay),
    CONSTRAINT FK_CHUYENBAY_DuongBay FOREIGN KEY (MaDuongBay) REFERENCES dbo.DUONGBAY(MaDuongBay),
    CONSTRAINT FK_CHUYENBAY_MayBay FOREIGN KEY (MaMayBay) REFERENCES dbo.MAYBAY(MaMayBay),
    CONSTRAINT CK_CHUYENBAY_MaIATA CHECK (MaChuyenBay LIKE '[A-Z][A-Z][0-9][0-9][0-9]'),
    CONSTRAINT CK_CHUYENBAY_ThoiGianBay CHECK (GioHaCanhDK > GioKhoiHanhDK),
    CONSTRAINT CK_CHUYENBAY_GiaVePhoThong CHECK (GiaVePhoThong > 0),
    CONSTRAINT CK_CHUYENBAY_GiaVeThuongGia CHECK (GiaVeThuongGia > 0),
    CONSTRAINT CK_CHUYENBAY_SoGheTrong CHECK (SoGheTrong >= 0),
    CONSTRAINT CK_CHUYENBAY_SoPhutTre CHECK (SoPhutTre >= 0),
    CONSTRAINT CK_CHUYENBAY_TrangThai CHECK (TrangThai IN (N'Lên lịch', N'Đúng giờ', N'Delay', N'Đã hủy', N'Đã bay')),
    CONSTRAINT CK_CHUYENBAY_ThoiGianThuc CHECK (
        (GioCatCanhTT IS NULL AND GioHaCanhTT IS NULL)
        OR (GioCatCanhTT IS NOT NULL AND GioHaCanhTT IS NOT NULL AND GioHaCanhTT > GioCatCanhTT)
    )
);
GO

CREATE TABLE dbo.NHANVIEN (
    MaNV VARCHAR(10) NOT NULL,
    HoTen NVARCHAR(100) NOT NULL,
    NgaySinh DATE NOT NULL,
    GioiTinh NVARCHAR(10) NOT NULL,
    SoDienThoai VARCHAR(15) NULL,
    Email VARCHAR(100) NULL,
    ChucVu NVARCHAR(50) NOT NULL,
    TrangThai NVARCHAR(30) NOT NULL,
    CONSTRAINT PK_NHANVIEN PRIMARY KEY (MaNV),
    CONSTRAINT CK_NHANVIEN_GioiTinh CHECK (GioiTinh IN (N'Nam', N'Nữ')),
    CONSTRAINT CK_NHANVIEN_ChucVu CHECK (ChucVu IN (N'Cơ trưởng', N'Cơ phó', N'Tiếp viên trưởng', N'Tiếp viên hàng không', N'Điều phối bay', N'Kỹ thuật viên tàu bay')),
    CONSTRAINT CK_NHANVIEN_TrangThai CHECK (TrangThai IN (N'Đang làm việc', N'Nghỉ phép'))
);
GO

CREATE TABLE dbo.PHANCONG (
    MaChuyenBay VARCHAR(5) NOT NULL,
    MaNV VARCHAR(10) NOT NULL,
    VaiTro NVARCHAR(30) NOT NULL,
    GioBatDau DATETIME2(0) NOT NULL,
    GioKetThuc DATETIME2(0) NOT NULL,
    CONSTRAINT PK_PHANCONG PRIMARY KEY (MaChuyenBay, MaNV),
    CONSTRAINT FK_PHANCONG_ChuyenBay FOREIGN KEY (MaChuyenBay) REFERENCES dbo.CHUYENBAY(MaChuyenBay),
    CONSTRAINT FK_PHANCONG_NhanVien FOREIGN KEY (MaNV) REFERENCES dbo.NHANVIEN(MaNV),
    CONSTRAINT CK_PHANCONG_VaiTro CHECK (VaiTro IN (N'Cơ trưởng', N'Cơ phó', N'Tiếp viên trưởng', N'Tiếp viên hàng không')),
    CONSTRAINT CK_PHANCONG_ThoiGian CHECK (GioKetThuc > GioBatDau)
);
GO

CREATE TABLE dbo.HANHKHACH (
    MaHanhKhach VARCHAR(10) NOT NULL,
    HoTen NVARCHAR(100) NOT NULL,
    NgaySinh DATE NOT NULL,
    SoGiayTo VARCHAR(30) NOT NULL,
    QuocTich NVARCHAR(50) NOT NULL,
    SoDienThoai VARCHAR(15) NULL,
    Email VARCHAR(100) NULL,
    CONSTRAINT PK_HANHKHACH PRIMARY KEY (MaHanhKhach),
    CONSTRAINT UQ_HANHKHACH_SoGiayTo UNIQUE (SoGiayTo)
);
GO

CREATE TABLE dbo.VEBAY (
    MaVe VARCHAR(20) NOT NULL,
    MaChuyenBay VARCHAR(5) NOT NULL,
    MaHanhKhach VARCHAR(10) NOT NULL,
    MaDatCho VARCHAR(20) NOT NULL,
    SoGhe VARCHAR(5) NOT NULL, -- sơ đồ demo: mỗi hàng tối đa sáu ghế A-F
    HangGhe NVARCHAR(20) NOT NULL,
    GiaVe DECIMAL(12,2) NOT NULL,
    NgayDat DATETIME2(0) NOT NULL CONSTRAINT DF_VEBAY_NgayDat DEFAULT (SYSDATETIME()),
    TrangThaiVe NVARCHAR(30) NOT NULL,
    CONSTRAINT PK_VEBAY PRIMARY KEY (MaVe),
    CONSTRAINT FK_VEBAY_ChuyenBay FOREIGN KEY (MaChuyenBay) REFERENCES dbo.CHUYENBAY(MaChuyenBay),
    CONSTRAINT FK_VEBAY_HanhKhach FOREIGN KEY (MaHanhKhach) REFERENCES dbo.HANHKHACH(MaHanhKhach),
    CONSTRAINT UQ_VEBAY_MaDatCho UNIQUE (MaDatCho),
    CONSTRAINT CK_VEBAY_GiaVe CHECK (GiaVe > 0),
    CONSTRAINT CK_VEBAY_HangGhe CHECK (HangGhe IN (N'Phổ thông', N'Thương gia')),
    CONSTRAINT CK_VEBAY_TrangThai CHECK (TrangThaiVe IN (N'Đã thanh toán', N'Đã hủy', N'Chờ check-in', N'Đã check-in'))
);
GO

-- Vé đã hủy không giữ chỗ và ghế đó có thể được bán lại.
-- Lưu ý: Tạm comment filtered index dưới đây để tránh bug hiển thị lặp bảng trên Extension Database Client
-- CREATE UNIQUE INDEX UX_VEBAY_ChuyenBay_GheConHieuLuc ON dbo.VEBAY(MaChuyenBay, SoGhe) WHERE TrangThaiVe <> N'Đã hủy';
CREATE INDEX IX_VEBAY_HanhKhach_ChuyenBay ON dbo.VEBAY(MaHanhKhach, MaChuyenBay);
GO

CREATE TABLE dbo.HOADON (
    MaHoaDon VARCHAR(20) NOT NULL,
    MaVe VARCHAR(20) NOT NULL,
    NgayThanhToan DATETIME2(0) NOT NULL,
    SoTien DECIMAL(12,2) NOT NULL,
    PhuongThucThanhToan NVARCHAR(30) NOT NULL,
    TrangThaiThanhToan NVARCHAR(30) NOT NULL,
    CONSTRAINT PK_HOADON PRIMARY KEY (MaHoaDon),
    CONSTRAINT FK_HOADON_VeBay FOREIGN KEY (MaVe) REFERENCES dbo.VEBAY(MaVe),
    CONSTRAINT UQ_HOADON_MaVe UNIQUE (MaVe),
    CONSTRAINT CK_HOADON_SoTien CHECK (SoTien > 0),
    CONSTRAINT CK_HOADON_PhuongThucThanhToan CHECK (PhuongThucThanhToan IN (N'Thẻ tín dụng', N'Chuyển khoản', N'Ví điện tử', N'Tiền mặt', N'Thẻ nội địa')),
    CONSTRAINT CK_HOADON_TrangThai CHECK (TrangThaiThanhToan IN (N'Thành công', N'Thất bại', N'Đã hoàn tiền'))
);
GO

CREATE INDEX IX_CHUYENBAY_TraCuu ON dbo.CHUYENBAY(GioKhoiHanhDK, MaDuongBay) INCLUDE (TrangThai, SoGheTrong);
CREATE INDEX IX_HOADON_Ngay_TrangThai ON dbo.HOADON(NgayThanhToan, TrangThaiThanhToan) INCLUDE (SoTien, MaVe);
GO

-- Data Dictionary: cột, kiểu dữ liệu, nullability, khóa chính/ngoại và default.
SELECT sc.name AS SchemaName, tb.name AS TableName, col.column_id AS OrdinalPosition,
       col.name AS ColumnName, TYPE_NAME(col.user_type_id) AS DataType,
       col.max_length AS MaxLengthBytes, col.precision AS PrecisionValue, col.scale AS ScaleValue,
       col.is_nullable AS IsNullable, col.is_identity AS IsIdentity, col.is_computed AS IsComputed,
       dc.definition AS DefaultExpression,
       CONVERT(BIT, CASE WHEN EXISTS (
           SELECT 1 FROM sys.key_constraints kc
           JOIN sys.index_columns ic ON ic.object_id=kc.parent_object_id AND ic.index_id=kc.unique_index_id
           WHERE kc.parent_object_id=col.object_id AND kc.type='PK' AND ic.column_id=col.column_id
       ) THEN 1 ELSE 0 END) AS IsPrimaryKey,
       STUFF((
           SELECT N', ' + QUOTENAME(OBJECT_SCHEMA_NAME(fkc.referenced_object_id)) + N'.'
                  + QUOTENAME(OBJECT_NAME(fkc.referenced_object_id)) + N'.'
                  + QUOTENAME(COL_NAME(fkc.referenced_object_id, fkc.referenced_column_id))
           FROM sys.foreign_key_columns fkc
           WHERE fkc.parent_object_id=col.object_id AND fkc.parent_column_id=col.column_id
           FOR XML PATH(''), TYPE
       ).value('.', 'NVARCHAR(MAX)'), 1, 2, N'') AS ForeignKeyReferences
FROM sys.tables tb
JOIN sys.schemas sc ON sc.schema_id=tb.schema_id
JOIN sys.columns col ON col.object_id=tb.object_id
LEFT JOIN sys.default_constraints dc ON dc.object_id=col.default_object_id
WHERE tb.is_ms_shipped=0
ORDER BY sc.name, tb.name, col.column_id;
GO
/*
  Các thuộc tính, kiểu dữ liệu, khóa và CHECK/UNIQUE/FK ở trên là data dictionary
  và danh mục ràng buộc của 9 bảng. SoGheTrong là tồn kho được TG1 cập nhật;
  giá thương gia so với phổ thông được TG4 bảo vệ để có lỗi nghiệp vụ dễ đọc.
*/
-- END scripts/script_create_db.sql
-- BEGIN scripts/script_trigger.sql
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
-- END scripts/script_trigger.sql
-- BEGIN scripts/script_insert_data.sql
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

USE QL_CHUYENBAY;
GO

-- Chạy sau DDL và trigger; nạp một lần trên database trống, đủ 15-20 dòng/bảng.
-- MaSanBay là mã IATA sân bay; các cột ngày giờ chuyến bay/tổ bay đều là UTC.
INSERT INTO SANBAY (MaSanBay, TenSanBay, ThanhPho, QuocGia, MuiGio, ViDo, KinhDo) VALUES
('SGN', N'Tan Son Nhat International Airport', N'Ho Chi Minh City', N'Vietnam', 'Asia/Ho_Chi_Minh', 10.818790, 106.651840),
('HAN', N'Noi Bai International Airport', N'Hanoi', N'Vietnam', 'Asia/Ho_Chi_Minh', 21.221217, 105.807182),
('DAD', N'Da Nang International Airport', N'Da Nang', N'Vietnam', 'Asia/Ho_Chi_Minh', 16.043889, 108.199444),
('CXR', N'Cam Ranh International Airport', N'Nha Trang', N'Vietnam', 'Asia/Ho_Chi_Minh', 11.998056, 109.219444),
('PQC', N'Phu Quoc International Airport', N'Phu Quoc', N'Vietnam', 'Asia/Ho_Chi_Minh', 10.169722, 103.993056),
('BMV', N'Buon Ma Thuot Airport', N'Buon Ma Thuot', N'Vietnam', 'Asia/Ho_Chi_Minh', 12.667778, 108.120000),
('SIN', N'Singapore Changi Airport', N'Singapore', N'Singapore', 'Asia/Singapore', 1.364420, 103.991531),
('BKK', N'Suvarnabhumi Airport', N'Bangkok', N'Thailand', 'Asia/Bangkok', 13.690000, 100.750111),
('KUL', N'Kuala Lumpur International Airport', N'Kuala Lumpur', N'Malaysia', 'Asia/Kuala_Lumpur', 2.745578, 101.709917),
('AUH', N'Zayed International Airport', N'Abu Dhabi', N'United Arab Emirates', 'Asia/Dubai', 24.433000, 54.651100),
('DXB', N'Dubai International Airport', N'Dubai', N'United Arab Emirates', 'Asia/Dubai', 25.253200, 55.365700),
('ICN', N'Incheon International Airport', N'Incheon', N'South Korea', 'Asia/Seoul', 37.460200, 126.440700),
('NRT', N'Narita International Airport', N'Tokyo', N'Japan', 'Asia/Tokyo', 35.772000, 140.392900),
('SYD', N'Sydney Kingsford Smith Airport', N'Sydney', N'Australia', 'Australia/Sydney', -33.939900, 151.175300),
('LHR', N'Heathrow Airport', N'London', N'United Kingdom', 'Europe/London', 51.470000, -0.454300),
('CDG', N'Charles de Gaulle Airport', N'Paris', N'France', 'Europe/Paris', 49.009700, 2.547900),
('LAX', N'Los Angeles International Airport', N'Los Angeles', N'United States', 'America/Los_Angeles', 33.941600, -118.408500),
('JFK', N'John F. Kennedy International Airport', N'New York', N'United States', 'America/New_York', 40.641300, -73.778100),
('DOH', N'Hamad International Airport', N'Doha', N'Qatar', 'Asia/Qatar', 25.273100, 51.608100),
('FRA', N'Frankfurt Airport', N'Frankfurt', N'Germany', 'Europe/Berlin', 50.037900, 8.562200);
GO

-- Nhập dữ liệu bảng máy bay
INSERT INTO MAYBAY (MaMayBay, SoHieu, LoaiMayBay, SoGhe, TrangThai) VALUES
('MB01', 'VN-A517', 'Airbus A321neo', 203, N'Sẵn sàng khai thác'),
('MB02', 'VJ-A534', 'Airbus A350-900', 305, N'Sẵn sàng khai thác'),
('MB03', 'QH-A551', 'Boeing 787-9 Dreamliner', 311, N'Sẵn sàng khai thác'),
('MB04', 'VU-A568', 'Boeing 787-10 Dreamliner', 367, N'Sẵn sàng khai thác'),
('MB05', 'SQ-9V585', 'Airbus A320-200', 180, N'Sẵn sàng khai thác'),
('MB06', 'EK-A6602', 'Boeing 737 MAX 8', 189, N'Sẵn sàng khai thác'),
('MB07', 'VN-A619', 'ATR 72-600', 72, N'Sẵn sàng khai thác'),
('MB08', 'VJ-A636', 'Airbus A321neo', 203, N'Sẵn sàng khai thác'),
('MB09', 'QH-A653', 'Airbus A350-900', 305, N'Sẵn sàng khai thác'),
('MB10', 'VU-A670', 'Boeing 787-9 Dreamliner', 311, N'Sẵn sàng khai thác'),
('MB11', 'SQ-9V687', 'Boeing 787-10 Dreamliner', 367, N'Sẵn sàng khai thác'),
('MB12', 'EK-A6704', 'Airbus A320-200', 180, N'Sẵn sàng khai thác'),
('MB13', 'VN-A721', 'Boeing 737 MAX 8', 189, N'Sẵn sàng khai thác'),
('MB14', 'VJ-A738', 'ATR 72-600', 72, N'Sẵn sàng khai thác'),
('MB15', 'QH-A755', 'Airbus A321neo', 203, N'Sẵn sàng khai thác'),
('MB16', 'VU-A772', 'Airbus A350-900', 305, N'Sẵn sàng khai thác'),
('MB17', 'SQ-9V789', 'Boeing 787-9 Dreamliner', 311, N'Sẵn sàng khai thác'),
('MB18', 'EK-A6806', 'Boeing 787-10 Dreamliner', 367, N'Sẵn sàng khai thác'),
('MB19', 'VN-A823', 'Airbus A320-200', 180, N'Sẵn sàng khai thác'),
('MB20', 'VJ-A840', 'Boeing 737 MAX 8', 189, N'Sẵn sàng khai thác');
GO

-- Nhập dữ liệu bảng nhân viên
INSERT INTO NHANVIEN (MaNV, HoTen, NgaySinh, GioiTinh, SoDienThoai, Email, ChucVu, TrangThai) VALUES
('NV01', N'Lý Minh Vương', '1977-04-06', N'Nam', '0910423187', 'nv.lgp6l1@vietnamairlines.vn', N'Cơ trưởng', N'Đang làm việc'),
('NV02', N'Phùng Linh Duyên', '1979-07-11', N'Nữ', '0910846374', 'nv.j7uuf2@vietnamairlines.vn', N'Cơ phó', N'Đang làm việc'),
('NV03', N'Hà Giang Lam', '1981-10-16', N'Nam', '0911269561', 'nv.3sr403@vietnamairlines.vn', N'Tiếp viên trưởng', N'Đang làm việc'),
('NV04', N'Tăng Diệu Thiện', '1983-01-21', N'Nữ', '0911692748', 'nv.v6hn54@vietnamairlines.vn', N'Tiếp viên hàng không', N'Đang làm việc'),
('NV05', N'Phạm Công Tráng', '1985-04-26', N'Nam', '0912115935', 'nv.ykqrv5@vietnamairlines.vn', N'Điều phối bay', N'Đang làm việc'),
('NV06', N'Hồ Uyển Khanh', '1987-07-03', N'Nữ', '0912539122', 'nv.aa1v06@vietnamairlines.vn', N'Kỹ thuật viên tàu bay', N'Đang làm việc'),
('NV07', N'Lâm Minh Huấn', '1989-10-08', N'Nam', '0912962309', 'nv.7z4oo7@vietnamairlines.vn', N'Cơ trưởng', N'Đang làm việc'),
('NV08', N'Trịnh Ngọc Uyên', '1991-01-13', N'Nữ', '0913385496', 'nv.ypuy68@vietnamairlines.vn', N'Cơ phó', N'Đang làm việc'),
('NV09', N'Mai Nhật Quân', '1993-04-18', N'Nam', '0913808683', 'nv.qxd199@vietnamairlines.vn', N'Tiếp viên trưởng', N'Đang làm việc'),
('NV10', N'Đào Hồng Mai', '1995-07-23', N'Nữ', '0914231870', 'nv.ba3ax10@vietnamairlines.vn', N'Tiếp viên hàng không', N'Đang làm việc'),
('NV11', N'Phan Bảo Long', '1997-10-28', N'Nam', '0914655057', 'nv.3kdee11@vietnamairlines.vn', N'Điều phối bay', N'Đang làm việc'),
('NV12', N'Phan Tuệ Mẫn', '1999-01-05', N'Nữ', '0915078244', 'nv.r83ar12@vietnamairlines.vn', N'Kỹ thuật viên tàu bay', N'Đang làm việc'),
('NV13', N'Ngô Sơn Lâm', '1976-04-10', N'Nam', '0915501431', 'nv.k95qn13@vietnamairlines.vn', N'Cơ trưởng', N'Đang làm việc'),
('NV14', N'Mai Thu Hồng', '1978-07-15', N'Nữ', '0915924618', 'nv.lqybm14@vietnamairlines.vn', N'Cơ phó', N'Đang làm việc'),
('NV15', N'Lâm Hữu Định', '1980-10-20', N'Nam', '0916347805', 'nv.qlory15@vietnamairlines.vn', N'Tiếp viên trưởng', N'Nghỉ phép'),
('NV16', N'Trần Cẩm Nhi', '1982-01-25', N'Nữ', '0916770992', 'nv.vaoue16@vietnamairlines.vn', N'Tiếp viên hàng không', N'Đang làm việc'),
('NV17', N'Phạm Đình Diệu', '1984-04-02', N'Nam', '0917194179', 'nv.4i1kc17@vietnamairlines.vn', N'Điều phối bay', N'Đang làm việc'),
('NV18', N'Phan Thu Nhiên', '1986-07-07', N'Nữ', '0917617366', 'nv.jtrl818@vietnamairlines.vn', N'Kỹ thuật viên tàu bay', N'Đang làm việc'),
('NV19', N'Tô Tường Lĩnh', '1988-10-12', N'Nam', '0918040553', 'nv.xfbwu19@vietnamairlines.vn', N'Cơ trưởng', N'Đang làm việc'),
('NV20', N'Đinh Thy Vân', '1990-01-17', N'Nữ', '0918463740', 'nv.nmami20@vietnamairlines.vn', N'Cơ phó', N'Đang làm việc');
GO

-- Nhập dữ liệu bảng hành khách
INSERT INTO HANHKHACH (MaHanhKhach, HoTen, NgaySinh, SoGiayTo, QuocTich, SoDienThoai, Email) VALUES
('HK01', N'Hà Mai Chi', '1983-08-10', '079103749123', N'VN', '0820351982', 'khachhang1.fmhg@gmail.com'),
('HK02', N'Trương Chí Hiếu', '1986-03-19', '079107498246', N'VN', '0820703964', 'khachhang2.wbmc@gmail.com'),
('HK03', N'Phạm Lan Thương', '1989-10-28', '079111247369', N'VN', '0821055946', 'khachhang3.yggs@gmail.com'),
('HK04', N'Tô Viễn Phương', '1992-05-09', '079114996492', N'VN', '0821407928', 'khachhang4.bxmd@gmail.com'),
('HK05', N'Bùi Nhã Lý', '1995-12-18', '079118745615', N'VN', '0821759910', 'khachhang5.g5mc@gmail.com'),
('HK06', N'Đặng Thế Sơn', '1998-07-27', '079122494738', N'VN', '0822111892', 'khachhang6.tp6e@gmail.com'),
('HK07', N'Hồ Kim Hương', '2001-02-08', '079126243861', N'VN', '0822463874', 'khachhang7.u2jc@gmail.com'),
('HK08', N'Lâm Khắc Tuấn', '1981-09-17', '079129992984', N'VN', '0822815856', 'khachhang8.v2f9@gmail.com'),
('HK09', N'Tăng Ngọc Dung', '1984-04-26', '079133742107', N'VN', '0823167838', 'khachhang9.dvsy@gmail.com'),
('HK10', N'Mai Vũ Minh', '1987-11-07', '079137491230', N'VN', '0823519820', 'khachhang10.zdfh@gmail.com'),
('HK11', N'Dương Thiếu Mai', '1990-06-16', '079141240353', N'VN', '0823871802', 'khachhang11.abt5@gmail.com'),
('HK12', N'Dương Chí Khiêm', '1993-01-25', '079144989476', N'VN', '0824223784', 'khachhang12.vbkh@gmail.com'),
('HK13', N'Trương Thiên Thêu', '1996-08-06', '079148738599', N'VN', '0824575766', 'khachhang13.vgmj@gmail.com'),
('HK14', N'Lê Công Bằng', '1999-03-15', '079152487722', N'VN', '0824927748', 'khachhang14.qupp@gmail.com'),
('HK15', N'Hoàng Vân Thanh', '2002-10-24', '079156236845', N'VN', '0825279730', 'khachhang15.y3gl@gmail.com'),
('HK16', N'Hồ Quang Lộc', '1982-05-05', '079159985968', N'VN', '0825631712', 'khachhang16.0sb1@gmail.com'),
('HK17', N'Đinh Như Loan', '1985-12-14', '079163735091', N'VN', '0825983694', 'khachhang17.dnkm@gmail.com'),
('HK18', N'Trịnh Tuấn Tú', '1988-07-23', '079167484214', N'SG', '0826335676', 'khachhang18.vqkl@gmail.com'),
('HK19', N'Hoàng Hương Trang', '1991-02-04', '079171233337', N'TH', '0826687658', 'khachhang19.w7rd@gmail.com'),
('HK20', N'Lâm Tân Long', '1994-09-13', '079174982460', N'VN', '0827039640', 'khachhang20.gzqz@gmail.com');
GO

-- Nhập dữ liệu bảng đường bay
INSERT INTO DUONGBAY (MaDuongBay, MaSanBayDi, MaSanBayDen, ThoiGianBayDuKien) VALUES
('DB01', 'SGN', 'HAN', 130),
('DB02', 'HAN', 'SGN', 130),
('DB03', 'SGN', 'DAD', 80),
('DB04', 'DAD', 'SGN', 80),
('DB05', 'HAN', 'DAD', 85),
('DB06', 'DAD', 'HAN', 85),
('DB07', 'SGN', 'CXR', 60),
('DB08', 'SGN', 'PQC', 65),
('DB09', 'HAN', 'PQC', 135),
('DB10', 'SGN', 'BMV', 55),
('DB11', 'HAN', 'BMV', 105),
('DB12', 'SGN', 'SIN', 125),
('DB13', 'SIN', 'SGN', 125),
('DB14', 'SGN', 'BKK', 95),
('DB15', 'HAN', 'BKK', 115),
('DB16', 'SGN', 'KUL', 120),
('DB17', 'HAN', 'AUH', 520),
('DB18', 'SGN', 'DXB', 450),
('DB19', 'SGN', 'ICN', 300),
('DB20', 'HAN', 'NRT', 300);
GO

-- Nhập dữ liệu bảng chuyến bay
INSERT INTO CHUYENBAY (MaChuyenBay, MaDuongBay, MaMayBay, GioKhoiHanhDK, GioHaCanhDK, GiaVePhoThong, GiaVeThuongGia, SoGheTrong, TrangThai) VALUES
('VN214', 'DB01', 'MB01', '2026-10-10 06:00:00', '2026-10-10 08:10:00', 1200000, 3000000, 203, N'Đã bay'),
('VN218', 'DB02', 'MB02', '2026-10-10 09:15:00', '2026-10-10 11:25:00', 1310000, 3360000, 305, N'Đã bay'),
('VN601', 'DB03', 'MB03', '2026-10-11 12:30:00', '2026-10-11 13:50:00', 1420000, 3720000, 311, N'Lên lịch'),
('VN716', 'DB04', 'MB04', '2026-10-11 15:45:00', '2026-10-11 17:05:00', 1530000, 4080000, 367, N'Lên lịch'),
('VN522', 'DB05', 'MB05', '2026-10-12 18:00:00', '2026-10-12 19:25:00', 1640000, 4440000, 180, N'Delay'),
('VJ130', 'DB06', 'MB06', '2026-10-12 06:15:00', '2026-10-12 07:40:00', 1750000, 4800000, 189, N'Lên lịch'),
('VJ152', 'DB07', 'MB07', '2026-10-13 09:30:00', '2026-10-13 10:30:00', 1860000, 5160000, 72, N'Đúng giờ'),
('VJ210', 'DB08', 'MB08', '2026-10-13 12:45:00', '2026-10-13 13:50:00', 1970000, 5520000, 203, N'Đúng giờ'),
('VJ362', 'DB09', 'MB09', '2026-10-14 15:00:00', '2026-10-14 17:15:00', 2080000, 5880000, 305, N'Đúng giờ'),
('VJ480', 'DB10', 'MB10', '2026-10-14 18:15:00', '2026-10-14 19:10:00', 2190000, 6240000, 311, N'Lên lịch'),
('QH202', 'DB11', 'MB11', '2026-10-15 06:30:00', '2026-10-15 08:15:00', 2300000, 6600000, 367, N'Delay'),
('QH156', 'DB12', 'MB12', '2026-10-15 09:45:00', '2026-10-15 11:50:00', 2410000, 6960000, 180, N'Lên lịch'),
('QH312', 'DB13', 'MB13', '2026-10-16 12:00:00', '2026-10-16 14:05:00', 2520000, 7320000, 189, N'Đúng giờ'),
('QH402', 'DB14', 'MB14', '2026-10-16 15:15:00', '2026-10-16 16:50:00', 2630000, 7680000, 72, N'Đúng giờ'),
('QH510', 'DB15', 'MB15', '2026-10-17 18:30:00', '2026-10-17 20:25:00', 2740000, 4540000, 203, N'Đúng giờ'),
('VU102', 'DB16', 'MB16', '2026-10-17 06:45:00', '2026-10-17 08:45:00', 2850000, 4900000, 305, N'Lên lịch'),
('VU118', 'DB17', 'MB17', '2026-10-18 09:00:00', '2026-10-18 17:40:00', 2960000, 5260000, 311, N'Delay'),
('SQ178', 'DB18', 'MB18', '2026-10-18 12:15:00', '2026-10-18 19:45:00', 3070000, 5620000, 367, N'Lên lịch'),
('SQ182', 'DB19', 'MB19', '2026-10-19 15:30:00', '2026-10-19 20:30:00', 3180000, 5980000, 180, N'Đúng giờ'),
('EK392', 'DB20', 'MB20', '2026-10-19 18:45:00', '2026-10-19 23:45:00', 3290000, 6340000, 189, N'Đã hủy');
GO

-- Bổ sung dữ liệu khai thác để chạy báo cáo hiệu suất và cursor bồi thường.
UPDATE dbo.CHUYENBAY
SET GioCatCanhTT = '2026-10-10 06:05:00', GioHaCanhTT = '2026-10-10 08:15:00'
WHERE MaChuyenBay = 'VN214';
UPDATE dbo.CHUYENBAY
SET GioCatCanhTT = '2026-10-10 09:45:00', GioHaCanhTT = '2026-10-10 11:55:00'
WHERE MaChuyenBay = 'VN218';
UPDATE dbo.CHUYENBAY SET SoPhutTre = 90, LyDoTrangThai = N'Chờ thời tiết thuận lợi' WHERE MaChuyenBay = 'VN522';
UPDATE dbo.CHUYENBAY SET SoPhutTre = 150, LyDoTrangThai = N'Kiểm tra kỹ thuật bổ sung' WHERE MaChuyenBay = 'QH202';
UPDATE dbo.CHUYENBAY SET SoPhutTre = 250, LyDoTrangThai = N'Ảnh hưởng dây chuyền khai thác' WHERE MaChuyenBay = 'VU118';
UPDATE dbo.CHUYENBAY SET LyDoTrangThai = N'Điều chỉnh kế hoạch khai thác' WHERE MaChuyenBay = 'EK392';

-- Nhập dữ liệu bảng phân công
INSERT INTO PHANCONG (MaChuyenBay, MaNV, VaiTro, GioBatDau, GioKetThuc) VALUES
('VN214', 'NV01', N'Cơ trưởng', '2026-10-10 05:00:00', '2026-10-10 08:40:00'),
('VN218', 'NV02', N'Cơ phó', '2026-10-10 08:15:00', '2026-10-10 11:55:00'),
('VN601', 'NV03', N'Tiếp viên trưởng', '2026-10-11 11:30:00', '2026-10-11 14:20:00'),
('VN716', 'NV04', N'Tiếp viên hàng không', '2026-10-11 14:45:00', '2026-10-11 17:35:00'),
('VN522', 'NV07', N'Cơ trưởng', '2026-10-12 17:00:00', '2026-10-12 19:55:00'),
('VJ130', 'NV08', N'Cơ phó', '2026-10-12 05:15:00', '2026-10-12 08:10:00'),
('VJ152', 'NV09', N'Tiếp viên trưởng', '2026-10-13 08:30:00', '2026-10-13 11:00:00'),
('VJ210', 'NV10', N'Tiếp viên hàng không', '2026-10-13 11:45:00', '2026-10-13 14:20:00'),
('VJ362', 'NV13', N'Cơ trưởng', '2026-10-14 14:00:00', '2026-10-14 17:45:00'),
('VJ480', 'NV14', N'Cơ phó', '2026-10-14 17:15:00', '2026-10-14 19:40:00'),
('QH202', 'NV03', N'Tiếp viên trưởng', '2026-10-15 05:30:00', '2026-10-15 08:45:00'),
('QH156', 'NV16', N'Tiếp viên hàng không', '2026-10-15 08:45:00', '2026-10-15 12:20:00'),
('QH312', 'NV19', N'Cơ trưởng', '2026-10-16 11:00:00', '2026-10-16 14:35:00'),
('QH402', 'NV20', N'Cơ phó', '2026-10-16 14:15:00', '2026-10-16 17:20:00'),
('QH510', 'NV03', N'Tiếp viên trưởng', '2026-10-17 17:30:00', '2026-10-17 20:55:00'),
('VU102', 'NV04', N'Tiếp viên hàng không', '2026-10-17 05:45:00', '2026-10-17 10:15:00'),
('VU118', 'NV01', N'Cơ trưởng', '2026-10-18 08:00:00', '2026-10-18 18:10:00'),
('SQ178', 'NV02', N'Cơ phó', '2026-10-18 11:15:00', '2026-10-18 20:15:00'),
('SQ182', 'NV09', N'Tiếp viên trưởng', '2026-10-19 14:30:00', '2026-10-19 21:00:00');
GO

-- Nhập dữ liệu bảng vé bay
INSERT INTO VEBAY (MaVe, MaChuyenBay, MaHanhKhach, MaDatCho, SoGhe, HangGhe, GiaVe, NgayDat, TrangThaiVe) VALUES
('VE01', 'VN214', 'HK01', 'PNR00RCP', '01A', N'Thương gia', 3000000, '2026-10-07 06:00:00', N'Đã thanh toán'),
('VE02', 'VN218', 'HK02', 'PNR01SAW', '14B', N'Phổ thông', 1310000, '2026-10-06 09:15:00', N'Đã check-in'),
('VE03', 'VN601', 'HK03', 'PNR02PYM', '15C', N'Phổ thông', 1420000, '2026-10-06 12:30:00', N'Đã thanh toán'),
('VE04', 'VN716', 'HK04', 'PNR03GIY', '18D', N'Phổ thông', 1530000, '2026-10-05 15:45:00', N'Chờ check-in'),
('VE05', 'VN522', 'HK05', 'PNR04DNH', '01E', N'Thương gia', 4440000, '2026-10-05 18:00:00', N'Đã thanh toán'),
('VE06', 'VJ130', 'HK06', 'PNR05ETT', '24F', N'Phổ thông', 1750000, '2026-10-04 06:15:00', N'Đã check-in'),
('VE07', 'VJ152', 'HK07', 'PNR06NFK', '10A', N'Phổ thông', 1860000, '2026-10-04 09:30:00', N'Đã thanh toán'),
('VE08', 'VJ210', 'HK08', 'PNR07FCD', '28B', N'Phổ thông', 1970000, '2026-10-10 12:45:00', N'Chờ check-in'),
('VE09', 'VJ362', 'HK09', 'PNR08WYN', '01C', N'Thương gia', 5880000, '2026-10-10 15:00:00', N'Đã thanh toán'),
('VE10', 'VJ480', 'HK10', 'PNR09UHW', '02D', N'Phổ thông', 2190000, '2026-10-09 18:15:00', N'Đã check-in'),
('VE11', 'QH202', 'HK11', 'PNR10BFP', '12E', N'Phổ thông', 2300000, '2026-10-09 06:30:00', N'Đã thanh toán'),
('VE12', 'QH156', 'HK12', 'PNR11XBO', '14F', N'Phổ thông', 2410000, '2026-10-08 09:45:00', N'Chờ check-in'),
('VE13', 'QH312', 'HK13', 'PNR12EXN', '01A', N'Thương gia', 7320000, '2026-10-08 12:00:00', N'Đã thanh toán'),
('VE14', 'QH402', 'HK14', 'PNR13ALX', '10B', N'Phổ thông', 2630000, '2026-10-07 15:15:00', N'Đã check-in'),
('VE15', 'QH510', 'HK15', 'PNR14RTY', '21C', N'Phổ thông', 2740000, '2026-10-14 18:30:00', N'Đã thanh toán'),
('VE16', 'VU102', 'HK16', 'PNR15SLP', '24D', N'Phổ thông', 2850000, '2026-10-13 06:45:00', N'Chờ check-in'),
('VE17', 'VU118', 'HK17', 'PNR16OAC', '01E', N'Thương gia', 5260000, '2026-10-13 09:00:00', N'Đã thanh toán'),
('VE18', 'SQ178', 'HK18', 'PNR17FWU', '28F', N'Phổ thông', 3070000, '2026-10-12 12:15:00', N'Đã check-in'),
('VE19', 'SQ182', 'HK19', 'PNR18CFH', '01A', N'Phổ thông', 3180000, '2026-10-12 15:30:00', N'Đã thanh toán'),
('VE20', 'EK392', 'HK20', 'PNR19JZF', '02B', N'Phổ thông', 3290000, '2026-10-11 18:45:00', N'Đã hủy');
GO

-- Nhập dữ liệu bảng hóa đơn
INSERT INTO HOADON (MaHoaDon, MaVe, NgayThanhToan, SoTien, PhuongThucThanhToan, TrangThaiThanhToan) VALUES
('HD01', 'VE01', '2026-10-07 06:15:00', 3000000, N'Thẻ tín dụng', N'Thành công'),
('HD02', 'VE02', '2026-10-06 09:30:00', 1310000, N'Chuyển khoản', N'Thành công'),
('HD03', 'VE03', '2026-10-06 12:45:00', 1420000, N'Ví điện tử', N'Thành công'),
('HD04', 'VE04', '2026-10-05 16:00:00', 1530000, N'Tiền mặt', N'Thành công'),
('HD05', 'VE05', '2026-10-05 18:15:00', 4440000, N'Thẻ nội địa', N'Thành công'),
('HD06', 'VE06', '2026-10-04 06:30:00', 1750000, N'Thẻ tín dụng', N'Thành công'),
('HD07', 'VE07', '2026-10-04 09:45:00', 1860000, N'Chuyển khoản', N'Thành công'),
('HD08', 'VE08', '2026-10-10 13:00:00', 1970000, N'Ví điện tử', N'Thành công'),
('HD09', 'VE09', '2026-10-10 15:15:00', 5880000, N'Tiền mặt', N'Thành công'),
('HD10', 'VE10', '2026-10-09 18:30:00', 2190000, N'Thẻ nội địa', N'Thành công'),
('HD11', 'VE11', '2026-10-09 06:45:00', 2300000, N'Thẻ tín dụng', N'Thành công'),
('HD12', 'VE12', '2026-10-08 10:00:00', 2410000, N'Chuyển khoản', N'Thành công'),
('HD13', 'VE13', '2026-10-08 12:15:00', 7320000, N'Ví điện tử', N'Thành công'),
('HD14', 'VE14', '2026-10-07 15:30:00', 2630000, N'Tiền mặt', N'Thành công'),
('HD15', 'VE15', '2026-10-14 18:45:00', 2740000, N'Thẻ nội địa', N'Thành công'),
('HD16', 'VE16', '2026-10-13 07:00:00', 2850000, N'Thẻ tín dụng', N'Thành công'),
('HD17', 'VE17', '2026-10-13 09:15:00', 5260000, N'Chuyển khoản', N'Thành công'),
('HD18', 'VE18', '2026-10-12 12:30:00', 3070000, N'Ví điện tử', N'Thành công'),
('HD19', 'VE19', '2026-10-12 15:45:00', 3180000, N'Tiền mặt', N'Thành công'),
('HD20', 'VE20', '2026-10-11 19:00:00', 3290000, N'Thẻ nội địa', N'Đã hoàn tiền');
GO
-- END scripts/script_insert_data.sql
-- BEGIN scripts/script_procedure.sql
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

-- Bảo mật theo vai trò: 4 roles chuẩn (Quản trị, Điều phối, Bán vé, Khách hàng)
IF DATABASE_PRINCIPAL_ID(N'QLCB_QuanTri') IS NULL CREATE ROLE QLCB_QuanTri;
IF DATABASE_PRINCIPAL_ID(N'QLCB_DieuPhoi') IS NULL CREATE ROLE QLCB_DieuPhoi;
IF DATABASE_PRINCIPAL_ID(N'QLCB_BanVe') IS NULL CREATE ROLE QLCB_BanVe;
IF DATABASE_PRINCIPAL_ID(N'QLCB_KhachHang') IS NULL CREATE ROLE QLCB_KhachHang;
IF DATABASE_PRINCIPAL_ID(N'QLCB_BaoCao') IS NOT NULL DROP ROLE QLCB_BaoCao;
GO

-- 1. Quản trị viên (QLCB_QuanTri): Toàn quyền quản trị cơ sở dữ liệu và báo cáo
GRANT CONTROL ON DATABASE::QL_CHUYENBAY TO QLCB_QuanTri;

-- 2. Điều phối viên (QLCB_DieuPhoi): Quản lý bay, hoãn/hủy, phân công tổ bay, công nhật, bồi thường, hiệu suất máy bay
GRANT EXECUTE ON OBJECT::dbo.SP2_DELAY_HUY TO QLCB_DieuPhoi;
GRANT EXECUTE ON OBJECT::dbo.SP5_PHANCONGTOBAY TO QLCB_DieuPhoi;
GRANT EXECUTE ON OBJECT::dbo.CS1_TinhBoiThuongChuyenBayDelay TO QLCB_DieuPhoi;
GRANT EXECUTE ON OBJECT::dbo.CS2_TongHopCongNhatPhuCap TO QLCB_DieuPhoi;
GRANT SELECT ON OBJECT::dbo.FN3_ThongKeMayBayTheoThang TO QLCB_DieuPhoi;
GRANT SELECT ON OBJECT::dbo.FN2_DanhSachGheTrong TO QLCB_DieuPhoi;
GRANT SELECT ON OBJECT::dbo.CHUYENBAY TO QLCB_DieuPhoi;
GRANT SELECT ON OBJECT::dbo.DUONGBAY TO QLCB_DieuPhoi;
GRANT SELECT ON OBJECT::dbo.SANBAY TO QLCB_DieuPhoi;
GRANT SELECT ON OBJECT::dbo.MAYBAY TO QLCB_DieuPhoi;
GRANT SELECT ON OBJECT::dbo.NHANVIEN TO QLCB_DieuPhoi;
GRANT SELECT ON OBJECT::dbo.PHANCONG TO QLCB_DieuPhoi;
GRANT SELECT ON OBJECT::dbo.VEBAY TO QLCB_DieuPhoi;
GRANT UPDATE ON OBJECT::dbo.MAYBAY (TrangThai) TO QLCB_DieuPhoi;

-- 3. Nhân viên Bán vé (QLCB_BanVe): Tra cứu, đặt vé, hủy vé, xem ghế, tra cứu hội viên
GRANT EXECUTE ON OBJECT::dbo.SP1_DATCHO_TAOVE TO QLCB_BanVe;
GRANT EXECUTE ON OBJECT::dbo.SP4_TRACUUDANHSACH TO QLCB_BanVe;
GRANT SELECT ON OBJECT::dbo.FN2_DanhSachGheTrong TO QLCB_BanVe;
GRANT EXECUTE ON OBJECT::dbo.FN1_HangHoiVien TO QLCB_BanVe;
GRANT SELECT ON OBJECT::dbo.CHUYENBAY TO QLCB_BanVe;
GRANT SELECT ON OBJECT::dbo.DUONGBAY TO QLCB_BanVe;
GRANT SELECT ON OBJECT::dbo.SANBAY TO QLCB_BanVe;
GRANT SELECT ON OBJECT::dbo.MAYBAY TO QLCB_BanVe;
GRANT SELECT ON OBJECT::dbo.HANHKHACH TO QLCB_BanVe;
GRANT SELECT ON OBJECT::dbo.VEBAY TO QLCB_BanVe;
GRANT SELECT ON OBJECT::dbo.HOADON TO QLCB_BanVe;
GRANT UPDATE ON OBJECT::dbo.VEBAY (TrangThaiVe) TO QLCB_BanVe;

-- 4. Khách hàng (QLCB_KhachHang): Tra cứu chuyến bay, đặt vé cá nhân, xem sơ đồ ghế trống, tra cứu hạng hội viên
GRANT EXECUTE ON OBJECT::dbo.SP4_TRACUUDANHSACH TO QLCB_KhachHang;
GRANT EXECUTE ON OBJECT::dbo.SP1_DATCHO_TAOVE TO QLCB_KhachHang;
GRANT SELECT ON OBJECT::dbo.FN2_DanhSachGheTrong TO QLCB_KhachHang;
GRANT EXECUTE ON OBJECT::dbo.FN1_HangHoiVien TO QLCB_KhachHang;
GRANT SELECT ON OBJECT::dbo.CHUYENBAY TO QLCB_KhachHang;
GRANT SELECT ON OBJECT::dbo.DUONGBAY TO QLCB_KhachHang;
GRANT SELECT ON OBJECT::dbo.SANBAY TO QLCB_KhachHang;
GRANT SELECT ON OBJECT::dbo.MAYBAY TO QLCB_KhachHang;
GO

/*
  Gán người dùng (thay [TenUser] bằng database user đã được DBA tạo):
  ALTER ROLE QLCB_QuanTri ADD MEMBER [TenUser];
  ALTER ROLE QLCB_DieuPhoi ADD MEMBER [TenUser];
  ALTER ROLE QLCB_BanVe ADD MEMBER [TenUser];
  ALTER ROLE QLCB_KhachHang ADD MEMBER [TenUser];

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
-- END scripts/script_procedure.sql
