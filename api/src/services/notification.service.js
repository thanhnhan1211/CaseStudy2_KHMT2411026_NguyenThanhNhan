const Notification = require('../models/notification.model');
const TaskShare = require('../models/taskShare.model');
const User = require('../models/user.model');
const { idOf } = require('./task.service');
const { buildInApp } = require('../utils/emailTemplates');
const { queueEmail } = require('./email.service');

// Tạo thông báo trong ứng dụng (+ email nếu sendEmail = true) cho từng người nhận.
// Người thực hiện thao tác (actor) không bao giờ nhận thông báo của chính mình.
// Lỗi ở đây không được làm hỏng thao tác chính.
async function dispatch({ type, task, actor, recipientIds, data = {}, sendEmail = false }) {
  try {
    const ids = [...new Set(recipientIds.map(String))].filter(
      (id) => !actor || id !== String(actor._id)
    );
    if (ids.length === 0) return;

    const users = await User.find({ _id: { $in: ids } }).select('fullName email');
    if (users.length === 0) return;

    const payload = {
      actorName: actor ? actor.fullName : '',
      taskTitle: task.title,
      ...data,
    };
    const { title, message } = buildInApp(type, payload);

    await Notification.insertMany(
      users.map((u) => ({ userId: u._id, taskId: task._id, type, title, message }))
    );

    if (sendEmail) {
      for (const user of users) {
        await queueEmail({ type, taskId: task._id, recipient: user, data: payload });
      }
    }
  } catch (error) {
    console.error('Không thể tạo thông báo:', error.message);
  }
}

// Người tạo + người được giao + người được chia sẻ
async function getParticipantIds(task) {
  const shares = await TaskShare.find({ taskId: task._id }).select('userId').lean();
  return [
    idOf(task.createdBy),
    ...task.assigneeIds.map(idOf),
    ...shares.map((s) => String(s.userId)),
  ];
}

const iso = (value) => (value ? new Date(value).toISOString() : null);

const notifyAssigned = (task, actor, users) =>
  dispatch({
    type: 'task_assigned',
    task,
    actor,
    recipientIds: users.map((u) => u._id),
    data: { dueDate: iso(task.dueDate) },
    sendEmail: true,
  });

const notifyShared = (task, actor, users, permission) =>
  dispatch({
    type: 'task_shared',
    task,
    actor,
    recipientIds: users.map((u) => u._id),
    data: { permission, dueDate: iso(task.dueDate) },
    sendEmail: true,
  });

// Đổi quyền chia sẻ: chỉ thông báo trong ứng dụng, không gửi email
const notifyShareUpdated = (task, actor, userIds, permission) =>
  dispatch({
    type: 'share_updated',
    task,
    actor,
    recipientIds: userIds,
    data: { permission },
    sendEmail: false,
  });

async function notifyDueDateChange(task, actor, oldDueDate, newDueDate) {
  await dispatch({
    type: 'due_date_changed',
    task,
    actor,
    recipientIds: await getParticipantIds(task),
    data: { oldDueDate: iso(oldDueDate), dueDate: iso(newDueDate) },
    sendEmail: true,
  });
}

// Hoàn thành: thông báo + email. Đổi trạng thái khác: chỉ thông báo trong ứng dụng.
async function notifyStatusChange(task, actor, from, to) {
  const completed = to === 'completed';
  await dispatch({
    type: completed ? 'task_completed' : 'status_changed',
    task,
    actor,
    recipientIds: await getParticipantIds(task),
    data: { from, to },
    sendEmail: completed,
  });
}

const notifyReminder = (task, recipientIds) =>
  dispatch({
    type: 'task_reminder',
    task,
    actor: null,
    recipientIds,
    data: { dueDate: iso(task.dueDate) },
    sendEmail: true,
  });

module.exports = {
  dispatch,
  notifyAssigned,
  notifyShared,
  notifyShareUpdated,
  notifyDueDateChange,
  notifyStatusChange,
  notifyReminder,
};
