const express = require('express');

const EmailLog = require('../models/emailLog.model');
const Task = require('../models/task.model');
const authMiddleware = require('../middleware/auth.middleware');
const { loadTask, requireManage } = require('../middleware/permission.middleware');
const { isObjectId } = require('../validators/task.validator');
const { MAX_ATTEMPTS, retryEmail } = require('../services/email.service');

// Không trả payload (dữ liệu nội bộ dùng để dựng lại email)
const publicLog = (log) => {
  const obj = log.toObject ? log.toObject() : { ...log };
  delete obj.payload;
  delete obj.__v;
  return obj;
};

// GET /api/tasks/:id/email-logs - chỉ người tạo xem được (có địa chỉ email người nhận)
const taskEmailLogRoutes = express.Router({ mergeParams: true });
taskEmailLogRoutes.use(authMiddleware, loadTask, requireManage);

taskEmailLogRoutes.get('/', async (req, res) => {
  try {
    const logs = await EmailLog.find({ taskId: req.task._id })
      .sort({ createdAt: -1, _id: -1 })
      .limit(100);
    res.status(200).json({ emailLogs: logs.map(publicLog) });
  } catch (error) {
    res.status(500).json({ message: 'Không thể lấy lịch sử gửi email' });
  }
});

// POST /api/email-logs/:id/retry - thử gửi lại email thất bại (chỉ người tạo công việc)
const emailLogRoutes = express.Router();
emailLogRoutes.use(authMiddleware);

emailLogRoutes.post('/:id/retry', async (req, res) => {
  try {
    const notFound = { message: 'Không tìm thấy bản ghi email' };
    if (!isObjectId(req.params.id)) return res.status(404).json(notFound);

    const log = await EmailLog.findById(req.params.id);
    if (!log || !log.taskId) return res.status(404).json(notFound);

    // Người không phải chủ công việc nhận 404 để không lộ bản ghi tồn tại
    const task = await Task.findById(log.taskId).select('createdBy');
    if (!task || String(task.createdBy) !== String(req.user._id)) {
      return res.status(404).json(notFound);
    }

    if (log.status !== 'failed') {
      return res.status(400).json({ message: 'Chỉ gửi lại được email đã thất bại' });
    }
    if (log.attempts >= MAX_ATTEMPTS) {
      return res.status(400).json({
        message: `Email đã thử gửi ${MAX_ATTEMPTS} lần, không thể gửi lại nữa`,
      });
    }

    const updated = await retryEmail(log._id);
    if (!updated) {
      return res.status(409).json({ message: 'Email đang được xử lý, hãy thử lại sau' });
    }
    res.status(200).json({ emailLog: publicLog(updated) });
  } catch (error) {
    res.status(500).json({ message: 'Không thể gửi lại email' });
  }
});

module.exports = { taskEmailLogRoutes, emailLogRoutes };
