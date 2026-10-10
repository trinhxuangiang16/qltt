# 📋 TÀI LIỆU HƯỚNG DẪN KIỂM THỬ HỆ THỐNG QUẢN LÝ CHUYẾN BAY (QLCB)

> **Mục đích:** Tài liệu hướng dẫn chi tiết từng bước kiểm thử (Test Guide) toàn bộ các chức năng của hệ thống CSDL & Ứng dụng Web Quản lý Chuyến bay, tuân thủ nghiêm ngặt **Quy chuẩn 5 bước thực nghiệm** phục vụ nghiệm thu đồ án.

---

## 🧭 QUY CHUẨN 5 BƯỚC BẮT BUỘC TRÊN TỪNG MÀN HÌNH

Mọi chức năng trên giao diện web (`http://localhost:5173`) đều được thiết kế đồng nhất theo 5 bước:

```
[Bước 1: Nghiệp vụ]  ➔  [Bước 2: SQL & Tham số]  ➔  [Bước 3: Dữ liệu trước]  ➔  [Bước 4: Nút thực thi]  ➔  [Bước 5: Kết quả / Mã lỗi]
```

1. **Nghiệp vụ:** Nêu rõ mục tiêu nghiệp vụ, điều kiện đầu vào và quy tắc ràng buộc cần chứng minh.
2. **SQL & Tham số:** Hiển thị câu lệnh T-SQL chỉ đọc kèm các tham số chuẩn bị gửi (tuyệt đối không nối chuỗi SQL).
3. **Trạng thái trước:** Truy vấn và hiển thị dữ liệu thực tế trong CSDL trước khi tác động.
4. **Thực thi:** Nút bấm gọi API / Procedure tương ứng.
5. **Kết quả / Rollback:** 
   * **Nếu hợp lệ:** Tải lại bảng để chứng minh dữ liệu đã thay đổi chuẩn xác.
   * **Nếu vi phạm ràng buộc:** Hiển thị mã lỗi SQL Server (`51001`–`51007`), tải lại bảng để chứng minh giao dịch đã bị **Rollback** và dữ liệu cũ vẫn giữ nguyên vẹn.

---

## 📌 THÔNG TIN MÔI TRƯỜNG DỮ LIỆU KIỂM THỬ

* **Mốc thời gian dữ liệu mẫu:** Tháng **10/2026** (Giờ lưu trong database theo chuẩn **UTC**).
* **Số lượng dữ liệu mẫu chuẩn:** 20 dòng ở các bảng `SANBAY`, `DUONGBAY`, `MAYBAY`, `CHUYENBAY`, `NHANVIEN`, `HANHKHACH`, `VEBAY`, `HOADON` và 19 dòng ở `PHANCONG`.
* **Địa chỉ chạy ứng dụng:** Mở trình duyệt web truy cập `http://localhost:5173`.

---

# PHẦN 1: KIỂM THỬ 5 STORED PROCEDURES NGHIỆP VỤ (SP1 – SP5)

---

### TEST CASE 1: SP1 – Tiếp nhận đặt chỗ & xuất vé mới
* **Mục tiêu:** Kiểm tra khả năng đặt chỗ, cấp mã vé mới và tự động cập nhật giảm số ghế trống thông qua Trigger TG1.
* **Đường dẫn trên Menu:** `Bán vé` ➔ **Đặt chỗ & xuất vé** (Mã: `SP1`).
* **Các bước thực hiện:**
  1. *Bước 1 & 2:* Xem mô tả nghiệp vụ và câu lệnh `EXEC dbo.SP1_DATCHO_TAOVE ...`.
  2. *Bước 3:* Quan sát bảng `Chuyến bay` (lưu ý số ghế trống ban đầu, ví dụ `SoGheTrong = 179`).
  3. *Bước 4:* Điền form kiểm thử:
     * **Chuyến bay:** Chọn chuyến bay còn ghế (ví dụ: `VN716`).
     * **Hành khách:** Chọn `HK01` (hoặc hành khách bất kỳ).
     * **Mã vé mới:** Điền `VE99` (hoặc mã vé chưa tồn tại).
     * **Mã đặt chỗ:** Điền `PNR99XYZ`.
     * **Số ghế:** Điền ghế trống (ví dụ: `10A` - tham khảo từ bảng ghế trống FN2 bên dưới form).
     * **Hạng ghế:** Chọn `Phổ thông`.
     * Nhấn nút: **`Tạo vé`**.
  4. *Bước 5 (Kết quả kỳ vọng):*
     * Hệ thống thông báo thành công: Trả về thông tin vé mới `VE99`, giá vé và trạng thái `Chờ check-in`.
     * Bảng chuyến bay được tải lại tự động: `SoGheTrong` **giảm đúng 1 ghế** (từ 179 xuống 178).

