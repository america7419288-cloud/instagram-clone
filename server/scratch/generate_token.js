// scratch/generate_token.js
const jwt = require('jsonwebtoken');
require('dotenv').config({ path: '.env' });

const payload = {
  id: 'ab5ea9f6-c38d-4fce-bdc7-bd9ad4b8e504',
  username: 'john_doe3'
};

const secret = process.env.JWT_SECRET || 'your_super_secret_jwt_key_change_this';
const token = jwt.sign(payload, secret, { expiresIn: '1h' });

console.log(token);
