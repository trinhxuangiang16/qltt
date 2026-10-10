# Task list: Ứng dụng demo quản lý chuyến bay

## 1. Hiện trạng đã kiểm tra

- Docker Compose đang chạy SQL Server 2022 tại `localhost,1433`; database `QL_CHUYENBAY` đang `ONLINE`, compatibility level 160.
- Database hiện có 9 bảng: `SANBAY`, `DUONGBAY`, `MAYBAY`, `CHUYENBAY`, `NHANVIEN`, `PHANCONG`, `HANHKHACH`, `VEBAY`, `HOADON`. Dữ liệu mẫu có 20 dòng ở 8 bảng và 19 dòng ở `PHANCONG`.
- DDL kiểm tra định dạng mã sân bay 3 chữ cái và mã chuyến bay 2 chữ cái + 3 số; việc xác nhận mã/tên đúng với danh mục IATA thực tế vẫn cần đối chiếu dữ liệu nguồn.
- Có 5 trigger (`TG1`–`TG5`), 3 function (`FN1`–`FN3`), 5 nghiệp vụ stored procedure (`SP1`–`SP5`) và 2 procedure dùng cursor (`CS1`, `CS2`). Các truy vấn của 5 báo cáo và role/grant đã có trong SQL.
- Đã thêm project React/Vite + Node/Express + `mssql`; frontend ở `src/`, API ở `server/`, hướng dẫn chạy ở `README.md`. File `.env` cục bộ không được Git theo dõi.
- Tài khoản ứng dụng `QLCB_AppLogin` thuộc role `QLCB_UngDung`; không kết nối app bằng `sa`. API và giao diện đã kết nối database hiện có mà không nạp lại dữ liệu mẫu.
- Đã build production và chạy thử luồng bán/hủy vé, SP5, truy vấn SP/FN/cursor/report và các trigger chặn. Dữ liệu thử đã dọn; số ghế và phân công mẫu trở về trạng thái trước thử nghiệm.
- Chưa kiểm tra độc lập danh mục tên/mã với nguồn IATA chính thức; hiện form chọn sân bay/chuyến từ danh mục có sẵn trong CSDL.
- Dữ liệu chuyến bay mẫu nằm trong tháng 10/2026. Màn hình lọc ngày nên cho phép dùng khoảng ngày có dữ liệu; không mặc định ngày hiện tại.

## 2. Quy ước bắt buộc cho từng thao tác

Mỗi màn hình thực thi một SP, trigger, function hoặc cursor phải trình bày đúng thứ tự sau:

1. **Nghiệp vụ:** nêu mục tiêu, điều kiện đầu vào và quy tắc cần chứng minh.
2. **SQL:** hiển thị câu lệnh SQL tương ứng ở chế độ chỉ đọc, cùng giá trị tham số sắp gửi. Không ghép giá trị người dùng vào chuỗi SQL.
3. **Trạng thái trước:** truy vấn và hiển thị các bảng liên quan trước khi thao tác.
4. **Thực thi:** nút có tên nghiệp vụ rõ ràng gọi đúng SP/function hoặc DML kích hoạt trigger/cursor.
5. **Kết quả:** tải lại bảng liên quan và hiển thị trạng thái sau khi thành công; nếu lỗi thì hiện mã và nội dung lỗi SQL Server, tải lại dữ liệu để chứng minh giao dịch đã bị từ chối/rollback.

Dùng cùng một thành phần giao diện cho năm bước trên để các màn hình có thứ tự nhất quán. Với function/cursor chỉ đọc, bước 4 chạy truy vấn và bước 5 tải lại dữ liệu đầu vào cùng kết quả trả về, không giả lập thay đổi dữ liệu.

## 3. Công việc phát triển ứng dụng

### A. Khởi tạo và kết nối

- [x] Chốt React JS theo yêu cầu người dùng; dùng Vite cho UI, Node/Express cho API và driver `mssql` cho SQL Server.
- [x] Tạo project ứng dụng, cấu hình kết nối `localhost:1433` / `QL_CHUYENBAY`; cấu hình nhạy cảm đặt trong `.env` bị Git bỏ qua.
- [x] Tạo login riêng `QLCB_AppLogin`, role `QLCB_UngDung`, cấp quyền đọc/routine cần thiết và DML giới hạn theo cột/bảng; API không dùng `sa`.
- [x] Tạo lớp API dùng tham số SQL, `request.execute()` cho procedure, đọc nhiều result set và trả lại số lỗi SQL Server cho giao diện.
- [x] Với thao tác bị trigger từ chối, SP tự rollback hoặc batch TG3 rollback; giao diện tải lại dữ liệu liên quan sau phản hồi thành công/lỗi.

