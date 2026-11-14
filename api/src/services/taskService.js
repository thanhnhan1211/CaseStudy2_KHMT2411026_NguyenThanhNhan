const Task = require('../models/Task');
const TaskShare = require('../models/TaskShare');
const TaskActivity = require('../models/TaskActivity');

/**
 * Lấy danh sách công việc có phân loại scope, tìm kiếm, lọc và sắp xếp
 */
const getTasksForUser = async (userId, queryParams) => {
  const {
    scope, // created | assigned | shared
    status, // todo | in_progress | completed
    priority, // low | medium | high
    assigneeId, // lọc theo người phụ trách
    q, // từ khóa tìm kiếm theo tên
    sortBy = 'createdAt', // dueDate | priority | createdAt
    order = 'desc', // asc | desc
  } = queryParams;

  // Lấy danh sách taskId được chia sẻ cho user
  const sharedRecords = await TaskShare.find({ userId }).select('taskId');
  const sharedTaskIds = sharedRecords.map((s) => s.taskId);

  // Xây dựng điều kiện quyền truy cập theo scope
  let scopeFilter = {};
  if (scope === 'created') {
    scopeFilter = { createdBy: userId };
  } else if (scope === 'assigned') {
    scopeFilter = { assigneeIds: userId };
  } else if (scope === 'shared') {
    scopeFilter = { _id: { $in: sharedTaskIds } };
  } else {
    // Mặc định: tất cả công việc liên quan (tạo, được giao, được chia sẻ)
    scopeFilter = {
      $or: [
        { createdBy: userId },
        { assigneeIds: userId },
        { _id: { $in: sharedTaskIds } },
      ],
    };
  }

  const filter = { ...scopeFilter };

  if (status) filter.status = status;
  if (priority) filter.priority = priority;
  if (assigneeId) filter.assigneeIds = assigneeId;
  if (q && q.trim()) {
    filter.title = { $regex: q.trim(), $options: 'i' };
  }

  // Xử lý sắp xếp
  const sortDirection = order === 'asc' ? 1 : -1;
  const allowedSortFields = ['dueDate', 'priority', 'createdAt', 'updatedAt'];
  const sortField = allowedSortFields.includes(sortBy) ? sortBy : 'createdAt';

  // Nếu sắp xếp theo priority (low < medium < high), dùng aggregation để map trọng số
  if (sortField === 'priority') {
    const tasks = await Task.aggregate([
      { $match: filter },
      {
        $addFields: {
          priorityWeight: {
            $switch: {
              branches: [
                { case: { $eq: ['$priority', 'high'] }, then: 3 },
                { case: { $eq: ['$priority', 'medium'] }, then: 2 },
                { case: { $eq: ['$priority', 'low'] }, then: 1 },
              ],
              default: 0,
            },
          },
        },
      },
      { $sort: { priorityWeight: sortDirection, createdAt: -1 } },
      { $project: { priorityWeight: 0 } },
    ]);
    return Task.populate(tasks, [
      { path: 'createdBy', select: 'fullName email avatarUrl' },
      { path: 'assigneeIds', select: 'fullName email avatarUrl' },
      { path: 'primaryAssigneeId', select: 'fullName email avatarUrl' },
    ]);
  }

  return Task.find(filter)
    .populate('createdBy', 'fullName email avatarUrl')
    .populate('assigneeIds', 'fullName email avatarUrl')
    .populate('primaryAssigneeId', 'fullName email avatarUrl')
    .sort({ [sortField]: sortDirection });
};

/**
 * Tạo công việc mới và ghi log hoạt động
 */
const createTask = async (userId, data) => {
  const task = await Task.create({
    title: data.title.trim(),
    description: data.description || '',
    createdBy: userId,
    assigneeIds: data.assigneeIds || [],
    primaryAssigneeId: data.primaryAssigneeId || null,
    startDate: data.startDate || null,
    dueDate: data.dueDate || null,
    priority: data.priority || 'medium',
    status: data.status || 'todo',
  });

  await TaskActivity.create({
    taskId: task._id,
    userId,
    action: 'create_task',
    details: { title: task.title, priority: task.priority, status: task.status },
  });

  return task.populate([
    { path: 'createdBy', select: 'fullName email avatarUrl' },
    { path: 'assigneeIds', select: 'fullName email avatarUrl' },
    { path: 'primaryAssigneeId', select: 'fullName email avatarUrl' },
  ]);
};

/**
 * Lấy chi tiết công việc
 */
const getTaskById = async (taskId) => {
  return Task.findById(taskId)
    .populate('createdBy', 'fullName email avatarUrl')
    .populate('assigneeIds', 'fullName email avatarUrl')
    .populate('primaryAssigneeId', 'fullName email avatarUrl');
};

/**
 * Cập nhật thông tin công việc và lưu lịch sử thay đổi
 */
const updateTask = async (task, userId, updates) => {
  const allowedFields = ['title', 'description', 'startDate', 'dueDate', 'priority', 'status'];
  const changes = {};

  allowedFields.forEach((field) => {
    if (updates[field] !== undefined) {
      changes[field] = { from: task[field], to: updates[field] };
      task[field] = updates[field];
    }
  });

  await task.save();

  if (Object.keys(changes).length > 0) {
    await TaskActivity.create({
      taskId: task._id,
      userId,
      action: 'update_task',
      details: changes,
    });
  }

  return task.populate([
    { path: 'createdBy', select: 'fullName email avatarUrl' },
    { path: 'assigneeIds', select: 'fullName email avatarUrl' },
    { path: 'primaryAssigneeId', select: 'fullName email avatarUrl' },
  ]);
};

/**
 * Cập nhật nhanh trạng thái công việc
 */
const updateTaskStatus = async (task, userId, newStatus) => {
  const oldStatus = task.status;
  task.status = newStatus;
  await task.save();

  if (oldStatus !== newStatus) {
    await TaskActivity.create({
      taskId: task._id,
      userId,
      action: 'update_status',
      details: { from: oldStatus, to: newStatus },
    });
  }

  return task;
};

/**
 * Xóa công việc cùng các dữ liệu liên quan
 */
const deleteTask = async (taskId) => {
  await Promise.all([
    Task.findByIdAndDelete(taskId),
    TaskShare.deleteMany({ taskId }),
    TaskActivity.deleteMany({ taskId }),
  ]);
};

/**
 * Lấy lịch sử hoạt động của công việc
 */
const getTaskActivities = async (taskId) => {
  return TaskActivity.find({ taskId })
    .populate('userId', 'fullName email avatarUrl')
    .sort({ createdAt: -1 });
};

module.exports = {
  getTasksForUser,
  createTask,
  getTaskById,
  updateTask,
  updateTaskStatus,
  deleteTask,
  getTaskActivities,
};
