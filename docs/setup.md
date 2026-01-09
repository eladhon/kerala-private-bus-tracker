# Setup Guide

Complete guide to setting up the Kerala Private Bus Tracker development environment.

## Prerequisites

### Required Software

| Software | Version | Purpose |
|----------|---------|---------|
| Flutter SDK | 3.10.3+ | Framework |
| Dart SDK | 3.0+ | Language |
| Git | Latest | Version control |
| VS Code / Android Studio | Latest | IDE |
| Android SDK | API 21+ | Android builds |
| Xcode | 14+ | iOS builds (macOS only) |
| Chrome | Latest | Web builds |

### Accounts Required

- **Supabase** - Free account at [supabase.com](https://supabase.com)

---

## Installation Steps

### 1. Clone Repository

```bash
git clone https://github.com/your-username/kerala-private-bus-tracker.git
cd kerala-private-bus-tracker
```

### 2. Install Flutter Dependencies

```bash
flutter pub get
```

### 3. Verify Flutter Setup

```bash
flutter doctor
```

Ensure all checks pass, especially:
- ✓ Flutter
- ✓ Android toolchain
- ✓ Chrome (for web)
- ✓ VS Code / Android Studio

---

## Supabase Configuration

### 1. Create Supabase Project

1. Go to [supabase.com](https://supabase.com)
2. Create new project
3. Note your **Project URL** and **anon/public key**

### 2. Database Setup

Run the following SQL in the Supabase SQL Editor:

> [!CAUTION]
> The full schema is in `docs/database.md`. Ensure you create all tables with proper constraints and RLS policies.

```sql
-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- Create tables (see docs/database.md for full schema)
-- Users, buses, routes, etc.
```

### 3. Enable Row Level Security

```sql
-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE buses ENABLE ROW LEVEL SECURITY;
ALTER TABLE routes ENABLE ROW LEVEL SECURITY;
-- ... repeat for all tables
```

### 4. Demo Authentication

> [!NOTE]
> This is a demo app. No Supabase Auth configuration required. Users are stored directly in the `public.users` table.

---

## Environment Configuration

### 1. Create `.env` File

Create `.env` in the project root:

```env
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
```

> [!WARNING]
> Never commit `.env` to version control. It's already in `.gitignore`.

### 2. Verify `.env` is in Assets

Check `pubspec.yaml`:

```yaml
flutter:
  assets:
    - .env
```

---

## Running the Application

### Android

```bash
# Connect device or start emulator
flutter devices

# Run on Android
flutter run
```

### iOS (macOS only)

```bash
cd ios
pod install
cd ..
flutter run -d ios
```

### Web (Admin Panel)

```bash
flutter run -d chrome
```

### All Platforms

```bash
# List available devices
flutter devices

# Run on specific device
flutter run -d <device-id>
```

---

## Build for Production

### Android APK

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Android App Bundle

```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### iOS (macOS only)

```bash
flutter build ios --release
# Open in Xcode for archive/distribution
```

### Web

```bash
flutter build web --release
# Output: build/web/
```

---

## Development Workflow

### Code Analysis

```bash
flutter analyze
```

### Run Tests

```bash
flutter test
```

### Hot Reload (Development)

While app is running:
- Press `r` for hot reload
- Press `R` for hot restart

---

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| `.env` not loading | Ensure it's listed in pubspec.yaml assets |
| Supabase connection failed | Check URL and key in `.env` |
| Location permission denied | Grant permissions in device settings |
| Build fails on iOS | Run `pod install` in ios/ folder |
| Map tiles not loading | Check internet connection |

### Reset Dependencies

```bash
flutter clean
flutter pub get
```

### Debug Logging

```dart
import 'package:flutter/foundation.dart';
debugPrint('Debug message');
```

---

## Project Configuration Files

| File | Purpose |
|------|---------|
| `pubspec.yaml` | Dependencies and assets |
| `analysis_options.yaml` | Linting rules |
| `.env` | Environment variables |
| `android/app/build.gradle` | Android config |
| `ios/Runner.xcodeproj` | iOS config |

---

## Deployment Notes

### Admin Panel Hosting

The web build can be hosted on:
- Supabase Hosting
- Vercel
- Netlify
- Firebase Hosting

### Mobile Distribution

- **Android**: Google Play Store or direct APK
- **iOS**: App Store Connect (Apple Developer Program required)

---

*For feature documentation, see [Features Guide](./features.md)*
