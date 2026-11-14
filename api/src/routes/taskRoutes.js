const express = require('express');
const router = express.Router();
const taskController = require('../controllers/taskController');
const { protect } = require('../middleware/authMiddleware');
const { checkTaskPermission } = require('../middleware/permissionMiddleware');
const {
  validateCreateTask,
  validateUpdateTask,
  validateStatusPatch,
  validateObjectId,
} = require('../validators/taskValidator');

// Tất cả các route /api/tasks đều yêu cầu đăng nhập
router.use(protect);

// GET /api/tasks & POST /api/tasks
router.get('/', taskController.getTasks);
router.post('/', validateCreateTask, taskController.createTask);

// GET /api/tasks/:id (viewer trở lên)
router.get('/:id', validateObjectId, checkTaskPermission('viewer'), taskController.getTaskDetail);

// PUT /api/tasks/:id (editor trở lên)
router.put(
  '/:id',
  validateObjectId,
  checkTaskPermission('editor'),
  validateUpdateTask,
  taskController.updateTask
);

// PATCH /api/tasks/:id/status (editor trở lên)
router.patch(
  '/:id/status',
  validateObjectId,
  checkTaskPermission('editor'),
  validateStatusPatch,
  taskController.updateTaskStatus
);

// DELETE /api/tasks/:id (chỉ owner - người tạo công việc)
router.delete('/:id', validateObjectId, checkTaskPermission('owner'), taskController.deleteTask);

// GET /api/tasks/:id/activities (viewer trở lên)
router.get(
  '/:id/activities',
  validateObjectId,
  checkTaskPermission('viewer'),
  taskController.getTaskActivities
);

module.exports = router;
