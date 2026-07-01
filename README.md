# Alara - School Management App

A Flutter mobile application for school management designed for teachers and students. This app provides role-based access to school management features, with Django backend and Supabase database integration.

## 🎯 Overview

Alara is a comprehensive school management system with dedicated interfaces for:
- **Teachers**: Manage attendance, assignments, student performance, and communicate with students
- **Students**: View schedules, check results, submit assignments, and access learning materials

## ✨ Features

### Teacher Features
- 📋 **Mark Daily Attendance** - Quick attendance marking for classes
- 🤖 **AI Question Generator** - Automatically generate questions for assessments
- 📚 **Assignment Upload & Learning Materials** - Share educational content with students
- 📊 **Student Performance Tracking** - Monitor and analyze student progress
- 🕐 **Class Timetable Management** - Create and manage class schedules
- 💬 **Communication Screen** - Direct messaging with students and administrators
- 📝 **Record Student Assignments** - Track assignment submissions and scores

### Student Features
- 📅 **View Timetable & Class Schedule** - Check daily class schedule
- 📈 **Check Results & Report Card** - View academic performance and report cards
- ✍️ **Submit Online Assignment** - Upload and submit completed assignments
- 📖 **Access Learning Materials** - Download and access course materials
- ✅ **Track Attendance Record** - View personal attendance statistics
- 📢 **Receive Announcements** - Get important notifications from school
- 💳 **View Fee/Payment Status** - Check payment and fee information

## 🏗️ Architecture

### Project Structure
```
alara/
├── lib/
│   ├── config/              # Configuration files
│   │   ├── constants.dart
│   │   ├── theme.dart
│   │   └── api_config.dart
│   ├── models/              # Data models
│   ├── services/            # API and auth services
│   ├── providers/           # State management
│   ├── screens/             # UI screens
│   │   ├── auth/
│   │   ├── teacher/
│   │   └── student/
│   ├── widgets/             # Reusable widgets
│   └── main.dart
├── pubspec.yaml
└── README.md
```

### Technology Stack
- **Frontend**: Flutter (Dart)
- **State Management**: Provider
- **Networking**: Dio
- **Backend**: Django (REST API)
- **Database**: Supabase
- **Authentication**: JWT Tokens
- **File Storage**: Supabase Storage

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.5.1+
- Dart SDK 3.5.1+
- Android Studio or Xcode
- Django backend running

### Installation

1. **Clone the repository**
   ```bash
   cd alara
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure API endpoints**
   - Open `lib/config/constants.dart`
   - Update `apiBaseUrl`, `supabaseUrl`, and `supabaseAnonKey`

4. **Run the app**
   ```bash
   flutter run
   ```

## 📱 How to Use

### Login
1. Launch the app
2. Enter email and password
3. App automatically routes to Teacher or Student dashboard based on role

### Teacher Dashboard
- Quick access to all 7 features via grid cards
- Bottom navigation for main sections
- Logout option in app bar

### Student Dashboard
- Quick access to all 8 features via grid cards
- Bottom navigation for main sections
- Logout option in app bar

## 🔐 Authentication

The app uses JWT (JSON Web Tokens) for authentication:
1. User logs in with email/password
2. Backend returns JWT token
3. Token stored locally using SharedPreferences
4. Token sent with all API requests
5. Automatic logout on token expiration

## 📡 API Integration

### Example Login Flow
```dart
// Login request
POST /auth/login/
{
  "email": "teacher@example.com",
  "password": "password"
}

// Response
{
  "token": "jwt_token_here",
  "user": {
    "id": "user_id",
    "email": "teacher@example.com",
    "name": "Teacher Name",
    "role": "teacher"
  }
}
```

## 🎨 Theme & Styling

The app uses Material Design 3 with custom colors:
- **Primary**: Green (#2E7D32)
- **Secondary**: Blue (#1976D2)
- **Accent**: Orange (#FF9800)
- **Background**: Light Gray (#F5F5F5)

## 📦 Dependencies

Key packages used:
- `provider: ^6.0.0` - State management
- `dio: ^5.3.1` - HTTP client
- `supabase_flutter: ^1.10.0` - Backend & authentication
- `go_router: ^13.0.0` - Routing
- `shared_preferences: ^2.2.0` - Local storage
- `image_picker: ^1.0.0` - File selection
- `cached_network_image: ^3.3.0` - Image caching
- `intl: ^0.19.0` - Internationalization

See `pubspec.yaml` for complete dependencies list.

## 🔄 State Management

The app uses the Provider pattern for state management:
- `AuthProvider` - Handles authentication and user session
- `TeacherProvider` - Manages teacher-specific data
- `StudentProvider` - Manages student-specific data

Example:
```dart
context.read<AuthProvider>().login(email, password);
```

## 📋 Future Enhancements

- Offline mode support
- Real-time notifications using Firebase Cloud Messaging
- Dark theme support
- Multi-language support
- Student parent portal
- Admin web dashboard
- Performance analytics
- Video content support

## 🐛 Troubleshooting

### Common Issues

**"Cannot connect to backend"**
- Check Django server is running
- Verify API URL in constants.dart
- Check internet connection

**"Dependencies not installing"**
```bash
flutter clean
flutter pub get
```

**"App crashes on startup"**
- Clear app data
- Reinstall: `flutter clean && flutter run`
- Check console logs for errors

## 📝 Development Guidelines

### Adding a New Feature
1. Create data model in `lib/models/`
2. Add API methods in `lib/services/api_service.dart`
3. Add provider methods if needed
4. Create UI screen
5. Add route in `main.dart`
6. Update navigation

### Code Style
- Use meaningful variable names
- Add comments for complex logic
- Keep functions small and focused
- Use const constructors where possible

## 📄 License

This project is private and confidential.

## 👥 Support

For support, reach out to the development team.

---

**Version**: 1.0.0  
**Created**: 2024  
**Last Updated**: 2024
