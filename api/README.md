# Task Manager API

- MSSV: <điền MSSV>
- Họ tên: <điền họ tên>

## Chạy dự án

```bash
npm install
copy .env.example .env   # Windows (macOS/Linux: cp), rồi sửa MONGODB_URI và JWT_SECRET
npm start
```

Tạo công việc mẫu cho một tài khoản đã đăng ký: `npm run seed -- email@cua-ban.com`

Gửi thử một email để kiểm tra cấu hình SMTP: `npm run test-email -- email-nhan@example.com`

## Endpoint

| Method | URL | Auth | Mô tả |
| --- | --- | --- | --- |
| GET | / | - | Kiểm tra server |
| POST | /api/auth/register | - | Đăng ký |
| POST | /api/auth/login | - | Đăng nhập |
| GET | /api/auth/me | Bearer | Thông tin người dùng hiện tại |
| PUT | /api/auth/me | Bearer | Cập nhật họ tên, ảnh đại diện |
| PUT | /api/auth/change-password | Bearer | Đổi mật khẩu |
| GET | /api/tasks | Bearer | Danh sách công việc có quyền truy cập |
| POST | /api/tasks | Bearer | Tạo công việc |
| GET | /api/tasks/:id | Bearer | Chi tiết công việc |
| PUT | /api/tasks/:id | Bearer | Sửa thông tin (người tạo, editor) |
| PATCH | /api/tasks/:id/status | Bearer | Đổi trạng thái (người tạo, editor, người được giao) |
| DELETE | /api/tasks/:id | Bearer | Xóa (chỉ người tạo) |
| GET | /api/tasks/:id/activities | Bearer | Lịch sử hoạt động |
| GET | /api/users/search?q= | Bearer | Tìm người dùng theo tên/email (không phân biệt dấu, tối thiểu 2 ký tự) |
| GET | /api/users/:id | Bearer | Thông tin công khai của một người dùng |
| GET | /api/tasks/:id/assignees | Bearer | Danh sách người được giao (kèm `isPrimary`) |
| POST | /api/tasks/:id/assignees | Bearer | Giao việc: `userIds` và/hoặc `emails`, tuỳ chọn `primaryAssigneeId` (chỉ người tạo) |
| PATCH | /api/tasks/:id/assignees/:userId | Bearer | Đặt/bỏ phụ trách chính: `{ isPrimary }` (chỉ người tạo) |
| DELETE | /api/tasks/:id/assignees/:userId | Bearer | Hủy giao việc (chỉ người tạo) |
| GET | /api/tasks/:id/shares | Bearer | Danh sách chia sẻ |
| POST | /api/tasks/:id/shares | Bearer | Chia sẻ: `userIds` và/hoặc `emails`, `permission` = viewer/editor (chỉ người tạo) |
| PATCH | /api/tasks/:id/shares/:shareId | Bearer | Đổi quyền: `{ permission }` (chỉ người tạo) |
| DELETE | /api/tasks/:id/shares/:shareId | Bearer | Thu hồi quyền (chỉ người tạo) |
| GET | /api/notifications | Bearer | Danh sách thông báo của tôi (`unread=true`, `page`, `limit`) |
| GET | /api/notifications/unread-count | Bearer | Số thông báo chưa đọc |
| PATCH | /api/notifications/:id/read | Bearer | Đánh dấu một thông báo đã đọc |
| PATCH | /api/notifications/read-all | Bearer | Đánh dấu tất cả đã đọc |
| GET | /api/tasks/:id/email-logs | Bearer | Lịch sử gửi email của công việc (chỉ người tạo) |
| POST | /api/email-logs/:id/retry | Bearer | Thử gửi lại email thất bại, tối đa 3 lần (chỉ người tạo) |
| GET | /api/statistics/tasks | Bearer | Thống kê theo trạng thái và mức độ ưu tiên, tỷ lệ hoàn thành (`scope`) |
| GET | /api/statistics/assignments | Bearer | Việc được giao cho tôi, tôi phụ trách chính, tôi đã giao cho người khác |
| GET | /api/statistics/deadlines | Bearer | Việc sắp đến hạn và quá hạn (`days` từ 1 đến 90, mặc định 7; `scope`) |

