const jwt = require('jsonwebtoken');
const User = require('../models/user.model');

// Yêu cầu header:  Authorization: Bearer <token>
module.exports = async function authMiddleware(req, res, next) {
  const header = req.headers.authorization || '';
  const [scheme, token] = header.split(' ');

  if (scheme !== 'Bearer' || !token) {
    return res.status(401).json({ message: 'Chưa đăng nhập' });
  }

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    const user = await User.findById(payload.id);

    if (!user) {
      return res.status(401).json({ message: 'Tài khoản không tồn tại' });
    }

    req.user = user;
    next();
  } catch (error) {
    return res
      .status(401)
      .json({ message: 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn' });
  }
};
