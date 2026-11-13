const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const MIN_PASSWORD_LENGTH = 6;

const isString = (v) => typeof v === 'string';

function checkFullName(fullName) {
  if (!isString(fullName) || fullName.trim().length < 2) {
    return 'Họ tên phải có ít nhất 2 ký tự';
  }
  if (fullName.trim().length > 100) {
    return 'Họ tên không được quá 100 ký tự';
  }
  return null;
}

function checkEmail(email) {
  if (!isString(email) || !EMAIL_REGEX.test(email.trim())) {
    return 'Email không hợp lệ';
  }
  return null;
}

function checkPassword(password, label = 'Mật khẩu') {
  if (!isString(password) || password.length < MIN_PASSWORD_LENGTH) {
    return `${label} phải có ít nhất ${MIN_PASSWORD_LENGTH} ký tự`;
  }
  if (password.length > 72) {
    // giới hạn của bcrypt
    return `${label} không được quá 72 ký tự`;
  }
  return null;
}

// Mỗi hàm trả về chuỗi lỗi đầu tiên, hoặc null nếu hợp lệ
function validateRegister({ fullName, email, password } = {}) {
  return (
    checkFullName(fullName) || checkEmail(email) || checkPassword(password)
  );
}

function validateLogin({ email, password } = {}) {
  if (!isString(email) || !email.trim() || !isString(password) || !password) {
    return 'Vui lòng nhập email và mật khẩu';
  }
  return null;
}

function validateUpdateProfile({ fullName, avatarUrl } = {}) {
  if (fullName === undefined && avatarUrl === undefined) {
    return 'Không có thông tin nào để cập nhật';
  }
  if (fullName !== undefined) {
    const error = checkFullName(fullName);
    if (error) return error;
  }
  if (avatarUrl !== undefined && !isString(avatarUrl)) {
    return 'Đường dẫn ảnh đại diện không hợp lệ';
  }
  return null;
}

function validateChangePassword({ currentPassword, newPassword } = {}) {
  if (!isString(currentPassword) || !currentPassword) {
    return 'Vui lòng nhập mật khẩu hiện tại';
  }
  const error = checkPassword(newPassword, 'Mật khẩu mới');
  if (error) return error;
  if (currentPassword === newPassword) {
    return 'Mật khẩu mới phải khác mật khẩu hiện tại';
  }
  return null;
}

module.exports = {
  validateRegister,
  validateLogin,
  validateUpdateProfile,
  validateChangePassword,
};
