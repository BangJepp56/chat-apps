// lib/main.dart
import 'package:chat/auth/login.dart';
import 'package:chat/screens/home.dart';
import 'package:chat/screens/profile.dart';
import 'package:chat/screens/search.dart';
import 'package:chat/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: "AIzaSyC2o0xwdUBMQFab5RNpriD_s1vfi1nNJiE",
        authDomain: "chat-app-676ee.firebaseapp.com",
        projectId: "chat-app-676ee",
        storageBucket: "chat-app-676ee.appspot.com",
        messagingSenderId: "982632217071",
        appId: "1:982632217071:android:1ac616e080dfdf62d0de1a",
      ),
    );
    print("Firebase initialized successfully");
  } catch (e) {
    print("Firebase initialization error: $e");
  }
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cihuy Chat',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: SplashScreen(),
      debugShowCheckedModeBanner: false,
      routes: {
        '/login': (context) => LoginPage(),
        '/messages': (context) => MessagesPage(),
        '/search': (context) => SearchPage(),
        '/profile': (context) => ProfilePage(),
      },
    );
  }
}