const { User } = require('../models');
const { hashPassword, comparePassword } = require('../utils/password.utils');
const {
  generateTokens,
  verifyRefreshToken,
} = require('../utils/jwt.utils');
const { successResponse, errorResponse } = require('../utils/response.utils');
const { Op } = require('sequelize');

const formatUserResponse = (user) => ({
  id: user.id,
  username: user.username,
  email: user.email,
  full_name: user.fullName,
  bio: user.bio,
  website: user.website,
  profile_pic_url: user.profile_pic_url,
  gender: user.gender,
  is_private: user.is_private,
  is_verified: user.is_verified,
  is_active: user.is_active,
  last_active_at: user.last_active_at,
  created_at: user.createdAt,
});

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

    let profile_pic_url = null;
    if (req.file) {
      try {
        const { uploadProfilePictureToCloudinary } = require('../services/upload.service');
        console.log('📸 Uploading profile picture during registration...');
        const uploadResult = await uploadProfilePictureToCloudinary(
          req.file.buffer,
          'profile_pics'
        );
        profile_pic_url = uploadResult.secure_url;
      } catch (uploadError) {
        console.error('❌ Profile pic upload error:', uploadError);
      }
    }

    const password_hash = await hashPassword(password);

    const newUser = await User.create({
      fullName: full_name,
      email: email.toLowerCase(),
      username: username.toLowerCase(),
      password_hash,
      profile_pic_url,
    });

    console.log('✅ New user created:', newUser.id);

    const { accessToken, refreshToken } = generateTokens(newUser.id);

    return successResponse(
      res,
      201,
      'Account created successfully! Welcome to Instagram Clone 🎉',
      {
        user: formatUserResponse(newUser),
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
      return errorResponse(res, 400, error.errors[0].message);
    }

    return errorResponse(res, 500, 'Something went wrong. Please try again.');
  }
};

const login = async (req, res) => {
  try {
    const { identifier, password } = req.body;

    console.log('🔐 Login attempt:', identifier);

    const user = await User.scope('withPassword').findOne({
      where: {
        [Op.or]: [
          { email: identifier.toLowerCase() },
          { username: identifier.toLowerCase() },
        ],
      },
    });

    if (!user) {
      return errorResponse(
        res,
        401,
        'Invalid credentials. Please check your email/username and password.'
      );
    }

    if (!user.is_active) {
      return errorResponse(
        res,
        403,
        'Your account has been deactivated. Please contact support.'
      );
    }

    if (user.is_banned) {
      return errorResponse(
        res,
        403,
        'Your account has been suspended. Please contact support.'
      );
    }

    if (!user.password_hash) {
      return errorResponse(
        res,
        400,
        'This account uses social login. Please login with Google or Facebook.'
      );
    }

    const isPasswordCorrect = await comparePassword(password, user.password_hash);

    if (!isPasswordCorrect) {
      console.log('❌ Wrong password for:', identifier);
      return errorResponse(
        res,
        401,
        'Invalid credentials. Please check your email/username and password.'
      );
    }

    await user.update({ last_active_at: new Date() });

    console.log('✅ Login successful:', user.id);

    const { accessToken, refreshToken } = generateTokens(user.id);

    return successResponse(
      res,
      200,
      'Login successful! Welcome back 👋',
      {
        user: formatUserResponse(user),
        tokens: {
          accessToken,
          refreshToken,
          expiresIn: process.env.JWT_EXPIRES_IN || '7d',
        },
      }
    );

  } catch (error) {
    console.error('❌ Login error:', error);
    return errorResponse(res, 500, 'Something went wrong. Please try again.');
  }
};

const getMe = async (req, res) => {
  try {
    const userId = req.user.id;
    const user = await User.findByPk(userId);

    if (!user) {
      return errorResponse(res, 404, 'User not found.');
    }

    await user.update({ last_active_at: new Date() });

    return successResponse(
      res,
      200,
      'User profile fetched successfully',
      { user: formatUserResponse(user) }
    );

  } catch (error) {
    console.error('❌ GetMe error:', error);
    return errorResponse(res, 500, 'Something went wrong.');
  }
};

const logout = async (req, res) => {
  try {
    const userId = req.user.id;
    await User.update(
      { last_active_at: new Date() },
      { where: { id: userId } }
    );

    console.log('👋 User logged out:', userId);

    return successResponse(
      res,
      200,
      'Logged out successfully. See you soon! 👋',
      {}
    );

  } catch (error) {
    console.error('❌ Logout error:', error);
    return errorResponse(res, 500, 'Something went wrong.');
  }
};

const refreshToken = async (req, res) => {
  try {
    const { refreshToken: token } = req.body;

    if (!token) {
      return errorResponse(res, 400, 'Refresh token is required.');
    }

    const decoded = verifyRefreshToken(token);

    if (!decoded) {
      return errorResponse(
        res,
        401,
        'Invalid or expired refresh token. Please login again.'
      );
    }

    const user = await User.findByPk(decoded.id);

    if (!user || !user.is_active || user.is_banned) {
      return errorResponse(
        res,
        401,
        'Account not found or has been deactivated.'
      );
    }

    const { accessToken, refreshToken: newRefreshToken } = generateTokens(user.id);

    console.log('🔄 Token refreshed for user:', user.id);

    return successResponse(
      res,
      200,
      'Token refreshed successfully',
      {
        tokens: {
          accessToken,
          refreshToken: newRefreshToken,
          expiresIn: process.env.JWT_EXPIRES_IN || '7d',
        },
      }
    );

  } catch (error) {
    console.error('❌ Refresh token error:', error);
    return errorResponse(res, 500, 'Something went wrong.');
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

    return successResponse(res, 200, 'Username check complete', {
      username: username.toLowerCase(),
      available: !existingUser,
      message: existingUser
        ? 'Username is already taken'
        : 'Username is available! ✅',
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
  login,
  getMe,
  logout,
  refreshToken,
  checkUsername,
  checkEmail,
};
