const { STATUSES, PRIORITIES } = require('../models/task.model');

const OBJECT_ID_REGEX = /^[0-9a-fA-F]{24}$/;
const SORT_FIELDS = ['dueDate', 'priority', 'createdAt'];
const SCOPES = ['all', 'created', 'assigned', 'shared'];

const isObjectId = (value) =>
  typeof value === 'string' && OBJECT_ID_REGEX.test(value);

// Trả về { ok, value }. null hoặc '' nghĩa là xóa ngày.
function parseDate(value) {
  if (value === null || value === '') return { ok: true, value: null };
  if (typeof value !== 'string') return { ok: false };
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return { ok: false };
  return { ok: true, value: date };
}

function checkDateOrder(startDate, dueDate) {
  if (startDate && dueDate && dueDate.getTime() < startDate.getTime()) {
    return 'Hạn hoàn thành không được trước ngày bắt đầu';
  }
  return null;
}

// Chỉ lấy các trường được phép (createdBy, assigneeIds... không được sửa ở đây)
// Trả về { error } hoặc { data }
function validateTaskInput(body = {}, { partial = false } = {}) {
  const data = {};

  if (body.title !== undefined || !partial) {
    if (typeof body.title !== 'string' || !body.title.trim()) {
      return { error: 'Tên công việc không được để trống' };
    }
    if (body.title.trim().length > 200) {
      return { error: 'Tên công việc không được quá 200 ký tự' };
    }
    data.title = body.title.trim();
  }

  if (body.description !== undefined) {
    if (body.description !== null && typeof body.description !== 'string') {
      return { error: 'Mô tả không hợp lệ' };
    }
    const description = (body.description || '').trim();
    if (description.length > 2000) {
      return { error: 'Mô tả không được quá 2000 ký tự' };
    }
    data.description = description;
  }

  if (body.priority !== undefined) {
    if (!PRIORITIES.includes(body.priority)) {
      return { error: 'Mức độ ưu tiên phải là low, medium hoặc high' };
    }
    data.priority = body.priority;
  }

  if (body.status !== undefined) {
    if (!STATUSES.includes(body.status)) {
      return { error: 'Trạng thái phải là todo, in_progress hoặc completed' };
    }
    data.status = body.status;
  }

  for (const [field, label] of [
    ['startDate', 'Ngày bắt đầu'],
    ['dueDate', 'Hạn hoàn thành'],
  ]) {
    if (body[field] !== undefined) {
      const parsed = parseDate(body[field]);
      if (!parsed.ok) return { error: `${label} không hợp lệ` };
      data[field] = parsed.value;
    }
  }

  if (partial && Object.keys(data).length === 0) {
    return { error: 'Không có thông tin nào để cập nhật' };
  }

  if (data.startDate !== undefined && data.dueDate !== undefined) {
    const error = checkDateOrder(data.startDate, data.dueDate);
    if (error) return { error };
  }

  return { data };
}

function validateStatusInput(body = {}) {
  if (!STATUSES.includes(body.status)) {
    return 'Trạng thái phải là todo, in_progress hoặc completed';
  }
  return null;
}

function validateListQuery(query = {}) {
  if (query.scope !== undefined && !SCOPES.includes(query.scope)) {
    return 'scope phải là all, created, assigned hoặc shared';
  }
  if (query.status !== undefined && !STATUSES.includes(query.status)) {
    return 'status không hợp lệ';
  }
  if (query.priority !== undefined && !PRIORITIES.includes(query.priority)) {
    return 'priority không hợp lệ';
  }
  if (query.assigneeId !== undefined && !isObjectId(query.assigneeId)) {
    return 'assigneeId không hợp lệ';
  }
  if (query.sortBy !== undefined && !SORT_FIELDS.includes(query.sortBy)) {
    return 'sortBy phải là dueDate, priority hoặc createdAt';
  }
  if (query.order !== undefined && !['asc', 'desc'].includes(query.order)) {
    return 'order phải là asc hoặc desc';
  }
  if (query.q !== undefined && typeof query.q !== 'string') {
    return 'q không hợp lệ';
  }
  return null;
}

module.exports = {
  isObjectId,
  checkDateOrder,
  validateTaskInput,
  validateStatusInput,
  validateListQuery,
};
