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
