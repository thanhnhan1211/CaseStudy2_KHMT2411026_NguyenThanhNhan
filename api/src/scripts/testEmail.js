// Gửi thử một email để kiểm tra cấu hình SMTP:
//   npm run test-email -- ten@gmail.com
const dotenv = require('dotenv');
const { isConfigured, getTransporter, getFrom } = require('../config/email');

dotenv.config();

(async () => {
  const to = (process.argv[2] || '').trim();
  if (!to) {
    console.error('Cách dùng: npm run test-email -- email-nhan@example.com');
    process.exit(1);
  }
  if (!isConfigured()) {
    console.error('Chưa cấu hình SMTP: thêm SMTP_HOST (và SMTP_USER, SMTP_PASS) vào file .env');
    process.exit(1);
  }

  try {
    await getTransporter().sendMail({
      from: getFrom(),
      to,
      subject: '[Task Manager] Email thử nghiệm',
      text: 'Nếu bạn đọc được email này thì cấu hình SMTP đã đúng.',
    });
    console.log(`Đã gửi email thử tới ${to}`);
  } catch (error) {
    console.error('Gửi thất bại:', error.message);
    process.exitCode = 1;
  }
})();