### B. Khung điều hướng và dùng chung

- [x] Tạo menu điều hướng cho tổng quan, tra cứu, bán/hủy vé, trạng thái chuyến, phân công, trigger, function, cursor, báo cáo và quản trị dữ liệu.
- [x] Dùng chung khung đúng thứ tự 5 bước cho SP, TG, FN, cursor và báo cáo: nghiệp vụ, SQL/tham số, trạng thái trước, nút chạy, dữ liệu sau/lỗi.
- [x] Bảng có tiêu đề cột, loading, trạng thái rỗng/lỗi, nút tải lại và thời điểm hoàn thành thao tác.
- [x] Form chọn mã từ danh mục database, kiểm tra trường bắt buộc, khoảng ngày, sân bay khác nhau, định dạng ghế, vai trò/giờ phân công và giá vé. **Còn thiếu:** xác nhận độc lập mã/tên từ nguồn IATA chính thức; chưa có import CSV.
- [x] Có xác nhận trước hủy vé/chuyến bay, thử xóa máy bay và thay đổi giá; ràng buộc database vẫn là lớp kiểm tra cuối.

### C. Màn hình theo Stored Procedure

Mỗi mục dưới đây phải dùng khung 5 bước ở mục 2.

| Nghiệp vụ | SQL hiển thị ở bước 2 | Dữ liệu trước/sau và nút thực thi |
|---|---|---|
| SP1 – Đặt chỗ, xuất vé | `EXEC dbo.SP1_DATCHO_TAOVE @MaVe, @MaChuyenBay, @MaHanhKhach, @MaDatCho, @SoGhe, @HangGhe` | Trước: `CHUYENBAY`, ghế từ FN2, vé của chuyến và hành khách. Nút **Tạo vé**. Sau: vé mới và `SoGheTrong` giảm 1. Kiểm tra chuyến, hành khách, hạng vé, ghế và dữ liệu bắt buộc trước khi gửi.
| SP2 – Delay/Hủy chuyến | `EXEC dbo.SP2_DELAY_HUY @MaChuyenBay, @TrangThaiMoi, @LyDo` | Trước: `CHUYENBAY`, `VEBAY`, `HOADON`. Nút **Cập nhật trạng thái**. Sau: trạng thái/lý do; khi hủy thành công, vé và hóa đơn liên quan phải thể hiện kết quả hoàn/hủy. Nếu TG2 chặn, hiển thị lỗi và dữ liệu vẫn giữ trạng thái cũ.
| SP3 – Doanh thu theo chặng | `EXEC dbo.SP3_TINHDOANHTHU @TuNgay, @DenNgay` | Trước: bộ lọc ngày và số liệu liên quan. Nút **Thống kê doanh thu**. Sau: kết quả nhóm theo đường bay, số vé thanh toán và tổng tiền.
| SP4 – Tra cứu chuyến | `EXEC dbo.SP4_TRACUUDANHSACH @MaSanBayDi, @MaSanBayDen, @NgayBay` | Trước: danh sách sân bay và bộ lọc. Nút **Tra cứu**. Sau: chuyến bay, giờ, máy bay, trạng thái và số ghế còn.
| SP5 – Phân công tổ bay | `EXEC dbo.SP5_PHANCONGTOBAY @MaChuyenBay, @MaNV, @VaiTro, @GioBatDauMoi, @GioKetThucMoi` | Trước: `CHUYENBAY`, `NHANVIEN`, `PHANCONG` của nhân viên. Nút **Phân công**. Sau: ca trực mới; nếu vai trò, giờ nghỉ hoặc định mức tuần không hợp lệ, hiện lỗi và giữ nguyên dữ liệu.

### D. Màn hình chứng minh 5 Trigger

