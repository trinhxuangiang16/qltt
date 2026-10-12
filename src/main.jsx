import React, { useEffect, useMemo, useRef, useState } from 'react';
import { createRoot } from 'react-dom/client';
import {
  Activity, AlertTriangle, ArrowDownRight, ArrowRight, ArrowUpRight, BarChart3, BookOpen,
  CalendarDays, Check, CheckCircle2, ChevronDown, Clock3, Database, FileBarChart2,
  FileCheck2, FileDown, Filter, Gauge, LayoutDashboard, Menu, Plane, PlaneTakeoff, RefreshCw,
  Search, Settings2, ShieldCheck, Ticket, Users, WalletCards, X, Zap,
} from 'lucide-react';
import './styles.css';

const workflows = {
  'sp1-book': {
    code: 'SP1', title: 'Đặt chỗ & xuất vé', category: 'Bán vé', icon: Ticket,
    description: 'Tiếp nhận thông tin hành khách, kiểm tra chuyến còn nhận đặt chỗ và chọn ghế đang trống. SP1 tạo vé; TG1 đồng bộ số ghế trong cùng giao dịch.',
    action: 'Tạo vé', sql: 'EXEC dbo.SP1_DATCHO_TAOVE @MaVe, @MaChuyenBay, @MaHanhKhach, @MaDatCho, @SoGhe, @HangGhe;',
    fields: [
      { key: 'MaChuyenBay', label: 'Chuyến bay', source: 'flights', required: true },
      { key: 'MaHanhKhach', label: 'Hành khách', source: 'passengers', required: true },
      { key: 'MaVe', label: 'Mã vé mới', type: 'text', required: true },
      { key: 'MaDatCho', label: 'Mã đặt chỗ', type: 'text', required: true },
      { key: 'SoGhe', label: 'Số ghế', type: 'text', required: true, placeholder: 'Ví dụ: 10A' },
      { key: 'HangGhe', label: 'Hạng ghế', type: 'select', choices: ['Phổ thông', 'Thương gia'], required: true },
    ],
  },
  'tg1-book': {
    code: 'TG1', title: 'TG1 · Giữ ghế khi xuất vé', category: 'Trigger', icon: Ticket,
    description: 'Kiểm chứng trigger tự giảm ghế trống sau khi SP1 phát hành vé. Chọn chuyến còn ghế và một vị trí chưa bán; sau khi tạo, số ghế và danh sách vé được tải lại.',
    action: 'Thực thi xuất vé', sql: 'EXEC dbo.SP1_DATCHO_TAOVE @MaVe, @MaChuyenBay, @MaHanhKhach, @MaDatCho, @SoGhe, @HangGhe;',
    fields: [
      { key: 'MaChuyenBay', label: 'Chuyến bay', source: 'flights', required: true },
      { key: 'MaHanhKhach', label: 'Hành khách', source: 'passengers', required: true },
      { key: 'MaVe', label: 'Mã vé thử', type: 'text', required: true },
      { key: 'MaDatCho', label: 'Mã đặt chỗ thử', type: 'text', required: true },
      { key: 'SoGhe', label: 'Ghế còn trống', type: 'text', required: true, placeholder: 'Chọn từ danh sách FN2 bên dưới' },
      { key: 'HangGhe', label: 'Hạng ghế', type: 'select', choices: ['Phổ thông', 'Thương gia'], required: true },
    ],
  },
  'tg1-cancel': {
    code: 'TG1', title: 'TG1 · Hoàn ghế khi hủy vé', category: 'Trigger', icon: Ticket,
    description: 'Hủy một vé còn hiệu lực. Trigger TG1 trả ghế về khoang của chuyến bay; màn hình tải lại vé và số ghế để kiểm chứng.',
    action: 'Thực thi hủy vé', sql: "UPDATE dbo.VEBAY SET TrangThaiVe=N'Đã hủy' WHERE MaVe=@MaVe AND TrangThaiVe<>N'Đã hủy';",
    fields: [{ key: 'MaVe', label: 'Vé còn hiệu lực', source: 'activeTickets', required: true }],
  },
  'sp2-status': {
    code: 'SP2', title: 'Cập nhật trạng thái chuyến bay', category: 'Điều phối', icon: PlaneTakeoff,
    description: 'Ghi nhận chuyến Delay hoặc Đã hủy cùng lý do. Khi hủy, SP2 hủy các vé liên quan và hoàn hóa đơn đã thanh toán; TG2 có quyền chặn nếu dưới 24 giờ.',
    action: 'Cập nhật trạng thái', sql: 'EXEC dbo.SP2_DELAY_HUY @MaChuyenBay, @TrangThaiMoi, @LyDo;',
    fields: [
      { key: 'MaChuyenBay', label: 'Chuyến bay', source: 'flights', required: true },
      { key: 'TrangThaiMoi', label: 'Trạng thái mới', type: 'select', choices: ['Delay', 'Đã hủy'], required: true },
      { key: 'LyDo', label: 'Lý do', type: 'textarea', required: true, placeholder: 'Ghi rõ lý do cập nhật' },
    ],
  },
  'tg2-test': {
    code: 'TG2', title: 'TG2 · Chặn hủy chuyến dưới 24 giờ', category: 'Trigger', icon: ShieldCheck,
    description: 'Thử hủy chuyến qua SP2 khi giờ khởi hành còn dưới 24 giờ. Kết quả mong đợi là lỗi SQL Server 51003; chuyến bay, vé và hóa đơn phải giữ nguyên.',
    action: 'Thử hủy chuyến (TG2)', sql: "EXEC dbo.SP2_DELAY_HUY @MaChuyenBay, N'Đã hủy', @LyDo;",
    fields: [
      { key: 'MaChuyenBay', label: 'Chuyến chưa khởi hành trong 24 giờ', source: 'tg2Flights', required: true },
      { key: 'LyDo', label: 'Lý do kiểm thử', type: 'text', required: true },
    ],
  },
  'sp3-revenue': {
    code: 'SP3', title: 'Doanh thu theo chặng bay', category: 'Báo cáo', icon: BarChart3,
    description: 'Tổng hợp hóa đơn thanh toán thành công theo đường bay trong khoảng ngày đóng [Từ ngày, Đến ngày]. Vé đã hủy không được tính.',
    action: 'Thống kê doanh thu', sql: 'EXEC dbo.SP3_TINHDOANHTHU @TuNgay, @DenNgay;',
    fields: [
      { key: 'TuNgay', label: 'Từ ngày', type: 'date', required: true },
      { key: 'DenNgay', label: 'Đến ngày', type: 'date', required: true },
    ],
  },
  'sp4-search': {
    code: 'SP4', title: 'Tra cứu chuyến bay', category: 'Tra cứu', icon: Search,
    description: 'Tìm chuyến theo sân bay đi, sân bay đến và ngày khởi hành. Kết quả gồm giờ bay, máy bay, trạng thái và số ghế còn.',
    action: 'Tra cứu chuyến', sql: 'EXEC dbo.SP4_TRACUUDANHSACH @MaSanBayDi, @MaSanBayDen, @NgayBay;',
    fields: [
      { key: 'MaSanBayDi', label: 'Sân bay đi', source: 'airports', required: true },
      { key: 'MaSanBayDen', label: 'Sân bay đến', source: 'airports', required: true },
      { key: 'NgayBay', label: 'Ngày bay (UTC)', type: 'date', required: true },
    ],
  },
  'sp5-crew': {
    code: 'SP5', title: 'Phân công tổ bay', category: 'Điều phối', icon: Users,
    description: 'Gán một nhân viên đủ điều kiện vào chuyến. SP5 kiểm tra vai trò, tình trạng làm việc, khoảng ca, trùng lịch và tối thiểu 8 giờ nghỉ; TG3 kiểm tra tối đa 30 giờ/tuần.',
    action: 'Lưu phân công', sql: 'EXEC dbo.SP5_PHANCONGTOBAY @MaChuyenBay, @MaNV, @VaiTro, @GioBatDauMoi, @GioKetThucMoi;',
    fields: [
      { key: 'MaChuyenBay', label: 'Chuyến bay', source: 'flights', required: true },
      { key: 'MaNV', label: 'Nhân viên', source: 'employees', required: true },
      { key: 'VaiTro', label: 'Vai trò', type: 'select', choices: ['Cơ trưởng', 'Cơ phó', 'Tiếp viên trưởng', 'Tiếp viên hàng không'], required: true },
      { key: 'GioBatDauMoi', label: 'Giờ bắt đầu (UTC)', type: 'datetime-local', required: true },
      { key: 'GioKetThucMoi', label: 'Giờ kết thúc (UTC)', type: 'datetime-local', required: true },
    ],
  },
  'tg3-test': {
    code: 'TG3', title: 'TG3 · Kiểm tra định mức 30 giờ/tuần', category: 'Trigger', icon: ShieldCheck,
    description: 'Thử thêm một batch 4 ca, tổng 32 giờ cho NV01 trong cùng tuần. Trigger TG3 phải trả lỗi 51004 và rollback toàn bộ batch, không để lại phân công thử.',
    action: 'Thử batch vượt định mức', sql: "BEGIN TRY\n  BEGIN TRANSACTION;\n  INSERT dbo.PHANCONG(MaChuyenBay,MaNV,VaiTro,GioBatDau,GioKetThuc) VALUES\n    ('QH156','NV01',N'Cơ trưởng','2026-10-15 00:00','2026-10-15 08:00'),\n    ('QH312','NV01',N'Cơ trưởng','2026-10-16 00:00','2026-10-16 08:00'),\n    ('QH402','NV01',N'Cơ trưởng','2026-10-16 09:00','2026-10-16 17:00'),\n    ('QH510','NV01',N'Cơ trưởng','2026-10-17 00:00','2026-10-17 08:00');\n  COMMIT TRANSACTION;\nEND TRY\nBEGIN CATCH\n  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;\n  THROW;\nEND CATCH;",
    fields: [],
  },
  'tg4-test': {
    code: 'TG4', title: 'TG4 · Bảo vệ giá vé thương gia', category: 'Trigger', icon: ShieldCheck,
    description: 'Thử đặt giá vé Thương gia bằng giá Phổ thông trên cùng chuyến. Trigger TG4 phải trả lỗi 51005; giá hợp lệ hiện có cần còn nguyên sau khi tải lại.',
    action: 'Thử giá không hợp lệ', sql: 'UPDATE dbo.CHUYENBAY SET GiaVeThuongGia=GiaVePhoThong WHERE MaChuyenBay=@MaChuyenBay;',
    fields: [{ key: 'MaChuyenBay', label: 'Chuyến bay', source: 'flights', required: true }],
  },
  'tg5-test': {
    code: 'TG5', title: 'TG5 · Chặn xóa máy bay có lịch bay', category: 'Trigger', icon: ShieldCheck,
    description: 'Thử xóa một máy bay đang được chuyến bay tương lai sử dụng. Trigger TG5 dự kiến trả lỗi 51006; máy bay và lịch bay phải còn nguyên.',
    action: 'Thử xóa máy bay', sql: 'DELETE FROM dbo.MAYBAY WHERE MaMayBay=@MaMayBay;',
    fields: [{ key: 'MaMayBay', label: 'Máy bay có chuyến bay tương lai', source: 'scheduledAircraft', required: true }],
  },
  'price-update': {
    code: 'CRUD', title: 'Cập nhật giá vé', category: 'Quản trị dữ liệu', icon: WalletCards,
    description: 'Điều chỉnh giá vé Thương gia của một chuyến bay. Form đối chiếu giá Phổ thông trước khi gửi; TG4 vẫn kiểm tra ở database và từ chối nếu giá mới không cao hơn.',
    action: 'Lưu giá vé mới', sql: 'UPDATE dbo.CHUYENBAY SET GiaVeThuongGia=@GiaVeMoi WHERE MaChuyenBay=@MaChuyenBay;',
    fields: [
      { key: 'MaChuyenBay', label: 'Chuyến bay', source: 'flights', required: true },
      { key: 'GiaVeMoi', label: 'Giá Thương gia mới (VND)', type: 'number', required: true },
    ],
  },
  'aircraft-maintenance': {
    code: 'CRUD', title: 'Tình trạng máy bay', category: 'Quản trị dữ liệu', icon: Plane,
    description: 'Cập nhật trạng thái khai thác máy bay theo danh mục hiện có. Ràng buộc CHECK trong CSDL chỉ chấp nhận Sẵn sàng khai thác hoặc Bảo dưỡng định kỳ.',
    action: 'Cập nhật tình trạng', sql: 'UPDATE dbo.MAYBAY SET TrangThai=@TrangThai WHERE MaMayBay=@MaMayBay;',
    fields: [
      { key: 'MaMayBay', label: 'Máy bay', source: 'aircraft', required: true },
      { key: 'TrangThai', label: 'Trạng thái', type: 'select', choices: ['Sẵn sàng khai thác', 'Bảo dưỡng định kỳ'], required: true },
    ],
  },
  'fn1-membership': {
    code: 'FN1', title: 'Tra cứu hạng hội viên', category: 'Function', icon: Users,
    description: 'Tính tổng hóa đơn đã thanh toán, chưa hoàn tiền và chưa hủy để trả về hạng hội viên theo ngưỡng tích lũy của function FN1.',
    action: 'Tính hạng hội viên', sql: 'SELECT dbo.FN1_HangHoiVien(@MaHanhKhach) AS HangHoiVien;',
    fields: [{ key: 'MaHanhKhach', label: 'Hành khách', source: 'passengers', required: true }],
  },
  'fn2-seats': {
    code: 'FN2', title: 'Sơ đồ ghế còn trống', category: 'Function', icon: Ticket,
    description: 'Liệt kê vị trí ghế chưa có vé hiệu lực theo sức chứa và sơ đồ hàng A–F của máy bay đang gán cho chuyến.',
    action: 'Tải danh sách ghế trống', sql: 'SELECT * FROM dbo.FN2_DanhSachGheTrong(@MaChuyenBay) ORDER BY SoGhe;',
    fields: [{ key: 'MaChuyenBay', label: 'Chuyến bay', source: 'flights', required: true }],
  },
  'fn3-aircraft': {
    code: 'FN3', title: 'Hiệu suất máy bay theo tháng', category: 'Function', icon: Gauge,
    description: 'Thống kê tần suất và tổng giờ bay lũy kế của một máy bay trong tháng được chọn.',
    action: 'Tính hiệu suất', sql: 'SELECT * FROM dbo.FN3_ThongKeMayBayTheoThang(@MaMayBay, @Nam, @Thang);',
    fields: [
      { key: 'MaMayBay', label: 'Máy bay', source: 'aircraft', required: true },
      { key: 'Nam', label: 'Năm', type: 'number', required: true },
      { key: 'Thang', label: 'Tháng', type: 'number', required: true },
    ],
  },
  'cs1-delay': {
    code: 'CS1', title: 'Tính bồi thường chuyến Delay', category: 'Cursor', icon: WalletCards,
    description: 'Cursor duyệt chuyến Delay, xác định số phút trễ, số vé còn hiệu lực và mức bồi thường cho từng hành khách theo các mốc trong procedure.',
    action: 'Tính bồi thường', sql: 'EXEC dbo.CS1_TinhBoiThuongChuyenBayDelay;', fields: [],
  },
  'cs2-payroll': {
    code: 'CS2', title: 'Tổng hợp công nhật & phụ cấp', category: 'Cursor', icon: WalletCards,
    description: 'Cursor nhóm phân công theo nhân viên, ngày và vai trò, rồi tính số chuyến, giờ công, công nhật và phụ cấp trong khoảng ngày.',
    action: 'Tổng hợp công nhật', sql: 'EXEC dbo.CS2_TongHopCongNhatPhuCap @TuNgay, @DenNgay;',
    fields: [
      { key: 'TuNgay', label: 'Từ ngày', type: 'date', required: true },
      { key: 'DenNgay', label: 'Đến ngày', type: 'date', required: true },
    ],
  },
  'report-ticket': {
    code: 'R1', title: 'Vé điện tử · E-ticket', category: 'Báo cáo', icon: FileCheck2,
    description: 'Lập vé điện tử gồm thông tin vé, hành khách, chặng bay và thanh toán; bản in hiển thị đủ 5 vùng báo cáo.',
    action: 'Tạo bản xem trước', sql: "SELECT N'HEADER' AS Phan,N'Vé điện tử' AS TieuDe,vb.MaVe,vb.MaDatCho,cb.MaChuyenBay,db.MaSanBayDi,db.MaSanBayDen\nFROM dbo.VEBAY vb JOIN dbo.CHUYENBAY cb ON cb.MaChuyenBay=vb.MaChuyenBay JOIN dbo.DUONGBAY db ON db.MaDuongBay=cb.MaDuongBay WHERE vb.MaVe=@MaVe;\nSELECT N'DETAIL' AS Phan,hk.HoTen,hk.SoGiayTo,vb.SoGhe,vb.HangGhe,vb.GiaVe,cb.GioKhoiHanhDK,cb.GioHaCanhDK\nFROM dbo.VEBAY vb JOIN dbo.HANHKHACH hk ON hk.MaHanhKhach=vb.MaHanhKhach JOIN dbo.CHUYENBAY cb ON cb.MaChuyenBay=vb.MaChuyenBay WHERE vb.MaVe=@MaVe;\nSELECT N'FOOTER' AS Phan,vb.TrangThaiVe,hd.TrangThaiThanhToan,hd.NgayThanhToan,hd.SoTien\nFROM dbo.VEBAY vb LEFT JOIN dbo.HOADON hd ON hd.MaVe=vb.MaVe WHERE vb.MaVe=@MaVe;",
    fields: [{ key: 'MaVe', label: 'Mã vé', source: 'tickets', required: true }], report: true,
  },
  'report-manifest': {
    code: 'R2', title: 'Danh sách hành khách · Manifest', category: 'Báo cáo', icon: Users,
    description: 'Danh sách hành khách còn hiệu lực của chuyến bay, bao gồm số ghế, giấy tờ và trạng thái check-in.',
    action: 'Tạo bản xem trước', sql: "SELECT N'HEADER' AS Phan,N'Passenger Manifest' AS TieuDe,cb.MaChuyenBay,db.MaSanBayDi,db.MaSanBayDen,cb.GioKhoiHanhDK\nFROM dbo.CHUYENBAY cb JOIN dbo.DUONGBAY db ON db.MaDuongBay=cb.MaDuongBay WHERE cb.MaChuyenBay=@MaChuyenBay;\nSELECT N'DETAIL' AS Phan,vb.MaVe,vb.SoGhe,vb.HangGhe,hk.HoTen,hk.NgaySinh,hk.SoGiayTo,hk.QuocTich,vb.TrangThaiVe\nFROM dbo.VEBAY vb JOIN dbo.HANHKHACH hk ON hk.MaHanhKhach=vb.MaHanhKhach WHERE vb.MaChuyenBay=@MaChuyenBay AND vb.TrangThaiVe<>N'Đã hủy' ORDER BY vb.SoGhe;\nSELECT N'FOOTER' AS Phan,COUNT(*) AS TongHanhKhach,SUM(CASE WHEN TrangThaiVe=N'Đã check-in' THEN 1 ELSE 0 END) AS DaCheckIn\nFROM dbo.VEBAY WHERE MaChuyenBay=@MaChuyenBay AND TrangThaiVe<>N'Đã hủy';",
    fields: [{ key: 'MaChuyenBay', label: 'Chuyến bay', source: 'flights', required: true }], report: true,
  },
  'report-crew': {
    code: 'R3', title: 'Phân công tổ bay theo ngày', category: 'Báo cáo', icon: CalendarDays,
    description: 'Bảng phân công phi hành đoàn theo ngày với vai trò, thời gian ca và tổng giờ công.',
    action: 'Tạo bản xem trước', sql: "SELECT N'HEADER' AS Phan,N'Phân công phi hành đoàn' AS TieuDe,@NgayBay AS NgayBaoCao;\nSELECT N'DETAIL' AS Phan,pc.MaChuyenBay,pc.MaNV,nv.HoTen,pc.VaiTro,pc.GioBatDau,pc.GioKetThuc,DATEDIFF(MINUTE,pc.GioBatDau,pc.GioKetThuc)/60.0 AS SoGio\nFROM dbo.PHANCONG pc JOIN dbo.NHANVIEN nv ON nv.MaNV=pc.MaNV WHERE CONVERT(date,pc.GioBatDau)=@NgayBay ORDER BY pc.GioBatDau;\nSELECT N'FOOTER' AS Phan,COUNT(*) AS SoPhanCong,COUNT(DISTINCT MaChuyenBay) AS SoChuyenBay,COALESCE(SUM(DATEDIFF(MINUTE,GioBatDau,GioKetThuc))/60.0,0) AS TongGioCong\nFROM dbo.PHANCONG WHERE CONVERT(date,GioBatDau)=@NgayBay;",
    fields: [{ key: 'NgayBay', label: 'Ngày báo cáo', type: 'date', required: true }], report: true,
  },
  'report-revenue': {
    code: 'R4', title: 'Doanh số theo đường bay', category: 'Báo cáo', icon: BarChart3,
    description: 'Tổng hợp số giao dịch và doanh thu thanh toán thành công theo từng đường bay trong khoảng ngày.',
    action: 'Tạo bản xem trước', sql: "SELECT N'HEADER' AS Phan,N'Doanh số theo đường bay' AS TieuDe,@TuNgay AS TuNgay,@DenNgay AS DenNgay;\nSELECT N'DETAIL' AS Phan,db.MaDuongBay,db.MaSanBayDi,db.MaSanBayDen,COUNT(hd.MaHoaDon) AS SoGiaoDich,COALESCE(SUM(hd.SoTien),0) AS DoanhThu\nFROM dbo.DUONGBAY db LEFT JOIN dbo.CHUYENBAY cb ON cb.MaDuongBay=db.MaDuongBay LEFT JOIN dbo.VEBAY vb ON vb.MaChuyenBay=cb.MaChuyenBay AND vb.TrangThaiVe<>N'Đã hủy'\nLEFT JOIN dbo.HOADON hd ON hd.MaVe=vb.MaVe AND hd.TrangThaiThanhToan=N'Thành công' AND hd.NgayThanhToan>=@TuNgay AND hd.NgayThanhToan<DATEADD(DAY,1,@DenNgay) GROUP BY db.MaDuongBay,db.MaSanBayDi,db.MaSanBayDen;\nSELECT N'FOOTER' AS Phan,COUNT(*) AS SoHoaDon,COALESCE(SUM(hd.SoTien),0) AS TongDoanhThu FROM dbo.HOADON hd JOIN dbo.VEBAY vb ON vb.MaVe=hd.MaVe WHERE hd.TrangThaiThanhToan=N'Thành công' AND vb.TrangThaiVe<>N'Đã hủy' AND hd.NgayThanhToan>=@TuNgay AND hd.NgayThanhToan<DATEADD(DAY,1,@DenNgay);",
    fields: [
      { key: 'TuNgay', label: 'Từ ngày', type: 'date', required: true },
      { key: 'DenNgay', label: 'Đến ngày', type: 'date', required: true },
    ], report: true,
  },
  'report-performance': {
    code: 'R5', title: 'Hiệu suất khai thác', category: 'Báo cáo', icon: Activity,
    description: 'Tổng hợp chuyến đúng giờ, Delay và hủy trong khoảng ngày, kèm tỷ lệ theo trạng thái.',
    action: 'Tạo bản xem trước', sql: "SELECT N'HEADER' AS Phan,N'Hiệu suất khai thác' AS TieuDe,@TuNgay AS TuNgay,@DenNgay AS DenNgay;\nSELECT N'DETAIL' AS Phan,TrangThai,COUNT(*) AS SoChuyen,CONVERT(decimal(6,2),100.0*COUNT(*)/NULLIF(SUM(COUNT(*)) OVER(),0)) AS TyLePhanTram\nFROM dbo.CHUYENBAY WHERE GioKhoiHanhDK>=@TuNgay AND GioKhoiHanhDK<DATEADD(DAY,1,@DenNgay) GROUP BY TrangThai;\nSELECT N'FOOTER' AS Phan,COUNT(*) AS TongChuyenBay,SUM(CASE WHEN TrangThai=N'Đúng giờ' OR (TrangThai=N'Đã bay' AND GioCatCanhTT IS NOT NULL AND DATEDIFF(MINUTE,GioKhoiHanhDK,GioCatCanhTT)<=15) THEN 1 ELSE 0 END) AS DungGio,\nSUM(CASE WHEN TrangThai=N'Delay' OR (GioCatCanhTT IS NOT NULL AND DATEDIFF(MINUTE,GioKhoiHanhDK,GioCatCanhTT)>15) THEN 1 ELSE 0 END) AS Hoan,SUM(CASE WHEN TrangThai=N'Đã hủy' THEN 1 ELSE 0 END) AS Huy\nFROM dbo.CHUYENBAY WHERE GioKhoiHanhDK>=@TuNgay AND GioKhoiHanhDK<DATEADD(DAY,1,@DenNgay);",
    fields: [
      { key: 'TuNgay', label: 'Từ ngày', type: 'date', required: true },
      { key: 'DenNgay', label: 'Đến ngày', type: 'date', required: true },
    ], report: true,
  },
};

