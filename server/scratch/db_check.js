require('dotenv').config();
const { sequelize } = require('../src/config/database');

async function checkDb() {
  try {
    await sequelize.authenticate();
    console.log('✅ Database connection successful!');
    
    // Check message_type enum values in the database
    const [results] = await sequelize.query(`
      SELECT enumlabel 
      FROM pg_enum 
      WHERE enumtypid = 'enum_messages_message_type'::regtype;
    `);
    
    console.log('Current DB Enum values for enum_messages_message_type:');
    console.log(results.map(r => r.enumlabel));
    
    // Let's also check messages table structure
    const [columns] = await sequelize.query(`
      SELECT column_name, data_type, is_nullable 
      FROM information_schema.columns 
      WHERE table_name = 'messages';
    `);
    console.log('\nColumns in messages table:');
    console.log(columns);
  } catch (error) {
    console.error('❌ Error checking database:', error);
  } finally {
    await sequelize.close();
  }
}

checkDb();
