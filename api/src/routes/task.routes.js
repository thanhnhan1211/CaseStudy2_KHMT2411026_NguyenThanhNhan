const express = require('express');

const Task = require('../models/task.model');
const TaskActivity = require('../models/taskActivity.model');
const authMiddleware = require('../middleware/auth.middleware');
const {
  validateTaskInput,
  validateStatusInput,
  validateListQuery,
  checkDateOrder,
} = require('../validators/task.validator');
const {
  USER_FIELDS,
  serializeTask,
  populateTask,
  findAccessibleTask,
  listTasks,
  logActivity,
  deleteTaskCascade,
} = require('../services/task.service');
const {
  notifyDueDateChange,
  notifyStatusChange,
} = require('../services/notification.service');

const router = express.Router();

// Mọi API công việc đều cần đăng nhập
router.use(authMiddleware);

const NOT_FOUND = { message: 'Không tìm thấy công việc' };

const sameValue = (a, b) => {
  const va = a instanceof Date ? a.getTime() : a ?? null;
  const vb = b instanceof Date ? b.getTime() : b ?? null;
  return va === vb;
};

// GET /api/tasks?scope=&status=&priority=&q=&assigneeId=&sortBy=&order=
router.get('/', async (req, res) => {
  try {
    const error = validateListQuery(req.query);
    if (error) return res.status(400).json({ message: error });

    const tasks = await listTasks(req.user._id, req.query);
    res.status(200).json({ count: tasks.length, tasks });
  } catch (error) {
    res.status(500).json({ message: 'Không thể lấy danh sách công việc' });
  }
});

// POST /api/tasks - Tạo công việc
router.post('/', async (req, res) => {
  try {
    const { error, data } = validateTaskInput(req.body);
    if (error) return res.status(400).json({ message: error });

    const dateError = checkDateOrder(data.startDate, data.dueDate);
    if (dateError) return res.status(400).json({ message: dateError });

    const task = await Task.create({ ...data, createdBy: req.user._id });
    await logActivity(task._id, req.user._id, 'created', {
      title: task.title,
    });

    await populateTask(task);
    res.status(201).json({
      task: serializeTask(task, {
        myRole: 'owner',
        permissions: {
          canEdit: true,
          canChangeStatus: true,
          canDelete: true,
          canManage: true,
        },
      }),
    });
  } catch (error) {
    res.status(500).json({ message: 'Không thể tạo công việc' });
  }
});

// GET /api/tasks/:id - Chi tiết
router.get('/:id', async (req, res) => {
  try {
    const found = await findAccessibleTask(req.params.id, req.user._id);
    if (!found) return res.status(404).json(NOT_FOUND);

    await populateTask(found.task);
    res.status(200).json({ task: serializeTask(found.task, found.access) });
  } catch (error) {
    res.status(500).json({ message: 'Không thể lấy chi tiết công việc' });
  }
});

// PUT /api/tasks/:id - Cập nhật thông tin (owner hoặc editor)
router.put('/:id', async (req, res) => {
  try {
    const found = await findAccessibleTask(req.params.id, req.user._id);
    if (!found) return res.status(404).json(NOT_FOUND);

    const { task, access } = found;
    if (!access.permissions.canEdit) {
      return res
        .status(403)
        .json({ message: 'Bạn không có quyền chỉnh sửa công việc này' });
    }

    const { error, data } = validateTaskInput(req.body, { partial: true });
    if (error) return res.status(400).json({ message: error });

    const startDate =
      data.startDate !== undefined ? data.startDate : task.startDate;
    const dueDate = data.dueDate !== undefined ? data.dueDate : task.dueDate;
    const dateError = checkDateOrder(startDate, dueDate);
    if (dateError) return res.status(400).json({ message: dateError });

    const changes = {};
    for (const [field, value] of Object.entries(data)) {
      if (!sameValue(task[field], value)) {
        changes[field] = { from: task[field], to: value };
        task[field] = value;
      }
    }

    if (Object.keys(changes).length > 0) {
      await task.save();
      await logActivity(task._id, req.user._id, 'updated', { changes });

      if (changes.dueDate) {
        await notifyDueDateChange(
          task,
          req.user,
          changes.dueDate.from,
          changes.dueDate.to
        );
      }
      if (changes.status) {
        await notifyStatusChange(task, req.user, changes.status.from, changes.status.to);
      }
    }

    await populateTask(task);
    res.status(200).json({ task: serializeTask(task, access) });
  } catch (error) {
    res.status(500).json({ message: 'Không thể cập nhật công việc' });
  }
});

// PATCH /api/tasks/:id/status - Đổi trạng thái (owner, editor hoặc người được giao)
router.patch('/:id/status', async (req, res) => {
  try {
    const found = await findAccessibleTask(req.params.id, req.user._id);
    if (!found) return res.status(404).json(NOT_FOUND);

    const { task, access } = found;
    if (!access.permissions.canChangeStatus) {
      return res
        .status(403)
        .json({ message: 'Bạn không có quyền đổi trạng thái công việc này' });
    }

    const error = validateStatusInput(req.body);
    if (error) return res.status(400).json({ message: error });

    if (task.status !== req.body.status) {
      const from = task.status;
      task.status = req.body.status;
      await task.save();
      await logActivity(task._id, req.user._id, 'status_changed', {
        from,
        to: task.status,
      });
      await notifyStatusChange(task, req.user, from, task.status);
    }

    await populateTask(task);
    res.status(200).json({ task: serializeTask(task, access) });
  } catch (error) {
    res.status(500).json({ message: 'Không thể cập nhật trạng thái' });
  }
});

// DELETE /api/tasks/:id - Chỉ người tạo được xóa
router.delete('/:id', async (req, res) => {
  try {
    const found = await findAccessibleTask(req.params.id, req.user._id);
    if (!found) return res.status(404).json(NOT_FOUND);

    if (!found.access.permissions.canDelete) {
      return res
        .status(403)
        .json({ message: 'Chỉ người tạo mới được xóa công việc' });
    }

    await deleteTaskCascade(found.task);
    res.status(200).json({ message: 'Đã xóa công việc' });
  } catch (error) {
    res.status(500).json({ message: 'Không thể xóa công việc' });
  }
});

// GET /api/tasks/:id/activities - Lịch sử hoạt động
router.get('/:id/activities', async (req, res) => {
  try {
    const found = await findAccessibleTask(req.params.id, req.user._id);
    if (!found) return res.status(404).json(NOT_FOUND);

    const activities = await TaskActivity.find({ taskId: found.task._id })
      .sort({ createdAt: -1 })
      .limit(100)
      .populate('userId', USER_FIELDS)
      .lean();

    res.status(200).json({ activities });
  } catch (error) {
    res.status(500).json({ message: 'Không thể lấy lịch sử hoạt động' });
  }
});

module.exports = router;
