const bcrypt = require('bcryptjs');


const hashPassword = async (plainPassword) => {
    const saltRounds = 12;

    return await bcrypt.hash(plainPassword, saltRounds);
};

const comparePassword = async (plainPassword, hashedPassword) => {
    return await bcrypt.compare(plainPassword, hashedPassword);
};

const validatePasswordStrength = (password) => {
    const errors = [];

    if (password.length < 6)
    {
        error.push('please enter a password longer thann 8 chars.')
    }
    if (password.length > 64) {
        error.push('please enter a password shorter than 64 chars.')
    }
    if (!/[A-Z]/.test(password)) {
        error.push('must include at least one uppercase letter')
    }
    if (!/[a-z]/.test(password)) {
        error.push('must include at least one lower case letter')
    }

    return {
        isValid: errors.length === 0,
        errors,
    };
};

module.exports = {
    hashPassword,
    comparePassword,
    validatePasswordStrength,
};