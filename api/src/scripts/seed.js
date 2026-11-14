// Tạo công việc mẫu cho MỘT TÀI KHOẢN ĐÃ ĐĂNG KÝ:
//   npm run seed -- email@cua-ban.com
const mongoose = require('mongoose');
const dotenv = require('dotenv');
const User = require('../models/user.model');
const Task = require('../models/task.model');

dotenv.config();

const day = 24 * 60 * 60 * 1000;
const inDays = (n) => new Date(Date.now() + n * day);

(async () => {
  const email = (process.argv[2] || '').trim().toLowerCase();
  if (!email) {
    console.error('Cách dùng: npm run seed -- email@cua-ban.com');
    process.exit(1);
  }

  try {
    await mongoose.connect(process.env.MONGODB_URI);

    const user = await User.findOne({ email });
    if (!user) {
      console.error(`Chưa có tài khoản ${email}. Hãy đăng ký trong app trước.`);
      process.exitCode = 1;
      return;
    }

    const samples = [
      { title: 'Học Flutter', description: 'Tìm hiểu REST API', priority: 'high', status: 'todo', dueDate: inDays(3) },
      { title: 'Làm bài tập', description: 'Hoàn thành bài thực hành Flutter', priority: 'medium', status: 'in_progress', startDate: inDays(-1), dueDate: inDays(5) },
      { title: 'Hoàn thành báo cáo', description: 'Viết báo cáo Case Study 2', priority: 'high', status: 'todo', dueDate: inDays(-1) },
      { title: 'Dọn dẹp tài liệu', priority: 'low', status: 'completed' },
    ].map((t) => ({ ...t, createdBy: user._id }));

    await Task.insertMany(samples);
    console.log(`Đã thêm ${samples.length} công việc mẫu cho ${email}`);
  } catch (error) {
    console.error('Seed error:', error);
    process.exitCode = 1;
  } finally {
    await mongoose.disconnect();
  }
})();
