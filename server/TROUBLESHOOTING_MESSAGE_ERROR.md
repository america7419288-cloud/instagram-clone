# Troubleshooting: Message Sending 500 Error

## Problem
Client receives `500 Internal Server Error` when sending messages with error message: "Failed to send message."

## Error Details from Client Log
```
POST https://instagram-clone-im0x.onrender.com/api/v1/conversations/02672f60-929e-492d-9ac8-499f3631b0f9/messages
Status: 500 Internal Server Error

Request Body:
{
  "content": "67",
  "message_type": "text",
  "temp_id": 1779242607678
}

Response:
{
  "success": false,
  "message": "Failed to send message.",
  "timestamp": "2026-05-20T02:03:29.933Z"
}
```

## Changes Made

### 1. Enhanced Error Logging
Added detailed logging to `conversation.controller.js` `sendMessage` function:

- **Request logging**: Logs conversation ID, sender ID, content preview, message type, and temp_id
- **Participant check logging**: Confirms if user is a valid participant
- **Message creation logging**: Confirms database insert
- **Association fetch logging**: Confirms full message retrieval with relations
- **Detailed error logging**: Logs error message, stack trace, and error name

### 2. Improved Error Response
Changed the generic error response to include the actual error message:
```javascript
return errorResponse(res, 500, `Failed to send message: ${error.message}`);
```

## How to Diagnose

### Step 1: Check Server Console Logs
After the changes, when you try to send a message, the server console will show:

```
📨 Send message request: {
  conversationId: '02672f60-929e-492d-9ac8-499f3631b0f9',
  senderId: '913beb2c-083f-415d-8dc8-0362g4ea6b702',
  content: '67',
  message_type: 'text',
  temp_id: 1779242607678
}
👤 Participant check: { found: true }
💾 Creating message in database...
✅ Message created: <message-id>
🔍 Fetching full message with associations...
✅ Full message fetched successfully
💬 Message sent in conversation 02672f60-929e-492d-9ac8-499f3631b0f9
```

**If the error occurs**, you'll see which step failed and the detailed error:
```
❌ Send message error: <Error object>
Error details: {
  message: 'Actual error message here',
  stack: '...',
  name: 'SequelizeError' (or other error type)
}
```

### Step 2: Common Issues and Solutions

#### Issue 1: Participant Not Found
**Log shows**: `👤 Participant check: { found: false }`

**Solution**: The user is not a participant in the conversation. Check:
```sql
SELECT * FROM conversation_participants 
WHERE conversation_id = '02672f60-929e-492d-9ac8-499f3631b0f9' 
AND user_id = '913beb2c-083f-415d-8dc8-0362g4ea6b702';
```

If no record exists, add the participant:
```sql
INSERT INTO conversation_participants (id, conversation_id, user_id, joined_at, created_at, updated_at)
VALUES (uuid_generate_v4(), '02672f60-929e-492d-9ac8-499f3631b0f9', '913beb2c-083f-415d-8dc8-0362g4ea6b702', NOW(), NOW(), NOW());
```

#### Issue 2: Conversation Doesn't Exist
**Error**: `conversation_id foreign key constraint fails`

**Solution**: Verify the conversation exists:
```sql
SELECT * FROM conversations WHERE id = '02672f60-929e-492d-9ac8-499f3631b0f9';
```

#### Issue 3: User Doesn't Exist
**Error**: `sender_id foreign key constraint fails`

**Solution**: Verify the user exists:
```sql
SELECT * FROM users WHERE id = '913beb2c-083f-415d-8dc8-0362g4ea6b702';
```

#### Issue 4: Association Loading Error
**Log shows**: Error occurs at "🔍 Fetching full message with associations..."

**Possible causes**:
- Missing model associations in `models/index.js`
- Database table structure mismatch
- Missing foreign key columns