---

### TEST CASE 2: SP2 – Cập nhật trạng thái chuyến bay (Delay / Hủy)
* **Mục tiêu:** Cập nhật trạng thái chuyến bay sang Delay hoặc Đã hủy. Nếu hủy chuyến hợp lệ, toàn bộ vé liên quan phải tự động hủy và hóa đơn được hoàn tiền.
* **Đường dẫn trên Menu:** `Điều phối` ➔ **Cập nhật trạng thái chuyến bay** (Mã: `SP2`).
* **Các bước thực hiện:**
  1. *Bước 1 & 2:* Xem nghiệp vụ và câu lệnh `EXEC dbo.SP2_DELAY_HUY ...`.
  2. *Bước 3:* Quan sát bảng `Chuyến bay` và danh sách vé trước khi cập nhật.
  3. *Bước 4:* Điền form kiểm thử:
     * **Chuyến bay:** Chọn chuyến bay (ví dụ: `VN218`).
     * **Trạng thái mới:** Chọn `Delay`.
     * **Lý do:** Điền `Thời tiết xấu tại sân bay đến`.
     * Nhấn nút: **`Cập nhật trạng thái`**.
  4. *Bước 5 (Kết quả kỳ vọng):*
     * Hệ thống báo cập nhật thành công.
     * Bảng chuyến bay hiển thị trạng thái `Delay` và cột lý do được cập nhật chính xác.

---

### TEST CASE 3: SP3 – Thống kê doanh thu theo chặng bay
* **Mục tiêu:** Tổng hợp số hóa đơn thanh toán thành công và tổng doanh thu theo từng chặng bay trong khoảng thời gian đóng `[Từ ngày, Đến ngày]`. Vé đã hủy không được cộng vào doanh thu.
* **Đường dẫn trên Menu:** `Báo cáo` ➔ **Doanh thu theo chặng bay** (Mã: `SP3`).
* **Các bước thực hiện:**
  1. *Bước 1, 2 & 3:* Xem nghiệp vụ và số lượng hóa đơn hiện có.
  2. *Bước 4:* Điền bộ lọc ngày:
     * **Từ ngày:** `2026-10-01`
     * **Đến ngày:** `2026-10-31`
     * Nhấn nút: **`Thống kê doanh thu`**.
  3. *Bước 5 (Kết quả kỳ vọng):*
     * Bảng kết quả trả về danh sách các chặng bay (`SGN-HAN`, `HAN-DAD`, `SGN-PQC`,...).
     * Mỗi chặng hiển thị số lượng giao dịch thành công và tổng doanh thu tính bằng VNĐ.

---

### TEST CASE 4: SP4 – Tra cứu chuyến bay theo điểm đi, điểm đến và ngày bay
* **Mục tiêu:** Tìm kiếm nhanh các chuyến bay phù hợp với nhu cầu hành khách.
* **Đường dẫn trên Menu:** `Tra cứu` ➔ **Tra cứu chuyến bay** (Mã: `SP4`).
* **Các bước thực hiện:**
  1. *Bước 3:* Xem danh mục mã sân bay IATA.
  2. *Bước 4:* Điền thông tin tra cứu:
     * **Sân bay đi:** Chọn `SGN` (Tân Sơn Nhất).
     * **Sân bay đến:** Chọn `HAN` (Nội Bài).
     * **Ngày bay (UTC):** `2026-10-07`.
     * Nhấn nút: **`Tra cứu chuyến`**.
  3. *Bước 5 (Kết quả kỳ vọng):*
     * Trả về danh sách chuyến bay khớp tiêu chí (ví dụ: `VN214`).
     * Hiển thị đầy đủ giờ bay, loại máy bay, số ghế còn trống và trạng thái khai thác.

