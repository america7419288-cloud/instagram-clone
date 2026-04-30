const { User } = require('../models');
const { hashPassword } = require('../utils/password.utils');
const { generateTokens } = require('../utils/jwt.utils');
const { successResponse, errorResponse } = require('../utils/response.utils');
const { Op } = require('sequelize');

const register = async (req, res) => {
  try {
    const { full_name, email, username, password } = req.body;

    console.log('📝 Register attempt:', { email, username });

    const existingUser = await User.unscoped().findOne({
      where: {
        [Op.or]: [
          { email: email.toLowerCase() },
          { username: username.toLowerCase() },
        ],
      },
    });

    if (existingUser) {
      if (existingUser.email === email.toLowerCase()) {
        return errorResponse(
          res,
          409, 
          'Email is already registered. Please login or use a different email.'
        );
      }

      if (existingUser.username === username.toLowerCase()) {
        return errorResponse(
          res,
          409,
          'Username is already taken. Please choose a different username.'
        );
      }
    }

    const password_hash = await hashPassword(password);

    const newUser = await User.create({
      fullName: full_name,
      email: email.toLowerCase(),
      username: username.toLowerCase(),
      password_hash: password_hash,

    });

    console.log('✅ New user created:', newUser.id);

    const { accessToken, refreshToken } = generateTokens(newUser.id);


    const userData = {
      id: newUser.id,
      username: newUser.username,
      email: newUser.email,
      full_name: newUser.full_name,
      bio: newUser.bio,
      profile_pic_url: newUser.profile_pic_url,
      is_private: newUser.is_private,
      is_verified: newUser.is_verified,
      created_at: newUser.createdAt,
    };


    return successResponse(
      res,
      201, 
      'Account created successfully! Welcome to Instagram Clone 🎉',
      {
        user: userData,
        tokens: {
          accessToken,
          refreshToken,
          expiresIn: process.env.JWT_EXPIRES_IN || '7d',
        },
      }
    );

  } catch (error) {
    console.error('❌ Register error:', error);

    if (error.name === 'SequelizeUniqueConstraintError') {
      const field = error.errors[0]?.path;
      return errorResponse(
        res,
        409,
        `${field === 'email' ? 'Email' : 'Username'} is already taken.`
      );
    }

   
    if (error.name === 'SequelizeValidationError') {
      const messages = error.errors.map((e) => e.message);
      return errorResponse(res, 400, messages[0]);
    }

 
    return errorResponse(
      res,
      500,
      'Something went wrong. Please try again.'
    );
  }
};


const checkUsername = async (req, res) => {
  try {
    const { username } = req.params;


    if (!/^[a-zA-Z0-9._]+$/.test(username)) {
      return errorResponse(
        res,
        400,
        'Username can only contain letters, numbers, dots and underscores'
      );
    }

    if (username.length < 3 || username.length > 30) {
      return errorResponse(
        res,
        400,
        'Username must be between 3 and 30 characters'
      );
    }

    const existingUser = await User.findOne({
      where: { username: username.toLowerCase() },
    });

    if (existingUser) {
      return successResponse(res, 200, 'Username check complete', {
        username: username.toLowerCase(),
        available: false,
        message: 'Username is already taken',
      });
    }

    return successResponse(res, 200, 'Username check complete', {
      username: username.toLowerCase(),
      available: true,
      message: 'Username is available! ✅',
    });

  } catch (error) {
    console.error('❌ Check username error:', error);
    return errorResponse(res, 500, 'Something went wrong');
  }
};


const checkEmail = async (req, res) => {
  try {
    const { email } = req.params;

    const existingUser = await User.findOne({
      where: { email: email.toLowerCase() },
    });

    return successResponse(res, 200, 'Email check complete', {
      email: email.toLowerCase(),
      available: !existingUser,
      message: existingUser
        ? 'Email is already registered'
        : 'Email is available ✅',
    });

  } catch (error) {
    console.error('❌ Check email error:', error);
    return errorResponse(res, 500, 'Something went wrong');
  }
};

module.exports = {
  register,
  checkUsername,
  checkEmail,
};