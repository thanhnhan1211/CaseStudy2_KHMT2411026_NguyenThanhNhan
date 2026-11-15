const express = require('express');
const mongoose = require('mongoose');
const dotenv = require('dotenv');

dotenv.config();

if (!process.env.JWT_SECRET) {
  console.error('Thiếu JWT_SECRET trong file .env');
  process.exit(1);
}

const app = express();

app.use(express.json());

const authRoutes = require('./routes/auth.routes');
const userRoutes = require('./routes/user.routes');
const taskRoutes = require('./routes/task.routes');
const assignmentRoutes = require('./routes/assignment.routes');
const taskShareRoutes = require('./routes/taskShare.routes');
const notificationRoutes = require('./routes/notification.routes');
const statisticsRoutes = require('./routes/statistics.routes');
const { taskEmailLogRoutes, emailLogRoutes } = require('./routes/emailLog.routes');
const { startReminderJob } = require('./jobs/reminder.job');

app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
// Các route con của công việc phải đặt trước /api/tasks
app.use('/api/tasks/:id/assignees', assignmentRoutes);
app.use('/api/tasks/:id/shares', taskShareRoutes);
app.use('/api/tasks/:id/email-logs', taskEmailLogRoutes);
app.use('/api/email-logs', emailLogRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/statistics', statisticsRoutes);
app.use('/api/tasks', taskRoutes);

mongoose
  .connect(process.env.MONGODB_URI)
  .then(() => {
    console.log('MongoDB connected');
    startReminderJob();
  })
  .catch((error) => {
    console.error('MongoDB connection error:', error);
  });

app.get('/', (req, res) => {
  res.json({
    message: 'Task Manager API is running',
  });
});

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
