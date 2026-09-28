import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzy2earn/core/app_router.dart';
import 'package:quizzy2earn/core/app_theme.dart';
import 'package:quizzy2earn/core/navigation_service.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';

import '../../widgets/bottom_banner_ad.dart';
import '../../main.dart'; // temporary (for gradient)

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen>
    with SingleTickerProviderStateMixin {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final phoneController = TextEditingController(); // ✅ STEP 1
  bool _acceptedTerms = false;
  bool _openingTerms = false;
  bool _acceptedPrivacy = false;

  bool _obscurePassword = true;
  bool _isLoading = false;

  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _slide = Tween(begin: const Offset(0, .1), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  Future<void> _openTerms() async {
    setState(() => _openingTerms = true);

    final doc = await FirebaseFirestore.instance
        .collection('app_config')
        .doc('privacy')
        .get();

    final version = (doc.data()?['currentVersion'] ?? "").toString();

    if (version.isEmpty) {
      setState(() => _openingTerms = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load Terms. Try again")),
      );
      return;
    }

    final agreed = await NavigationService.pushNamed(
      AppRouter.privacy,
      args: {
        'forceAgree': false,
        'currentTermsVersion': version,
      },
    );

    if (!mounted) return;

    setState(() {
      _acceptedPrivacy = agreed == true;
      _openingTerms = false;
    });
  }

  Future<void> _openTermsSimple() async {
    final agreed = await NavigationService.pushNamed(
      AppRouter.termsView,
    );

    if (!mounted) return;

    setState(() {
      _acceptedTerms = agreed == true;
    });
  }

  Future<void> _createAccount() async {

    // 🟢 PHONE VALIDATION
    final phone = phoneController.text.trim();

    if (!RegExp(r'^[0-9]{10}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter valid 10-digit Indian phone number'),
        ),
      );
      return;
    }

    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept Terms & Conditions')),
      );
      return;
    }

    if (!_acceptedPrivacy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept Privacy Policy')),
      );
      return;
    }

    if (nameController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        phoneController.text.trim().isEmpty ||
        passwordController.text.trim().length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill all fields (min 8 char password)')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1️⃣ CREATE AUTH USER
      final userCredential =
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final user = userCredential.user!;

      // 📱 DEVICE INFO (SAVE ONLY WHEN ACCOUNT CREATED)

      final deviceInfo = DeviceInfoPlugin();

      String platform = Platform.isAndroid ? "Android" : "iOS";
      String model = "Unknown";

      if (Platform.isAndroid) {
        final android = await deviceInfo.androidInfo;
        model = android.model;
      } else if (Platform.isIOS) {
        final ios = await deviceInfo.iosInfo;
        model = ios.utsname.machine;
      }

      final packageInfo = await PackageInfo.fromPlatform();

      final userCode = user.uid.substring(0, 8).toUpperCase();

      final termsDoc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('privacy')
          .get();

      final currentVersion = termsDoc.data()?['currentVersion'] ?? "1.0.0";

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': nameController.text.trim(),
        'email': user.email,
        'phone': '+91${phoneController.text.trim()}',
        'coinsAvailable': 0,
        'coinsLocked': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),

        'emailVerified': false,
        'emailEditable': true,
        'emailVerifiedAt': null,

        'agreedToPrivacy': true,
        'agreedPrivacyVersion': currentVersion,
        'privacyAgreedAt': FieldValue.serverTimestamp(),

        'agreedToTerms': true,
        'agreedTermsVersion': currentVersion,
        'termsAgreedAt': FieldValue.serverTimestamp(),

        /// ⭐ DAILY LOGIN
        'dailyLogin': {
          'streak': 0,
          'lastClaim': null,
          'lastMissed': null,
        },

        'earnings': {
          'referralCoins': 0,
          'surveyCoins': 0,
        },

        /// ⭐ BONUS
        'bonus': {
          'weeklyEarned': 0,
          'weeklyResetAt': FieldValue.serverTimestamp(),
        },

        'deviceInfo': {
          'platform': platform,
          'model': model,
          'appVersion': packageInfo.version,
        },
      });

      final db = FirebaseFirestore.instance;

      // ✅ Create referral subcollection
      await db
          .collection('users')
          .doc(user.uid)
          .collection('referral')
          .doc('main')
          .set({
        'code': userCode,
      }, SetOptions(merge: true));

      // ✅ Create global referral code
      await db.collection('referral_codes').doc(userCode).set({
        'uid': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3️⃣ NAVIGATE TO HOME
      if (mounted) {
        NavigationService.pushAndRemoveAll(AppRouter.home);
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Account creation failed')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        decoration: const BoxDecoration(gradient: appBackgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => NavigationService.goBack(),
                      ),
                    ),

                    Image.asset('assets/images/Hello-pana.png', height: 180),

                    const SizedBox(height: 16),

                    const Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 6),

                    const Text(
                      'Join Quizzy2Earn and start earning',
                      style: TextStyle(color: Colors.white70),
                    ),

                    const SizedBox(height: 30),

                    // 👤 NAME
                    glassInput(
                      child: TextField(
                        controller: nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Full Name',
                          hintStyle: TextStyle(color: Colors.white70),
                          prefixIcon: Icon(Icons.person, color: Colors.white),
                          border: InputBorder.none,
                        ),
                      ),
                    ),

                    // 📧 EMAIL
                    glassInput(
                      child: TextField(
                        controller: emailController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Email',
                          hintStyle: TextStyle(color: Colors.white70),
                          prefixIcon: Icon(Icons.email, color: Colors.white),
                          border: InputBorder.none,
                        ),
                      ),
                    ),

                    // 📱 PHONE (NEW)
                    glassInput(
                      child: TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Phone Number',
                          hintStyle: TextStyle(color: Colors.white70),
                          prefixIcon: Icon(Icons.phone, color: Colors.white),
                          prefixText: '+91 ',
                          prefixStyle: TextStyle(color: Colors.white),
                          counterText: '',
                          border: InputBorder.none,
                        ),
                      ),
                    ),

                    // 🔒 PASSWORD
                    glassInput(
                      child: TextField(
                        controller: passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Password',
                          hintStyle: const TextStyle(color: Colors.white70),
                          prefixIcon:
                          const Icon(Icons.lock, color: Colors.white),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),

                    // ✅ TERMS
                    Row(
                      children: [
                        Checkbox(
                          value: _acceptedTerms,
                          onChanged: (v) {
                            if (v == true) {
                              _openTermsSimple();
                            } else {
                              setState(() => _acceptedTerms = false);
                            }
                          },
                          activeColor: Colors.deepPurple,
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: _openTermsSimple,
                            child: const Text(
                              'I agree to the Terms & Conditions',
                              style: TextStyle(
                                color: Colors.white,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // ✅ PRIVACY
                    Row(
                      children: [
                        Checkbox(
                          value: _acceptedPrivacy,
                          onChanged: _openingTerms
                              ? null
                              : (v) {
                            if (v == true) {
                              _openTerms(); // privacy
                            } else {
                              setState(() => _acceptedPrivacy = false);
                            }
                          },
                          activeColor: Colors.deepPurple,
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: _openingTerms ? null : _openTerms,
                            child: const Text(
                              'I agree to the Privacy Policy',
                              style: TextStyle(
                                color: Colors.white,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // 🔘 CREATE BUTTON
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_isLoading || !_acceptedTerms || !_acceptedPrivacy) ? null : _createAccount,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.deepPurple,
                          padding:
                          const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Text(
                          'Create Account',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    TextButton(
                      onPressed: () {
                        NavigationService.pushNamed(AppRouter.login);
                      },
                      child: const Text(
                        "Already have an account? Login",
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