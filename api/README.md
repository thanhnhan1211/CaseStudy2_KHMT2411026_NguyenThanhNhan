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
