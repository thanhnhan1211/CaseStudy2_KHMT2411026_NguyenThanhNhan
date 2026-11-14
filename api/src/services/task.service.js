const Task = require('../models/task.model');
const TaskShare = require('../models/taskShare.model');
const TaskActivity = require('../models/taskActivity.model');
const { isObjectId } = require('../validators/task.validator');

const USER_FIELDS = 'fullName email avatarUrl';
const PRIORITY_RANK = { low: 1, medium: 2, high: 3 };

const idOf = (value) => String(value && value._id ? value._id : value);

/**
 * Quyền của một người trên một công việc:
 *  - owner    (người tạo)           : xem, sửa, đổi trạng thái, xóa
 *  - editor   (chia sẻ quyền sửa)   : xem, sửa, đổi trạng thái (KHÔNG xóa)
 *  - assignee (người được giao)     : xem, đổi trạng thái
 *  - viewer   (chia sẻ quyền xem)   : chỉ xem
 */
function computeAccess(task, userId, sharePermission) {
  const uid = String(userId);
  const isOwner = idOf(task.createdBy) === uid;
  const isAssignee = (task.assigneeIds || []).some((a) => idOf(a) === uid);
  const isEditor = sharePermission === 'editor';
  const isViewer = sharePermission === 'viewer';

  return {
    canView: isOwner || isAssignee || isEditor || isViewer,
    myRole: isOwner
      ? 'owner'
      : isEditor
      ? 'editor'
      : isAssignee
      ? 'assignee'
      : isViewer
      ? 'viewer'
      : null,
    permissions: {
      canEdit: isOwner || isEditor,
      canChangeStatus: isOwner || isEditor || isAssignee,
      canDelete: isOwner,
      // giao việc + quản lý chia sẻ: chỉ người tạo
      canManage: isOwner,
    },
  };
}

function serializeTask(task, access) {
  const obj = task.toObject ? task.toObject() : { ...task };
  delete obj.__v;
  return { ...obj, myRole: access.myRole, permissions: access.permissions };
}

function populateTask(taskOrQuery) {
  return taskOrQuery.populate([
    { path: 'createdBy', select: USER_FIELDS },
    { path: 'assigneeIds', select: USER_FIELDS },
    { path: 'primaryAssigneeId', select: USER_FIELDS },
  ]);
}

// Trả về { task, access } nếu người dùng được xem; ngược lại trả null
// (cố ý không phân biệt "không tồn tại" và "không có quyền" để không lộ dữ liệu)
async function findAccessibleTask(taskId, userId) {
  if (!isObjectId(String(taskId))) return null;

  const task = await Task.findById(taskId);
  if (!task) return null;

  const share = await TaskShare.findOne({ taskId: task._id, userId });
  const access = computeAccess(task, userId, share && share.permission);
  if (!access.canView) return null;

  return { task, access };
}

function escapeRegex(text) {
  return text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

const timeOf = (date) => (date ? new Date(date).getTime() : null);

function sortTasks(tasks, sortBy = 'createdAt', order) {
  const defaultOrder = { dueDate: 'asc', priority: 'desc', createdAt: 'desc' };
  const dir = (order || defaultOrder[sortBy]) === 'asc' ? 1 : -1;

  const byCreated = (a, b) => timeOf(b.createdAt) - timeOf(a.createdAt);

  return [...tasks].sort((a, b) => {
    if (sortBy === 'dueDate') {
      const ta = timeOf(a.dueDate);
      const tb = timeOf(b.dueDate);
      if (ta === null && tb === null) return byCreated(a, b);
      if (ta === null) return 1; // không có hạn luôn xếp cuối
      if (tb === null) return -1;
      return ta === tb ? byCreated(a, b) : (ta - tb) * dir;
    }
    if (sortBy === 'priority') {
      const diff = PRIORITY_RANK[a.priority] - PRIORITY_RANK[b.priority];
      return diff === 0 ? byCreated(a, b) : diff * dir;
    }
    return (timeOf(a.createdAt) - timeOf(b.createdAt)) * dir;
  });
}

async function listTasks(userId, query) {
  const shares = await TaskShare.find({ userId })
    .select('taskId permission')
    .lean();
  const shareMap = new Map(shares.map((s) => [String(s.taskId), s.permission]));

  const scopes = {
    created: { createdBy: userId },
    assigned: { assigneeIds: userId },
    shared: { _id: { $in: shares.map((s) => s.taskId) } },
  };
  const scopeFilter = scopes[query.scope] || { $or: Object.values(scopes) };

  const and = [scopeFilter];
  if (query.status) and.push({ status: query.status });
  if (query.priority) and.push({ priority: query.priority });
  if (query.assigneeId) and.push({ assigneeIds: query.assigneeId });
  if (query.q && query.q.trim()) {
    and.push({
      title: { $regex: escapeRegex(query.q.trim()), $options: 'i' },
    });
  }

  const tasks = await populateTask(Task.find({ $and: and }));
  const sorted = sortTasks(tasks, query.sortBy, query.order);

  return sorted.map((task) =>
    serializeTask(
      task,
      computeAccess(task, userId, shareMap.get(String(task._id)))
    )
  );
}

// Ghi lịch sử hoạt động; lỗi ghi log không làm hỏng thao tác chính
async function logActivity(taskId, userId, action, details = {}) {
  try {
    await TaskActivity.create({ taskId, userId, action, details });
  } catch (error) {
    console.error('Không ghi được lịch sử hoạt động:', error.message);
  }
}

async function deleteTaskCascade(task) {
  await TaskShare.deleteMany({ taskId: task._id });
  await TaskActivity.deleteMany({ taskId: task._id });
  await Task.deleteOne({ _id: task._id });
}

module.exports = {
  USER_FIELDS,
  idOf,
  escapeRegex,
  computeAccess,
  serializeTask,
  populateTask,
  findAccessibleTask,
  listTasks,
  sortTasks,
  logActivity,
  deleteTaskCascade,
};
