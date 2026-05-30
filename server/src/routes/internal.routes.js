const express = require('express');
const router = express.Router();
const { User } = require('../models');
const { successResponse, errorResponse } = require('../utils/response.utils');

// Middleware to verify inter-service secret
const verifyInternalSecret = (req, res, next) => {
  const secret = req.headers['x-service-secret'];
  if (!secret || secret !== process.env.INTER_SERVICE_SECRET) {
    return errorResponse(res, 403, 'Forbidden. Invalid inter-service secret.');
  }
  next();
};

router.post('/auth-events', verifyInternalSecret, async (req, res) => {
  const { event, data } = req.body;

  console.log(`📡 Received internal auth event: ${event}`, data);

  try {
    if (event === 'user.verified') {
      const { userId, email, username, fullName, passwordHash } = data;

      // Upsert user in Postgres
      const [user, created] = await User.findOrCreate({
        where: { id: userId },
        defaults: {
          id: userId,
          email: email.toLowerCase(),
          username: username.toLowerCase(),
          fullName,
          password_hash: passwordHash,
          is_verified: true,
          is_active: true,
        },
      });

      if (!created) {
        await user.update({
          email: email.toLowerCase(),
          username: username.toLowerCase(),
          fullName,
          password_hash: passwordHash,
          is_verified: true,
        });
      }

      console.log(`👤 Sync User ${username} in Postgres: ${created ? 'CREATED' : 'UPDATED'}`);
      return successResponse(res, 200, 'User synced successfully', { userId });
    }

    if (event === 'password.changed') {
      const { userId, passwordHash } = data;

      const user = await User.findByPk(userId);
      if (!user) {
        return errorResponse(res, 404, 'User not found in Postgres');
      }

      await user.update({ password_hash: passwordHash });
      console.log(`🔑 Password updated for User ${user.username} in Postgres`);
      return successResponse(res, 200, 'Password hash synced successfully');
    }

    return errorResponse(res, 400, `Unsupported event: ${event}`);
  } catch (error) {
    console.error('❌ Internal auth event handler error:', error);
    return errorResponse(res, 500, 'Internal server error while syncing');
  }
});

module.exports = router;
