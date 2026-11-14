const express = require('express');

const TaskShare = require('../models/taskShare.model');
const authMiddleware = require('../middleware/auth.middleware');
const { loadTask, requireManage } = require('../middleware/permission.middleware');
const { isObjectId } = require('../validators/task.validator');
const { validateTargets, validatePermission } = require('../validators/share.validator');
const { resolveTargets } = require('../services/user.service');
const { USER_FIELDS, logActivity } = require('../services/task.service');

// Gắn vào /api/tasks/:id/shares
const router = express.Router({ mergeParams: true });

router.use(authMiddleware, loadTask);

async function shareList(taskId) {
  const shares = await TaskShare.find({ taskId })
    .sort({ createdAt: 1 })
    .populate('userId', USER_FIELDS)
    .populate('sharedBy', USER_FIELDS)
    .lean();

  return shares.map((s) => ({
    _id: s._id,
    user: s.userId,
    permission: s.permission,
    sharedBy: s.sharedBy,
    createdAt: s.createdAt,
  }));
}

async function findShare(req) {
  if (!isObjectId(req.params.shareId)) return null;
  return TaskShare.findOne({ _id: req.params.shareId, taskId: req.task._id });
}

const NOT_FOUND_SHARE = { message: 'Không tìm thấy bản ghi chia sẻ' };

// GET /api/tasks/:id/shares - ai có quyền xem công việc đều xem được danh sách
router.get('/', async (req, res) => {
  try {
    res.status(200).json({ shares: await shareList(req.task._id) });
  } catch (error) {
    res.status(500).json({ message: 'Không thể lấy danh sách chia sẻ' });
  }
});

// POST /api/tasks/:id/shares  { userIds?, emails?, permission }
router.post('/', requireManage, async (req, res) => {
  try {
    const task = req.task;

    const permissionError = validatePermission(req.body.permission);
    if (permissionError) return res.status(400).json({ message: permissionError });

    const targets = validateTargets(req.body);
    if (targets.error) return res.status(400).json({ message: targets.error });

    const resolved = await resolveTargets(targets);
    if (resolved.error) {
      return res.status(resolved.status).json({ message: resolved.error });
    }

    if (resolved.users.some((u) => String(u._id) === String(task.createdBy))) {
      return res
        .status(400)
        .json({ message: 'Không cần chia sẻ cho người tạo công việc' });
    }

    const existing = await TaskShare.find({
      taskId: task._id,
      userId: { $in: resolved.users.map((u) => u._id) },
    });
    const existingMap = new Map(existing.map((s) => [String(s.userId), s]));

    let createdCount = 0;
    for (const user of resolved.users) {
      const share = existingMap.get(String(user._id));

      if (!share) {
        try {
          await TaskShare.create({
            taskId: task._id,
            userId: user._id,
            permission: req.body.permission,
            sharedBy: req.user._id,
          });
          createdCount += 1;
          await logActivity(task._id, req.user._id, 'shared', {
            user: { id: user._id, fullName: user.fullName },
            permission: req.body.permission,
          });
        } catch (error) {
          if (!(error && error.code === 11000)) throw error; // trùng do gửi đồng thời
        }
      } else if (share.permission !== req.body.permission) {
        const from = share.permission;
        share.permission = req.body.permission;
        await share.save();
        await logActivity(task._id, req.user._id, 'share_updated', {
          user: { id: user._id, fullName: user.fullName },
          from,
          to: share.permission,
        });
      }
    }

    res
      .status(createdCount > 0 ? 201 : 200)
      .json({ shares: await shareList(task._id) });
  } catch (error) {
    res.status(500).json({ message: 'Không thể chia sẻ công việc' });
  }
});

// PATCH /api/tasks/:id/shares/:shareId  { permission }
router.patch('/:shareId', requireManage, async (req, res) => {
  try {
    const permissionError = validatePermission(req.body.permission);
    if (permissionError) return res.status(400).json({ message: permissionError });

    const share = await findShare(req);
    if (!share) return res.status(404).json(NOT_FOUND_SHARE);

    if (share.permission !== req.body.permission) {
      const from = share.permission;
      share.permission = req.body.permission;
      await share.save();
      await logActivity(req.task._id, req.user._id, 'share_updated', {
        user: { id: share.userId },
        from,
        to: share.permission,
      });
    }

    res.status(200).json({ shares: await shareList(req.task._id) });
  } catch (error) {
    res.status(500).json({ message: 'Không thể đổi quyền chia sẻ' });
  }
});

// DELETE /api/tasks/:id/shares/:shareId - Thu hồi quyền
router.delete('/:shareId', requireManage, async (req, res) => {
  try {
    const share = await findShare(req);
    if (!share) return res.status(404).json(NOT_FOUND_SHARE);

    await TaskShare.deleteOne({ _id: share._id });
    await logActivity(req.task._id, req.user._id, 'share_revoked', {
      user: { id: share.userId },
      permission: share.permission,
    });

    res.status(200).json({ shares: await shareList(req.task._id) });
  } catch (error) {
    res.status(500).json({ message: 'Không thể thu hồi quyền chia sẻ' });
  }
});

module.exports = router;
