const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const User = require('../models/user.model');
const authMiddleware = require('../middleware/auth.middleware');
const {
  validateRegister,
  validateLogin,
  validateUpdateProfile,
  validateChangePassword,
} = require('../validators/auth.validator');

const router = express.Router();

const signToken = (user) =>
  jwt.sign({ id: user._id.toString() }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN || '7d',
  });

// POST /api/auth/register - Đăng ký
router.post('/register', async (req, res) => {
  try {
    const error = validateRegister(req.body);
    if (error) return res.status(400).json({ message: error });

    const { fullName, password } = req.body;
    const email = req.body.email.trim().toLowerCase();

    const existing = await User.findOne({ email });
    if (existing) {
      return res.status(409).json({ message: 'Email đã được sử dụng' });
    }

    const passwordHash = await bcrypt.hash(password, 10);
    const user = await User.create({
      fullName: fullName.trim(),
      email,
      passwordHash,
    });

    res.status(201).json({ token: signToken(user), user });
  } catch (error) {
    if (error && error.code === 11000) {
      return res.status(409).json({ message: 'Email đã được sử dụng' });
    }
    res.status(500).json({ message: 'Không thể đăng ký tài khoản' });
  }
});

// POST /api/auth/login - Đăng nhập
router.post('/login', async (req, res) => {
  try {
    const error = validateLogin(req.body);
    if (error) return res.status(400).json({ message: error });

    const email = req.body.email.trim().toLowerCase();
    const user = await User.findOne({ email });

    // Cùng một thông báo cho cả "sai email" và "sai mật khẩu"
    const valid =
      user && (await bcrypt.compare(req.body.password, user.passwordHash));
    if (!valid) {
      return res
        .status(401)
        .json({ message: 'Email hoặc mật khẩu không đúng' });
    }

    res.status(200).json({ token: signToken(user), user });
  } catch (error) {
    res.status(500).json({ message: 'Không thể đăng nhập' });
  }
});

// GET /api/auth/me - Thông tin người dùng hiện tại
router.get('/me', authMiddleware, (req, res) => {
  res.status(200).json({ user: req.user });
});

// PUT /api/auth/me - Cập nhật thông tin cá nhân (họ tên, ảnh đại diện)
router.put('/me', authMiddleware, async (req, res) => {
  try {
    const error = validateUpdateProfile(req.body);
    if (error) return res.status(400).json({ message: error });

    const { fullName, avatarUrl } = req.body;
    if (fullName !== undefined) req.user.fullName = fullName.trim();
    if (avatarUrl !== undefined) req.user.avatarUrl = avatarUrl.trim();

    await req.user.save();
    res.status(200).json({ user: req.user });
  } catch (error) {
    res.status(500).json({ message: 'Không thể cập nhật thông tin' });
  }
});

// PUT /api/auth/change-password - Đổi mật khẩu
router.put('/change-password', authMiddleware, async (req, res) => {
  try {
    const error = validateChangePassword(req.body);
    if (error) return res.status(400).json({ message: error });

    const { currentPassword, newPassword } = req.body;

    const match = await bcrypt.compare(
      currentPassword,
      req.user.passwordHash
    );
    if (!match) {
      return res
        .status(400)
        .json({ message: 'Mật khẩu hiện tại không đúng' });
    }

    req.user.passwordHash = await bcrypt.hash(newPassword, 10);
    await req.user.save();

    res.status(200).json({ message: 'Đổi mật khẩu thành công' });
  } catch (error) {
    res.status(500).json({ message: 'Không thể đổi mật khẩu' });
  }
});

// Đăng xuất: JWT không lưu trên server, client chỉ cần xóa token.

module.exports = router;