### Tham số của GET /api/tasks

| Tham số | Giá trị |
| --- | --- |
| scope | `all` (mặc định), `created`, `assigned`, `shared` |
| status | `todo`, `in_progress`, `completed` |
| priority | `low`, `medium`, `high` |
| q | tìm theo tên công việc |
| assigneeId | lọc theo người phụ trách |
| sortBy | `createdAt` (mặc định), `dueDate`, `priority` |
| order | `asc`, `desc` |

### Phân quyền công việc

| Vai trò | Xem | Sửa thông tin | Đổi trạng thái | Xóa |
| --- | --- | --- | --- | --- |
| Người tạo (owner) | có | có | có | có |
| Chia sẻ quyền sửa (editor) | có | có | có | không |
| Người được giao (assignee) | có | không | có | không |
| Chia sẻ quyền xem (viewer) | có | không | không | không |

Giao việc và quản lý chia sẻ chỉ dành cho **người tạo**: editor, người được giao và viewer đều nhận `403`.
Một người vừa được giao vừa được chia sẻ thì quyền được cộng dồn. Thu hồi hoặc hủy giao có hiệu lực ngay.

Người không liên quan nhận `404` (không tiết lộ công việc có tồn tại hay không).

API cần đăng nhập gửi header `Authorization: Bearer <token>`.
Android Emulator gọi API qua `http://10.0.2.2:3000/api`.

## Thông báo và email

| Sự kiện | Thông báo trong app | Email | Người nhận |
| --- | --- | --- | --- |
| Giao việc mới | có | có | người được giao |
| Chia sẻ công việc | có | có | người được chia sẻ |
| Đổi quyền chia sẻ | có | không | người bị đổi quyền |
| Đổi hạn hoàn thành | có | có | người tạo, người được giao, người được chia sẻ |
| Đổi trạng thái | có | không | như trên |
| Hoàn thành công việc | có | có | như trên |
| Sắp đến hạn (nhắc việc) | có | có | người được giao (không có thì người tạo) |

Người thực hiện thao tác không nhận thông báo của chính mình.

Email được gửi **ở nền** từ backend, mỗi email có một bản ghi trong `email_logs`
(`pending` → `sent` hoặc `failed`, kèm số lần thử và lỗi). Email thất bại được thử gửi lại
qua `POST /api/email-logs/:id/retry` (tối đa 3 lần, mỗi bản ghi chỉ có một lần gửi tại một thời điểm).
Nếu chưa cấu hình SMTP, ứng dụng vẫn chạy: thông báo trong app vẫn có, email được ghi nhận `failed`.

### Cấu hình SMTP (file `.env`)

Ví dụ với Gmail: bật xác minh 2 bước, tạo **Mật khẩu ứng dụng** (App Password) và dùng nó làm `SMTP_PASS`.

```
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER=ban@gmail.com
SMTP_PASS=mat_khau_ung_dung
MAIL_FROM=Task Manager <ban@gmail.com>
```

### Nhắc việc

Tác vụ nền chạy mỗi `REMINDER_INTERVAL_MINUTES` phút (mặc định 60) và nhắc các việc chưa hoàn thành
sẽ đến hạn trong `REMINDER_HOURS` giờ tới (mặc định 24). Mỗi hạn chỉ nhắc một lần; đổi hạn mới thì được nhắc lại.
Đặt `REMINDER_ENABLED=false` để tắt.

## Thống kê

- Chỉ tính các công việc người dùng được truy cập (tự tạo, được giao, được chia sẻ); `scope` thu hẹp phạm vi
  (`all`, `created`, `assigned`, `shared`). Người dùng không bao giờ thấy số liệu của công việc người khác.
- **Quá hạn**: chưa hoàn thành và hạn đã qua. **Sắp đến hạn**: chưa hoàn thành và hạn nằm trong `days` ngày tới.
  Việc đã hoàn thành không bao giờ được tính là quá hạn.
- Mỗi danh sách hạn trả tối đa 20 việc (xếp theo hạn tăng dần) nhưng `count` luôn là tổng số thật.
- Tỷ lệ hoàn thành = số việc hoàn thành / tổng số việc (0 nếu chưa có việc nào).
