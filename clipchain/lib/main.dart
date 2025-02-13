import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:media_kit/media_kit.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'firebase_options.dart';
import 'providers/index.dart';
import 'providers/chain_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/profile_screen.dart';
import 'config/cloudinary_config.dart';
import 'app_data_initializer.dart';
import 'providers/video_player_provider.dart';
import 'services/media_kit_player_impl.dart';
import 'global.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    print('Loading environment variables...');
    await dotenv.load(fileName: '.env');
    print('Environment variables loaded. Available keys: ${dotenv.env.keys}');
    
    // Initialize MediaKit
    MediaKit.ensureInitialized();
    print('MediaKit initialized');
    
    // Initialize Firebase first
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized successfully');

    // Configure Firebase Functions for production
    final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
    print('Firebase Functions configured for us-central1');
    
    // Initialize Cloudinary
    await CloudinaryConfig.initialize();
    print('All services initialized successfully');
    
    runApp(const App());
  } catch (e, stackTrace) {
    print('Error during app initialization: $e');
    print('Stack trace: $stackTrace');
    rethrow;
  }
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => VideoProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => LikesProvider()),
        ChangeNotifierProvider(create: (_) => ChainProvider()),
        ChangeNotifierProvider(
          create: (_) => VideoPlayerProvider(
            factory: MediaKitVideoPlayerFactory(),
          ),
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'ClipChain',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const AppDataInitializer(
            child: AuthWrapper(),
          ),
          '/signup': (context) => const SignupScreen(),
          '/profile': (context) {
            final userId = ModalRoute.of(context)?.settings.arguments as String?;
            return ProfileScreen(userId: userId);
          },
          '/feed': (context) {
            final videoId = ModalRoute.of(context)?.settings.arguments as String?;
            return HomeScreen(initialVideoId: videoId);
          },
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // Simply return the appropriate screen based on auth state
        // No navigation needed here as this wrapper will rebuild when auth state changes
        if (authProvider.isAuthenticated) {
          return const HomeScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