const navGroups = [
  { label: 'Tổng quan', items: [{ id: 'home', label: 'Trang chủ', icon: LayoutDashboard }] },
  { label: 'Nghiệp vụ', items: [
    { id: 'sp4-search', label: 'Tra cứu chuyến bay', icon: Search },
    { id: 'sp1-book', label: 'Đặt chỗ & bán vé', icon: Ticket },
    { id: 'tg1-cancel', label: 'Hủy vé / hoàn ghế', icon: RefreshCw },
    { id: 'sp2-status', label: 'Trạng thái chuyến', icon: PlaneTakeoff },
    { id: 'sp5-crew', label: 'Phân công tổ bay', icon: Users },
  ] },
  { label: 'Logic cơ sở dữ liệu', items: [
    { id: 'tg1-book', label: 'TG1 · Giữ ghế', icon: Zap },
    { id: 'tg2-test', label: 'TG2 · Chặn hủy < 24h', icon: ShieldCheck },
    { id: 'tg3-test', label: 'TG3 · Giới hạn giờ bay', icon: ShieldCheck },
    { id: 'tg4-test', label: 'TG4 · Kiểm tra giá vé', icon: ShieldCheck },
    { id: 'tg5-test', label: 'TG5 · Bảo vệ máy bay', icon: ShieldCheck },
    { id: 'fn1-membership', label: 'FN1 · Hạng hội viên', icon: Users },
    { id: 'fn2-seats', label: 'FN2 · Ghế trống', icon: Ticket },
    { id: 'fn3-aircraft', label: 'FN3 · Hiệu suất máy bay', icon: Gauge },
    { id: 'cs1-delay', label: 'CS1 · Bồi thường Delay', icon: WalletCards },
    { id: 'cs2-payroll', label: 'CS2 · Công nhật', icon: WalletCards },
  ] },
  { label: 'Báo cáo', items: [
    { id: 'report-ticket', label: 'R1 · Vé điện tử', icon: FileCheck2 },
    { id: 'report-manifest', label: 'R2 · Passenger manifest', icon: Users },
    { id: 'report-crew', label: 'R3 · Phân công theo ngày', icon: CalendarDays },
    { id: 'report-revenue', label: 'R4 · Doanh số đường bay', icon: BarChart3 },
    { id: 'report-performance', label: 'R5 · Hiệu suất khai thác', icon: Activity },
  ] },
  { label: 'Quản trị dữ liệu', items: [
    { id: 'price-update', label: 'Cập nhật giá vé', icon: WalletCards },
    { id: 'aircraft-maintenance', label: 'Tình trạng máy bay', icon: Plane },
  ] },
];

