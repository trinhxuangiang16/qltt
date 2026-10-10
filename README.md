# ✈️ HƯỚNG DẪN CÀI ĐẶT & CHẠY DỰ ÁN QUẢN LÝ CHUYẾN BAY (QLCB) TẠI LOCAL

> **Dành cho:** Bất kỳ ai (kể cả người chưa từng lập trình) cũng có thể làm theo từng bước để chạy dự án trên máy cá nhân một cách nhanh chóng và chính xác.

---

## 📌 YÊU CẦU PHẦN MỀM TRƯỚC KHI BẮT ĐẦU

Hãy đảm bảo máy tính của bạn đã cài đặt sẵn 2 phần mềm sau:
1. **Docker Desktop**: [Tải tại đây](https://www.docker.com/products/docker-desktop/) (Đảm bảo đã mở Docker Desktop lên và thấy icon cá voi xanh báo `Engine running`).
2. **Node.js** (Phiên bản 18 hoặc 20 trở lên): [Tải tại đây](https://nodejs.org/) (Khuyên dùng bản LTS).
3. **Trình duyệt web**: Google Chrome, Microsoft Edge, Firefox, Cốc Cốc,...

---

## 💻 CHỌN TERMINAL & VỊ TRÍ THƯ MỤC LÀM VIỆC

### 1. Dùng Terminal nào?
* Trên Windows: Khuyên dùng **PowerShell** (hoặc **Command Prompt / Windows Terminal**).
* Không cần quyền Administrator đặc biệt, chỉ cần mở PowerShell thông thường.

### 2. Mở Terminal đúng vị trí thư mục dự án:
* **Cách nhanh nhất:** 
  1. Mở File Explorer và tìm đến thư mục dự án `QLCB`.
  2. Bấm chuột vào thanh địa chỉ ở phía trên cùng của thư mục, gõ chữ `powershell` rồi nhấn **Enter**.
* **Cách qua lệnh `cd`:**
  Mở PowerShell lên và gõ:
  ```powershell
  cd "C:\Users\jiang\Desktop\QLCB"
  ```
  *(Thay thế đường dẫn trên bằng đường dẫn thư mục `QLCB` trên máy của bạn nếu khác)*.
* **Kiểm tra vị trí:**
  Gõ lệnh sau để chắc chắn bạn đang đứng đúng thư mục có chứa file `docker-compose.yml`:
  ```powershell
  ls
  ```
  (Nếu thấy có các file `docker-compose.yml`, `package.json`, `demo_sanbay.sql` là đã đứng đúng chỗ).

---

## 🚀 CÁC BƯỚC KHỞI CHẠY CHI TIẾT (TỪ A ĐẾN Z)

### BƯỚC 1: Khởi chạy SQL Server 2022 bằng Docker

Nếu bạn **chưa từng tải SQL Server về máy**, đừng lo! Docker sẽ tự động tải image (`mcr.microsoft.com/mssql/server:2022-latest`, khoảng 1.5 GB) về máy trong lần chạy đầu tiên.

Tại cửa sổ PowerShell (đang đứng ở thư mục `QLCB`), chạy chính xác lệnh sau:

```powershell
docker compose up -d
```

* **Hiện tượng diễn ra:**
  * Nếu lần đầu chạy: Màn hình sẽ hiện tiến trình tải các layer `Pulling ...`. Quá trình này mất khoảng 1–3 phút tùy tốc độ mạng.
  * Khi xong, màn hình sẽ hiển thị: `[+] Running 2/2 Container sqlserver_qlcb Started`.

* **Kiểm tra xem SQL Server đã chạy thành công chưa:**
  Gõ lệnh:
  ```powershell
  docker ps
  ```
  *Kết quả:* Bạn sẽ thấy một dòng có tên container `sqlserver_qlcb`, cổng `0.0.0.0:1433->1433/tcp` và trạng thái `Up` là thành công.

---

### BƯỚC 2: Nạp cơ sở dữ liệu mẫu (`demo_sanbay.sql`) vào SQL Server

Sau khi container SQL Server đã bật, ta cần tạo Database `QL_CHUYENBAY`, 9 bảng, 5 Stored Procedures, 5 Triggers, 3 Functions, 2 Cursors và dữ liệu mẫu.

Chạy tuần tự 2 lệnh sau trong PowerShell:

1. **Copy file script vào container Docker:**
   ```powershell
   docker cp demo_sanbay.sql sqlserver_qlcb:/tmp/demo_sanbay.sql
   ```

2. **Thực thi nạp script SQL:**
   ```powershell
   docker exec sqlserver_qlcb /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Pass@123456" -C -i /tmp/demo_sanbay.sql
   ```

*(Lệnh chạy mất khoảng 3–5 giây. Khi chạy xong và con trỏ terminal quay lại dấu nhắc lệnh là dữ liệu đã được nạp hoàn chỉnh).*

---

### BƯỚC 3: Cài đặt thư viện Node.js & Tạo tài khoản ứng dụng

1. **Cài đặt các gói thư viện dự án:**
   ```powershell
   npm install
   ```
   *(Đợi khoảng 10–20 giây để npm tải các gói React, Vite, Express, mssql,...)*.

2. **Tự động cấp quyền tài khoản CSDL và tạo file `.env`:**
   Ứng dụng tuân thủ chuẩn an toàn thông tin: không dùng tài khoản quản trị `sa` trực tiếp trong web mà dùng tài khoản ứng dụng riêng biệt `QLCB_AppLogin`.
   
   Chạy lệnh PowerShell sau để hệ thống tự động thiết lập:
   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\server\setup-demo-user.ps1 -SqlAdminPassword "Pass@123456"
   ```
   *Kết quả thành công:* Hiện dòng chữ `Created QLCB_AppLogin, QLCB_UngDung, and the local .env file.`

*(Lưu ý: Nếu không chạy được script trên do chính sách bảo mật máy tính, bạn chỉ cần tạo file `.env` ở thư mục gốc với nội dung:)*
```env
DB_SERVER=localhost
DB_PORT=1433
DB_NAME=QL_CHUYENBAY
DB_USER=sa
DB_PASSWORD=Pass@123456
DB_ENCRYPT=false
PORT=3001
```

---

### BƯỚC 4: Khởi động Ứng dụng Web (Frontend + Backend)

Chỉ với **1 câu lệnh duy nhất**, hệ thống sẽ bật song song cả Backend API và Frontend React:

```powershell
npm run dev
```

* **Thông tin hiển thị trên màn hình:**
  * **Backend API:** Sẵn sàng tại `http://localhost:3001`
  * **Frontend Web:** Sẵn sàng tại `http://localhost:5173`

* **Mở ứng dụng:**
  Bật trình duyệt web (Chrome / Edge) và truy cập vào địa chỉ:
  👉 **`http://localhost:5173`**

Ngay lập tức, bạn sẽ thấy màn hình Dashboard hệ thống **SkyRoute Flight Operations** với đầy đủ các số liệu trực quan từ SQL Server!

---

## 🛠️ HƯỚNG DẪN TẮT HOẶC KHỞI ĐỘNG LẠI DỰ ÁN

* **Muốn dừng ứng dụng web:** Tại cửa sổ PowerShell đang chạy `npm run dev`, nhấn tổ hợp phím **`Ctrl + C`**, gõ `y` rồi nhấn Enter.
* **Muốn dừng container SQL Server:**
  ```powershell
  docker compose down
  ```
* **Muốn bật lại vào hôm sau:**
  Chỉ cần mở PowerShell tại thư mục `QLCB` và chạy:
  ```powershell
  docker compose up -d
  npm run dev
  ```
  *(Dữ liệu đã được lưu bền vững trong Docker volume, không bị mất đi).*

---

## ❓ CÁC VẤN ĐỀ THƯỜNG GẶP VÀ CÁCH XỬ LÝ (FAQ)

### 1. Báo lỗi `docker: command not found` hoặc lỗi không kết nối được Docker daemon?
* **Khắc phục:** Hãy kiểm tra xem bạn đã mở phần mềm **Docker Desktop** lên chưa. Docker Desktop bắt buộc phải đang chạy dưới khay hệ thống.

### 2. Báo lỗi xung đột cổng `1433` (Port is already allocated)?
* **Nguyên nhân:** Máy tính của bạn đã có một phiên bản SQL Server khác đang cài trực tiếp trên Windows và chiếm cổng 1433.
* **Khắc phục:**
  1. Mở cửa sổ `services.msc` trên Windows.
  2. Tìm dịch vụ `SQL Server (MSSQLSERVER)` và bấm **Stop**.
  3. Sau đó chạy lại `docker compose up -d`.

### 3. Trang web báo lỗi "Không thể kết nối cơ sở dữ liệu"?
* **Khắc phục:** Kiểm tra lại file `.env` đã có mật khẩu chính xác chưa, và đảm bảo container `sqlserver_qlcb` đang ở trạng thái `Up` (kiểm tra bằng lệnh `docker ps`).

---

*📖 Xem tiếp hướng dẫn kiểm thử chi tiết từng chức năng tại file:* **[test_guide.md](file:///c:/Users/jiang/Desktop/QLCB/test_guide.md)**
