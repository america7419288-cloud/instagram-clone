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
        errors.push('please enter a password longer than 6 chars.')
    }
    if (password.length > 64) {
        errors.push('please enter a password shorter than 64 chars.')
    }
    if (!/[A-Z]/.test(password)) {
        errors.push('must include at least one uppercase letter')
    }
    if (!/[a-z]/.test(password)) {
        errors.push('must include at least one lowercase letter')
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
