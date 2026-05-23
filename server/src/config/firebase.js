// server/src/config/firebase.js

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

let firebaseInitialized = false;
let firebaseInitError = null;

const initializeFirebase = () => {
    if (firebaseInitialized) return admin;

    try {
        let credential;

        // ─── Option 1: Use service account JSON file ──────
        // (Good for development)
        const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;

        if (serviceAccountPath) {
            const resolvedPath = path.resolve(serviceAccountPath);

            if (fs.existsSync(resolvedPath)) {
                const serviceAccount = require(resolvedPath);
                credential = admin.credential.cert(serviceAccount);
                console.log('🔥 Firebase: Using service account file');
            } else {
                firebaseInitError = `serviceAccountKey.json not found at: ${resolvedPath}`;
            }
        }

        // ─── Option 2: Use env vars individually ──────────
        // (Good for production/Render)
        if (!credential && process.env.FIREBASE_PROJECT_ID) {
            const serviceAccount = {
                type: 'service_account',
                project_id: process.env.FIREBASE_PROJECT_ID,
                private_key_id: process.env.FIREBASE_PRIVATE_KEY_ID,
                private_key: process.env.FIREBASE_PRIVATE_KEY
                    ?.replace(/\\n/g, '\n'),
                client_email: process.env.FIREBASE_CLIENT_EMAIL,
                client_id: process.env.FIREBASE_CLIENT_ID,
                auth_uri:
                    'https://accounts.google.com/o/oauth2/auth',
                token_uri:
                    'https://oauth2.googleapis.com/token',
                auth_provider_x509_cert_url:
                    'https://www.googleapis.com/oauth2/v1/certs',
                client_x509_cert_url: `https://www.googleapis.com/robot/v1/metadata/x509/${process.env.FIREBASE_CLIENT_EMAIL
                    }`,
            };
            // ─── Validate all required fields are present ────
            const required = [
                'project_id', 'private_key', 'client_email', 'private_key_id'
            ];
            const missing = required.filter(k => !serviceAccount[k] ||
                serviceAccount[k].includes('xxxxx') ||
                serviceAccount[k].includes('your-project')
            );
            if (missing.length > 0) {
                const errStr = `Incomplete env vars — missing/placeholder: ${missing.join(', ')}`;
                console.error(`❌ Firebase: ${errStr}`);
                console.error('   Set correct values in Render env vars or use FIREBASE_SERVICE_ACCOUNT_PATH');
                firebaseInitError = errStr;
                return null;
            }
            credential = admin.credential.cert(serviceAccount);
            console.log(`🔥 Firebase: Using env vars (project: ${serviceAccount.project_id})`);
        }

        if (!credential) {
            const errStr = 'No credentials found. Ensure serviceAccountKey.json exists or FIREBASE_* env vars are set.';
            console.warn(`⚠️ Firebase: ${errStr}`);
            if (!firebaseInitError) {
                firebaseInitError = errStr;
            }
            return null;
        }

        // ─── Initialize only if not already done ──────────
        if (!admin.apps.length) {
            admin.initializeApp({ credential });
        }

        firebaseInitialized = true;
        firebaseInitError = null;
        console.log('✅ Firebase Admin initialized');
        return admin;

    } catch (error) {
        console.error('❌ Firebase initialization error:', error.message);
        firebaseInitError = `Initialization catch error: ${error.message}`;
        return null;
    }
};

// ─── Get messaging instance ────────────────────────────
const getMessaging = () => {
    const app = initializeFirebase();
    if (!app) return null;
    try {
        return app.messaging();
    } catch (e) {
        firebaseInitError = `Get messaging instance error: ${e.message}`;
        return null;
    }
};

const getFirebaseInitError = () => {
    if (!firebaseInitialized) {
        initializeFirebase();
    }
    return firebaseInitError;
};

module.exports = { initializeFirebase, getMessaging, getFirebaseInitError };