---

### TEST CASE 5: SP5 – Phân công tổ bay & kiểm tra giờ nghỉ
* **Mục tiêu:** Phân công nhân sự vào chuyến bay, tự động kiểm tra vai trò hợp lệ, tránh trùng lịch bay và đảm bảo nhân viên được nghỉ tối thiểu 8 tiếng giữa 2 ca liên tiếp.
* **Đường dẫn trên Menu:** `Điều phối` ➔ **Phân công tổ bay** (Mã: `SP5`).
* **Các bước thực hiện:**
  1. *Bước 3:* Xem lịch các ca trực hiện tại của nhân viên để chọn thời gian hợp lệ.
  2. *Bước 4:* Điền form phân công:
     * **Chuyến bay:** Chọn chuyến (ví dụ: `VN716`).
     * **Nhân viên:** Chọn `NV02` (Cơ phó).
     * **Vai trò:** `Cơ phó`.
     * **Giờ bắt đầu (UTC):** `2026-10-18T00:00`.
     * **Giờ kết thúc (UTC):** `2026-10-18T06:00`.
     * Nhấn nút: **`Lưu phân công`**.
  3. *Bước 5 (Kết quả kỳ vọng):*
     * Hệ thống thông báo thành công.
     * Bảng ca trực của nhân viên được tải lại và hiển thị thêm ca trực vừa phân công.

---

# PHẦN 2: KIỂM THỬ 5 TRIGGERS BẢO VỆ TOÀN VẸN (TG1 – TG5)

> ⚠️ **Đặc điểm kiểm thử Trigger:** Các trigger được kích hoạt thông qua câu lệnh DML. Tại đây, ta chủ động thực hiện các hành vi **vi phạm ràng buộc** để chứng minh Trigger hoạt động chính xác, quăng lỗi và Rollback bảo vệ CSDL.

---

### TEST CASE 6: TG1 – Hoàn ghế trống khi hủy vé
* **Mục tiêu:** Chứng minh khi hủy một vé còn hiệu lực, Trigger TG1 tự động cộng hoàn trả lại 1 ghế trống cho chuyến bay.
* **Đường dẫn trên Menu:** `Trigger` ➔ **TG1 · Hoàn ghế khi hủy vé**.
* **Các bước thực hiện:**
  1. *Bước 3:* Quan sát vé được chọn (ví dụ vé `VE01` có trạng thái `Đã thanh toán`) và số ghế trống hiện tại của chuyến bay `VN214`.
  2. *Bước 4:* Chọn vé `VE01` và nhấn nút: **`Thực thi hủy vé`**.
  3. *Bước 5 (Kết quả kỳ vọng):*
     * Trạng thái vé chuyển thành `Đã hủy`.
     * Số ghế trống `SoGheTrong` của chuyến bay lập tức **tăng lên 1** (hoàn ghế thành công).

---

### TEST CASE 7: TG2 – Chặn hủy chuyến bay khi còn dưới 24 giờ (Lỗi 51003)
* **Mục tiêu:** Đảm bảo hãng hàng không không được tùy tiện hủy chuyến bay cận giờ khởi hành (< 24 giờ).
* **Đường dẫn trên Menu:** `Trigger` ➔ **TG2 · Chặn hủy chuyến dưới 24 giờ**.
* **Các bước thực hiện:**
  1. *Bước 3:* Quan sát danh sách các chuyến bay khởi hành trong vòng 24 giờ tới (trạng thái đang là `Đúng giờ` hoặc `Delay`).
  2. *Bước 4:* 
     * Chọn một chuyến bay trong danh sách dưới 24 giờ.
     * Điền lý do: `Thử nghiệm hủy cận giờ`.
     * Nhấn nút: **`Thử hủy chuyến (TG2)`**.
  3. *Bước 5 (Kết quả kỳ vọng):*
     * ❌ Xuất hiện hộp thông báo lỗi màu đỏ từ SQL Server:
       * **Mã lỗi:** `51003`
       * **Nội dung:** `TG2: Không được phép hủy chuyến bay khi thời gian khởi hành còn dưới 24 giờ.`
     * Bảng chuyến bay và các vé liên quan được tải lại: **Giữ nguyên trạng thái ban đầu**, chứng minh giao dịch bị Rollback hoàn toàn.

