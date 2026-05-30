// src/utils/response.utils.js

function success(code, message, data = {}) {
  return {
    success: true,
    code,
    message,
    data,
  };
}

function error(code, message, data = {}) {
  return {
    success: false,
    code,
    message,
    data,
  };
}

module.exports = { success, error };
