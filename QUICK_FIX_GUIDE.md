# Quick Fix Guide - Message Sending Error

## 🚀 Immediate Actions (Do These First!)

### 1. Restart Your Backend Server
The code changes need a server restart to take effect.

**If running locally**:
```bash
cd server
# Stop the current server (Ctrl+C)
npm start
```

**If on Render.com**:
1. Go to https://dashboard.render.com
2. Find your service: `instagram-clone-im0x`
3. Click "Manual Deploy" → "Deploy latest commit"
4. Wait for deployment to complete (~2-3 minutes)

### 2. Test the Debug Endpoint
Replace `YOUR_TOKEN` with your actual auth token:

```bash
curl -X GET \
  "https://instagram-clone-im0x.onrender.com/api/v1/conversations/02672f60-929e-492d-9ac8-499f3631b0f9/debug" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

**Or test in your Flutter app** by adding this temporary code:

```dart
// In chat_api.dart or anywhere with dio instance
Future<void> debugConversation(String conversationId) async {
  try {
    final response = await _dio.get('/conversations/$conversationId/debug');
    print('🔍 DEBUG RESPONSE: ${response.data}');
  } catch (e) {
    print('❌ DEBUG ERROR: $e');
  }
}
```

### 3. Check the Debug Response

**✅ GOOD Response** (Everything is OK):
```json
{
  "success": true,
  "debug_info": {
    "conversation": { "exists": true },
    "participant": { "exists": true, "is_active": true },
    "user": { "exists": true },
    "database": { "connected": true }
  }
}
```

**❌ BAD Response** (Problem Found):
```json
{
  "success": true,
  "debug_info": {
    "conversation": { "exists": true },
    "participant": { "exists": false },  // ← PROBLEM HERE!
    ...
  }
}
```

### 4. Fix Based on Debug Response

#### Problem: `participant.exists: false`
**You're not a participant in this conversation**

**Quick Fix** (Run in your PostgreSQL database):
```sql
-- Replace with your actual IDs
INSERT INTO conversation_participants (
  id, 
  conversation_id, 
  user_id, 
  joined_at, 
  created_at, 
  updated_at
)
VALUES (
  gen_random_uuid(),
  '02672f60-929e-492d-9ac8-499f3631b0f9',  -- conversation ID
  '913beb2c-083f-415d-8dc8-0362g4ea6b702', -- your user ID
  NOW(),
  NOW(),
  NOW()
);
```

#### Problem: `conversation.exists: false`
**The conversation doesn't exist**

**Quick Fix**: Create a new conversation from the Flutter app or check if you're using the correct conversation ID.

#### Problem: `database.connected: false`
**Database connection issue**

**Quick Fix**: Check your `.env` file:
```env
DATABASE_URL=postgresql://username:password@host:port/database
```

Test connection:
```bash
psql $DATABASE_URL -c "SELECT 1;"
```

### 5. Try Sending a Message
After fixing the issue, try sending a message from your Flutter app.

### 6. Check Server Logs
Look for these log messages in your server console:

**✅ Success**:
```
📨 Send message request: { ... }
👤 Participant check: { found: true }
💾 Creating message in database...
✅ Message created: abc-123
🔍 Fetching full message with associations...
✅ Full message fetched successfully
💬 Message sent in conversation ...
```

**❌ Error**:
```
📨 Send message request: { ... }
❌ Send message error: <actual error message>
Error details: { message: '...', name: '...', stack: '...' }
```

## 📋 Quick Checklist

- [ ] Backend server restarted
- [ ] Debug endpoint tested
- [ ] Debug response shows all `true` values
- [ ] If participant issue: Added user to conversation_participants table
- [ ] Message send attempted from Flutter app
- [ ] Server logs checked

## 🆘 Still Not Working?

### Get Your Conversation ID
In your Flutter app, add this log:
```dart
// In chat_page.dart
print('🔍 Current conversation ID: ${widget.conversationId}');
```

### Get Your User ID
```dart
// In your auth provider or wherever you have user info
print('🔍 Current user ID: ${currentUser.id}');
```

### Check Server Logs on Render.com
1. Go to https://dashboard.render.com
2. Click on your service
3. Click "Logs" tab
4. Look for the emoji logs: 📨, 👤, 💾, ✅, ❌

### Test with cURL
Replace with your actual values:
```bash
curl -X POST \
  "https://instagram-clone-im0x.onrender.com/api/v1/conversations/YOUR_CONVERSATION_ID/messages" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"content": "test message", "message_type": "text"}'
```

## 📞 Need More Help?

Provide these details:
1. ✅ Debug endpoint response (full JSON)
2. ✅ Server logs (the emoji logs)
3. ✅ Your conversation ID
4. ✅ Your user ID
5. ✅ Error message from Flutter app

## 📚 Detailed Guides

- `MESSAGE_SEND_FIX_SUMMARY.md` - Complete fix summary
- `server/TROUBLESHOOTING_MESSAGE_ERROR.md` - Detailed troubleshooting

---

**TIP**: The most common issue is that the user is not added to the `conversation_participants` table. Check that first!
