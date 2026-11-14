const express = require('express');

const User = require('../models/user.model');
const authMiddleware = require('../middleware/auth.middleware');
const { isObjectId } = require('../validators/task.validator');
const { USER_FIELDS } = require('../services/task.service');
const { normalizeText } = require('../utils/text');

// Số tài khoản tối đa được quét mỗi lần tìm (đủ cho quy mô bài tập)
const SCAN_LIMIT = 2000;

const router = express.Router();

router.use(authMiddleware);

// GET /api/users/search?q= - Tìm theo tên hoặc email (tối thiểu 2 ký tự, không phân biệt dấu)
router.get('/search', async (req, res) => {
  try {
    const q = String(req.query.q || '').trim();
    if (q.length < 2) {
      return res.status(400).json({ message: 'Nhập ít nhất 2 ký tự để tìm' });
    }

    // Tìm không phân biệt hoa/thường và dấu tiếng Việt (gõ "van" vẫn ra "Văn")
    const keyword = normalizeText(q);
    const candidates = await User.find().select(USER_FIELDS).limit(SCAN_LIMIT);
    const users = candidates
      .filter(
        (u) =>
          normalizeText(u.fullName).includes(keyword) ||
          normalizeText(u.email).includes(keyword)
      )
      .sort((a, b) => a.fullName.localeCompare(b.fullName, 'vi'))
      .slice(0, 10);

    res.status(200).json({ users });
  } catch (error) {
    res.status(500).json({ message: 'Không thể tìm người dùng' });
  }
});

// GET /api/users/:id - Thông tin công khai
router.get('/:id', async (req, res) => {
  try {
    if (!isObjectId(req.params.id)) {
      return res.status(404).json({ message: 'Không tìm thấy người dùng' });
    }
    const user = await User.findById(req.params.id).select(USER_FIELDS);
    if (!user) {
      return res.status(404).json({ message: 'Không tìm thấy người dùng' });
    }
    res.status(200).json({ user });
  } catch (error) {
    res.status(500).json({ message: 'Không thể lấy thông tin người dùng' });
  }
});

module.exports = router;
