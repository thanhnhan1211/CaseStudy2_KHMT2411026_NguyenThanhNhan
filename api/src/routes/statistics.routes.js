const express = require('express');

const authMiddleware = require('../middleware/auth.middleware');
const {
  taskStatistics,
  assignmentStatistics,
  deadlineStatistics,
} = require('../services/statistics.service');

const router = express.Router();

router.use(authMiddleware);

const SCOPES = ['all', 'created', 'assigned', 'shared'];

function scopeError(scope) {
  if (scope !== undefined && !SCOPES.includes(scope)) {
    return 'scope phải là all, created, assigned hoặc shared';
  }
  return null;
}

// GET /api/statistics/tasks?scope= - Theo trạng thái và mức độ ưu tiên
router.get('/tasks', async (req, res) => {
  try {
    const error = scopeError(req.query.scope);
    if (error) return res.status(400).json({ message: error });

    res.status(200).json(await taskStatistics(req.user._id, req.query.scope));
  } catch (error) {
    res.status(500).json({ message: 'Không thể lấy thống kê công việc' });
  }
});

// GET /api/statistics/assignments - Việc được giao và đang phụ trách
router.get('/assignments', async (req, res) => {
  try {
    res.status(200).json(await assignmentStatistics(req.user._id));
  } catch (error) {
    res.status(500).json({ message: 'Không thể lấy thống kê giao việc' });
  }
});

// GET /api/statistics/deadlines?days=7&scope= - Sắp đến hạn và quá hạn
router.get('/deadlines', async (req, res) => {
  try {
    const error = scopeError(req.query.scope);
    if (error) return res.status(400).json({ message: error });

    let days = 7;
    if (req.query.days !== undefined) {
      if (!/^\d+$/.test(String(req.query.days))) {
        return res.status(400).json({ message: 'days phải là số nguyên từ 1 đến 90' });
      }
      days = Number(req.query.days);
      if (days < 1 || days > 90) {
        return res.status(400).json({ message: 'days phải là số nguyên từ 1 đến 90' });
      }
    }

    res
      .status(200)
      .json(await deadlineStatistics(req.user._id, { scope: req.query.scope, days }));
  } catch (error) {
    res.status(500).json({ message: 'Không thể lấy thống kê hạn hoàn thành' });
  }
});

module.exports = router;
