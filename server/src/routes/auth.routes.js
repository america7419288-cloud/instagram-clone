const express = require('express');
const router = express.Router();

const {
  register,
  checkUsername,
  checkEmail,
} = require('../controllers/auth.controller');

const {
  registerValidation,
  handleValidationErrors,
} = require('../validators/auth.validator');
router.post(
  '/register',
  registerValidation,       
  handleValidationErrors,    
  register                 
);

router.get('/check-username/:username', checkUsername);
router.get('/check-email/:email', checkEmail);
module.exports = router;