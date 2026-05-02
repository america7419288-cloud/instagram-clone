// server/src/config/database.js

const { Sequelize } = require('sequelize');

let sequelize;

if (process.env.DATABASE_URL) {
  // ─── Production: Use connection string (Supabase) ──────
  sequelize = new Sequelize(process.env.DATABASE_URL, {
    dialect: 'postgres',
    logging: false,
    dialectOptions: {
      ssl: {
        require: true,
        rejectUnauthorized: false,
      },
    },
    pool: {
      max: 5,
      min: 0,
      acquire: 60000,
      idle: 10000,
    },
    define: {
      timestamps: true,
      underscored: true,
    },
  });
} else {
  // ─── Development: Use individual env vars (localhost) ───
  sequelize = new Sequelize(
    process.env.DB_NAME || 'instagram_clone',
    process.env.DB_USER || 'postgres',
    process.env.DB_PASS || 'postgres',
    {
      host: process.env.DB_HOST || 'localhost',
      port: process.env.DB_PORT || 5432,
      dialect: 'postgres',
      logging: false,
      pool: {
        max: 5,
        min: 0,
        acquire: 30000,
        idle: 10000,
      },
      define: {
        timestamps: true,
        underscored: true,
      },
    }
  );
}

const testConnection = async () => {
  try {
    await sequelize.authenticate();
    console.log('✅ Database connected successfully');

    const isProduction = !!process.env.DATABASE_URL;
    if (isProduction) {
      console.log('   📡 Connected to: Supabase (Production)');
    } else {
      console.log('   📡 Connected to: localhost (Development)');
    }
  } catch (error) {
    console.error('❌ Database connection failed:', error.message);
    process.exit(1);
  }
};

module.exports = { sequelize, testConnection };