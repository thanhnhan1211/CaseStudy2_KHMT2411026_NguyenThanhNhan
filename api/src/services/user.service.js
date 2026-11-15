const User = require('../models/user.model');
const { USER_FIELDS } = require('./task.service');

// Tìm các tài khoản theo userIds và/hoặc emails.
// Trả về { users } hoặc { status, error } nếu có người không tồn tại.
async function resolveTargets({ userIds = [], emails = [] }) {
  const byId = userIds.length
    ? await User.find({ _id: { $in: userIds } }).select(USER_FIELDS)
    : [];
  const byEmail = emails.length
    ? await User.find({ email: { $in: emails } }).select(USER_FIELDS)
    : [];

  const foundIds = new Set(byId.map((u) => String(u._id)));
  const foundEmails = new Set(byEmail.map((u) => u.email));

  const missing = [
    ...userIds.filter((id) => !foundIds.has(id)),
    ...emails.filter((e) => !foundEmails.has(e)),
  ];
  if (missing.length > 0) {
    return {
      status: 404,
      error: `Không tìm thấy người dùng: ${missing.join(', ')}`,
    };
  }

  // Giữ đúng thứ tự người dùng đã chọn (userIds trước, rồi emails) và loại trùng
  // (một người có thể được chọn cả bằng id lẫn email). Thứ tự quan trọng vì
  // người đầu tiên được giao sẽ là người phụ trách chính.
  const idMap = new Map(byId.map((u) => [String(u._id), u]));
  const emailMap = new Map(byEmail.map((u) => [u.email, u]));
  const ordered = [
    ...userIds.map((id) => idMap.get(id)),
    ...emails.map((email) => emailMap.get(email)),
  ];

  const unique = new Map();
  ordered.forEach((u) => {
    if (!unique.has(String(u._id))) unique.set(String(u._id), u);
  });
  return { users: [...unique.values()] };
}

module.exports = { resolveTargets };
