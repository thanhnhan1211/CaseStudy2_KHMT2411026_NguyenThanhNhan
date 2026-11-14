const taskService = require('../services/taskService');

const getTasks = async (req, res, next) => {
  try {
    const userId = req.user.id || req.user._id.toString();
    const tasks = await taskService.getTasksForUser(userId, req.query);
    res.status(200).json(tasks);
  } catch (error) {
    next(error);
  }
};

const createTask = async (req, res, next) => {
  try {
    const userId = req.user.id || req.user._id.toString();
    const task = await taskService.createTask(userId, req.body);
    res.status(201).json(task);
  } catch (error) {
    next(error);
  }
};

const getTaskDetail = async (req, res, next) => {
  try {
    const task = await taskService.getTaskById(req.params.id);
    res.status(200).json({
      ...task.toObject(),
      currentUserRole: req.taskRole,
    });
  } catch (error) {
    next(error);
  }
};

const updateTask = async (req, res, next) => {
  try {
    const userId = req.user.id || req.user._id.toString();
    const updatedTask = await taskService.updateTask(req.task, userId, req.body);
    res.status(200).json(updatedTask);
  } catch (error) {
    next(error);
  }
};

const updateTaskStatus = async (req, res, next) => {
  try {
    const userId = req.user.id || req.user._id.toString();
    const updatedTask = await taskService.updateTaskStatus(req.task, userId, req.body.status);
    res.status(200).json(updatedTask);
  } catch (error) {
    next(error);
  }
};

const deleteTask = async (req, res, next) => {
  try {
    await taskService.deleteTask(req.params.id);
    res.status(200).json({ message: 'Đã xóa công việc thành công' });
  } catch (error) {
    next(error);
  }
};

const getTaskActivities = async (req, res, next) => {
  try {
    const activities = await taskService.getTaskActivities(req.params.id);
    res.status(200).json(activities);
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getTasks,
  createTask,
  getTaskDetail,
  updateTask,
  updateTaskStatus,
  deleteTask,
  getTaskActivities,
};
