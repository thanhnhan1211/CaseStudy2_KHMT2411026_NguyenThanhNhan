const STATUS_LABELS = {
  todo: 'Chưa thực hiện',
  in_progress: 'Đang thực hiện',
  completed: 'Đã hoàn thành',
};

const PERMISSION_LABELS = {
  viewer: 'chỉ xem',
  editor: 'chỉnh sửa',
};

const timeZone = () => process.env.APP_TIMEZONE || 'Asia/Ho_Chi_Minh';

function formatDate(value) {
  const date = value ? new Date(value) : null;
  if (!date || Number.isNaN(date.getTime())) return 'chưa đặt';
  return date.toLocaleDateString('vi-VN', {
    timeZone: timeZone(),
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  });
}

function formatDateTime(value) {
  const date = value ? new Date(value) : null;
  if (!date || Number.isNaN(date.getTime())) return 'chưa đặt';
  return `${date.toLocaleTimeString('vi-VN', {
    timeZone: timeZone(),
    hour: '2-digit',
    minute: '2-digit',
  })} ${formatDate(value)}`;
}

function escapeHtml(text) {
  return String(text ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

// Tiêu đề email không được chứa xuống dòng (chống chèn header)
const oneLine = (text) => String(text ?? '').replace(/[\r\n]+/g, ' ').trim();

const statusLabel = (s) => STATUS_LABELS[s] || s;
const permissionLabel = (p) => PERMISSION_LABELS[p] || p;

// Nội dung thông báo trong ứng dụng
function buildInApp(type, data = {}) {
  const actor = data.actorName || 'Hệ thống';
  const task = data.taskTitle || '';

  switch (type) {
    case 'task_assigned':
      return {
        title: 'Bạn được giao việc mới',
        message: `${actor} đã giao cho bạn công việc "${task}".`,
      };
    case 'task_shared':
      return {
        title: 'Công việc được chia sẻ với bạn',
        message: `${actor} đã chia sẻ công việc "${task}" cho bạn (${permissionLabel(data.permission)}).`,
      };
    case 'share_updated':
      return {
        title: 'Quyền truy cập thay đổi',
        message: `${actor} đã đổi quyền của bạn trên công việc "${task}" thành ${permissionLabel(data.permission)}.`,
      };
    case 'due_date_changed':
      return {
        title: 'Hạn hoàn thành thay đổi',
        message: `${actor} đã đổi hạn của "${task}" từ ${formatDate(data.oldDueDate)} sang ${formatDate(data.dueDate)}.`,
      };
    case 'status_changed':
      return {
        title: 'Trạng thái công việc thay đổi',
        message: `${actor} đã chuyển "${task}" từ "${statusLabel(data.from)}" sang "${statusLabel(data.to)}".`,
      };
    case 'task_completed':
      return {
        title: 'Công việc đã hoàn thành',
        message: `${actor} đã hoàn thành công việc "${task}".`,
      };
    case 'task_reminder':
      return {
        title: 'Công việc sắp đến hạn',
        message: `Công việc "${task}" sẽ đến hạn vào ${formatDateTime(data.dueDate)}.`,
      };
    default:
      return { title: 'Thông báo', message: task };
  }
}

// Nội dung email: { subject, text, html }
function buildEmail(type, data = {}) {
  const { title, message } = buildInApp(type, data);

  const rows = [['Công việc', data.taskTitle || '']];
  if (type === 'due_date_changed' || type === 'task_reminder') {
    rows.push(['Hạn hoàn thành', formatDate(data.dueDate)]);
  }
  if (type === 'task_assigned' || type === 'task_shared') {
    if (data.dueDate) rows.push(['Hạn hoàn thành', formatDate(data.dueDate)]);
  }

  const footer =
    'Email này được gửi tự động từ Task Manager. Hãy mở ứng dụng để xem chi tiết.';

  const text = [
    title,
    '',
    message,
    '',
    ...rows.map(([k, v]) => `${k}: ${v}`),
    '',
    footer,
  ].join('\n');

  const html = `<div style="font-family:Arial,sans-serif;max-width:520px;margin:auto;color:#222">
  <h2 style="color:#3f51b5">${escapeHtml(title)}</h2>
  <p>${escapeHtml(message)}</p>
  <table style="border-collapse:collapse">
    ${rows
      .map(
        ([k, v]) =>
          `<tr><td style="padding:4px 12px 4px 0;color:#666">${escapeHtml(k)}</td><td style="padding:4px 0"><b>${escapeHtml(v)}</b></td></tr>`
      )
      .join('\n    ')}
  </table>
  <p style="color:#888;font-size:12px;margin-top:24px">${escapeHtml(footer)}</p>
</div>`;

  return {
    subject: `[Task Manager] ${oneLine(title)}: ${oneLine(data.taskTitle)}`,
    text,
    html,
  };
}

module.exports = { buildInApp, buildEmail, formatDate, escapeHtml, STATUS_LABELS };
