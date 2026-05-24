const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.cert(
    require('./studymate-6ee53-firebase-adminsdk-fbsvc-bc7f3f18b0.json'),
  ),
});

async function makeAdmin() {
  await admin.auth().setCustomUserClaims(
    'irG83CEEz8QoLRYa0LqdUcpJmvC3',
    { admin: true },
  );
  console.log('Admin claim set for irG83CEEz8QoLRYa0LqdUcpJmvC3');
}

makeAdmin().catch((error) => {
  console.error('Failed to set admin claim:', error);
  process.exitCode = 1;
});
