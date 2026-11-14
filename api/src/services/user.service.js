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

  // Loại trùng (một người có thể được chọn cả bằng id lẫn email)
  const unique = new Map();
  [...byId, ...byEmail].forEach((u) => unique.set(String(u._id), u));
  return { users: [...unique.values()] };
}

module.exports = { resolveTargets };
