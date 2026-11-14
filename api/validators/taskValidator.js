const mongoose = require('mongoose');

const VALID_STATUSES = ['todo', 'in_progress', 'completed'];
const VALID_PRIORITIES = ['low', 'medium', 'high'];

const validateCreateTask = (req, res, next) => {
  const { title, priority, status, startDate, dueDate } = req.body;

  if (!title || typeof title !== 'string' || title.trim().length === 0) {
    return res.status(400).json({ message: 'Tên công việc (title) là bắt buộc' });
  }

  if (priority && !VALID_PRIORITIES.includes(priority)) {
    return res.status(400).json({ message: 'Mức độ ưu tiên không hợp lệ (low, medium, high)' });
  }

  if (status && !VALID_STATUSES.includes(status)) {
    return res.status(400).json({ message: 'Trạng thái không hợp lệ (todo, in_progress, completed)' });
  }

  if (startDate && dueDate && new Date(startDate) > new Date(dueDate)) {
    return res.status(400).json({ message: 'Ngày bắt đầu không được lớn hơn hạn hoàn thành' });
  }

  next();
};

const validateUpdateTask = (req, res, next) => {
  const { title, priority, status, startDate, dueDate } = req.body;

  if (title !== undefined && (typeof title !== 'string' || title.trim().length === 0)) {
    return res.status(400).json({ message: 'Tên công việc không được để trống' });
  }

  if (priority !== undefined && !VALID_PRIORITIES.includes(priority)) {
    return res.status(400).json({ message: 'Mức độ ưu tiên không hợp lệ (low, medium, high)' });
  }

  if (status !== undefined && !VALID_STATUSES.includes(status)) {
    return res.status(400).json({ message: 'Trạng thái không hợp lệ (todo, in_progress, completed)' });
  }

  if (startDate && dueDate && new Date(startDate) > new Date(dueDate)) {
    return res.status(400).json({ message: 'Ngày bắt đầu không được lớn hơn hạn hoàn thành' });
  }

  next();
};

const validateStatusPatch = (req, res, next) => {
  const { status } = req.body;
  if (!status || !VALID_STATUSES.includes(status)) {
    return res.status(400).json({ message: 'Trạng thái không hợp lệ (todo, in_progress, completed)' });
  }
  next();
};

const validateObjectId = (req, res, next) => {
  if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
    return res.status(400).json({ message: 'ID công việc không hợp lệ' });
  }
  next();
};

module.exports = {
  validateCreateTask,
  validateUpdateTask,
  validateStatusPatch,
  validateObjectId,
};