const ROLES = {
  admin: {
    id: 'admin',
    label: 'Quản trị viên',
    badge: 'QT',
    roleClass: 'role-admin',
    roleTitle: 'Toàn quyền quản trị',
    desc: 'Xem toàn bộ báo cáo, kiểm thử trigger & cấu hình',
  },
  flightops: {
    id: 'flightops',
    label: 'Điều phối viên',
    badge: 'ĐP',
    roleClass: 'role-flightops',
    roleTitle: 'Điều phối khai thác',
    desc: 'Cập nhật chuyến bay, tổ bay & báo cáo vận hành',
  },
  ticketing: {
    id: 'ticketing',
    label: 'Nhân viên bán vé',
    badge: 'BV',
    roleClass: 'role-ticketing',
    roleTitle: 'Bộ phận bán vé',
    desc: 'Đặt chỗ, xuất vé, hủy vé & xem vé điện tử',
  },
  customer: {
    id: 'customer',
    label: 'Khách hàng',
    badge: 'KH',
    roleClass: 'role-customer',
    roleTitle: 'Hành khách',
    desc: 'Tra cứu chuyến bay, tình trạng ghế & đặt vé',
  },
};

const ROLE_PERMISSIONS = {
  customer: [
    'home',
    'sp4-search',
    'fn2-seats',
    'fn1-membership',
    'sp1-book',
    'report-ticket',
  ],
  ticketing: [
    'home',
    'sp4-search',
    'fn2-seats',
    'fn1-membership',
    'sp1-book',
    'tg1-cancel',
    'report-ticket',
  ],
  flightops: [
    'home',
    'sp4-search',
    'fn2-seats',
    'sp2-status',
    'sp5-crew',
    'aircraft-maintenance',
    'fn3-aircraft',
    'cs1-delay',
    'cs2-payroll',
    'report-manifest',
    'report-crew',
    'report-performance',
  ],
  admin: ['*'],
};

