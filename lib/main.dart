import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'widgets/bottom_banner_ad.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/home/home_screen.dart';
import 'package:quizzy2earn/core/app_router.dart';
import 'package:quizzy2earn/core/navigation_service.dart';

// 🔹 Glass input wrapper
Widget glassInput({required Widget child}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.18),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: Colors.white.withOpacity(0.3)),
    ),
    child: child,
  );
}

Widget inputField({
  required TextEditingController controller,
  required String hint,
  required IconData icon,
  bool obscure = false,
}) {
  return TextField(
    controller: controller,
    obscureText: obscure,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: Colors.white),
      filled: true,
      fillColor: Colors.white.withOpacity(0.15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  await MobileAds.instance.initialize(); // 👈 ADD THIS

  runApp(const Quizzy2EarnApp());
}

Future<UserCredential> signInWithGoogle() async {
  final GoogleSignInAccount? googleUser =
  await GoogleSignIn().signIn();

  if (googleUser == null) {
    throw Exception('Google sign-in aborted');
  }

  final GoogleSignInAuthentication googleAuth =
  await googleUser.authentication;

  final credential = GoogleAuthProvider.credential(
    accessToken: googleAuth.accessToken,
    idToken: googleAuth.idToken,
  );

  return await FirebaseAuth.instance.signInWithCredential(credential);
}

Future<bool> checkUserProfileExists() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;

  final userDoc =
  FirebaseFirestore.instance.collection('users').doc(user.uid);

  final snapshot = await userDoc.get();
  return snapshot.exists;
}

class Quizzy2EarnApp extends StatelessWidget {
  const Quizzy2EarnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quizzy2Earn',
      debugShowCheckedModeBanner: false,

      navigatorKey: NavigationService.navigatorKey,
      initialRoute: AppRouter.welcome,
      onGenerateRoute: AppRouter.generateRoute,

      theme: ThemeData(
        primarySwatch: Colors.deepPurple,

        // ✅ CENTER TITLE GLOBALLY
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
            letterSpacing: 0.5,
          ),
          elevation: 0,
        ),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // ⏳ Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 🔐 DOUBLE CHECK AUTH STATE
        final user = FirebaseAuth.instance.currentUser;

        if (user == null) {
          return const WelcomeScreen();
        }

        // ✅ Valid logged-in user
        return const HomeScreen();
      },
    );
  }
}

class ReferenceWebView extends StatelessWidget {
  final String url;

  const ReferenceWebView({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const BottomBannerAd(),
      appBar: AppBar(
        title: const Text('Explanation'),
        backgroundColor: Colors.deepPurple,
      ),
      body: WebViewWidget(
        controller: WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..loadRequest(Uri.parse(url)),
      ),
    );
  }
}