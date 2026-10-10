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