---

### TEST CASE 8: TG3 – Chặn phân công vượt định mức 30 giờ bay/tuần (Lỗi 51004)
* **Mục tiêu:** Bảo vệ an toàn bay bằng cách ngăn chặn phi công/tiếp viên bị phân công quá tải (> 30 giờ trong 1 tuần).
* **Đường dẫn trên Menu:** `Trigger` ➔ **TG3 · Kiểm tra định mức 30 giờ/tuần**.
* **Các bước thực hiện:**
  1. *Bước 3:* Xem số ca hiện tại của phi công `NV01`.
  2. *Bước 4:* Nhấn nút: **`Thử batch vượt định mức`** (Gửi một khối lệnh gồm 4 ca trực liên tiếp tổng cộng 32 giờ cho `NV01` trong cùng tuần).
  3. *Bước 5 (Kết quả kỳ vọng):*
     * ❌ Xuất hiện thông báo lỗi từ SQL Server:
       * **Mã lỗi:** `51004`
       * **Nội dung:** `TG3: Tổng giờ bay được phân công trong tuần vượt quá định mức 30 giờ.`
     * Bảng phân công của `NV01` được tải lại: **Không có ca nào trong 4 ca trên được ghi vào CSDL** (Rollback toàn bộ batch).

---

### TEST CASE 9: TG4 – Ép buộc giá vé Thương gia phải cao hơn Phổ thông (Lỗi 51005)
* **Mục tiêu:** Ngăn chặn lỗi nghiệp vụ nhập giá vé vô lý (giá vé Thương gia bằng hoặc thấp hơn Phổ thông).
* **Đường dẫn trên Menu:** `Trigger` ➔ **TG4 · Bảo vệ giá vé thương gia**.
* **Các bước thực hiện:**
  1. *Bước 3:* Xem giá vé chuyến bay hiện tại (ví dụ: Phổ thông `2.500.000` VND, Thương gia `5.000.000` VND).
  2. *Bước 4:* Chọn chuyến bay và nhấn nút: **`Thử giá không hợp lệ`** (Lệnh SQL cố tình gán `GiaVeThuongGia = GiaVePhoThong`).
  3. *Bước 5 (Kết quả kỳ vọng):*
     * ❌ Xuất hiện thông báo lỗi từ SQL Server:
       * **Mã lỗi:** `51005`
       * **Nội dung:** `TG4: Giá vé hạng Thương gia phải lớn hơn giá vé hạng Phổ thông trên cùng chuyến bay.`
     * Giá vé cũ vẫn giữ nguyên vẹn sau khi tải lại.

---

### TEST CASE 10: TG5 – Chặn xóa máy bay đang có lịch bay trong tương lai (Lỗi 51006)
* **Mục tiêu:** Ngăn chặn việc xóa thông tin máy bay khi máy bay đó đang được điều phối chở khách cho các chuyến bay tương lai.
* **Đường dẫn trên Menu:** `Trigger` ➔ **TG5 · Chặn xóa máy bay có lịch bay**.
* **Các bước thực hiện:**
  1. *Bước 3:* Xem máy bay được chọn và danh sách các chuyến bay tương lai đang sử dụng máy bay này.
  2. *Bước 4:* Nhấn nút: **`Thử xóa máy bay`**.
  3. *Bước 5 (Kết quả kỳ vọng):*
     * ❌ Xuất hiện thông báo lỗi từ SQL Server:
       * **Mã lỗi:** `51006`
       * **Nội dung:** `TG5: Không thể xóa thông tin máy bay đang nằm trong lịch bay tương lai.`
     * Máy bay hoàn toàn không bị xóa khỏi bảng `MAYBAY`.

---

# PHẦN 3: KIỂM THỬ 3 FUNCTIONS (FN1 – FN3)

---

### TEST CASE 11: FN1 – Tra cứu hạng hội viên tích lũy
* **Đường dẫn trên Menu:** `Function` ➔ **FN1 · Tra cứu hạng hội viên**.
* **Các bước thực hiện:**
  1. *Bước 4:* Chọn hành khách `HK01` (hoặc `HK13`).
  2. Nhấn nút: **`Tính hạng hội viên`**.
