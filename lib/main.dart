import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'features/chat/screens/chat_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/sign_input/screens/sign_input_screen.dart';
import 'services/sign_language_service.dart';
import 'shared/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Request Camera Permission on startup for the prototype
  await Permission.camera.request();
  
  // Lock orientation to portrait
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const SignChatApp());
}

class SignChatApp extends StatelessWidget {
  const SignChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<SignLanguageService>(
          create: (_) => SignLanguageService(),
        ),
      ],
      child: MaterialApp.router(
        title: 'SignChat',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: _router,
      ),
    );
  }
}

final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
      routes: [
        GoRoute(
          path: 'chat/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            final name = state.uri.queryParameters['name'];
            return ChatScreen(id: id, name: name);
          },
        ),
         GoRoute(
          path: 'sign-input',
          builder: (context, state) => const SignInputScreen(),
        ),
      ],
    ),
  ],
);
