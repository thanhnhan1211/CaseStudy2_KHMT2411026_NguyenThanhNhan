const Task = require('../models/task.model');
const { buildScopeFilter } = require('./task.service');

const STATUSES = ['todo', 'in_progress', 'completed'];
const PRIORITIES = ['low', 'medium', 'high'];
const DAY_MS = 24 * 60 * 60 * 1000;
const LIST_LIMIT = 20; // số công việc tối đa trả về trong mỗi danh sách hạn

// Đếm số công việc theo một trường, luôn đủ các khóa (giá trị 0 nếu không có)
async function countBy(filter, field, keys) {
  const rows = await Task.aggregate([
    { $match: filter },
    { $group: { _id: `$${field}`, count: { $sum: 1 } } },
  ]);
  const result = Object.fromEntries(keys.map((k) => [k, 0]));
  for (const row of rows) {
    if (row._id in result) result[row._id] = row.count;
  }
  return result;
}

const sum = (counts) => Object.values(counts).reduce((a, b) => a + b, 0);

// { total, active (chưa hoàn thành), byStatus }
async function statusBreakdown(filter) {
  const byStatus = await countBy(filter, 'status', STATUSES);
  const total = sum(byStatus);
  return { total, active: total - byStatus.completed, byStatus };
}

// Thống kê theo trạng thái và mức độ ưu tiên
async function taskStatistics(userId, scope) {
  const { scopeFilter } = await buildScopeFilter(userId, scope);
  const [byStatus, byPriority] = await Promise.all([
    countBy(scopeFilter, 'status', STATUSES),
    countBy(scopeFilter, 'priority', PRIORITIES),
  ]);
  const total = sum(byStatus);
  const completionRate =
    total === 0 ? 0 : Math.round((byStatus.completed / total) * 1000) / 10;

  return { scope: scope || 'all', total, byStatus, byPriority, completionRate };
}

// Việc được giao cho tôi, việc tôi phụ trách chính, việc tôi đã giao cho người khác
async function assignmentStatistics(userId) {
  const [assignedToMe, primaryResponsible, assignedByMe] = await Promise.all([
    statusBreakdown({ assigneeIds: userId }),
    statusBreakdown({ primaryAssigneeId: userId }),
    statusBreakdown({
      createdBy: userId,
      assigneeIds: { $elemMatch: { $ne: userId } },
    }),
  ]);
  return { assignedToMe, primaryResponsible, assignedByMe };
}

const summary = (task) => ({
  _id: task._id,
  title: task.title,
  status: task.status,
  priority: task.priority,
  dueDate: task.dueDate,
});

// Việc sắp đến hạn (trong `days` ngày tới) và việc đã quá hạn. Việc đã hoàn thành không tính.
async function deadlineStatistics(userId, { scope, days = 7, now = new Date() } = {}) {
  const { scopeFilter } = await buildScopeFilter(userId, scope);
  const until = new Date(now.getTime() + days * DAY_MS);
  const open = { status: { $ne: 'completed' } };

  const dueSoonFilter = { $and: [scopeFilter, open, { dueDate: { $gte: now, $lte: until } }] };
  const overdueFilter = { $and: [scopeFilter, open, { dueDate: { $lt: now } }] };
  const noDueFilter = { $and: [scopeFilter, open, { dueDate: null }] };

  const list = (filter) =>
    Task.find(filter)
      .select('title status priority dueDate')
      .sort({ dueDate: 1, _id: 1 })
      .limit(LIST_LIMIT)
      .lean();

  const [dueSoonCount, dueSoon, overdueCount, overdue, noDueDate] = await Promise.all([
    Task.countDocuments(dueSoonFilter),
    list(dueSoonFilter),
    Task.countDocuments(overdueFilter),
    list(overdueFilter),
    Task.countDocuments(noDueFilter),
  ]);

  return {
    scope: scope || 'all',
    days,
    dueSoon: { count: dueSoonCount, tasks: dueSoon.map(summary) },
    overdue: { count: overdueCount, tasks: overdue.map(summary) },
    noDueDate,
  };
}

module.exports = {
  LIST_LIMIT,
  taskStatistics,
  assignmentStatistics,
  deadlineStatistics,
};
