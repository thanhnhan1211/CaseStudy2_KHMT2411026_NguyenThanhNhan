// Bỏ dấu tiếng Việt và viết thường: "Nguyễn Văn Đức" -> "nguyen van duc"
function normalizeText(text) {
  return String(text || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/đ/g, 'd')
    .replace(/Đ/g, 'D')
    .toLowerCase();
}

module.exports = { normalizeText };
