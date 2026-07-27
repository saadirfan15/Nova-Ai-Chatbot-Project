import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'screens/chat_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const AiChatbotApp());
}

class MyApp extends AiChatbotApp {
  const MyApp({super.key});
}

class AiChatbotApp extends StatelessWidget {
  const AiChatbotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: MaterialApp(
        title: 'ai_chatbot',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme(),
        routes: {
          '/login': (_) => const LoginScreen(),
          '/register': (_) => const RegisterScreen(),
          '/chat': (_) => const ChatScreen(),
        },
        home: const AuthGate(),
        // child: MaterialApp(
        //   title: 'ai_chatbot',
        //   debugShowCheckedModeBanner: false,
        //   theme: AppTheme.darkTheme(),
        //   initialRoute: '/login',
        //   routes: {
        //     '/login': (_) => const LoginScreen(),
        //     '/register': (_) => const RegisterScreen(),
        //     '/chat': (_) => const ChatScreen(),
        //   },
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      );
    }

    if (auth.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pushReplacementNamed('/chat');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      );
    }

    return const LoginScreen();
  }
}
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import 'config/theme.dart';
// import 'providers/auth_provider.dart';
// import 'screens/chat_screen.dart';
// import 'screens/login_screen.dart';
// import 'screens/register_screen.dart';

// void main() {
//   WidgetsFlutterBinding.ensureInitialized();

//   SystemChrome.setSystemUIOverlayStyle(
//     const SystemUiOverlayStyle(
//       statusBarColor: Colors.transparent,
//       statusBarIconBrightness: Brightness.dark,
//     ),
//   );

//   runApp(const AiChatbotApp());
// }

// class MyApp extends AiChatbotApp {
//   const MyApp({super.key});
// }

// class AiChatbotApp extends StatelessWidget {
//   const AiChatbotApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MultiProvider(
//       providers: [ChangeNotifierProvider(create: (_) => AuthProvider())],
//       child: MaterialApp(
//         title: 'ai_chatbot',
//         debugShowCheckedModeBanner: false,
//         theme: AppTheme.darkTheme(),
//         initialRoute: '/login',
//         routes: {
//           '/login': (_) => const LoginScreen(),
//           '/register': (_) => const RegisterScreen(),
//           '/chat': (_) => const ChatScreen(),
//         },
//         home: const AuthGate(),
//       ),
//     );
//   }
// }

// class AuthGate extends StatefulWidget {
//   const AuthGate({super.key});

//   @override
//   State<AuthGate> createState() => _AuthGateState();
// }

// class _AuthGateState extends State<AuthGate> {
//   @override
//   void initState() {
//     super.initState();

//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       context.read<AuthProvider>().initialize();
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     final auth = context.watch<AuthProvider>();

//     if (auth.isLoading) {
//       return const Scaffold(
//         body: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
//       );
//     }

//     if (auth.isAuthenticated) {
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         if (mounted) {
//           Navigator.of(context).pushReplacementNamed('/chat');
//         }
//       });

//       return const Scaffold(
//         body: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
//       );
//     }

//     return const LoginScreen();
//   }
// }
