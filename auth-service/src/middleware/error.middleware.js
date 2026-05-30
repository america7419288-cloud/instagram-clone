// src/middleware/error.middleware.js

const logger = require('../utils/logger');
const { error } = require('../utils/response.utils');

function errorHandler(err, req, res, next) {
  logger.error('Unhandled error:', err);

  const status = err.status || 500;
  const code = err.code || 'SERVER_ERROR';
  const message = err.message || 'An unexpected error occurred.';

  return res.status(status).json(error(code, message));
}

module.exports = { errorHandler };
