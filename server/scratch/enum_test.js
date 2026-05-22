require('dotenv').config();
const { sequelize } = require('../src/config/database');

async function test() {
  try {
    await sequelize.authenticate();
    console.log('✅ Connected');
    await sequelize.query("ALTER TYPE enum_messages_message_type ADD VALUE IF NOT EXISTS 'post'");
    await sequelize.query("ALTER TYPE enum_messages_message_type ADD VALUE IF NOT EXISTS 'reel'");
    await sequelize.query("ALTER TYPE enum_messages_message_type ADD VALUE IF NOT EXISTS 'story'");
    console.log('✅ Success altering type!');
  } catch (err) {
    console.error('❌ Error altering type:', err);
  } finally {
    await sequelize.close();
  }
}
test();
