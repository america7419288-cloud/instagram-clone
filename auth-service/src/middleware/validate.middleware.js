// src/middleware/validate.middleware.js

const { body, query, validationResult } = require('express-validator');
const { error } = require('../utils/response.utils');

const validateRegister = [
  body('email').isEmail().withMessage('Please provide a valid email address'),
  body('username')
    .trim()
    .isLength({ min: 3, max: 30 })
    .withMessage('Username must be between 3 and 30 characters')
    .matches(/^[a-z0-9._]+$/)
    .withMessage('Username can only contain lowercase letters, numbers, dots, and underscores'),
  body('password')
    .isLength({ min: 8 })
    .withMessage('Password must be at least 8 characters long'),
  body('fullName').optional().trim().isLength({ max: 60 }).withMessage('Full name cannot exceed 60 characters'),
  body('full_name').optional().trim().isLength({ max: 60 }).withMessage('Full name cannot exceed 60 characters'),
];

const validateLogin = [
  body('password').notEmpty().withMessage('Password is required'),
  body().custom((body, { req }) => {
    const val = req.body.emailOrUsername || req.body.identifier;
    if (!val) {
      throw new Error('Email or username is required');
    }
    req.body.emailOrUsername = val;
    return true;
  }),
];

const validateVerifyEmail = [
  body('email').isEmail().withMessage('Valid email is required'),
  body('otp')
    .isLength({ min: 6, max: 6 })
    .withMessage('Verification code must be exactly 6 digits')
    .isNumeric()
    .withMessage('Verification code must be numeric'),
];

const validateForgotPassword = [
  body('email').isEmail().withMessage('Valid email is required'),
];

const validateVerifyResetOtp = [
  body('email').isEmail().withMessage('Valid email is required'),
  body('otp').isLength({ min: 6, max: 6 }).withMessage('OTP must be exactly 6 digits'),
];

const validateResetPassword = [
  body('resetToken').notEmpty().withMessage('Reset token is required'),
  body('newPassword').isLength({ min: 8 }).withMessage('New password must be at least 8 characters long'),
];

const validateChangePassword = [
  body('currentPassword').notEmpty().withMessage('Current password is required'),
  body('newPassword').isLength({ min: 8 }).withMessage('New password must be at least 8 characters long'),
];

const validateRefresh = [
  body('refreshToken').notEmpty().withMessage('Refresh token is required'),
];

const validateSendOtp = [
  body('email').isEmail().withMessage('Valid email is required'),
  body('type').isIn(['email_verify', 'password_reset', 'login', 'phone_verify']).withMessage('Invalid OTP type'),
];

const validateVerifyOtp = [
  body('email').isEmail().withMessage('Valid email is required'),
  body('otp').isLength({ min: 6, max: 6 }).withMessage('OTP must be exactly 6 digits'),
  body('type').isIn(['email_verify', 'password_reset', 'login', 'phone_verify']).withMessage('Invalid OTP type'),
];

function checkValidation(req, res, next) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    const errorDetails = errors.array().map(err => ({
      field: err.path,
      message: err.msg,
    }));
    return res.status(400).json(error(
      'VALIDATION_FAILED',
      errors.array()[0].msg,
      errorDetails
    ));
  }
  next();
}

module.exports = {
  validateRegister,
  validateLogin,
  validateVerifyEmail,
  validateForgotPassword,
  validateVerifyResetOtp,
  validateResetPassword,
  validateChangePassword,
  validateRefresh,
  validateSendOtp,
  validateVerifyOtp,
  checkValidation,
};
