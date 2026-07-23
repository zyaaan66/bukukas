// Kumpulan validator sederhana untuk input dari client.
// Dipusatkan di sini supaya aturan validasi konsisten di semua route.

function isValidPhoneNumber(phone) {
  if (!phone || typeof phone !== 'string') return false;
  // Terima format 08xxxxxxxxxx, +62xxxxxxxxxx, atau 62xxxxxxxxxx, 10-15 digit
  const cleaned = phone.trim();
  return /^(\+62|62|0)8[0-9]{8,12}$/.test(cleaned);
}

function isValidPassword(password) {
  return typeof password === 'string' && password.length >= 6;
}

function isPositiveNumber(value) {
  const num = Number(value);
  return !isNaN(num) && num > 0;
}

module.exports = { isValidPhoneNumber, isValidPassword, isPositiveNumber };
