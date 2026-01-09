# Kerala Private Bus Tracker 🚌

A comprehensive mobile application for tracking and managing Kerala's private bus services. Built with Flutter and Supabase, this app provides real-time bus tracking, route search, and fleet management capabilities.

## 👥 Team Members

This is a college project developed by:

- **Eldho Eapen**
- **Aswin Unnikrishnan**
- **Adithyan EV**
- **Nayana C Jayan**

## ✨ Features

### For Passengers (User App)
- 🗺️ **Real-time Bus Tracking** - Live GPS tracking with smooth location updates
- 🔍 **Route Search** - Find buses by source and destination stops
- ⭐ **Favorites** - Save frequently used buses for quick access
- 📜 **Trip History** - View past journeys
- 🎓 **Student Pass** - Apply for student concessions with ID verification
- 💬 **In-app Chat** - Communicate with bus conductors
- ⏱️ **ETA Calculation** - Estimated arrival times based on live location
- 🆘 **SOS Alerts** - Emergency alert system for passenger safety

### For Conductors
- 📍 **GPS Sharing** - Share live bus location with passengers
- 🔄 **Availability Toggle** - Mark bus as available/unavailable
- 📊 **Delay Reporting** - Report delays with reasons
- 🛠️ **Maintenance Reports** - Submit repair and fuel reports
- 💬 **Passenger Messaging** - Respond to passenger queries

### For Administrators (Web Panel)
- 📈 **Dashboard** - Overview of fleet statistics
- 🚌 **Bus Management** - Add, edit, delete buses
- 👤 **Conductor Management** - Manage conductor accounts
- 🛤️ **Route Management** - Create and manage routes with stops
- 📅 **Shift Scheduling** - Assign conductors to buses and routes
- 🔔 **SOS Monitoring** - Real-time emergency alert monitoring
- 📊 **Analytics** - Performance and usage analytics

## 🛠️ Technology Stack

| Category | Technology |
|----------|------------|
| **Frontend** | Flutter (Dart) |
| **Backend** | Supabase (PostgreSQL + Realtime) |
| **Maps** | flutter_map (OpenStreetMap) |
| **Location** | Geolocator, Geocoding |
| **State Management** | Provider |
| **Authentication** | Demo (public.users table) |
| **Notifications** | Flutter Local Notifications |

## 📋 Prerequisites

- Flutter SDK (^3.10.3)
- Dart SDK
- Supabase account
- Android Studio / VS Code
- Git

## 🚀 Getting Started

### 1. Clone the Repository
```bash
git clone https://github.com/your-username/kerala-private-bus-tracker.git
cd kerala-private-bus-tracker
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Configure Environment
Create a `.env` file in the project root:
```env
SUPABASE_URL=your_supabase_project_url
SUPABASE_KEY=your_supabase_anon_key
```

### 4. Run the Application
```bash
# For mobile (Android/iOS)
flutter run

# For web (Admin panel)
flutter run -d chrome
```

## 📁 Project Structure

```
lib/
├── main.dart              # App entry point
├── app_theme.dart         # Theme configuration
├── config/                # Configuration files
├── models/                # Data models (16 models)
├── screens/               # UI screens
│   ├── admin/             # Admin panel screens
│   ├── auth/              # Authentication screens
│   ├── conductor/         # Conductor app screens
│   └── user/              # Passenger app screens
├── services/              # Business logic & API services
├── shared/                # Shared utilities
└── widgets/               # Reusable UI components
```

## 📖 Documentation

Detailed documentation is available in the [`docs/`](./docs/) folder:

- [Project Overview](./docs/overview.md)
- [System Architecture](./docs/architecture.md)
- [Database Schema](./docs/database.md)
- [Features Guide](./docs/features.md)
- [API Reference](./docs/api.md)
- [Setup Guide](./docs/setup.md)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

<p align="center">
  Made with ❤️ in Kerala, India
</p>
