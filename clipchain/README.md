# ClipChain

A Flutter application for creating and charing videos.

## Features

- 🔐 Secure user authentication with Firebase

## Getting Started

### Prerequisites

- Flutter SDK (latest stable version)
- Firebase account
- Android Studio / VS Code with Flutter extensions

### Setup

1. Clone the repository:
   ```bash
   git clone [your-repository-url]
   cd clipchain
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Firebase Setup:
   - Create a new Firebase project
   - Add Android and iOS apps in Firebase console
   - Download and place the configuration files:
     - Android: `google-services.json` in `android/app/`
     - iOS: `GoogleService-Info.plist` in `ios/Runner/`
   - Enable Email/Password authentication in Firebase Console

4. Run the app:
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── main.dart              # App entry point
├── providers/
│   └── auth_provider.dart # Authentication state management
├── screens/
│   ├── home_screen.dart   # Main app screen
│   ├── login_screen.dart  # User login
│   └── signup_screen.dart # User registration
└── services/
    └── auth_service.dart  # Firebase authentication service
```

## Development

### Architecture
- Provider pattern for state management
- Service-based architecture for business logic
- Firebase for backend services

### Code Style
This project follows the official [Flutter style guide](https://dart.dev/guides/language/effective-dart/style).

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
