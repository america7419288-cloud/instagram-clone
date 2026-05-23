// server/src/services/push.service.js

const { getMessaging } = require('../config/firebase');

// ─────────────────────────────────────────────────────
// NOTIFICATION TEMPLATES
// Returns title + body for each notification type
// ─────────────────────────────────────────────────────
const getNotificationContent = (type, senderUsername, extra = {}) => {
    switch (type) {
        // ─── Post interactions ──────────────────────────────
        case 'like':
            return {
                title: 'New like',
                body: `${senderUsername} liked your photo`,
                icon: '❤️',
            };

        case 'comment':
            return {
                title: 'New comment',
                body: extra.commentText
                    ? `${senderUsername}: ${extra.commentText.length > 60
                        ? extra.commentText.substring(0, 60) + '...'
                        : extra.commentText
                    }`
                    : `${senderUsername} commented on your post`,
                icon: '💬',
            };

        case 'comment_like':
            return {
                title: 'Comment liked',
                body: `${senderUsername} liked your comment`,
                icon: '❤️',
            };

        case 'mention':
            return {
                title: 'You were mentioned',
                body: `${senderUsername} mentioned you in a post`,
                icon: '@',
            };

        case 'mention_comment':
            return {
                title: 'You were mentioned',
                body: `${senderUsername} mentioned you in a comment`,
                icon: '@',
            };

        // ─── Follow interactions ────────────────────────────
        case 'follow':
            return {
                title: 'New follower',
                body: `${senderUsername} started following you`,
                icon: '👤',
            };

        case 'follow_request':
            return {
                title: 'Follow request',
                body: `${senderUsername} requested to follow you`,
                icon: '👤',
            };

        case 'follow_accepted':
            return {
                title: 'Follow request accepted',
                body: `${senderUsername} accepted your follow request`,
                icon: '✅',
            };

        // ─── Messages ───────────────────────────────────────
        case 'message':
            return {
                title: senderUsername,
                body: extra.messageText
                    ? extra.messageText.length > 80
                        ? extra.messageText.substring(0, 80) + '...'
                        : extra.messageText
                    : 'Sent you a message',
                icon: '💬',
            };

        // ─── Story interactions ─────────────────────────────
        case 'story_reaction':
            return {
                title: 'Story reaction',
                body: `${senderUsername} reacted to your story`,
                icon: extra.emoji || '😮',
            };

        case 'story_reply':
            return {
                title: `${senderUsername}`,
                body: extra.replyText || 'Replied to your story',
                icon: '↩️',
            };

        case 'story_answer':
            return {
                title: 'New answer',
                body: `${senderUsername} answered your question`,
                icon: '❓',
            };

        default:
            return {
                title: 'Instagram Clone',
                body: `${senderUsername} sent you a notification`,
                icon: '🔔',
            };
    }
};

// ─────────────────────────────────────────────────────
// DEEP LINK DATA
// Tells the Flutter app where to navigate on tap
// ─────────────────────────────────────────────────────
const getNotificationData = (type, extra = {}) => {
    const base = { type };

    switch (type) {
        case 'like':
        case 'comment':
        case 'comment_like':
        case 'mention':
        case 'mention_comment':
            return {
                ...base,
                route: '/post',
                postId: extra.postId || '',
            };

        case 'follow':
        case 'follow_request':
        case 'follow_accepted':
            return {
                ...base,
                route: '/profile',
                username: extra.senderUsername || '',
            };

        case 'message':
            return {
                ...base,
                route: '/chat',
                conversationId: extra.conversationId || '',
                username: extra.senderUsername || '',
            };

        case 'story_reaction':
        case 'story_reply':
        case 'story_answer':
            return {
                ...base,
                route: '/story',
                storyId: extra.storyId || '',
            };

        default:
            return { ...base, route: '/notifications' };
    }
};

