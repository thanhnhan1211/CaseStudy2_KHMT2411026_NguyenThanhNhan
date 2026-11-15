const Task = require('../models/task.model');
const { notifyReminder } = require('../services/notification.service');

// Nhắc các công việc chưa hoàn thành sẽ đến hạn trong REMINDER_HOURS giờ tới.
// Mỗi hạn chỉ nhắc một lần: đổi hạn mới thì được nhắc lại.
async function runReminders(now = new Date()) {
  const hours = Number(process.env.REMINDER_HOURS) || 24;
  const until = new Date(now.getTime() + hours * 60 * 60 * 1000);

  const candidates = await Task.find({
    status: { $ne: 'completed' },
    dueDate: { $gt: now, $lte: until },
  });

  let reminded = 0;
  for (const task of candidates) {
    // "Giành" quyền nhắc một cách nguyên tử để không nhắc trùng
    const claimed = await Task.findOneAndUpdate(
      {
        _id: task._id,
        status: { $ne: 'completed' },
        dueDate: task.dueDate,
        reminderSentFor: { $ne: task.dueDate },
      },
      { $set: { reminderSentFor: task.dueDate } }
    );
    if (!claimed) continue;

    const recipients =
      task.assigneeIds.length > 0 ? task.assigneeIds : [task.createdBy];
    await notifyReminder(task, recipients);
    reminded += 1;
  }
  return reminded;
}

function startReminderJob() {
  if (process.env.REMINDER_ENABLED === 'false') {
    console.log('Nhắc việc tự động: đã tắt');
    return;
  }

  const minutes = Number(process.env.REMINDER_INTERVAL_MINUTES) || 60;
  const run = () =>
    runReminders().catch((error) =>
      console.error('Lỗi tác vụ nhắc việc:', error.message)
    );

  setTimeout(run, 10 * 1000).unref();
  setInterval(run, minutes * 60 * 1000).unref();
  console.log(`Nhắc việc tự động: kiểm tra mỗi ${minutes} phút`);
}

module.exports = { runReminders, startReminderJob };