function canAccess(role, workflowId) {
  if (!role || role === 'admin') return true;
  const list = ROLE_PERMISSIONS[role] || [];
  return list.includes(workflowId);
}

let activeRole = 'admin';

function first(items, value) { return (items || []).find((item) => item.MaChuyenBay === value) || (items || [])[0]; }
function firstValue(items, key, fallback) { return (items && items[0] && items[0][key]) || fallback; }

function initialParams(id, options) {
  const flight = id === 'tg2-test'
    ? first(options.tg2Flights, 'VN601')
    : first(options.flights, id === 'sp5-crew' ? 'QH510' : 'VN716');
  const fields = workflows[id].fields;
  const values = {};
  for (const field of fields) {
    if (field.source === 'flights') values[field.key] = flight && flight.MaChuyenBay;
    else if (field.source === 'airports') values[field.key] = field.key === 'MaSanBayDi' ? 'SGN' : 'HAN';
    else if (field.source === 'passengers') values[field.key] = firstValue(options.passengers, 'MaHanhKhach', 'HK01');
    else if (field.source === 'employees') values[field.key] = 'NV01';
    else if (field.source === 'aircraft') values[field.key] = firstValue(options.aircraft, 'MaMayBay', 'MB01');
    else if (field.source === 'scheduledAircraft') values[field.key] = firstValue(options.scheduledAircraft, 'MaMayBay', '');
    else if (field.source === 'tickets') values[field.key] = firstValue(options.tickets, 'MaVe', 'VE01');
    else if (field.source === 'activeTickets') values[field.key] = firstValue((options.tickets || []).filter((row) => row.TrangThaiVe !== 'Đã hủy'), 'MaVe', 'VE01');
    else if (field.key === 'MaVe') values[field.key] = 'DEMO' + Math.random().toString(36).slice(2, 9).toUpperCase();
    else if (field.key === 'MaDatCho') values[field.key] = 'PNR' + Math.random().toString(36).slice(2, 9).toUpperCase();
    else if (field.key === 'SoGhe') values[field.key] = '40A';
    else if (field.key === 'HangGhe') values[field.key] = 'Phổ thông';
    else if (field.key === 'GiaVeMoi') values[field.key] = String(Math.max(1, Number(flight && flight.GiaVeThuongGia || 1000000) + 100000));
    else if (field.key === 'TrangThaiMoi') values[field.key] = id === 'tg2-test' ? 'Đã hủy' : 'Delay';
    else if (field.key === 'LyDo') values[field.key] = id === 'tg2-test' ? 'Kiểm thử trigger TG2' : 'Điều chỉnh kế hoạch khai thác';
    else if (field.key === 'TuNgay') values[field.key] = '2026-10-01';
    else if (field.key === 'DenNgay') values[field.key] = '2026-10-31';
    else if (field.key === 'NgayBay') values[field.key] = id === 'report-crew' ? '2026-10-14' : '2026-10-10';
    else if (field.key === 'MaNV') values[field.key] = 'NV01';
    else if (field.key === 'VaiTro') values[field.key] = 'Cơ trưởng';
    else if (field.key === 'GioBatDauMoi') values[field.key] = '2026-10-17T17:30';
    else if (field.key === 'GioKetThucMoi') values[field.key] = '2026-10-17T21:00';
    else if (field.key === 'Nam') values[field.key] = '2026';
    else if (field.key === 'Thang') values[field.key] = '10';
    else if (field.key === 'TrangThai' && id === 'aircraft-maintenance') values[field.key] = 'Sẵn sàng khai thác';
    else if (field.type === 'select') values[field.key] = field.choices[0];
    else values[field.key] = '';
  }
  return values;
}

async function api(url, options = {}) {
  const headers = {
    'x-user-role': activeRole,
    ...(options.headers || {}),
  };
  const response = await fetch(url, { ...options, headers });
  const body = await response.json();
  if (body && body.ok === false && body.error) throw body.error;
  if (!response.ok && body.error) throw body.error;
  return body;
}

function formatValue(value, key) {
  if (value === null || value === undefined || value === '') return '—';
  if (typeof value === 'boolean') return value ? 'Có' : 'Không';
  if (typeof value === 'string' && /^\d{4}-\d{2}-\d{2}T/.test(value)) {
    return value.replace('T', ' ').replace(/\.\d{3}Z$/, ' UTC').replace(/Z$/, ' UTC').slice(0, 23);
  }
  if (typeof value === 'number' && /gia|tien|doanhthu|boithuong|congn hat|phucap|tongthanhtoan|sotien/i.test(key || '')) {
    return new Intl.NumberFormat('vi-VN').format(value) + ' ₫';
  }
  if (typeof value === 'number') return new Intl.NumberFormat('vi-VN', { maximumFractionDigits: 2 }).format(value);
  return String(value);
}

function DataTable({ rows, empty = 'Không có bản ghi phù hợp.', compact = false }) {
  const list = rows || [];
  const columns = list.length ? Object.keys(list[0]) : [];
  if (!columns.length) return <div className="table-empty"><Database size={16} />{empty}</div>;
  return (
    <div className={'table-wrap' + (compact ? ' compact' : '')}>
      <table>
        <thead><tr>{columns.map((column) => <th key={column}>{column.replace(/([a-z])([A-Z])/g, '$1 $2')}</th>)}</tr></thead>
        <tbody>{list.map((row, index) => <tr key={index}>{columns.map((column) => <td key={column}>{formatValue(row[column], column)}</td>)}</tr>)}</tbody>
      </table>
      <div className="table-count">{list.length} dòng</div>
    </div>
  );
}

