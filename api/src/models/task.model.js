const mongoose = require('mongoose');

const STATUSES = ['todo', 'in_progress', 'completed'];
const PRIORITIES = ['low', 'medium', 'high'];

const taskSchema = new mongoose.Schema(
  {
    title: {
      type: String,
      required: true,
      trim: true,
    },

    description: {
      type: String,
      default: '',
    },

    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },

    // Nhóm C (giao việc) sẽ dùng 2 trường này
    assigneeIds: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
    primaryAssigneeId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },

    // Hạn đã được nhắc việc (để mỗi hạn chỉ nhắc một lần)
    reminderSentFor: { type: Date, default: null },

    startDate: { type: Date, default: null },
    dueDate: { type: Date, default: null },

    priority: {
      type: String,
      enum: PRIORITIES,
      default: 'medium',
    },

    status: {
      type: String,
      enum: STATUSES,
      default: 'todo',
    },
  },
  {
    timestamps: true,
  }
);

taskSchema.index({ assigneeIds: 1 });

module.exports = mongoose.model('Task', taskSchema);
module.exports.STATUSES = STATUSES;
module.exports.PRIORITIES = PRIORITIES;
