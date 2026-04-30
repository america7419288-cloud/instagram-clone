const { sequelize } = require("../config/database");

const User = require('./User.model');


const syncDatabase = async () => {
    try {
        await sequelize.sync({ alter: true });

        console.log('✅ Database tables synced successfully!');
    console.log('📋 Tables created/updated:');
    console.log('   → users');
  } catch (error) {
    console.error('❌ Database sync failed:', error.message);
    throw error;
  }
};

module.exports = {
  sequelize,
  syncDatabase,
  User,
};