function Sidebar({ active, setActive, open, setOpen, databaseName, currentRole, onRoleChange }) {
  const roleMeta = ROLES[currentRole] || ROLES.admin;
  return (
    <aside className={'sidebar' + (open ? ' open' : '')}>
      <div className="brand-row">
        <div className="brand-mark"><Plane size={22} fill="currentColor" /></div>
        <div><div className="brand-name">skyroute</div><div className="brand-sub">FLIGHT OPERATIONS</div></div>
        <button className="icon-button sidebar-close" onClick={() => setOpen(false)} aria-label="Đóng menu"><X size={18} /></button>
      </div>
      <div className="workspace-pill"><span className="workspace-dot" />{databaseName || 'QL_CHUYENBAY'}<ChevronDown size={14} /></div>
      <nav>
        {navGroups.map((group) => {
          const visibleItems = group.items.filter((item) => canAccess(currentRole, item.id));
          if (!visibleItems.length) return null;
          return (
            <div className="nav-group" key={group.label}>
              <div className="nav-heading">{group.label}</div>
              {visibleItems.map((item) => {
                const Icon = item.icon;
                return (
                  <button key={item.id} className={'nav-link' + (active === item.id ? ' active' : '')}
                    onClick={() => { setActive(item.id); setOpen(false); }}>
                    <Icon size={17} strokeWidth={1.8} /><span>{item.label}</span>
                    {item.id.startsWith('tg') && <span className="nav-tag">DB</span>}
                  </button>
                );
              })}
            </div>
          );
        })}
      </nav>
      <div className="sidebar-bottom">
        <div className="db-card"><div className="db-icon"><Database size={16} /></div><div><strong>SQL Server</strong><small>{databaseName || 'Đang kiểm tra kết nối'}</small></div><span className="live-dot" /></div>
        <div className="role-switcher-card">
          <div className="role-switcher-header">
            <div className={'avatar ' + roleMeta.roleClass}>{roleMeta.badge}</div>
            <div className="role-info">
              <strong>{roleMeta.label}</strong>
              <small>{roleMeta.roleTitle}</small>
            </div>
          </div>
          <div className="role-select-wrap">
            <label htmlFor="role-select" className="role-select-label">Vai trò mô phỏng:</label>
            <select
              id="role-select"
              className="role-select"
              value={currentRole}
              onChange={(e) => onRoleChange(e.target.value)}
            >
              {Object.values(ROLES).map((r) => (
                <option key={r.id} value={r.id}>
                  {r.badge} · {r.label}
                </option>
              ))}
            </select>
          </div>
        </div>
      </div>
    </aside>
  );
}

function Topbar({ title, subtitle, setOpen, online, currentRole }) {
  const roleMeta = ROLES[currentRole] || ROLES.admin;
  return (
    <header className="topbar">
      <button className="icon-button menu-toggle" onClick={() => setOpen(true)} aria-label="Mở menu"><Menu size={20} /></button>
      <div className="breadcrumbs"><span>Quản lý chuyến bay</span><span className="crumb-sep">/</span><strong>{title}</strong></div>
      <div className="topbar-right">
        <div className={'role-pill ' + roleMeta.roleClass}>
          <span className="role-pill-badge">{roleMeta.badge}</span>
          <span>{roleMeta.label}</span>
        </div>
        <div className={'connection-chip' + (online ? ' online' : ' offline')}><span />{online ? 'SQL Server kết nối' : 'Mất kết nối'}</div>
        <div className="top-date"><CalendarDays size={15} /> 10 — 19 OCT 2026</div>
      </div>
    </header>
  );
}

function FlightStatus({ value }) {
  const state = value === 'Đã hủy' ? 'cancelled' : value === 'Delay' ? 'delay' : value === 'Đúng giờ' ? 'ontime' : value === 'Đã bay' ? 'completed' : 'scheduled';
  return <span className={'status-badge ' + state}><i />{value || '—'}</span>;
}

function Dashboard({ dashboard, options, setActive, reload, currentRole }) {
  const counts = (dashboard && dashboard.counts) || {};
  const roleMeta = ROLES[currentRole] || ROLES.admin;

  const welcomeTitles = {
    admin: { greeting: 'Xin chào, Quản trị viên', desc: 'Toàn quyền quản trị cơ sở dữ liệu và hệ thống báo cáo Skyroute.' },
    flightops: { greeting: 'Xin chào, Điều phối viên', desc: 'Theo dõi lịch bay, phân công tổ bay và xử lý điều phối thời gian thực.' },
    ticketing: { greeting: 'Xin chào, Nhân viên bán vé', desc: 'Quản lý đặt chỗ, tra cứu chuyến bay và phát hành vé điện tử.' },
    customer: { greeting: 'Xin chào, Quý khách hàng', desc: 'Tra cứu thông tin chuyến bay, sơ đồ ghế trống và đặt vé trực tuyến.' },
  };
  const welcome = welcomeTitles[currentRole] || welcomeTitles.admin;

  const stats = currentRole === 'customer'
    ? [
        { label: 'Chuyến bay', value: counts.ChuyenBay || 0, note: 'Đang mở đặt chỗ', icon: Plane, color: 'blue' },
        { label: 'Sân bay kết nối', value: (options && options.airports ? options.airports.length : 3), note: 'Mạng lưới khai thác', icon: PlaneTakeoff, color: 'green' },
        { label: 'Dịch vụ tra cứu', value: '24/7', note: 'Lịch bay & ghế trống', icon: Search, color: 'violet' },
        { label: 'Tích lũy hội viên', value: 'FN1', note: 'Tra cứu hạng thẻ cá nhân', icon: Users, color: 'orange' },
      ]
    : currentRole === 'flightops'
    ? [
        { label: 'Chuyến bay', value: counts.ChuyenBay || 0, note: 'Trong lịch khai thác', icon: Plane, color: 'blue' },
        { label: 'Đội bay', value: counts.MayBay || 0, note: 'Máy bay trong danh mục', icon: PlaneTakeoff, color: 'green' },
        { label: 'Tổ bay', value: 'SP5', note: 'Phân công & giờ nghỉ', icon: Users, color: 'violet' },
        { label: 'Hiệu suất', value: 'R5', note: 'Tỷ lệ đúng giờ & chậm', icon: Activity, color: 'orange' },
      ]
    : currentRole === 'ticketing'
    ? [
        { label: 'Chuyến bay', value: counts.ChuyenBay || 0, note: 'Mở bán vé', icon: Plane, color: 'blue' },
        { label: 'Vé đã phát hành', value: counts.VeBay || 0, note: 'Tổng vé hệ thống', icon: Ticket, color: 'violet' },
        { label: 'Hành khách', value: counts.HanhKhach || 0, note: 'Hồ sơ khách hàng', icon: Users, color: 'orange' },
        { label: 'Sơ đồ ghế', value: 'FN2', note: 'Vị trí ghế còn mở bán', icon: PlaneTakeoff, color: 'green' },
      ]
    : [
        { label: 'Chuyến bay', value: counts.ChuyenBay || 0, note: 'Trong lịch khai thác', icon: Plane, color: 'blue' },
        { label: 'Vé đã phát hành', value: counts.VeBay || 0, note: 'Tổng vé trong hệ thống', icon: Ticket, color: 'violet' },
        { label: 'Hành khách', value: counts.HanhKhach || 0, note: 'Hồ sơ khách hàng', icon: Users, color: 'orange' },
        { label: 'Đội bay', value: counts.MayBay || 0, note: 'Máy bay trong danh mục', icon: PlaneTakeoff, color: 'green' },
      ];

  const quickItemsByRole = {
    admin: [
      ['sp1-book', 'Đặt chỗ & bán vé', 'Tạo vé, kiểm tra ghế trống', Ticket, 'quick-blue'],
      ['sp5-crew', 'Phân công tổ bay', 'Xếp lịch và kiểm tra thời gian nghỉ', Users, 'quick-violet'],
      ['tg2-test', 'Kiểm tra Trigger', 'Thử quy tắc chặn hủy dưới 24h', ShieldCheck, 'quick-orange'],
      ['report-revenue', 'Báo cáo doanh thu', 'Xem kết quả theo đường bay', BarChart3, 'quick-green'],
    ],
    flightops: [
      ['sp2-status', 'Cập nhật chuyến bay', 'Ghi nhận Delay hoặc Hủy chuyến', PlaneTakeoff, 'quick-blue'],
      ['sp5-crew', 'Phân công tổ bay', 'Gán nhân sự và kiểm tra ca nghỉ', Users, 'quick-violet'],
      ['cs1-delay', 'Bồi thường Delay', 'Tính tiền bồi thường hành khách', WalletCards, 'quick-orange'],
      ['report-performance', 'Hiệu suất khai thác', 'Báo cáo R5 tỷ lệ đúng giờ', Activity, 'quick-green'],
    ],
    ticketing: [
      ['sp4-search', 'Tra cứu chuyến bay', 'Kiểm tra lịch bay & giờ khởi hành', Search, 'quick-blue'],
      ['sp1-book', 'Đặt chỗ & bán vé', 'SP1 tạo vé & giữ chỗ hành khách', Ticket, 'quick-violet'],
      ['tg1-cancel', 'Hủy vé / hoàn ghế', 'TG1 tự động hoàn lại ghế trống', RefreshCw, 'quick-orange'],
      ['report-ticket', 'Vé điện tử R1', 'Xem và in vé điện tử hành khách', FileCheck2, 'quick-green'],
    ],
    customer: [
      ['sp4-search', 'Tra cứu chuyến bay', 'Tìm chuyến theo ngày & điểm đến', Search, 'quick-blue'],
      ['sp1-book', 'Đặt vé trực tuyến', 'Điền thông tin và chọn hạng ghế', Ticket, 'quick-violet'],
      ['fn2-seats', 'Sơ đồ ghế trống', 'Xem vị trí ghế còn mở bán', Ticket, 'quick-orange'],
      ['fn1-membership', 'Hạng hội viên', 'Tra cứu ưu đãi thẻ tích lũy', Users, 'quick-green'],
    ],
  };

  return (
    <div className="dashboard page-enter">
      <div className="welcome-row">
        <div>
          <div className="eyebrow"><span className="eyebrow-line" />TỔNG QUAN HOẠT ĐỘNG · {roleMeta.label.toUpperCase()}</div>
          <h1>{welcome.greeting} <span>✦</span></h1>
          <p>{welcome.desc}</p>
        </div>
        <button className="button secondary" onClick={reload}><RefreshCw size={15} /> Làm mới</button>
      </div>
      <div className="stats-grid">
        {stats.map((stat) => {
          const Icon = stat.icon;
          return (
            <div className="stat-card" key={stat.label}>
              <div className={'stat-icon ' + stat.color}><Icon size={19} /></div>
              <span className="stat-trend"><Activity size={12} />SQL LIVE</span>
              <div className="stat-label">{stat.label}</div>
              <div className="stat-value">{stat.value}</div>
              <div className="stat-note">{stat.note}</div>
            </div>
          );
        })}
      </div>
      <div className="dashboard-grid">
        <section className="panel flight-panel">
          <div className="panel-heading">
            <div><h2>Chuyến bay theo lịch</h2><p>Các chuyến bay trong dữ liệu mẫu · giờ UTC</p></div>
            <button className="text-button" onClick={() => setActive('sp4-search')}>Tra cứu chuyến <ArrowRight size={14} /></button>
          </div>
          <DataTable rows={dashboard && dashboard.flights} empty="Chưa có dữ liệu lịch bay." compact />
        </section>
        <section className="panel status-panel">
          <div className="panel-heading"><div><h2>Trạng thái khai thác</h2><p>Phân bố chuyến theo trạng thái</p></div><div className="soft-icon"><Activity size={17} /></div></div>
          <div className="status-list">
            {(dashboard && dashboard.mix || []).map((row) => (
              <div className="status-row" key={row.TrangThai}>
                <div><FlightStatus value={row.TrangThai} /><span className="status-number">{row.SoChuyen}</span></div>
                <div className="status-track"><span style={{ width: Math.max(5, (row.SoChuyen / Math.max(1, counts.ChuyenBay || 1)) * 100) + '%' }} /></div>
              </div>
            ))}
          </div>
          {canAccess(currentRole, 'sp2-status') ? (
            <button className="wide-button" onClick={() => setActive('sp2-status')}>Cập nhật trạng thái <ArrowRight size={15} /></button>
          ) : (
            <button className="wide-button" onClick={() => setActive('sp4-search')}>Tra cứu chuyến bay <ArrowRight size={15} /></button>
          )}
        </section>
      </div>
      <section className="quick-panel panel">
        <div className="panel-heading"><div><h2>Truy cập nhanh</h2><p>Đi thẳng đến tác vụ thường dùng theo quyền của bạn</p></div></div>
        <div className="quick-grid">
          {(quickItemsByRole[currentRole] || quickItemsByRole.admin).map(([id, title, note, Icon, tint]) => (
            <button key={id} className="quick-item" onClick={() => setActive(id)}>
              <div className={'quick-icon ' + tint}><Icon size={19} /></div>
              <div><strong>{title}</strong><small>{note}</small></div>
              <ArrowRight size={16} className="quick-arrow" />
            </button>
          ))}
        </div>
      </section>
    </div>
  );
}

