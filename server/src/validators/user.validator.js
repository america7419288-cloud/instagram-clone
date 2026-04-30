// server/src/validators/user.validator.js

const { body, query, validationResult } = require('express-validator');

// ─── UPDATE PROFILE VALIDATION ─────────────────────────────
const updateProfileValidation = [
  body('full_name')
    .optional()
    .trim()
    .isLength({ min: 1, max: 100 })
    .withMessage('Full name must be between 1 and 100 characters'),

  body('username')
    .optional()
    .trim()
    .isLength({ min: 3, max: 30 })
    .withMessage('Username must be between 3 and 30 characters')
    .matches(/^[a-zA-Z0-9._]+$/)
    .withMessage(
      'Username can only contain letters, numbers, dots and underscores'
    ),

  body('bio')
    .optional()
    .isLength({ max: 150 })
    .withMessage('Bio cannot exceed 150 characters'),

  body('website')
    .optional()
    .trim()
    .custom((value) => {
      // Allow empty string (to remove website)
      if (!value || value === '') return true;
      // Basic URL validation
      const urlPattern = /^(https?:\/\/)?([\da-z.-]+)\.([a-z.]{2,6})([/\w .-]*)*\/?$/;
      if (!urlPattern.test(value)) {
        throw new Error('Please provide a valid website URL');
      }
      return true;
    }),

  body('gender')
    .optional()
    .isIn(['male', 'female', 'custom', 'prefer_not_to_say', ''])
    .withMessage('Invalid gender value'),

  body('is_private')
    .optional()
    .isBoolean()
    .withMessage('is_private must be true or false'),
];

// ─── SEARCH VALIDATION ─────────────────────────────────────
const searchValidation = [
  query('q')
    .notEmpty()
    .withMessage('Search query is required')
    .isLength({ min: 1, max: 50 })
    .withMessage('Search query must be between 1 and 50 characters'),

  query('page')
    .optional()
    .isInt({ min: 1 })
    .withMessage('Page must be a positive number'),

  query('limit')
    .optional()
    .isInt({ min: 1, max: 50 })
    .withMessage('Limit must be between 1 and 50'),
];

// ─── HANDLE VALIDATION ERRORS ──────────────────────────────
const handleValidationErrors = (req, res, next) => {
  const errors = validationResult(req);

  if (!errors.isEmpty()) {
    const formattedErrors = errors.array().map((error) => ({
      field: error.path,
      message: error.msg,
    }));

    return res.status(400).json({
      success: false,
      message: 'Validation failed',
      errors: formattedErrors,
      timestamp: new Date().toISOString(),
    });
  }

  next();
};

module.exports = {
  updateProfileValidation,
  searchValidation,
  handleValidationErrors,
};