**Solution**: Check that all associations are properly defined:
```javascript
// In models/index.js
Message.belongsTo(User, { foreignKey: 'sender_id', as: 'sender' });
Message.belongsTo(Message, { foreignKey: 'reply_to_message_id', as: 'repliedTo' });
Message.belongsTo(Post, { foreignKey: 'shared_post_id', as: 'sharedPost' });
Message.belongsTo(Reel, { foreignKey: 'shared_post_id', as: 'sharedReel' });
Message.belongsTo(Story, { foreignKey: 'shared_post_id', as: 'sharedStory' });
```

#### Issue 5: Socket.IO Not Initialized
**Error**: `Cannot read property 'to' of undefined`

**Solution**: Ensure Socket.IO is properly initialized in `app.js`:
```javascript
const io = require('socket.io')(server);
app.set('io', io);
```

#### Issue 6: Database Connection Issue
**Error**: `Connection refused` or `ECONNREFUSED`

**Solution**: Check database connection in `.env`:
```env
DATABASE_URL=postgresql://user:password@host:port/database
```

Test connection:
```javascript
const { sequelize } = require('./config/database');
sequelize.authenticate()
  .then(() => console.log('✅ Database connected'))
  .catch(err => console.error('❌ Database connection failed:', err));
```

### Step 3: Test with Minimal Request

Try sending a message with minimal data to isolate the issue:

```bash
curl -X POST \
  https://instagram-clone-im0x.onrender.com/api/v1/conversations/02672f60-929e-492d-9ac8-499f3631b0f9/messages \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"content": "test", "message_type": "text"}'
```

**Note**: Remove `temp_id` from the request to see if that's causing issues.

### Step 4: Check Database Schema

Verify the messages table has all required columns:
```sql
\d messages
```

Expected columns:
- `id` (UUID, primary key)
- `conversation_id` (UUID, foreign key)
- `sender_id` (UUID, foreign key)
- `content` (TEXT, nullable)
- `media_url` (VARCHAR, nullable)
- `message_type` (ENUM)
- `shared_post_id` (UUID, nullable)
- `reply_to_message_id` (UUID, nullable)
- `is_deleted` (BOOLEAN)
- `deleted_at` (TIMESTAMP, nullable)
- `created_at` (TIMESTAMP)
- `updated_at` (TIMESTAMP)

## Quick Fix Checklist

1. ✅ **Enhanced logging added** - Server will now show detailed error information
2. ⏳ **Check server logs** - Look for the specific error message
3. ⏳ **Verify conversation exists** - Check database
4. ⏳ **Verify user is participant** - Check conversation_participants table
5. ⏳ **Test database connection** - Ensure PostgreSQL is accessible
6. ⏳ **Check Socket.IO initialization** - Verify in app.js
7. ⏳ **Review environment variables** - Ensure all required vars are set

## Next Steps

1. **Restart the server** to apply the logging changes
2. **Try sending a message** from the Flutter app
3. **Check the server console** for the detailed logs
4. **Share the error details** from the server logs for further diagnosis

## Additional Debugging

If the issue persists, add this temporary debugging endpoint:

```javascript
// In conversation.routes.js
router.get('/conversations/:id/debug', authenticateToken, async (req, res) => {
  const { id } = req.params;
  const userId = req.user.id;
  
  const conversation = await Conversation.findByPk(id);
  const participant = await ConversationParticipant.findOne({
    where: { conversation_id: id, user_id: userId }
  });
  
  res.json({
    conversation: conversation ? 'exists' : 'not found',
    participant: participant ? 'is participant' : 'not participant',
    userId,
    conversationId: id,
  });
});
```

Test with:
```
GET /api/v1/conversations/02672f60-929e-492d-9ac8-499f3631b0f9/debug
```

## Contact Points

If you need further assistance, provide:
1. Server console logs (with the new detailed logging)
2. Database schema for `messages` table
3. Result of the debug endpoint
4. PostgreSQL version and connection status
