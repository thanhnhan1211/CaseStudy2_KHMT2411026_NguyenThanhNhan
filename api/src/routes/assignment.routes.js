const express = require('express');

const User = require('../models/user.model');
const authMiddleware = require('../middleware/auth.middleware');
const { loadTask, requireManage } = require('../middleware/permission.middleware');
const { isObjectId } = require('../validators/task.validator');
const { validateTargets, MAX_TARGETS } = require('../validators/share.validator');
const { resolveTargets } = require('../services/user.service');
const { idOf, populateTask, logActivity } = require('../services/task.service');
const { notifyAssigned } = require('../services/notification.service');

// Gắn vào /api/tasks/:id/assignees
const router = express.Router({ mergeParams: true });

router.use(authMiddleware, loadTask);

// Danh sách người được giao, kèm cờ isPrimary
async function assigneeList(task) {
  await populateTask(task);
  const primaryId = task.primaryAssigneeId ? idOf(task.primaryAssigneeId) : null;
  return task.assigneeIds.map((u) => ({
    _id: u._id,
    fullName: u.fullName,
    email: u.email,
    avatarUrl: u.avatarUrl,
    isPrimary: idOf(u) === primaryId,
  }));
}

const NOT_ASSIGNEE = { message: 'Người này chưa được giao công việc' };

// GET /api/tasks/:id/assignees
router.get('/', async (req, res) => {
  try {
    res.status(200).json({ assignees: await assigneeList(req.task) });
  } catch (error) {
    res.status(500).json({ message: 'Không thể lấy danh sách người được giao' });
  }
});

// POST /api/tasks/:id/assignees  { userIds?, emails?, primaryAssigneeId? }
router.post('/', requireManage, async (req, res) => {
  try {
    const task = req.task;

    const targets = validateTargets(req.body);
    if (targets.error) return res.status(400).json({ message: targets.error });

    const resolved = await resolveTargets(targets);
    if (resolved.error) {
      return res.status(resolved.status).json({ message: resolved.error });
    }

    const currentIds = task.assigneeIds.map(String);
    const added = resolved.users.filter((u) => !currentIds.includes(String(u._id)));
    const finalIds = [...currentIds, ...added.map((u) => String(u._id))];

    if (finalIds.length > MAX_TARGETS) {
      return res
        .status(400)
        .json({ message: `Mỗi công việc chỉ giao tối đa ${MAX_TARGETS} người` });
    }

    // Người phụ trách chính: theo yêu cầu, nếu không thì lấy người đầu tiên
    const requestedPrimary = req.body.primaryAssigneeId;
    let newPrimary = task.primaryAssigneeId ? String(task.primaryAssigneeId) : null;
    if (requestedPrimary !== undefined && requestedPrimary !== null) {
      if (!isObjectId(requestedPrimary) || !finalIds.includes(requestedPrimary)) {
        return res.status(400).json({
          message: 'Người phụ trách chính phải nằm trong danh sách được giao',
        });
      }
      newPrimary = requestedPrimary;
    } else if (!newPrimary && finalIds.length > 0) {
      newPrimary = finalIds[0];
    }

    const primaryChanged =
      newPrimary !== (task.primaryAssigneeId ? String(task.primaryAssigneeId) : null);

    if (added.length > 0 || primaryChanged) {
      task.assigneeIds = finalIds;
      task.primaryAssigneeId = newPrimary;
      await task.save();

      if (added.length > 0) {
        await logActivity(task._id, req.user._id, 'assigned', {
          users: added.map((u) => ({ id: u._id, fullName: u.fullName })),
        });
        await notifyAssigned(task, req.user, added);
      }
      if (primaryChanged) {
        await logActivity(task._id, req.user._id, 'primary_changed', {
          primaryAssigneeId: newPrimary,
        });
      }
    }

    res
      .status(added.length > 0 ? 201 : 200)
      .json({ assignees: await assigneeList(task) });
  } catch (error) {
    res.status(500).json({ message: 'Không thể giao việc' });
  }
});

// PATCH /api/tasks/:id/assignees/:userId  { isPrimary: true|false }
router.patch('/:userId', requireManage, async (req, res) => {
  try {
    const task = req.task;
    const { userId } = req.params;

    if (typeof req.body.isPrimary !== 'boolean') {
      return res.status(400).json({ message: 'isPrimary phải là true hoặc false' });
    }
    if (!isObjectId(userId) || !task.assigneeIds.map(String).includes(userId)) {
      return res.status(404).json(NOT_ASSIGNEE);
    }

    const isCurrentPrimary = String(task.primaryAssigneeId) === userId;
    if (req.body.isPrimary && !isCurrentPrimary) {
      task.primaryAssigneeId = userId;
      await task.save();
      await logActivity(task._id, req.user._id, 'primary_changed', {
        primaryAssigneeId: userId,
      });
    } else if (!req.body.isPrimary && isCurrentPrimary) {
      task.primaryAssigneeId = null;
      await task.save();
      await logActivity(task._id, req.user._id, 'primary_changed', {
        primaryAssigneeId: null,
      });
    }

    res.status(200).json({ assignees: await assigneeList(task) });
  } catch (error) {
    res.status(500).json({ message: 'Không thể cập nhật người phụ trách' });
  }
});

// DELETE /api/tasks/:id/assignees/:userId - Hủy giao việc cho một người
router.delete('/:userId', requireManage, async (req, res) => {
  try {
    const task = req.task;
    const { userId } = req.params;

    if (!isObjectId(userId) || !task.assigneeIds.map(String).includes(userId)) {
      return res.status(404).json(NOT_ASSIGNEE);
    }

    const removed = await User.findById(userId).select('fullName');
    task.assigneeIds = task.assigneeIds.filter((id) => String(id) !== userId);

    // Người phụ trách chính bị gỡ thì chuyển cho người còn lại đầu tiên (nếu có)
    if (String(task.primaryAssigneeId) === userId) {
      task.primaryAssigneeId = task.assigneeIds.length > 0 ? task.assigneeIds[0] : null;
    }
    await task.save();

    await logActivity(task._id, req.user._id, 'unassigned', {
      user: { id: userId, fullName: removed ? removed.fullName : null },
    });

    res.status(200).json({ assignees: await assigneeList(task) });
  } catch (error) {
    res.status(500).json({ message: 'Không thể hủy giao việc' });
  }
});

module.exports = router;
