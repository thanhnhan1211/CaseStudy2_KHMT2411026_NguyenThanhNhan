const express = require('express');

const Notification = require('../models/notification.model');
const authMiddleware = require('../middleware/auth.middleware');
const { isObjectId } = require('../validators/task.validator');

const router = express.Router();

router.use(authMiddleware);

// GET /api/notifications?unread=true&page=1&limit=50
router.get('/', async (req, res) => {
  try {
    const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 50, 1), 100);
    const page = Math.max(parseInt(req.query.page, 10) || 1, 1);

    const filter = { userId: req.user._id };
    if (req.query.unread === 'true') filter.isRead = false;

    const [notifications, total, unreadCount] = await Promise.all([
      Notification.find(filter)
        .sort({ createdAt: -1, _id: -1 })
        .skip((page - 1) * limit)
        .limit(limit),
      Notification.countDocuments(filter),
      Notification.countDocuments({ userId: req.user._id, isRead: false }),
    ]);

    res.status(200).json({ notifications, total, unreadCount, page, limit });
  } catch (error) {
    res.status(500).json({ message: 'Không thể lấy danh sách thông báo' });
  }
});

// GET /api/notifications/unread-count
router.get('/unread-count', async (req, res) => {
  try {
    const unreadCount = await Notification.countDocuments({
      userId: req.user._id,
      isRead: false,
    });
    res.status(200).json({ unreadCount });
  } catch (error) {
    res.status(500).json({ message: 'Không thể đếm thông báo chưa đọc' });
  }
});

// PATCH /api/notifications/read-all
router.patch('/read-all', async (req, res) => {
  try {
    const result = await Notification.updateMany(
      { userId: req.user._id, isRead: false },
      { $set: { isRead: true } }
    );
    res.status(200).json({ modified: result.modifiedCount, unreadCount: 0 });
  } catch (error) {
    res.status(500).json({ message: 'Không thể đánh dấu đã đọc' });
  }
});

// PATCH /api/notifications/:id/read - chỉ thông báo của chính mình
router.patch('/:id/read', async (req, res) => {
  try {
    if (!isObjectId(req.params.id)) {
      return res.status(404).json({ message: 'Không tìm thấy thông báo' });
    }
    const notification = await Notification.findOneAndUpdate(
      { _id: req.params.id, userId: req.user._id },
      { $set: { isRead: true } },
      { new: true }
    );
    if (!notification) {
      return res.status(404).json({ message: 'Không tìm thấy thông báo' });
    }
    res.status(200).json({ notification });
  } catch (error) {
    res.status(500).json({ message: 'Không thể đánh dấu đã đọc' });
  }
});

module.exports = router;