function getFieldOptions(field, options) {
  if (field.source === 'flights') return (options.flights || []).map((row) => ({ value: row.MaChuyenBay, label: row.MaChuyenBay + ' · ' + row.MaSanBayDi + ' → ' + row.MaSanBayDen + ' · ' + row.TrangThai }));
  if (field.source === 'tg2Flights') return (options.tg2Flights || []).map((row) => ({ value: row.MaChuyenBay, label: row.MaChuyenBay + ' · ' + row.MaSanBayDi + ' → ' + row.MaSanBayDen + ' · còn dưới 24 giờ' }));
  if (field.source === 'airports') return (options.airports || []).map((row) => ({ value: row.MaSanBay, label: row.MaSanBay + ' · ' + row.TenSanBay }));
  if (field.source === 'passengers') return (options.passengers || []).map((row) => ({ value: row.MaHanhKhach, label: row.MaHanhKhach + ' · ' + row.HoTen }));
  if (field.source === 'employees') return (options.employees || []).map((row) => ({ value: row.MaNV, label: row.MaNV + ' · ' + row.HoTen + ' · ' + row.ChucVu }));
  if (field.source === 'aircraft') return (options.aircraft || []).map((row) => ({ value: row.MaMayBay, label: row.MaMayBay + ' · ' + row.SoHieu + ' · ' + row.LoaiMayBay }));
  if (field.source === 'scheduledAircraft') return (options.scheduledAircraft || []).map((row) => ({ value: row.MaMayBay, label: row.MaMayBay + ' · ' + row.SoHieu + ' · ' + row.LoaiMayBay }));
  if (field.source === 'tickets') return (options.tickets || []).map((row) => ({ value: row.MaVe, label: row.MaVe + ' · ' + row.MaChuyenBay + ' · ' + row.MaHanhKhach }));
  if (field.source === 'activeTickets') return (options.tickets || []).filter((row) => row.TrangThaiVe !== 'Đã hủy').map((row) => ({ value: row.MaVe, label: row.MaVe + ' · ' + row.MaChuyenBay + ' · ghế ' + row.SoGhe }));
  return (field.choices || []).map((value) => ({ value, label: value }));
}

function WorkflowFields({ fields, params, setParams, options }) {
  if (!fields.length) return <div className="no-inputs"><CheckCircle2 size={16} /> Luồng này không cần tham số đầu vào.</div>;
  return <div className="form-grid">{fields.map((field) => {
    const choices = getFieldOptions(field, options);
    return <label className={'form-field' + (field.type === 'textarea' ? ' span-2' : '')} key={field.key}>
      <span>{field.label}{field.required && <i>*</i>}</span>
      {field.source || field.type === 'select' ? <select required={Boolean(field.required)} value={params[field.key] || ''} onChange={(event) => setParams({ ...params, [field.key]: event.target.value })}>
        {!choices.length && <option value="">Không có dữ liệu</option>}{choices.map((choice) => <option key={choice.value} value={choice.value}>{choice.label}</option>)}
      </select> : field.type === 'textarea' ? <textarea value={params[field.key] || ''} placeholder={field.placeholder || ''} onChange={(event) => setParams({ ...params, [field.key]: event.target.value })} rows={3} />
        : <input required={Boolean(field.required)} maxLength={field.key === 'MaVe' || field.key === 'MaDatCho' ? 20 : undefined} type={field.type || 'text'} value={params[field.key] || ''} placeholder={field.placeholder || ''} min={field.type === 'number' ? '1' : undefined} max={field.key === 'Thang' ? '12' : undefined} onChange={(event) => setParams({ ...params, [field.key]: event.target.value })} />}
    </label>;
  })}</div>;
}

function StepHeading({ number, title, hint, done, active }) {
  return <div className={'step-heading' + (active ? ' active' : '')}><span className={'step-number' + (done ? ' done' : '')}>{done ? <Check size={14} /> : number}</span><div><h3>{title}</h3>{hint && <p>{hint}</p>}</div></div>;
}

function ReportDocument({ workflow, tables, recordsets }) {
  const headerRows = (recordsets && recordsets[0]) || [];
  const detailRows = (recordsets && recordsets[1]) || [];
  const footerRows = (recordsets && recordsets[2]) || [];
  const pageColumns = detailRows.length ? Object.keys(detailRows[0]) : [];
  return <div className="report-document" id="report-document">
    <div className="report-region report-header-region"><div className="report-brand"><span className="report-logo"><Plane size={18} /></span><span>SKYROUTE <small>AIRLINE OPERATIONS</small></span></div><div className="report-title"><div>REPORT HEADER</div><h2>{workflow.title}</h2><p>QL_CHUYENBAY · Báo cáo truy xuất từ SQL Server · Giờ UTC</p></div>{headerRows.length > 0 && <DataTable rows={headerRows} compact />}</div>
    <div className="report-region page-header-region"><div className="report-band-label">PAGE HEADER <span>Tiêu đề cột lặp theo trang</span></div>{pageColumns.length ? <div className="page-header-columns">{pageColumns.map((column) => <span key={column}>{column}</span>)}</div> : <div className="page-header-columns"><span>Chưa có dòng chi tiết trong bộ lọc</span></div>}</div>
    <div className="report-region detail-region"><div className="report-band-label">DETAIL <span>{detailRows.length} dòng chi tiết</span></div><DataTable rows={detailRows} empty="Không có bản ghi chi tiết." compact /></div>
    <div className="report-region page-footer-region"><div className="report-band-label">PAGE FOOTER <span>In lúc {new Date().toLocaleString('vi-VN')} · <b className="page-number">Trang 1</b></span></div></div>
    <div className="report-region report-footer-region"><div className="report-band-label">REPORT FOOTER <span>Tổng kết cuối báo cáo</span></div><DataTable rows={footerRows} empty="Không có dòng tổng kết." compact /></div>
  </div>;
}

