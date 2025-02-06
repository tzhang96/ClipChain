import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/index.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'config/cloudinary_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    print('Initializing app...');
    
    // Initialize Firebase first
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized successfully');
    
    // Initialize Cloudinary
    await CloudinaryConfig.initialize();
    print('All services initialized successfully');
    
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => VideoProvider()),
          ChangeNotifierProvider(create: (_) => UserProvider()),
          ChangeNotifierProvider(
            create: (context) {
              final likesProvider = LikesProvider();
              likesProvider.initialize(context.read<VideoProvider>());
              return likesProvider;
            },
          ),
        ],
        child: const MyApp(),
      ),
    );
  } catch (e) {
    print('Error during app initialization: $e');
    // You may want to show an error screen here instead of crashing
    rethrow;
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void reassemble() {
    super.reassemble();
    // Reinitialize Cloudinary on hot reload
    CloudinaryConfig.reinitialize().then((_) {
      print('Cloudinary reinitialized after hot reload');
    }).catchError((error) {
      print('Error reinitializing Cloudinary after hot reload: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        title: 'ClipChain',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const AuthWrapper(),
        routes: {
          '/signup': (context) => const SignupScreen(),
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
        if (authProvider.isAuthenticated) {
          return const HomeScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
