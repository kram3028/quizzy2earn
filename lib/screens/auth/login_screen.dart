import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:quizzy2earn/core/app_router.dart';
import 'package:quizzy2earn/core/navigation_service.dart';
import 'dart:io';

import '../../widgets/bottom_banner_ad.dart';
import 'package:quizzy2earn/core/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  bool showPassword = false;

  late AnimationController _animController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Widget _glassInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white70),
          prefixIcon: Icon(icon, color: Colors.white),
          suffixIcon: suffix,
          filled: true,
          fillColor: Colors.white.withOpacity(0.18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    if (emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter email and password')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // 🔐 FIREBASE AUTH LOGIN
      final userCredential =
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final user = userCredential.user!;

      // 📱 DEVICE INFO
      final deviceInfo = DeviceInfoPlugin();
      String platform = Platform.isAndroid ? 'Android' : 'iOS';
      String model = 'Unknown';

      if (Platform.isAndroid) {
        final android = await deviceInfo.androidInfo;
        model = android.model;
      } else if (Platform.isIOS) {
        final ios = await deviceInfo.iosInfo;
        model = ios.utsname.machine;
      }

      final packageInfo = await PackageInfo.fromPlatform();

      // 🟢 SAVE LOGIN + DEVICE INFO
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'lastLogin': FieldValue.serverTimestamp(),
        'devicePlatform': platform,
        'deviceModel': model,
        'appVersion': packageInfo.version,
      });

      // 🚀 NAVIGATE AFTER SUCCESS
      if (mounted) {
        NavigationService.pushAndRemoveAll(AppRouter.home);
      }

    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Login failed')),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    if (emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email first')),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: emailController.text.trim(),
      );

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Reset Email Sent'),
          content: const Text(
            'Check your email to reset your password.',
          ),
          actions: [
            TextButton(
              onPressed: () => NavigationService.goBack(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Error sending reset email')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const BottomBannerAd(),
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: appBackgroundGradient,
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 24),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon:
                        const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => NavigationService.goBack(),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Image.asset(
                      'assets/images/Login-pana.png',
                      height: 180,
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'Welcome Back',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 6),

                    const Text(
                      'Login to continue earning rewards',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),

                    const SizedBox(height: 30),

                    _glassInput(
                      controller: emailController,
                      hint: 'Email',
                      icon: Icons.email,
                    ),

                    _glassInput(
                      controller: passwordController,
                      hint: 'Password',
                      icon: Icons.lock,
                      obscure: !showPassword,
                      suffix: IconButton(
                        icon: Icon(
                          showPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            showPassword = !showPassword;
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 0),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _forgotPassword,
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 1),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.deepPurple,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: isLoading ? null : _login,
                        child: isLoading
                            ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.deepPurple,
                          ),
                        )
                            : const Text(
                          'Login',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    TextButton(
                      onPressed: () {
                        NavigationService.pushNamed(AppRouter.createAccount);
                      },
                      child: const Text(
                        "Don't have an account? Create one",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}