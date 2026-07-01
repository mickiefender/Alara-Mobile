# Alara Flutter App - Configuration

## Environment Variables

Create a `.env` file in the root of the project with the following variables:

```
# Django Backend API
API_BASE_URL=http://your-django-backend.com/api

# Supabase Configuration
SUPABASE_URL=https://your-supabase-url.supabase.co
SUPABASE_ANON_KEY=your-supabase-anon-key

# App Configuration
APP_NAME=Alara
APP_VERSION=1.0.0
```

## Setup Instructions

### Prerequisites
- Flutter SDK (3.5.1 or higher)
- Dart SDK (3.5.1 or higher)
- Android Studio or Xcode (for running on emulator/device)

### Installation

1. **Clone or extract the project:**
   ```bash
   cd alara
   ```

2. **Get dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure API endpoints:**
   Update `lib/config/constants.dart` with your Django backend URL and Supabase credentials.

4. **Run the app:**
   ```bash
   flutter run
   ```

### Running on Different Platforms

**Android:**
```bash
flutter run -d android
```

**iOS:**
```bash
flutter run -d ios
```

**Web:**
```bash
flutter run -d chrome
```

## Project Structure

```
alara/
├── lib/
│   ├── config/          # App configuration (theme, constants, API)
│   ├── models/          # Data models
│   ├── services/        # API and authentication services
│   ├── providers/       # State management (Provider)
│   ├── screens/         # UI screens organized by role
│   ├── widgets/         # Reusable widgets
│   └── main.dart        # App entry point
├── pubspec.yaml         # Project dependencies
└── README.md            # This file
```

## API Integration

The app communicates with a Django backend. Ensure your backend has the following endpoints:

### Authentication
- `POST /auth/login/` - User login
- `POST /auth/logout/` - User logout

### User
- `GET /users/{id}/` - Get user profile
- `PUT /users/{id}/` - Update user profile

### Attendance
- `GET /attendance/?class_id=X` - Get attendance records
- `POST /attendance/mark/` - Mark attendance
- `GET /attendance/student/{id}/` - Get student attendance

### Assignments
- `GET /assignments/?class_id=X` - Get assignments
- `POST /assignments/create/` - Create assignment
- `POST /assignments/submit/` - Submit assignment

### Other endpoints for timetable, announcements, messages, performance, and materials.

## Features

### Teacher Features
- Mark daily attendance
- AI question generator
- Upload assignments & learning materials
- Track student performance
- Manage class timetable
- Communication with students/admin
- Record student assignments

### Student Features
- View timetable & class schedule
- Check results & report card
- Submit online assignments
- Access learning materials
- Track attendance record
- Receive announcements
- View fee/payment status

## Development

### Code Standards
- Use consistent naming conventions
- Create separate models for different entities
- Use providers for state management
- Keep screens focused and modular

### Adding New Features
1. Create model in `lib/models/`
2. Add API methods in `lib/services/api_service.dart`
3. Add provider methods if needed
4. Create screen in appropriate folder
5. Add route in `main.dart`

### Troubleshooting

**Dependencies not installed:**
```bash
flutter pub get
flutter pub upgrade
```

**Build cache issues:**
```bash
flutter clean
flutter pub get
flutter run
```

## Contact & Support

For issues or questions about the implementation, please reach out to the development team.
