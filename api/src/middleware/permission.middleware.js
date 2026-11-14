const { findAccessibleTask } = require('../services/task.service');

// Nạp công việc từ :id; người không có quyền xem nhận 404
async function loadTask(req, res, next) {
  try {
    const found = await findAccessibleTask(req.params.id, req.user._id);
    if (!found) {
      return res.status(404).json({ message: 'Không tìm thấy công việc' });
    }
    req.task = found.task;
    req.access = found.access;
    next();
  } catch (error) {
    res.status(500).json({ message: 'Không thể kiểm tra quyền truy cập' });
  }
}

// Giao việc và quản lý chia sẻ chỉ dành cho người tạo công việc
function requireManage(req, res, next) {
  if (!req.access.permissions.canManage) {
    return res.status(403).json({
      message: 'Chỉ người tạo công việc mới được giao việc hoặc quản lý chia sẻ',
    });
  }
  next();
}

module.exports = { loadTask, requireManage };
