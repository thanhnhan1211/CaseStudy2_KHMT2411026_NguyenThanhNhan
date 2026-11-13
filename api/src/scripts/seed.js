// Tạo dữ liệu mẫu: npm run seed
const mongoose = require('mongoose');
const dotenv = require('dotenv');
const Task = require('../models/task.model');

dotenv.config();

const samples = [
  { title: 'Học Flutter', description: 'Tìm hiểu REST API', category: 'Study', priority: 'High', status: 'Pending' },
  { title: 'Làm bài tập', description: 'Hoàn thành bài thực hành Flutter', category: 'Study', priority: 'Medium', status: 'InProgress' },
  { title: 'Hoàn thành báo cáo', description: 'Viết báo cáo Case Study 2', category: 'Project', priority: 'High', status: 'Pending' },
];

(async () => {
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    await Task.insertMany(samples);
    console.log(`Đã thêm ${samples.length} công việc mẫu`);
  } catch (error) {
    console.error('Seed error:', error);
  } finally {
    await mongoose.disconnect();
  }
})();