// ─────────────────────────────────────────────────────
// SEND PUSH NOTIFICATION
// Main function - call this from notification.service.js
// ─────────────────────────────────────────────────────
const sendPushNotification = async ({
    fcmToken,
    type,
    senderUsername,
    extra = {},
    richResult = false,
}) => {
    // ─── Guard: no token → skip silently ─────────────────
    if (!fcmToken) {
        return richResult ? { success: false, error: 'FCM token is empty' } : false;
    }

    const messaging = getMessaging();

    // ─── Guard: Firebase not initialized ─────────────────
    if (!messaging) {
        const { getFirebaseInitError } = require('../config/firebase');
        const initErr = getFirebaseInitError() || 'Firebase Messaging is not initialized on the server.';
        console.warn('⚠️ Push: Firebase not ready, skipping push:', initErr);
        return richResult ? { success: false, error: initErr } : false;
    }

    try {
        const content = getNotificationContent(type, senderUsername, extra);
        const data = getNotificationData(type, { ...extra, senderUsername });

        // ─── Build FCM message ────────────────────────────
        const message = {
            token: fcmToken,

            // ─── Notification (shown by OS when app is background) ──
            notification: {
                title: content.title,
                body: content.body,
            },

            // ─── Data payload (always delivered, used for navigation) ──
            // All values must be strings for FCM
            data: Object.fromEntries(
                Object.entries(data).map(([k, v]) => [k, String(v || '')])
            ),

            // ─── Android specific ──────────────────────────────
            android: {
                priority: 'high',
                notification: {
                    channelId: 'instagram_clone_channel',
                    priority: 'high',
                    defaultSound: true,
                    clickAction: 'FLUTTER_NOTIFICATION_CLICK',
                    icon: '@mipmap/ic_launcher',
                    color: '#0095F6',
                },
            },

            // ─── iOS (APNs) specific ──────────────────────────
            apns: {
                payload: {
                    aps: {
                        sound: 'default',
                        badge: 1,
                        category: type,
                        contentAvailable: true,
                    },
                },
                headers: {
                    'apns-priority': '10',
                },
            },

            // ─── Web (if needed later) ─────────────────────────
            webpush: {
                headers: { Urgency: 'high' },
                notification: {
                    title: content.title,
                    body: content.body,
                    icon: '/icon.png',
                },
            },
        };

        const response = await messaging.send(message);
        console.log(`✅ Push sent [${type}] to token ...${fcmToken.slice(-8)}`);
        return richResult ? { success: true } : true;

    } catch (error) {
        // ─── Handle invalid/expired tokens ────────────────
        if (
            error.code === 'messaging/invalid-registration-token' ||
            error.code === 'messaging/registration-token-not-registered'
        ) {
            console.warn(
                `⚠️ Push: Invalid FCM token ...${fcmToken.slice(-8)} - should be cleared`
            );
            return richResult 
                ? { success: false, status: 'invalid_token', error: error.message }
                : 'invalid_token';
        }

        console.error(`❌ Push error [${type}]:`, error.message);
        return richResult 
            ? { success: false, status: 'failed', error: error.message, code: error.code }
            : false;
    }
};


// ─────────────────────────────────────────────────────
// SEND TO MULTIPLE TOKENS (batch)
// ─────────────────────────────────────────────────────
const sendPushToMultiple = async ({
    fcmTokens,
    type,
    senderUsername,
    extra = {},
}) => {
    if (!fcmTokens || fcmTokens.length === 0) return;

    const messaging = getMessaging();
    if (!messaging) return;

    const content = getNotificationContent(type, senderUsername, extra);
    const data = getNotificationData(type, { ...extra, senderUsername });

    const message = {
        tokens: fcmTokens,
        notification: {
            title: content.title,
            body: content.body,
        },
        data: Object.fromEntries(
            Object.entries(data).map(([k, v]) => [k, String(v || '')])
        ),
        android: {
            priority: 'high',
            notification: {
                channelId: 'instagram_clone_channel',
                priority: 'high',
                clickAction: 'FLUTTER_NOTIFICATION_CLICK',
                color: '#0095F6',
            },
        },
        apns: {
            payload: {
                aps: { sound: 'default', badge: 1 },
            },
        },
    };

    try {
        const response = await messaging.sendEachForMulticast(message);
        console.log(
            `✅ Push multicast: ${response.successCount}/${fcmTokens.length} delivered`
        );
        return response;
    } catch (error) {
        console.error('❌ Push multicast error:', error.message);
    }
};

module.exports = {
    sendPushNotification,
    sendPushToMultiple,
    getNotificationContent,
};