Các trigger được kích hoạt bởi DML/SP; không gọi trigger trực tiếp. Mỗi mục cần có dữ liệu liên quan trước thao tác, nút nghiệp vụ và tải lại sau thao tác.

| Trigger | Cách kích hoạt trên giao diện | Trạng thái cần chứng minh |
|---|---|---|
| TG1 – Giữ/hoàn ghế | Tạo vé bằng SP1; hủy vé bằng cập nhật `VEBAY.TrangThaiVe`. | Ghế còn giảm 1 khi xuất vé và tăng lại 1 khi hủy; ghế sai/đã bán bị từ chối.
| TG2 – Chặn hủy dưới 24h | Hủy chuyến qua SP2 khi còn dưới 24 giờ. | Hiện lỗi SQL `51003`; `CHUYENBAY`, vé, hóa đơn giữ trạng thái trước giao dịch.
| TG3 – Định mức giờ bay tuần | Dùng màn hình kiểm thử quản trị để gửi nhiều phân công trong một giao dịch, tổng giờ tuần vượt 30 giờ. SP5 vẫn dùng cho phân công thông thường. | Hiện lỗi `51004`; rollback toàn bộ batch và `PHANCONG` không đổi.
| TG4 – Giá thương gia | Form quản trị thay `GiaVeThuongGia` bằng hoặc thấp hơn `GiaVePhoThong`. | Hiện lỗi `51005`; giá trước đó vẫn còn sau khi tải lại.
| TG5 – Không xóa máy bay có lịch tương lai | Nút **Xóa máy bay** gửi lệnh xóa theo `MaMayBay`. | Hiện lỗi `51006`; máy bay và lịch bay vẫn còn. Nếu chỉ có lịch sử, hiển thị lỗi bảo vệ lịch sử `51007`.

SQL kích hoạt cần hiển thị ở bước 2 cho các thao tác kiểm thử trigger:

```sql
-- TG1 xuất vé: dùng SP1; hoàn ghế: hủy vé đang hiệu lực.
EXEC dbo.SP1_DATCHO_TAOVE @MaVe, @MaChuyenBay, @MaHanhKhach, @MaDatCho, @SoGhe, @HangGhe;
UPDATE dbo.VEBAY SET TrangThaiVe=N'Đã hủy' WHERE MaVe=@MaVe;

-- TG2: yêu cầu SP2 hủy chuyến gần giờ khởi hành.
EXEC dbo.SP2_DELAY_HUY @MaChuyenBay, N'Đã hủy', @LyDo;

-- TG3 kiểm thử: NV01 đã có ca VU118; batch vượt tổng 30 giờ tuần.
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT dbo.PHANCONG(MaChuyenBay,MaNV,VaiTro,GioBatDau,GioKetThuc) VALUES
    ('QH156','NV01',N'Cơ trưởng','2026-10-15 00:00:00','2026-10-15 08:00:00'),
    ('QH312','NV01',N'Cơ trưởng','2026-10-16 00:00:00','2026-10-16 08:00:00'),
    ('QH402','NV01',N'Cơ trưởng','2026-10-16 09:00:00','2026-10-16 17:00:00'),
    ('QH510','NV01',N'Cơ trưởng','2026-10-17 00:00:00','2026-10-17 08:00:00');
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

-- TG4: đổi giá thương gia bằng/thấp hơn giá phổ thông để trigger từ chối.
UPDATE dbo.CHUYENBAY SET GiaVeThuongGia=@GiaVeMoi WHERE MaChuyenBay=@MaChuyenBay;

-- TG5: xóa máy bay có chuyến trong lịch tương lai.
DELETE FROM dbo.MAYBAY WHERE MaMayBay=@MaMayBay;
```

### E. Màn hình Function và Cursor

Mỗi chức năng dùng khung 5 bước; ở bước 4 chạy câu lệnh, ở bước 5 hiển thị kết quả mới nhất.

- [x] **FN1 – Xếp hạng hội viên:** giao diện hiển thị hành khách/hóa đơn trước và kết quả hạng sau khi chạy function.
- [x] **FN2 – Ghế trống:** hiển thị chuyến, máy bay, vé trước và danh sách ghế FN2 sau khi chạy.
- [x] **FN3 – Hiệu suất máy bay tháng:** hiển thị máy bay/lịch tháng trước và số chuyến/giờ bay sau khi chạy.
- [x] **CS1 – Tính bồi hoàn chuyến Delay:** hiển thị chuyến Delay/vé trước và bồi thường theo chuyến sau cursor.
- [x] **CS2 – Công nhật/phụ cấp:** hiển thị phân công/nhân viên trước và tổng hợp ca/giờ/công/phụ cấp sau cursor.

