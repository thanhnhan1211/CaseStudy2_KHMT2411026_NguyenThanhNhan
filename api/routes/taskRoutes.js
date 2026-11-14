const express = require('express');
const router = express.Router();
const taskController = require('../controllers/taskController');
const authMiddleware = require('../middleware/authMiddleware');
const { checkTaskPermission } = require('../middleware/permissionMiddleware');
const {
  validateCreateTask,
  validateUpdateTask,
  validateStatusPatch,
  validateObjectId,
} = require('../validators/taskValidator');

// Hỗ trợ cả 2 kiểu export từ authMiddleware (module.exports = fn hoặc module.exports = { protect })
const protect = typeof authMiddleware === 'function' ? authMiddleware : authMiddleware.protect;

router.use(protect);

router.get('/', taskController.getTasks);
router.post('/', validateCreateTask, taskController.createTask);

router.get('/:id', validateObjectId, checkTaskPermission('viewer'), taskController.getTaskDetail);

router.put(
  '/:id',
  validateObjectId,
  checkTaskPermission('editor'),
  validateUpdateTask,
  taskController.updateTask
);

router.patch(
  '/:id/status',
  validateObjectId,
  checkTaskPermission('editor'),
  validateStatusPatch,
  taskController.updateTaskStatus
);

router.delete('/:id', validateObjectId, checkTaskPermission('owner'), taskController.deleteTask);

router.get(
  '/:id/activities',
  validateObjectId,
  checkTaskPermission('viewer'),
  taskController.getTaskActivities
);

module.exports = router;
