// scratch/test_fcm_endpoint.js
const TOKEN = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6ImFiNWVhOWY2LWMzOGQtNGZjZS1iZGM3LWJkOWFkNGI4ZTUwNCIsInVzZXJuYW1lIjoiam9obl9kb2UzIiwiaWF0IjoxNzc3NzkzMjUyLCJleHAiOjE3Nzc3OTY4NTJ9.SQ7rFnof997MpPdqIqEZltrXUvI0V1c3D1h7iv4UM18';
const BASE_URL = 'http://127.0.0.1:5000/api/v1';

async function test() {
  try {
    console.log('Testing SAVE FCM token...');
    const saveRes = await fetch(`${BASE_URL}/users/fcm-token`, {
      method: 'PUT',
      headers: { 
        'Authorization': `Bearer ${TOKEN}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ fcmToken: 'fake-test-token-1234567890' })
    });
    console.log('Save Status:', saveRes.status);
    console.log('Save Response:', await saveRes.json());

    console.log('\nTesting CLEAR FCM token...');
    const clearRes = await fetch(`${BASE_URL}/users/fcm-token`, {
      method: 'DELETE',
      headers: { 'Authorization': `Bearer ${TOKEN}` }
    });
    console.log('Clear Status:', clearRes.status);
    console.log('Clear Response:', await clearRes.json());

  } catch (error) {
    console.error('Error during test:', error.message);
  }
}

test();
