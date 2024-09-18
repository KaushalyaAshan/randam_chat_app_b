import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:randam_chat_app_b/screens/chat_screen.dart';
import 'package:randam_chat_app_b/screens/login_screen.dart';
import 'package:randam_chat_app_b/screens/waiting_screen.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chat App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => SplashScreen(),
        '/login': (context) => LoginScreen(),
        '/waiting': (context) => WaitingScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/chat') {
          final String chatId = settings.arguments as String;
          return MaterialPageRoute(
            builder: (context) => ChatScreen(chatId: chatId, chatName: '',),
          );
        }
        return null;
      },
    );
  }
}
