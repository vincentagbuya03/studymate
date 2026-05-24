# Firebase Setup

1. Create a Firebase project, then enable Email/Password sign-in in Firebase Auth.
2. Create a Cloud Firestore database.
3. Install FlutterFire CLI if needed:

```bash
dart pub global activate flutterfire_cli
```

4. Configure this app from the repo root:

```bash
flutterfire configure
```

Let it overwrite `lib/firebase_options.dart` with the real project values and generate the native Firebase config files.

5. Deploy Firestore rules:

```bash
firebase deploy --only firestore:rules
```

## Make Yourself Admin

Use a one-time trusted environment with Firebase Admin SDK credentials. Replace the UID with your Firebase Auth user UID:

```js
const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
});

async function main() {
  await admin.auth().setCustomUserClaims('YOUR_UID', { admin: true });
  console.log('Admin claim set.');
}

main().catch(console.error);
```

Sign out and back in so the client receives a fresh ID token. The web admin route is `/admin`; it is only registered on Flutter web and Firestore rules require `admin=true` for listing users or toggling `disabled`.

## Data Layout

Planner data is stored under each user:

- `users/{uid}/subjects/{subjectId}`
- `users/{uid}/assignments/{assignmentId}`
- `users/{uid}/exams/{examId}`
- `users/{uid}/grades/{gradeId}`

Firestore offline persistence is enabled by the app. Mobile and desktop clients can read cached planner data offline and queue writes until connectivity returns.
