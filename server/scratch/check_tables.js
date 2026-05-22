require('dotenv').config();
const { sequelize } = require('../src/config/database');

async function checkTables() {
  try {
    await sequelize.authenticate();
    console.log('✅ Database connection successful!');
    
    // Check reels table columns
    const [reelsCols] = await sequelize.query(`
      SELECT column_name, data_type, is_nullable 
      FROM information_schema.columns 
      WHERE table_name = 'reels';
    `);
    console.log('\nColumns in reels table:');
    console.log(reelsCols);

    // Check stories table columns
    const [storiesCols] = await sequelize.query(`
      SELECT column_name, data_type, is_nullable 
      FROM information_schema.columns 
      WHERE table_name = 'stories';
    `);
    console.log('\nColumns in stories table:');
    console.log(storiesCols);

    // Check if there are any stories/reels to get IDs for testing
    const [stories] = await sequelize.query('SELECT * FROM stories LIMIT 3;');
    console.log('\nSample stories:');
    console.log(stories);

    const [reels] = await sequelize.query('SELECT * FROM reels LIMIT 3;');
    console.log('\nSample reels:');
    console.log(reels);

  } catch (error) {
    console.error('❌ Error checking database:', error);
  } finally {
    await sequelize.close();
  }
}

checkTables();