function exportReportCSV(workflow, recordsets) {
  const sectionNames = ['Report Header', 'Detail', 'Report Footer'];
  const rows = (recordsets || []).flatMap((group, index) => (group || []).map((row) => ({ Section: sectionNames[index] || 'Data', ...row })));
  if (!rows.length) return;
  const columns = Array.from(new Set(rows.flatMap((row) => Object.keys(row))));
  const quote = (value) => {
    let text = String(value === null || value === undefined ? '' : value);
    if (typeof value === 'string' && /^[\s]*[=+@-]/.test(text)) text = "'" + text;
    return '"' + text.replace(/"/g, '""') + '"';
  };
  const csv = '\uFEFF' + [columns.map(quote).join(','), ...rows.map((row) => columns.map((column) => quote(row[column])).join(','))].join('\r\n');
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = workflow.code.toLowerCase() + '-qlcb.csv';
  link.click();
  URL.revokeObjectURL(url);
}

function Workflow({ id, options, setActive, currentRole }) {
  const workflow = workflows[id];
  if (!workflow) return <div className="notice notice-amber">Không tìm thấy luồng nghiệp vụ.</div>;

  if (!canAccess(currentRole, id)) {
    const roleMeta = ROLES[currentRole] || { label: currentRole };
    return (
      <div className="forbidden-card panel page-enter">
        <div className="forbidden-icon"><ShieldCheck size={28} /></div>
        <h2>Quyền truy cập bị từ chối (403 Forbidden)</h2>
        <p>Vai trò <strong>{roleMeta.label}</strong> không có quyền truy cập chức năng <code>{workflow.code} · {workflow.title}</code>.</p>
        <p style={{ marginTop: 8, fontSize: '11px', color: '#9a3412' }}>Theo ma trận phân quyền hệ thống, chỉ các vai trò được cấp phép mới có thể xem và thực thi chức năng này.</p>
        <div className="forbidden-actions">
          <button className="button primary" onClick={() => setActive('home')}>
            Quay về Trang chủ
          </button>
        </div>
      </div>
    );
  }

  const [params, setParams] = useState(() => initialParams(id, options));
  const stateRequestId = useRef(0);
  const [before, setBefore] = useState(null);
  const [after, setAfter] = useState(null);
  const [runResult, setRunResult] = useState(null);
  const [error, setError] = useState(null);
  const [loadingState, setLoadingState] = useState(false);
  const [running, setRunning] = useState(false);
  const [dirty, setDirty] = useState(false);
  const Icon = workflow.icon;
  const formValidation = useMemo(() => {
    const missing = workflow.fields.filter((field) => field.required && !String(params[field.key] || '').trim());
    if (missing.length) return 'Cần nhập hoặc chọn: ' + missing.map((field) => field.label).join(', ') + '.';
    if (id === 'sp4-search' && params.MaSanBayDi === params.MaSanBayDen) return 'Sân bay đi và sân bay đến phải khác nhau.';
    if (['sp3-revenue', 'cs2-payroll', 'report-revenue', 'report-performance'].includes(id) && params.TuNgay > params.DenNgay) return 'Từ ngày phải nhỏ hơn hoặc bằng Đến ngày.';
    if (id === 'fn3-aircraft' && (Number(params.Thang) < 1 || Number(params.Thang) > 12 || !Number.isInteger(Number(params.Nam)))) return 'Tháng cần từ 1 đến 12 và năm phải là số nguyên.';
    if (id === 'price-update') {
      const flight = (options.flights || []).find((row) => row.MaChuyenBay === params.MaChuyenBay);
      if (!Number.isFinite(Number(params.GiaVeMoi)) || Number(params.GiaVeMoi) <= 0) return 'Giá vé cần là số lớn hơn 0.';
      if (flight && Number(params.GiaVeMoi) <= Number(flight.GiaVePhoThong)) return 'Giá Thương gia phải cao hơn giá Phổ thông để thỏa TG4.';
    }
    if (['sp1-book', 'tg1-book'].includes(id) && !/^\d{1,3}[A-F]$/i.test(params.SoGhe || '')) return 'Số ghế cần theo dạng hàng + cột A–F, ví dụ 10A.';
    if (id === 'sp5-crew' && new Date(params.GioKetThucMoi) <= new Date(params.GioBatDauMoi)) return 'Giờ kết thúc phải sau giờ bắt đầu.';
    if (id === 'tg2-test' && !(options.tg2Flights || []).length) return 'Hiện không có chuyến chưa khởi hành trong 24 giờ tới để thử TG2.';
    if (id === 'tg5-test' && !(options.scheduledAircraft || []).length) return 'Hiện không có máy bay gắn với chuyến bay tương lai để thử TG5.';
    return '';
  }, [id, params, options, workflow.fields]);

  async function loadState(paramsToLoad = params) {
    const requestId = ++stateRequestId.current;
    setLoadingState(true);
    setError(null);
    try {
      const queryString = new URLSearchParams(paramsToLoad).toString();
      const data = await api('/api/workflows/' + id + '/state?' + queryString);
      if (requestId === stateRequestId.current) {
        setBefore(data.tables || []);
        setDirty(false);
      }
    } catch (loadError) {
      if (requestId === stateRequestId.current) {
        setError(loadError);
        setBefore(null);
      }
    } finally {
      if (requestId === stateRequestId.current) setLoadingState(false);
    }
  }

  useEffect(() => {
    setDirty(true);
    const timer = setTimeout(() => loadState(params), 300);
    return () => clearTimeout(timer);
  }, [id, params]);

  function changeParams(next) {
    if (id === 'sp5-crew' && next.MaNV !== params.MaNV) {
      const employee = (options.employees || []).find((row) => row.MaNV === next.MaNV);
      if (employee) next = { ...next, VaiTro: employee.ChucVu };
    }
    stateRequestId.current += 1;
    setParams(next);
    setDirty(true);
    setBefore(null);
    setAfter(null);
    setRunResult(null);
    setError(null);
  }

  async function execute() {
    if (dirty || !before || formValidation) return;
    if (id === 'tg1-cancel' && !window.confirm('Hủy vé ' + params.MaVe + '? TG1 sẽ trả ghế về chuyến bay.')) return;
    if (id === 'sp2-status' && params.TrangThaiMoi === 'Đã hủy' && !window.confirm('Hủy chuyến ' + params.MaChuyenBay + '? Vé liên quan sẽ bị hủy và hóa đơn thành công được hoàn tiền.')) return;
    if (id === 'price-update' && !window.confirm('Cập nhật giá vé Thương gia của ' + params.MaChuyenBay + ' thành ' + new Intl.NumberFormat('vi-VN').format(Number(params.GiaVeMoi)) + ' VND?')) return;
    if (id === 'tg5-test' && !window.confirm('Thử xóa máy bay ' + params.MaMayBay + '? Trigger TG5 dự kiến chặn vì còn chuyến bay trong lịch tương lai.')) return;
    setRunning(true);
    setError(null);
    setAfter(null);
    setRunResult(null);
    try {
      const response = await api('/api/workflows/' + id + '/run', {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(params),
      });
      setRunResult(response.result || { recordsets: [] });
    } catch (runError) {
      setError(runError);
    }
    try {
      const queryString = new URLSearchParams(params).toString();
      const refreshed = await api('/api/workflows/' + id + '/state?' + queryString);
      setAfter(refreshed.tables || []);
    } catch (refreshError) {
      setError((current) => current || refreshError);
    }
    setRunning(false);
  }

  const recordsets = runResult && runResult.recordsets || [];
  const resultRows = recordsets.reduce((all, set) => all.concat(set || []), []);
  const hasResult = runResult !== null || error !== null;
  const noFlightsFound = id === 'sp4-search' && runResult !== null && !error && resultRows.length === 0;
  const sqlParams = Object.entries(params).filter(([, value]) => value !== '' && value !== null && value !== undefined);

  return <div className="workflow-page page-enter">
    <div className="workflow-title-row"><div><div className="eyebrow"><span className="eyebrow-line" />{workflow.category.toUpperCase()} / {workflow.code}</div><h1><span className="title-icon"><Icon size={23} /></span>{workflow.title}</h1><p>{workflow.description}</p></div><div className="workflow-actions-top"><span className="workflow-code">{workflow.code}</span>{workflow.report && runResult && <><button className="button secondary" onClick={() => exportReportCSV(workflow, recordsets)}><FileDown size={15} /> Xuất CSV</button><button className="button secondary" onClick={() => window.print()}><FileCheck2 size={15} /> In / lưu PDF</button></>}</div></div>
    <div className="step-progress">{['Nghiệp vụ', 'Câu lệnh SQL', 'Trạng thái trước', 'Thực thi', 'Kết quả sau'].map((label, index) => <div className={'progress-item' + ((index === 4 && hasResult) || (index === 2 && before) || (index < 2) ? ' complete' : '')} key={label}><span>{index + 1}</span><small>{label}</small>{index < 4 && <i />}</div>)}</div>

    <section className="workflow-card">
      <div className="workflow-step"><StepHeading number="1" title="Đề bài nghiệp vụ" hint="Mục tiêu và quy tắc cần kiểm chứng" done /><div className="step-content"><div className="business-callout"><div className="callout-icon"><BookOpen size={17} /></div><div><strong>{workflow.code} · {workflow.title}</strong><p>{workflow.description}</p></div></div></div></div>
      <div className="workflow-step"><StepHeading number="2" title="Câu lệnh SQL tương ứng" hint="Câu lệnh chỉ hiển thị; API gửi tham số riêng đến SQL Server" done /><div className="step-content"><div className="sql-box"><div className="sql-toolbar"><span><span className="sql-dot red" /><span className="sql-dot yellow" /><span className="sql-dot green" /> SQL Server · T-SQL</span><span className="readonly-label"><ShieldCheck size={13} /> Xem trước</span></div><pre>{workflow.sql}</pre></div>
        {sqlParams.length > 0 && <div className="parameter-list"><span>Giá trị tham số</span>{sqlParams.map(([key, value]) => <code key={key}><b>@{key}</b> = {String(value)}</code>)}</div>}</div></div>
      <div className="workflow-step"><StepHeading number="3" title="Dữ liệu liên quan trước thao tác" hint="Ảnh chụp trạng thái hiện tại từ các bảng trong CSDL" done={Boolean(before)} active={!before} /><div className="step-content"><div className="state-toolbar"><div><strong>Trạng thái ban đầu</strong><small>{before ? 'Đã tải từ database' : 'Tải dữ liệu để mở khóa bước thực thi'}</small></div><button className="button secondary small" onClick={loadState} disabled={loadingState || running}><RefreshCw size={14} className={loadingState ? 'spin' : ''} /> Tải lại dữ liệu</button></div>
        {dirty && <div className="notice notice-amber"><AlertTriangle size={15} /> Tham số đã đổi; hệ thống đang tải lại trạng thái theo bộ lọc mới.</div>}
        {loadingState && <div className="loading-line"><span className="spinner" /> Đang truy vấn dữ liệu...</div>}
        {before && <div className="state-tables">{before.map((table, index) => <section className="data-section" key={table.title}><div className="data-title"><span className="data-index">0{index + 1}</span><strong>{table.title}</strong><span className="row-count">{table.rows.length} dòng</span></div><DataTable rows={table.rows} /></section>)}</div>}
      </div></div>
      <div className="workflow-step action-step"><StepHeading number="4" title="Thực thi nghiệp vụ" hint="Nút gọi đúng stored procedure hoặc DML để kích hoạt trigger" done={Boolean(hasResult)} active={Boolean(before) && !hasResult} /><div className="step-content"><WorkflowFields fields={workflow.fields} params={params} setParams={changeParams} options={options} />{formValidation && <div className="notice notice-amber validation-note"><AlertTriangle size={15} />{formValidation}</div>}<div className="execute-box"><div className="execute-context"><div className="execute-icon"><Zap size={18} fill="currentColor" /></div><div><strong>{workflow.action}</strong><small>{workflow.fields.length ? 'Kiểm tra lại các tham số trước khi chạy.' : 'Thao tác chỉ đọc dữ liệu và trả kết quả mới nhất.'}</small></div></div><button className="button primary" onClick={execute} disabled={!before || dirty || loadingState || running || Boolean(formValidation)}>{running ? <><span className="button-spinner" /> Đang xử lý...</> : <><Zap size={16} />{workflow.action}</>}</button></div></div></div>
      <div className="workflow-step result-step"><StepHeading number="5" title="Tải lại và kiểm chứng kết quả" hint="Bảng sau thao tác hoặc mã lỗi SQL Server cùng dữ liệu đã làm mới" done={Boolean(after)} active={Boolean(hasResult)} /><div className="step-content">
        {!hasResult && <div className="result-placeholder"><div className="placeholder-icon"><ArrowDownRight size={19} /></div><div><strong>Kết quả sẽ hiển thị tại đây</strong><p>Sau khi thực thi, hệ thống tự truy vấn lại các bảng liên quan.</p></div></div>}
        {hasResult && <>
          {error ? <div className="error-result"><div className="error-icon"><AlertTriangle size={18} /></div><div><strong>SQL Server đã từ chối thao tác</strong><p><b>Mã lỗi: {error.number || error.code || 'Ứng dụng'}</b> · {error.message}</p><small>Đã tải lại dữ liệu bên dưới để xác nhận trạng thái sau lỗi.</small></div></div> : noFlightsFound ? <div className="notice notice-amber"><Search size={16} /><div><strong>Không có chuyến bay phù hợp</strong><p>Không tìm thấy chuyến bay cho sân bay đi {params.MaSanBayDi}, sân bay đến {params.MaSanBayDen} vào ngày {params.NgayBay}. Hãy đổi điều kiện tra cứu.</p></div></div> : <div className="success-result"><div className="success-icon"><CheckCircle2 size={18} /></div><div><strong>{workflow.report ? 'Đã tạo dữ liệu xem trước báo cáo' : 'Thao tác hoàn tất'}</strong><p>Hoàn tất lúc {new Date().toLocaleTimeString('vi-VN')} · Dữ liệu liên quan đã được tải lại từ SQL Server.</p></div></div>}
          {workflow.report && !error && <ReportDocument workflow={workflow} tables={after} recordsets={recordsets} />}
          {!workflow.report && resultRows.length > 0 && <section className="result-data"><div className="data-title"><span className="data-index result-index"><CheckCircle2 size={14} /></span><strong>Kết quả trả về từ SQL Server</strong><span className="row-count">{resultRows.length} dòng</span></div><DataTable rows={resultRows} /></section>}
          {after && <div className="state-tables after-tables">{after.map((table, index) => <section className="data-section" key={table.title}><div className="data-title"><span className="data-index after-index">{String(index + 1).padStart(2, '0')}</span><strong>{table.title} · sau thao tác</strong><span className="row-count">{table.rows.length} dòng</span></div><DataTable rows={table.rows} /></section>)}</div>}
        </>}
      </div></div>
    </section>
    <div className="workflow-footnote"><ShieldCheck size={15} /><span>Lệnh được gửi bằng tham số SQL riêng. Thông báo lỗi giữ nguyên số lỗi SQL Server để đối chiếu trigger và ràng buộc trong CSDL.</span></div>
  </div>;
}

function App() {
  const [active, setActive] = useState('home');
  const [currentRole, setCurrentRole] = useState('admin');
  const [menuOpen, setMenuOpen] = useState(false);
  const [options, setOptions] = useState(null);
  const [dashboard, setDashboard] = useState(null);
  const [health, setHealth] = useState(null);
  const [bootError, setBootError] = useState(null);
  const [loading, setLoading] = useState(true);
  const activeWorkflow = workflows[active];
  const activeTitle = activeWorkflow ? activeWorkflow.title : 'Tổng quan';

  async function reloadDashboard(roleOverride) {
    setLoading(true);
    try {
      if (roleOverride) activeRole = roleOverride;
      const [healthResult, optionResult, dashboardResult] = await Promise.all([
        api('/api/health'), api('/api/options'), api('/api/dashboard'),
      ]);
      setHealth(healthResult);
      setOptions(optionResult);
      setDashboard(dashboardResult);
      setBootError(null);
    } catch (error) {
      setBootError(error);
      setHealth(null);
    } finally { setLoading(false); }
  }

  function handleRoleChange(newRole) {
    activeRole = newRole;
    setCurrentRole(newRole);
    if (!canAccess(newRole, active)) {
      setActive('home');
    }
    reloadDashboard(newRole);
  }

  useEffect(() => { reloadDashboard(); }, []);
  const databaseName = health && health.databaseName || 'QL_CHUYENBAY';

  return <div className="app-shell">
    <Sidebar
      active={active}
      setActive={setActive}
      open={menuOpen}
      setOpen={setMenuOpen}
      databaseName={databaseName}
      currentRole={currentRole}
      onRoleChange={handleRoleChange}
    />
    {menuOpen && <button className="sidebar-scrim" onClick={() => setMenuOpen(false)} aria-label="Đóng menu" />}
    <main className="main-area">
      <Topbar
        title={activeTitle}
        setOpen={setMenuOpen}
        online={Boolean(health && health.ok)}
        currentRole={currentRole}
      />
      <div className="content-area">
        {loading && !options ? (
          <div className="app-loading"><span className="spinner" /><strong>Đang kết nối SQL Server…</strong></div>
        ) : bootError ? (
          <div className="connection-error panel">
            <div className="connection-error-icon"><Database size={22} /></div>
            <h1>Chưa kết nối được cơ sở dữ liệu</h1>
            <p>{bootError.message || 'Hãy kiểm tra SQL Server và cấu hình DB_USER, DB_PASSWORD trong file .env.'}</p>
            <div className="connection-help">Kiểm tra container SQL Server đang chạy, sau đó cấu hình thông tin đăng nhập cho tài khoản ứng dụng rồi thử lại.</div>
            <button className="button primary" onClick={() => reloadDashboard(currentRole)}><RefreshCw size={15} /> Thử kết nối lại</button>
          </div>
        ) : active === 'home' ? (
          <Dashboard
            dashboard={dashboard}
            options={options}
            setActive={setActive}
            reload={() => reloadDashboard(currentRole)}
            currentRole={currentRole}
          />
        ) : (
          <Workflow
            key={active + '-' + currentRole}
            id={active}
            options={options}
            setActive={setActive}
            currentRole={currentRole}
          />
        )}
      </div>
      <footer className="app-footer"><span>© 2026 Skyroute Flight Operations</span><span>QLCB DEMO <i /> SQL Server</span></footer>
    </main>
  </div>;
}

createRoot(document.getElementById('root')).render(<React.StrictMode><App /></React.StrictMode>);
