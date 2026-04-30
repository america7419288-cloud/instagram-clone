const { body, validationResult } = require('express-validator');

const registerValidation = [

    body('full_name')
    .trim()
    .notEmpty()
    .withMessage('full name is required')
    .isLength({ min: 2, max: 100 })
    .withMessage('Full name must be between 2 and 100 chars.'),

    body('email')
    .trim()
    .notEmpty()
    .withMessage('Email is required')
    .isEmail()
    .withMessage('Please provide a valid email address')
    .normalizeEmail()
    .toLowerCase(),

    body('username')
    .trim()
    .notEmpty()
    .withMessage('Username is required')
    .isLength({ min: 3, max: 30 })
    .withMessage('Username must be between 3 and 30 chars.')
    .matches(/^[a-zA-Z0-9._]+$/)
    .withMessage(
        'Username can only contains letters, numbers, dots and underscoress')
    .toLowerCase(),

    body('password')
    .notEmpty()
    .withMessage('Password is required')
    .isLength({ min: 8 })
    .withMessage('Password must at least 8 chars. long')
    .isLength({ max: 64 })
    .withMessage('Password must be in 64 chars.')
];


const loginValidation = [
    body('identifier')
    .trim()
    .notEmpty()
    .withMessage('Email or username is required'),


    body('password')
        .notEmpty()
        .withMessage('Password is required'),
];



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
    registerValidation,
    loginValidation,
    handleValidationErrors,

};