### F. Màn hình báo cáo và quản trị dữ liệu

- [x] Có đủ 5 báo cáo R1–R5; bản xem trước tách đủ Report Header, Page Header, Detail, Page Footer, Report Footer.
- [x] Báo cáo có tham số, hiển thị dữ liệu trước và result sets sau, có thể xuất CSV hoặc in/lưu PDF bằng hộp thoại trình duyệt. Cần tiếp tục soát nội dung theo mẫu nộp UIT.
- [x] Có màn hình 5 bước cập nhật giá vé và tình trạng máy bay; TG4/TG5 có màn hình thử trigger riêng.
- [ ] Hoàn thiện quy trình import/export, backup/restore cho SQL Server Docker. Database có role/grant và ví dụ backup; file CSV phải được đặt trong container để `BULK INSERT` đọc được.
- [x] Cung cấp script PowerShell `server/setup-demo-user.ps1` để quản trị tạo login/role ứng dụng; không cấp `sa` cho app.

## 4. Kiểm thử, bằng chứng và nghiệm thu

- [x] Kiểm tra kết nối thành công, API/UI, truy vấn tham số; chạy `npm.cmd run build` và thử server production. Chưa chụp/kiểm tra trực quan trên nhiều kích thước màn hình.
- [x] Kiểm tra SP1–SP5: tạo/hủy vé, cập nhật SP2 ở trạng thái Delay hiện có, SP3/SP4, phân công hợp lệ SP5; dọn vé/phân công thử sau kiểm tra.
- [x] Kiểm tra luồng TG1 bán/hủy cho ghế giảm rồi hoàn về; TG2–TG5 trả lỗi lần lượt `51003`–`51006` và dữ liệu mẫu không đổi. **Còn thiếu:** kiểm thử riêng TG1 `51001`/`51002` và TG5 `51007`.
- [x] Chạy FN1–FN3, CS1–CS2; kết quả trả về từ routine và các bảng nguồn hiển thị trong giao diện.
- [x] Chạy đủ R1–R5 với dữ liệu tháng 10/2026; kiểm tra các result set Header/Detail/Footer và phần giao diện dựng thêm Page Header/Page Footer.
- [ ] Với mỗi nghiệp vụ cần minh họa, lưu ảnh chụp đủ 5 bước: mô tả, SQL, dữ liệu trước, thao tác, dữ liệu sau/thông báo lỗi. Lưu tên file ảnh theo mã SP/TG/FN/CS hoặc báo cáo.
- [x] Viết hướng dẫn chạy Docker/app, cấu hình login riêng và khởi động ở `README.md`; không nạp lại database khi chạy app.

## 5. Tài liệu và sản phẩm nộp theo `text.md`

- [ ] Hoàn thiện báo cáo: phát biểu bài toán, mục tiêu, đối tượng, quy trình, đặc tả chức năng, quan hệ/thực thể, ERD, chuẩn hóa, Data Dictionary, ràng buộc và kết quả test.
- [ ] Định dạng báo cáo theo mẫu UIT và bổ sung trích dẫn IEEE.
- [ ] Soạn slide thuyết trình 15–20 trang.
- [ ] Quay và biên tập video demo 15–20 phút; kịch bản video nên đi theo 5 bước giao diện và có trường hợp trigger chặn thao tác.

## 6. Tiêu chí hoàn thành ứng dụng

- Kết nối được database hiện có mà không chạy lại script nạp dữ liệu.
- Menu mở đủ màn hình; mọi SP, trigger, function, cursor được truy cập qua luồng giao diện có đủ 5 bước.
- Thao tác hợp lệ cập nhật và tải lại dữ liệu; thao tác vi phạm hiển thị lỗi SQL Server, rollback và chứng minh dữ liệu không đổi.
- Có đủ 5 báo cáo, ảnh chụp kiểm thử và tài liệu hướng dẫn chạy demo.
