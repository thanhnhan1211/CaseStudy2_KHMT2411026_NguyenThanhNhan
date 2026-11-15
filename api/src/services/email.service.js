const EmailLog = require('../models/emailLog.model');
const { isConfigured, getTransporter, getFrom } = require('../config/email');
const { buildEmail } = require('../utils/emailTemplates');

const MAX_ATTEMPTS = 3;

// Theo dõi các lần gửi đang chạy nền (để test chờ xong)
const inFlight = new Set();
function track(promise) {
  inFlight.add(promise);
  const done = () => inFlight.delete(promise);
  promise.then(done, done);
}
async function idle() {
  while (inFlight.size > 0) await Promise.allSettled([...inFlight]);
}

// Gửi một email theo bản ghi log. Chỉ một tiến trình "giành" được log đang pending,
// nên không bao giờ gửi trùng cùng một lần.
async function sendLog(logId) {
  const log = await EmailLog.findOneAndUpdate(
    { _id: logId, status: 'pending' },
    { $inc: { attempts: 1 } },
    { new: true }
  );
  if (!log) return null;

  try {
    if (!isConfigured()) {
      throw new Error('SMTP chưa được cấu hình (thiếu SMTP_HOST trong file .env)');
    }
    const { subject, text, html } = buildEmail(log.eventType, log.payload);
    await getTransporter().sendMail({
      from: getFrom(),
      to: log.recipientEmail,
      subject,
      text,
      html,
    });
    log.status = 'sent';
    log.sentAt = new Date();
    log.errorMessage = '';
  } catch (error) {
    log.status = 'failed';
    log.errorMessage = String((error && error.message) || error).slice(0, 300);
  }

  await log.save();
  return log;
}

// Ghi nhận yêu cầu gửi email rồi gửi ở nền (không làm chậm request)
async function queueEmail({ type, taskId, recipient, data }) {
  const { subject } = buildEmail(type, data);
  const log = await EmailLog.create({
    taskId,
    recipientId: recipient._id,
    recipientEmail: recipient.email,
    eventType: type,
    subject,
    status: 'pending',
    attempts: 0,
    payload: data,
  });

  track(
    sendLog(log._id).catch((error) =>
      console.error('Lỗi khi gửi email:', error.message)
    )
  );
  return log;
}

// Thử gửi lại một email thất bại (tối đa MAX_ATTEMPTS lần). Trả về null nếu không đủ điều kiện.
async function retryEmail(logId) {
  const log = await EmailLog.findOneAndUpdate(
    { _id: logId, status: 'failed', attempts: { $lt: MAX_ATTEMPTS } },
    { $set: { status: 'pending', errorMessage: '' } },
    { new: true }
  );
  if (!log) return null;
  return sendLog(log._id);
}

module.exports = { MAX_ATTEMPTS, queueEmail, sendLog, retryEmail, idle };
