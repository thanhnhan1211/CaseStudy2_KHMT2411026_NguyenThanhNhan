const { isObjectId } = require('./task.validator');

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const PERMISSIONS = ['viewer', 'editor'];
const MAX_TARGETS = 20;

// Nhận danh sách người qua userIds và/hoặc emails
// Trả về { error } hoặc { userIds, emails } (đã loại trùng, email viết thường)
function validateTargets(body = {}) {
  const rawIds = body.userIds === undefined ? [] : body.userIds;
  const rawEmails = body.emails === undefined ? [] : body.emails;

  if (!Array.isArray(rawIds) || !Array.isArray(rawEmails)) {
    return { error: 'userIds và emails phải là mảng' };
  }
  if (!rawIds.every(isObjectId)) {
    return { error: 'userIds chứa giá trị không hợp lệ' };
  }
  if (
    !rawEmails.every((e) => typeof e === 'string' && EMAIL_REGEX.test(e.trim()))
  ) {
    return { error: 'emails chứa địa chỉ không hợp lệ' };
  }

  const userIds = [...new Set(rawIds)];
  const emails = [...new Set(rawEmails.map((e) => e.trim().toLowerCase()))];

  if (userIds.length + emails.length === 0) {
    return { error: 'Vui lòng chọn ít nhất một người' };
  }
  if (userIds.length + emails.length > MAX_TARGETS) {
    return { error: `Chỉ chọn tối đa ${MAX_TARGETS} người mỗi lần` };
  }
  return { userIds, emails };
}

function validatePermission(permission) {
  if (!PERMISSIONS.includes(permission)) {
    return 'Quyền phải là viewer hoặc editor';
  }
  return null;
}

module.exports = { validateTargets, validatePermission, MAX_TARGETS };