* **Kết quả kỳ vọng:**
  * Hàm Scalar Function `dbo.FN1_HangHoiVien` tự động tính tổng tiền tích lũy từ các vé đã thanh toán thành công và trả về hạng: **`Bạc`**, **`Vàng`**, hoặc **`Kim Cương`**.

---

### TEST CASE 12: FN2 – Sơ đồ ghế còn trống (Hiển thị Lưới Seat Map)
* **Đường dẫn trên Menu:** `Function` ➔ **FN2 · Sơ đồ ghế còn trống**.
* **Các bước thực hiện:**
  1. *Bước 4:* Chọn chuyến bay (ví dụ: `VN716`).
  2. Nhấn nút: **`Tải danh sách ghế trống`**.
* **Kết quả kỳ vọng:**
  * Trả về danh sách ghế chưa bán.
  * **Đặc biệt:** Danh sách ghế được hiển thị ở dạng **Lưới ngang – dọc trực quan (Seat Map Grid)** với các huy hiệu nhỏ gọn (`01A`, `01B`, `01C`,... `30F`), có hiệu ứng hover tương tác, không bị tràn cuộn dài toàn trang.

---

### TEST CASE 13: FN3 – Thống kê hiệu suất máy bay theo tháng
* **Đường dẫn trên Menu:** `Function` ➔ **FN3 · Hiệu suất máy bay theo tháng**.
* **Các bước thực hiện:**
  1. *Bước 4:* Chọn máy bay `MB01`, nhập **Năm:** `2026`, **Tháng:** `10`.
  2. Nhấn nút: **`Tính hiệu suất`**.
* **Kết quả kỳ vọng:**
  * Trả về bảng tổng hợp Table-Valued gồm: `MaMayBay`, `TongSoChuyenBay`, `TongGioBay` và `TrangThaiHienTai`.

---

# PHẦN 4: KIỂM THỬ 2 CURSORS DUYỆT TỪNG DÒNG (CS1 – CS2)

---

### TEST CASE 14: CS1 – Duyệt chuyến Delay tính tiền bồi hoàn tự động
* **Đường dẫn trên Menu:** `Cursor` ➔ **CS1 · Tính bồi thường chuyến Delay**.
* **Các bước thực hiện:**
  1. *Bước 3:* Quan sát danh sách các chuyến bay đang có trạng thái `Delay`.
  2. *Bước 4:* Nhấn nút: **`Tính bồi thường`**.
* **Kết quả kỳ vọng:**
  * Con trỏ duyệt từng chuyến bay bị hoãn, căn cứ số phút trễ (`> 120 phút` hoặc `> 240 phút`) và số lượng hành khách còn hiệu lực để tính ra số tiền bồi thường cụ thể cho từng chuyến.

---

### TEST CASE 15: CS2 – Duyệt danh sách phi hành đoàn tổng hợp công nhật & phụ cấp
* **Đường dẫn trên Menu:** `Cursor` ➔ **CS2 · Tổng hợp công nhật & phụ cấp**.
* **Các bước thực hiện:**
  1. *Bước 4:* Nhập khoảng ngày: **Từ ngày:** `2026-10-01`, **Đến ngày:** `2026-10-31`.
  2. Nhấn nút: **`Tổng hợp công nhật`**.
* **Kết quả kỳ vọng:**
  * Con trỏ duyệt qua từng nhân viên theo từng ca trực, nhóm theo vai trò (Cơ trưởng, Cơ phó, Tiếp viên) để tính ra: `Tổng số ca`, `Tổng giờ bay`, `Lương công nhật` và `Tiền phụ cấp trách nhiệm`.

---

# PHẦN 5: KIỂM THỬ 5 BÁO CÁO TỔNG HỢP CHUẨN 5 VÙNG (R1 – R5)

> 📑 **Quy chuẩn 5 vùng:** Mỗi báo cáo đều tách biệt rõ ràng 5 vùng:
> 1. **Report Header:** Tên báo cáo, logo SkyRoute.
> 2. **Page Header:** Metadata, tiêu đề cột.
> 3. **Detail:** Các dòng dữ liệu chi tiết.
> 4. **Page Footer:** Ngày giờ xuất (UTC), đánh số trang.
> 5. **Report Footer:** Tổng kết tổng số dòng, tổng tiền, tỷ lệ %.

