const nodemailer = require('nodemailer');

let transporter = null;
let override = null; // dùng cho kiểm thử

// Đã cấu hình SMTP trong .env chưa
function isConfigured() {
  return Boolean(override || process.env.SMTP_HOST);
}

function getTransporter() {
  if (override) return override;

  if (!transporter) {
    const port = Number(process.env.SMTP_PORT) || 587;
    transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST,
      port,
      secure: process.env.SMTP_SECURE === 'true', // true cho cổng 465
      auth: process.env.SMTP_USER
        ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS }
        : undefined,
      connectionTimeout: 10000,
      greetingTimeout: 10000,
      socketTimeout: 15000,
    });
  }
  return transporter;
}

function getFrom() {
  return (
    process.env.MAIL_FROM ||
    `Task Manager <${process.env.SMTP_USER || 'no-reply@taskmanager.local'}>`
  );
}

// Chỉ dùng trong test: thay bộ gửi mail bằng đối tượng giả
function setTransporterForTests(fake) {
  override = fake;
}

module.exports = { isConfigured, getTransporter, getFrom, setTransporterForTests };
