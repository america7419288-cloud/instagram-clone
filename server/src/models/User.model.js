const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const User = sequelize.define(
    'User',
    {
        id: {
            type: DataTypes.UUID,
            defaultValue: DataTypes.UUIDV4,
            primaryKey: true,
            allowNull: false,
        },
        username: {
            type: DataTypes.STRING(30),
            allowNull: false,
            unique: {
                name: 'unique_username',
                msg: 'Username already taken'
            },
            validate: {
                len: {
                    args: [3, 30],
                    msg: 'Username must be between 3 to 30 chars.'
                },
                is: {
                    args: /^[a-zA-z0-9._]+$/,
                    msg: 'Username can only contains letters, numbers, dots and underscores'
                },
                notNull: {
                    msg: 'Username is required'
                }
            }
        },
        email: {
            type: DataTypes.STRING(255),
            allowNull: false,
            unique: {
                name: 'unique_email',
                msg: 'Email already taken'
            },
            validate: {
                isEmail: {
                    args: true,
                    msg: 'Invalid email format'
                },
                notNull: {
                    msg: 'Email is required'
                }
            }
        },
        password_hash: {
            type: DataTypes.STRING(100),
            allowNull: false,
            validate: {
                len: {
                    args: [8, 100],
                    msg: 'Password must be at least 8 characters long'
                },
                notNull: {
                    msg: 'Password is required'
                }
            }
        },
        fullName: {
            type: DataTypes.STRING(100),
            allowNull: false,
            validate: {
                len: {
                    args: [3, 100],
                    msg: 'Full name must be at least 3 characters long'
                },
                notNull: {
                    msg: 'Full name is required'
                }
            }
        },
        fcmToken: {
            type: DataTypes.TEXT,
            allowNull: true, 
        },
        bio: {
            type: DataTypes.STRING(255),
            allowNull: true,
            validate: {
                len: {
                    args: [0, 255],
                    msg: 'Bio cannot exceed 255 characters'
                }
            }
        },
        profile_pic_url: {
            type: DataTypes.STRING(500),
            allowNull: true,
            defaultValue: null,
            validate: {
                len: {
                    args: [0, 255],
                    msg: 'Profile picture URL cannot exceed 255 characters'
                }
            }
        },
        gender: {
            type: DataTypes.ENUM(
                'male',
                'female',
                'custom',
                'prefer_not_say'
            ),
            allowNull: true,
        },
        website: {
            type: DataTypes.STRING(255),
            allowNull: true,
            validate: {
                isUrl: {
                    msg: 'Please provide a valid url'
                }
            }
        },
        is_private: {
            type: DataTypes.BOOLEAN,
            defaultValue: false,
            allowNull: false,
        },
        is_verified: {
            type: DataTypes.BOOLEAN,
            defaultValue: false,
            allowNull: false,
        },

        is_active: {
            type: DataTypes.BOOLEAN,
            defaultValue: true,
            allowNull: false,
        },

        is_banned: {
            type: DataTypes.BOOLEAN,
            defaultValue: false,
            allowNull: false,
        },

        google_id: {
            type: DataTypes.STRING(255),
            allowNull: true,
            unique: true,
        },

        facebook_id: {
            type: DataTypes.STRING(255),
            allowNull: true,
            unique: true,
        },

        last_active_at: {
            type: DataTypes.DATE,
            defaultValue: DataTypes.NOW,
        },
    },

    {
        tableName: 'users',
        timestamps: true,
        underscored: true,

        indexes: [
            { fields: ['username'] },
            { fields: ['email'] },
            { fields: ['last_active_at'] },
        ],


        hooks: {

            beforeSave: (user) => {
                if (user.username) {
                    user.username = user.username.toLowerCase();
                }
                if (user.email) {
                    user.email = user.email.toLowerCase();
                }
            },
        },


        defaultScope: {
            attributes: {
                exclude: ['password_hash', 'google_id', 'facebook_id']
            }
        },


        scopes: {
            withPassword: {
                attributes: { include: ['password_hash'] }
            },
            withSensitive: {
                attributes: {
                    include: ['password_hash', 'google_id', 'facebook_id']
                }
            }
        }
    });

module.exports = User;