---

### TEST CASE 16: Báo cáo R1 – Vé điện tử (E-ticket)
* **Đường dẫn:** `Báo cáo` ➔ **Vé điện tử · E-ticket**.
* **Thao tác:** Chọn mã vé `VE01` và nhấn **`Tạo bản xem trước`**.
* **Kiểm tra chức năng:**
  * Thử bấm nút **`Xuất CSV`** ➔ File `.csv` được tải về máy tính.
  * Thử bấm nút **`In / Lưu PDF`** ➔ Trình duyệt mở hộp thoại in với định dạng A4 chuẩn đẹp.

### TEST CASE 17: Báo cáo R2 – Danh sách hành khách chuyến bay (Passenger Manifest)
* **Đường dẫn:** `Báo cáo` ➔ **Danh sách hành khách · Manifest**.
* **Thao tác:** Chọn chuyến bay `VN716` và nhấn **`Tạo bản xem trước`**.
* **Kỳ vọng:** Hiển thị danh sách khách có vé hợp lệ, số ghế, giấy tờ tùy thân và trạng thái check-in; Report Footer đếm tổng số khách.

### TEST CASE 18: Báo cáo R3 – Phân công tổ bay theo ngày
* **Đường dẫn:** `Báo cáo` ➔ **Phân công tổ bay theo ngày**.
* **Thao tác:** Chọn ngày `2026-10-07` và nhấn **`Tạo bản xem trước`**.
* **Kỳ vọng:** Liệt kê các ca trực trong ngày của phi hành đoàn và tổng giờ công phục vụ.

### TEST CASE 19: Báo cáo R4 – Báo cáo doanh số theo đường bay
* **Đường dẫn:** `Báo cáo` ➔ **Doanh số theo đường bay**.
* **Thao tác:** Nhập khoảng ngày tháng 10/2026 và bấm **`Tạo bản xem trước`**.
* **Kỳ vọng:** Thống kê doanh số theo tuyến, Footer tổng hợp tổng tiền toàn hệ thống.

### TEST CASE 20: Báo cáo R5 – Thống kê hiệu suất khai thác
* **Đường dẫn:** `Báo cáo` ➔ **Hiệu suất khai thác**.
* **Thao tác:** Nhập khoảng ngày tháng 10/2026 và bấm **`Tạo bản xem trước`**.
* **Kỳ vọng:** Thống kê tỷ lệ % chuyến Đúng giờ, Hoãn (Delay) và Đã hủy; Report Footer tổng kết số lượng chuyến bay theo từng nhóm.

---

## 🛑 BẢNG TRA CỨU MÃ LỖI SQL SERVER KHI NGHIỆM THU ĐỒ ÁN

| Mã lỗi SQL | Vị trí phát sinh | Ý nghĩa nghiệp vụ |
|---|---|---|
| **51001** | `TG1_CapNhatSoGheTrong` | Số ghế chỉ định không tồn tại trên sơ đồ máy bay |
| **51002** | `TG1_CapNhatSoGheTrong` | Không đủ ghế trống hoặc số ghế hoàn vượt sức chứa |
| **51003** | `TG2_ChanHuyChuyenDuoi24h` | Chặn hủy chuyến bay khi thời gian cất cánh < 24 giờ |
| **51004** | `TG3_DinhMucGioBayTuan` | Chặn phân công nhân viên vượt định mức 30 giờ/tuần |
| **51005** | `TG4_GiaVeThuongGia` | Ép buộc giá vé Thương gia phải lớn hơn Phổ thông |
| **51006** | `TG5_ChanXoaMayBayCoLich` | Chặn xóa máy bay đang có lịch bay trong tương lai |
| **51007** | `TG5_ChanXoaMayBayCoLich` | Chặn xóa máy bay đã có lịch sử khai thác trong quá khứ |
| **51101** – **51105** | `SP1` – `SP5` | Các lỗi kiểm tra tham số đầu vào của Stored Procedures |
