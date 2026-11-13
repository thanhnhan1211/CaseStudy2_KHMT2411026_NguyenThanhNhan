# Task Manager API

- MSSV: <điền MSSV>
- Họ tên: <điền họ tên>

## Chạy dự án

```bash
npm install
copy .env.example .env   # Windows (macOS/Linux: cp), rồi sửa MONGODB_URI và JWT_SECRET
npm run seed             # (tuỳ chọn) tạo dữ liệu mẫu
npm start
```

## Endpoint

| Method | URL | Auth | Mô tả |
| --- | --- | --- | --- |
| GET | / | - | Kiểm tra server |
| GET | /api/tasks | - | Danh sách công việc |
| POST | /api/auth/register | - | Đăng ký (fullName, email, password) |
| POST | /api/auth/login | - | Đăng nhập (email, password) |
| GET | /api/auth/me | Bearer | Thông tin người dùng hiện tại |
| PUT | /api/auth/me | Bearer | Cập nhật fullName, avatarUrl |
| PUT | /api/auth/change-password | Bearer | Đổi mật khẩu (currentPassword, newPassword) |

API cần đăng nhập gửi header `Authorization: Bearer <token>`.
Android Emulator gọi API qua `http://10.0.2.2:3000/api`.
