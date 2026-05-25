# StudyMate

A beautiful, offline-first student productivity planner app built with Flutter.

## Features

- **Organize Everything:** Manage classes, grades, and subjects in one place.
- **Never Miss a Beat:** Smart reminders for assignments and exams.
- **Precision Alerts:** Set precise alarms for your deadlines.
- **Offline-First:** All your data is stored locally on your device.
- **StudyMate Website:** A promotional landing page is included in the `/website` directory.

## Getting Started

### Prerequisites

- Flutter SDK
- Android Studio / VS Code

### Running the App

1. Clone the repository.
2. Run `flutter pub get`.
3. Run `flutter run`.

### Web Support

The app is compatible with Flutter Web. To set up the database binaries for web, run:

```bash
dart run sqflite_common_ffi_web:setup
```

Then run:

```bash
flutter run -d chrome
```

## Promotional Website

The promotional website can be found in the `website/` directory. Open `website/index.html` in any browser to view it.

## Release Builds

```bash
flutter build apk --release
flutter build web --release
```

The release APK is generated at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Copy the release APK to `web/StudyMate.apk` when updating the public download link.

## Deploy Web To Vercel

Build the web app first, then deploy the generated static output:

```bash
flutter build web --release
cd build/web
vercel . --prod --yes
```

If Vercel gives you a generated deployment URL, alias that deployment to the public domain:

```bash
vercel alias set <deployment-url> studymates-app.vercel.app
```

`web/vercel.json` is copied into `build/web` during the Flutter build so Vercel serves Flutter routes through `index.html`.

# Push to Github

```bash
git add .
git commit -m "commit message"
git push origin Vincent
```

vercel project ls
