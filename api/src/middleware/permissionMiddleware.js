const Task = require('../models/Task');
const TaskShare = require('../models/TaskShare');

/**
 * Kiểm tra quyền truy cập công việc của người dùng hiện tại:
 * - owner: người tạo công việc (toàn quyền: xem, sửa, xóa, giao việc, chia sẻ)
 * - editor: người được giao việc hoặc người được chia sẻ quyền 'editor' (xem, sửa, đổi trạng thái)
 * - viewer: người được chia sẻ quyền 'viewer' (chỉ xem)
 */
const checkTaskPermission = (requiredLevel = 'viewer') => {
  const levelRank = { viewer: 1, editor: 2, owner: 3 };

  return async (req, res, next) => {
    try {
      const taskId = req.params.id;
      const userId = req.user.id || req.user._id.toString();

      const task = await Task.findById(taskId);
      if (!task) {
        return res.status(404).json({ message: 'Không tìm thấy công việc' });
      }

      let userRole = null;

      if (task.createdBy.toString() === userId) {
        userRole = 'owner';
      } else {
        const isAssignee = task.assigneeIds.some((id) => id.toString() === userId);
        const share = await TaskShare.findOne({ taskId, userId });

        if (isAssignee || (share && share.permission === 'editor')) {
          userRole = 'editor';
        } else if (share && share.permission === 'viewer') {
          userRole = 'viewer';
        }
      }

      if (!userRole) {
        return res.status(403).json({ message: 'Bạn không có quyền truy cập công việc này' });
      }

      if (levelRank[userRole] < levelRank[requiredLevel]) {
        return res.status(403).json({
          message: `Thao tác này yêu cầu quyền ${requiredLevel}, quyền hiện tại của bạn là ${userRole}`,
        });
      }

      req.task = task;
      req.taskRole = userRole;
      next();
    } catch (error) {
      next(error);
    }
  };
};

module.exports = { checkTaskPermission };
