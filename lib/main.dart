import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ads/ad_helper.dart';
import 'levels_screen.dart';
import 'daily_spin_screen.dart';
import 'widgets/bottom_banner_ad.dart';

const LinearGradient appBackgroundGradient = LinearGradient(
  colors: [
    Color(0xFF6A11CB),
    Color(0xFF2575FC),
  ],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

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
      home: const AuthGate(),
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

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EmailLoginScreen(),
                  ),
                );
              },
              child: const Text('Login with Email'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PhoneLoginScreen(),
                  ),
                );
              },
              child: const Text('Login with Phone'),
            ),
          ],
        ),
      ),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: appBackgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/Welcome-rafiki.png',
                height: 220,
                fit: BoxFit.contain,
              ),

              const SizedBox(height: 1),

              const Text(
                'Quizzy2Earn',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Answer quizzes and earn real rewards',
                style: TextStyle(color: Colors.white70),
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: 260,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateAccountScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Create Account',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: 260,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LoginScreen(),
                      ),
                    );
                  },
                  child: const Text('Login'),
                ),
              ),

              const SizedBox(height: 30),

              const Text(
                'Secure • Verified • Trusted',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
        .doc('terms')
        .get();

    final version = doc.data()?['currentVersion'] ?? "1.0";

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TermsConditionsScreen(
          forceAgree: false,
          currentTermsVersion: version,
        ),
      ),
    );

    setState(() {
      _acceptedTerms = true;
      _openingTerms = false;
    });
  }

  // 🔥 STEP 3: CONNECT FIREBASE AUTH + FIRESTORE
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
        const SnackBar(
          content: Text('You must accept Terms & Conditions'),
        ),
      );
      return;
    }

    if (nameController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        phoneController.text.trim().isEmpty ||
        passwordController.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill all fields (min 6 char password)')),
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

      // 2️⃣ SAVE USER DATA IN FIRESTORE
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': nameController.text.trim(),
        'email': user.email,
        'phone': '+91${phoneController.text.trim()}',
        'coinsAvailable': 0,
        'coinsLocked': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),

        // 👇 keep these (used by Profile verification)
        'emailVerified': false,
        'emailEditable': true,
        'emailVerifiedAt': null,

        // 🔥 STEP 1D — TERMS ACCEPTANCE (ADD HERE)
        'agreedToTerms': true,
        'agreedTermsVersion': "1.0",  // ⚠️ must match app_config version
        'termsAgreedAt': FieldValue.serverTimestamp(),
      });

      // 3️⃣ NAVIGATE TO HOME
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
              (_) => false,
        );
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
                        onPressed: () => Navigator.pop(context),
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

                    Row(
                      children: [
                        Checkbox(
                          value: _acceptedTerms,
                          onChanged: _openingTerms
                              ? null
                              : (v) {
                            if (v == true) {
                              _openTerms();
                            } else {
                              setState(() => _acceptedTerms = false);
                            }
                          },
                          activeColor: Colors.deepPurple,
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: _openingTerms ? null : _openTerms,
                            child: _openingTerms
                                ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                                : RichText(
                            text: const TextSpan(
                                style: TextStyle(color: Colors.white70, fontSize: 13),
                                children: [
                                  TextSpan(text: 'I agree to the '),
                                  TextSpan(
                                    text: 'Terms & Privacy Policy',
                                    style: TextStyle(
                                      color: Colors.white,
                                      decoration: TextDecoration.underline,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
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
                        onPressed: (_isLoading || !_acceptedTerms) ? null : _createAccount,
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
                            color: Colors.deepPurple,
                          ),
                        )
                            : const Text(
                          'Create Account',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
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
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
              (_) => false,
        );
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
              onPressed: () => Navigator.pop(context),
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
                        onPressed: () => Navigator.pop(context),
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
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CreateAccountScreen(),
                          ),
                        );
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  bool dataValidationFailed = false;
  String selectedUpiMethod = 'GPay';
  String selectedGiftCard = 'Amazon';
  String selectedPayoutCategory = 'UPI'; // or 'GiftCard'
  int invalidQuestionCount = 0;
  int coinsAvailable = 0;
  int coinsLocked = 0;
  int selectedTabIndex = 0;
  StreamSubscription<DocumentSnapshot>? userSubscription;
  StreamSubscription<QuerySnapshot>? withdrawSubscription;
  Map<String, dynamic>? latestWithdrawRequest;
  String currentTermsVersion = 'v1';
  bool get hasPendingWithdraw =>
      latestWithdrawRequest != null &&
      latestWithdrawRequest!['status'] == 'pending';
  late ConfettiController _confettiController;
  String? _previousStatus;
  late AnimationController _homeAnimController;
  RewardedInterstitialAd? _rewardedInterstitialAd;
  RewardedInterstitialAd? _spinOpenAd;
  int quizCounterForInterstitial = 0;
  int quizStartCount = 0;
  int questionAdCounter = 0;

  final String sheetUrl =
      'https://script.google.com/macros/s/AKfycbx2INUKrRWYjmyGCQBjP180T_RLZcLwKfn_vA1NLMGmEV52-5B3udzdSI4NEPcY9l58/exec';

  List<Map<String, dynamic>> questions = [];

  @override
  void initState() {
    super.initState();

    verifyUserStillExists();

    loadQuestionsFromSheet(); // ❓ Load quiz questions

    loadCurrentTermsVersion();

    startUserRealtimeListener(); // 🔴 REAL-TIME

    startWithdrawRealtimeListener();

    saveFcmToken();

    listenForegroundNotifications();

    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));

    _homeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _homeAnimController.forward();

    _loadRewardedInterstitialAd();

    _loadSpinOpenAd();
  }

  void _loadRewardedInterstitialAd() {
    RewardedInterstitialAd.load(
      adUnitId: AdHelper.rewardedInterstitialAdUnitId,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback:
      RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedInterstitialAd = ad;
          debugPrint('✅ Rewarded Interstitial Loaded');
        },
        onAdFailedToLoad: (error) {
          debugPrint('❌ Failed to load rewarded interstitial: $error');
        },
      ),
    );
  }

  void _loadSpinOpenAd() {
    RewardedInterstitialAd.load(
      adUnitId: AdHelper.rewardedInterstitialAdUnitId,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback:
      RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _spinOpenAd = ad;
          debugPrint('✅ Spin Open Ad Loaded');
        },
        onAdFailedToLoad: (error) {
          debugPrint('❌ Spin Open Ad Failed: $error');
        },
      ),
    );
  }

  void _showRewardedInterstitialThen(VoidCallback onContinue) {
    if (_rewardedInterstitialAd != null) {
      _rewardedInterstitialAd!.fullScreenContentCallback =
          FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _loadRewardedInterstitialAd();
              onContinue(); // 👉 continue original action
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _loadRewardedInterstitialAd();
              onContinue(); // 👉 still continue
            },
          );

      _rewardedInterstitialAd!.show(
        onUserEarnedReward: (ad, reward) {
          debugPrint('User watched rewarded interstitial');
        },
      );
    } else {
      // If ad not ready → continue normally
      onContinue();
    }
  }

  Future<void> verifyUserStillExists() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists) {
      // 🚨 Profile deleted by admin → force logout
      await FirebaseAuth.instance.signOut();
    }
  }

  Future<void> loadQuestionsFromSheet() async {
    final response = await http.get(Uri.parse(sheetUrl));

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);

      final List<Map<String, dynamic>> loadedQuestions = [];

      invalidQuestionCount = 0;

      for (final item in jsonList) {
        if (!isValidQuestion(item)) {
          invalidQuestionCount++;
          continue; // skip bad row
        }

        loadedQuestions.add({
          'question': item['question'].toString().trim(),
          'options': [
            item['option1'].toString().trim(),
            item['option2'].toString().trim(),
            item['option3'].toString().trim(),
            item['option4'].toString().trim(),
          ],
          'answer': item['answer'].toString().trim(),
          'reference': item['reference']?.toString().trim() ?? '',
        });
      }
      if (!mounted) return;

      setState(() {
        questions = loadedQuestions;
        dataValidationFailed = invalidQuestionCount > 0;
      });
    }
  }

  @override
  void dispose() {
    userSubscription?.cancel();
    withdrawSubscription?.cancel();

    _confettiController.dispose();
    _homeAnimController.dispose();

    super.dispose(); // Must Last
  }

  void startUserRealtimeListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    userSubscription?.cancel();

    userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((doc) {
      if (!doc.exists) return;
      final data = doc.data();
      if (data == null) return;

      final agreedVersion = data['agreedTermsVersion'];

      setState(() {
        coinsAvailable = (data['coinsAvailable'] as num?)?.toInt() ?? 0;
        coinsLocked = (data['coinsLocked'] as num?)?.toInt() ?? 0;
      });

      // 🔥 FORCE RE-AGREE WHEN TERMS VERSION CHANGES
      if (agreedVersion != currentTermsVersion) {
        _forceTermsAgreement();
      }
    });
  }

  Future<void> loadCurrentTermsVersion() async {
    final doc = await FirebaseFirestore.instance
        .collection('app_config')
        .doc('terms')
        .get();

    if (doc.exists) {
      currentTermsVersion = doc['currentVersion'] ?? '1.0';
    }
  }

  void startWithdrawRealtimeListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    withdrawSubscription?.cancel();

    withdrawSubscription = FirebaseFirestore.instance
        .collection('withdraw_requests')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAtLocal', descending: true) // ✅ NO INDEX NEEDED
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      if (snapshot.docs.isEmpty) {
        setState(() => latestWithdrawRequest = null);
        return;
      }

      final doc = snapshot.docs.first;
      final data = doc.data();
      final status = data['status'];

      // 🎉 STATUS CHANGE DETECTOR
      if (_previousStatus == 'pending' && status == 'paid') {
        _confettiController.play();
        HapticFeedback.heavyImpact();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Payment Successful! Coins redeemed.'),
            backgroundColor: Colors.green,
          ),
        );
      }

      _previousStatus = status;

      setState(() {
        latestWithdrawRequest = data;
      });

      debugPrint('LATEST STATUS → ${data['status']}');
    });
  }

  Future<void> saveFcmToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({
      'fcmToken': token,
    });
  }

  void listenForegroundNotifications() {
    FirebaseMessaging.onMessage.listen((message) {
      if (!mounted) return;

      final notification = message.notification;
      if (notification == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(notification.title ?? 'Notification'),
        ),
      );
    });
  }

  Future<void> settleCoinsAfterAdminAction({
    required String withdrawDocId,
    required String status,
    required int amount,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userRef =
    FirebaseFirestore.instance.collection('users').doc(user.uid);

    final withdrawRef =
    FirebaseFirestore.instance.collection('withdraw_requests').doc(withdrawDocId);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      final withdrawSnap = await tx.get(withdrawRef);

      if (!withdrawSnap.exists) return;
      if (withdrawSnap['coinsSettled'] == true) return;

      final available = (userSnap['coinsAvailable'] as num).toInt();
      final locked = (userSnap['coinsLocked'] as num).toInt();

      if (status == 'paid') {
        // ✅ Coins already deducted → just clear locked
        tx.update(userRef, {
          'coinsLocked': locked - amount,
        });
      }

      if (status == 'rejected') {
        // 🔄 Refund coins
        tx.update(userRef, {
          'coinsAvailable': available + amount,
          'coinsLocked': locked - amount,
        });
      }

      // 🔐 MARK AS SETTLED (VERY IMPORTANT)
      tx.update(withdrawRef, {
        'coinsSettled': true,
      });
    });
  }

  void _forceTermsAgreement() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false, // 🚨 MUST accept
        builder: (_) => AlertDialog(
          title: const Text('Terms Updated'),
          content: const Text(
            'Our Terms & Conditions have been updated. Please review and agree to continue using withdrawals.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TermsConditionsScreen(
                      forceAgree: true,
                      currentTermsVersion: currentTermsVersion,
                    ),
                  ),
                );
              },
              child: const Text('Review & Agree'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> addBonusCoins(int amount) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({
      'coinsAvailable': FieldValue.increment(amount),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('🎉 You earned $amount bonus coins!')),
    );
  }

  bool isValidQuestion(Map<String, dynamic> item) {
    final question = item['question']?.toString().trim() ?? '';
    final option1 = item['option1']?.toString().trim() ?? '';
    final option2 = item['option2']?.toString().trim() ?? '';
    final option3 = item['option3']?.toString().trim() ?? '';
    final option4 = item['option4']?.toString().trim() ?? '';
    final answer = item['answer']?.toString().trim() ?? '';

    // Basic checks
    if (question.isEmpty ||
        option1.isEmpty ||
        option2.isEmpty ||
        option3.isEmpty ||
        option4.isEmpty ||
        answer.isEmpty) {
      return false;
    }

    // Answer must match one of the options
    final options = [option1, option2, option3, option4];
    if (!options.contains(answer)) {
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    Widget currentScreen;

    if (selectedTabIndex == 0) {
      currentScreen = buildHomeTab();
    } else if (selectedTabIndex == 1) {
      currentScreen = buildWalletTab();
    } else if (selectedTabIndex == 2) {
      currentScreen = buildWithdrawalTab();
    } else {
      currentScreen = buildProfileTab();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quizzy2Earn'),
        backgroundColor: Colors.deepPurple,
      ),

      body: currentScreen,

      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BottomBannerAd(),
          BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: selectedTabIndex,
            onTap: (index) {
              setState(() {
                selectedTabIndex = index;
              });
            },
            selectedItemColor: Colors.deepPurple,
            unselectedItemColor: Colors.grey,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.quiz), label: 'Quiz'),
              BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'My Wallet'),
              BottomNavigationBarItem(icon: Icon(Icons.payments), label: 'Withdraw'),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildHomeTab() {
    void openLevels() {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LevelsScreen(questions: questions),
        ),
      );
    }

    void handleStartQuiz() {
      quizStartCount++;

      bool shouldShowStartAd = quizStartCount > 1;

      if (_rewardedInterstitialAd != null && shouldShowStartAd) {
        _rewardedInterstitialAd!.fullScreenContentCallback =
            FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                _loadRewardedInterstitialAd();
                openLevels();
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                ad.dispose();
                _loadRewardedInterstitialAd();
                openLevels();
              },
            );

        _rewardedInterstitialAd!.show(
          onUserEarnedReward: (_, __) {},
        );
      } else {
        openLevels();
      }
    }

    void handleOpenSpin() {
      void openSpin() {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const DailySpinScreen(),
          ),
        );
      }

      if (_spinOpenAd != null) {
        _spinOpenAd!.fullScreenContentCallback =
            FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                _loadSpinOpenAd();
                openSpin();
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                ad.dispose();
                _loadSpinOpenAd();
                openSpin();
              },
            );

        _spinOpenAd!.show(onUserEarnedReward: (_, __) {});
      } else {
        openSpin();
      }
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E1E2C), Color(0xFF2A2A40)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          if (dataValidationFailed)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.orange.shade200,
              child: Text(
                '⚠️ Admin Notice: $invalidQuestionCount invalid question(s) skipped',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  /// 💰 WALLET BAR
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade400,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepPurple.withOpacity(0.4),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text(
                          'Your Wallet',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '🟡 Coins: Live',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  /// 🎮 START QUIZ CARD
                  GestureDetector(
                    onTap: handleStartQuiz,
                    child: _gameCard(
                      icon: Icons.quiz,
                      title: 'Start Quiz',
                      subtitle: 'Answer questions & earn coins',
                      colors: const [Colors.deepPurple, Colors.purpleAccent],
                    ),
                  ),

                  const SizedBox(height: 22),

                  /// 🎰 DAILY SPIN CARD
                  GestureDetector(
                    onTap: handleOpenSpin,
                    child: _gameCard(
                      icon: Icons.casino,
                      title: 'Daily Spin Wheel',
                      subtitle: 'Spin & win bonus coins',
                      colors: const [Colors.orange, Colors.deepOrange],
                    ),
                  ),

                  const SizedBox(height: 30),

                  /// 🧩 MORE GAMES
                  const Text(
                    'More Ways to Earn',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 14),

                  _comingSoonCard(
                    icon: Icons.poll,
                    title: 'Surveys (BitLabs)',
                    subtitle: 'Complete surveys & earn big rewards',
                  ),

                  const SizedBox(height: 14),

                  _comingSoonCard(
                    icon: Icons.extension,
                    title: 'More Mini Games',
                    subtitle: 'Exciting games coming soon...',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gameCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> colors,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: colors.first.withOpacity(0.4),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 42, color: Colors.white),
          const SizedBox(width: 18),
          Expanded(
            child: Text(
              '$title\n$subtitle',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Icon(Icons.arrow_forward_ios, color: Colors.white),
        ],
      ),
    );
  }

  Widget _comingSoonCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$title\n$subtitle',
              style: const TextStyle(color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildWalletTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        children: [

          const SizedBox(height: 10),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '📅 Withdrawals are processed in the first week of every month',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 🎨 WALLET CARD
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.deepPurple.shade400,
                  Colors.deepPurple.shade700,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepPurple.withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'My Wallet',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 12),

                // 💰 TOTAL
                Text(
                  '${coinsAvailable + coinsLocked}',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 4),

                const Text(
                  'Total Coins',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 20),

                // 🔹 AVAILABLE & LOCKED
                Row(
                  children: [
                    Expanded(
                      child: _walletStat(
                        icon: Icons.account_balance_wallet,
                        label: 'Available',
                        value: coinsAvailable.toString(),
                        color: Colors.greenAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _walletStat(
                        icon: Icons.lock,
                        label: 'Locked',
                        value: coinsLocked.toString(),
                        color: Colors.orangeAccent,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                const Text(
                  'Locked coins are under withdrawal review',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 15),

          // 🔘 REDEEM BUTTON
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.redeem),
              label: Text(
                coinsAvailable < 5000
                  ? 'Minimum 5000 coins required'
                  : 'Redeem Coins',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              onPressed: coinsAvailable < 5000
                ? null
                : () {
                  _showRewardedInterstitialThen(() {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                          RedeemScreen(
                            coins: coinsAvailable,
                            hasPendingWithdraw: hasPendingWithdraw,
                            currentTermsVersion: currentTermsVersion,
                            onShowAdThen: (VoidCallback action) {
                              _showRewardedInterstitialThen(action);
                            },
                            onWithdraw: (amount, payoutMethod,
                                payoutDetail) async {
                              await createWithdrawRequest(
                                amount: amount,
                                payoutMethod: payoutMethod,
                                payoutDetail: payoutDetail,
                              );

                              setState(() {
                                selectedTabIndex = 2;
                              });
                            },
                          ),
                      ),
                    );
                  });
                },
            ),
          ),

          const SizedBox(height: 10),

          const Text(
            'Rewards are processed securely',
            style: TextStyle(fontSize: 14, color: Colors.black45),
          ),
        ],
      ),
    );
  }

  Widget _walletStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildStartButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onPressed: questions.isEmpty
          ? null
          : () {

        quizStartCount++;

        bool shouldShowStartAd = quizStartCount > 1;

        void openLevels() {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LevelsScreen(
                questions: questions,
              ),
            ),
          );
        }

        if (_rewardedInterstitialAd != null && shouldShowStartAd) {

          _rewardedInterstitialAd!.fullScreenContentCallback =
              FullScreenContentCallback(
                onAdDismissedFullScreenContent: (ad) {
                  ad.dispose();
                  _loadRewardedInterstitialAd();

                  // 👉 OPEN LEVELS AFTER AD
                  openLevels();
                },
                onAdFailedToShowFullScreenContent: (ad, error) {
                  ad.dispose();
                  _loadRewardedInterstitialAd();

                  openLevels();
                },
              );

          _rewardedInterstitialAd!.show(
            onUserEarnedReward: (ad, reward) {},
          );

        } else {
          openLevels();
        }
      },
      child: Text(
        questions.isEmpty ? 'Loading Questions...' : 'Start Quiz',
      ),
    );
  }

  Widget buildWithdrawalTab() {
    if (latestWithdrawRequest == null) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'No withdrawal request found.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final status = latestWithdrawRequest!['status'];
    final amount =
    (latestWithdrawRequest!['requestedAmount'] as num).toDouble();
    final payoutMethod = latestWithdrawRequest!['payoutMethod'];
    final payoutDetail = latestWithdrawRequest!['payoutDetail'];

    String statusText;
    if (status == 'paid') {
      statusText = payoutMethod == 'GiftCard'
          ? '✅ Gift Card sent to $payoutDetail'
          : '✅ Paid to $payoutDetail';
    } else if (status == 'rejected') {
      statusText = payoutMethod == 'GiftCard'
          ? '❌ Gift Card request rejected'
          : '❌ Payment rejected';
    } else {
      statusText = payoutMethod == 'GiftCard'
          ? '⏳ Gift Card pending for $payoutDetail'
          : '⏳ UPI pending to $payoutDetail';
    }

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.account_balance_wallet,
                      color: Colors.deepPurple),
                  SizedBox(width: 8),
                  Text(
                    'Withdrawal Status',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.deepPurple.shade400,
                      Colors.deepPurple.shade600,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '₹${amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: status == 'paid'
                      ? Colors.green.shade50
                      : status == 'rejected'
                      ? Colors.red.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  statusText,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              buildWithdrawalHistory(),
            ],
          ),
        ),

        // 🎉 CONFETTI OVERLAY (correct place)
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              Colors.green,
              Colors.deepPurple,
              Colors.orange,
              Colors.blue,
            ],
          ),
        ),
      ],
    );
  }

  Widget buildWithdrawalHistory() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('withdraw_requests')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'paid')
          .orderBy('createdAtLocal', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text(
            'No withdrawal history found.',
            style: TextStyle(color: Colors.grey),
          );
        }

        return Column(
          children: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return buildWithdrawHistoryCard(data);
          }).toList(),
        );
      },
    );
  }

  Widget buildWithdrawHistoryCard(Map<String, dynamic> data) {
    final amount = (data['requestedAmount'] as num).toDouble();
    final status = data['status'] ?? 'pending';
    final payoutMethod = data['payoutMethod'] ?? '';
    final txnId = data['transactionId'];
    final date = DateTime.fromMillisecondsSinceEpoch(
      data['createdAtLocal'],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '₹${amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              _statusBadge(status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            payoutMethod,
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Requested on ${_formatDate(date)}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          if (txnId != null && txnId.toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Txn ID: $txnId',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    String text;
    IconData icon;

    switch (status) {
      case 'paid':
        color = Colors.green;
        text = 'Paid';
        icon = Icons.check_circle;
        break;
      case 'rejected':
        color = Colors.red;
        text = 'Rejected';
        icon = Icons.cancel;
        break;
      default:
        color = Colors.orange;
        text = 'Pending';
        icon = Icons.hourglass_bottom;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> createWithdrawRequest({
    required double amount,
    required String payoutMethod,
    required String payoutDetail,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userRef =
    FirebaseFirestore.instance.collection('users').doc(user.uid);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);

      final available = (userSnap['coinsAvailable'] as num).toInt();
      final locked = (userSnap['coinsLocked'] as num).toInt();

      // 🔒 PREVENT DUPLICATE PENDING (SAFE)
      if (locked > 0) {
        throw Exception('Pending withdrawal already exists');
      }

      if (available < amount) {
        throw Exception('Insufficient balance');
      }

      // 🔒 LOCK COINS
      tx.update(userRef, {
        'coinsAvailable': available - amount,
        'coinsLocked': locked + amount,
      });

      // 🔥 CREATE WITHDRAW REQUEST
      final withdrawRef =
      FirebaseFirestore.instance.collection('withdraw_requests').doc();

      tx.set(withdrawRef, {
        'userId': user.uid,
        'requestedAmount': amount,
        'payoutMethod': payoutMethod,
        'payoutDetail': payoutDetail,
        'status': 'pending',
        'coinsSettled': false,
        'createdAt': FieldValue.serverTimestamp(),
        'createdAtLocal': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  Widget buildProfileTab() {
    return ProfileTab(
      onSaveWithAd: (VoidCallback saveAction) {
        _showRewardedInterstitialThen(saveAction);
      },
    );
  }

  Widget buildPayoutTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.deepPurple),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.lock, color: Colors.grey),
        onTap: () {
          // Placeholder for backend integration
        },
      ),
    );
  }

  void openReferenceLink(String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReferenceWebView(url: url),
      ),
    );
  }

  Future<void> addCoin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({
      'coinsAvailable': FieldValue.increment(1),
    });
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

class RedeemScreen extends StatefulWidget {
  final int coins;
  final bool hasPendingWithdraw;
  final String currentTermsVersion;
  final Function(VoidCallback) onShowAdThen;
  final Function(
    double amount,
    String payoutMethod,
    String payoutDetail,
  ) onWithdraw;

  const RedeemScreen({
    super.key,
    required this.coins,
    required this.hasPendingWithdraw,
    required this.currentTermsVersion,
    required this.onWithdraw,
    required this.onShowAdThen,
  });

  @override
  State<RedeemScreen> createState() => _RedeemScreenState();
}

class _RedeemScreenState extends State<RedeemScreen> {
  final TextEditingController upiIdController = TextEditingController();
  final TextEditingController giftCardEmailController = TextEditingController();
  final TextEditingController withdrawCoinsController = TextEditingController();
  static const double minWithdrawAmount = 4000;

  // 🟢 STEP 1: STATE VARIABLES
  String selectedPayoutCategory = 'UPI'; // UPI | GiftCard
  String selectedUpiMethod = 'GPay';
  String selectedGiftCard = 'Amazon';
  bool agreedToTerms = false;

  @override
  void initState() {
    super.initState();
    _showTermsIfFirstTime();
    withdrawCoinsController.addListener(() {
      setState(() {}); // rebuild to update red border + button state
    });
  }

  Future<void> _showTermsIfFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyShown = prefs.getBool('termsShown') ?? false;

    if (!alreadyShown) {
      await prefs.setBool('termsShown', true);

      if (!mounted) return;

      Future.microtask(() {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TermsConditionsScreen(
              currentTermsVersion: widget.currentTermsVersion,
            ),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double coinToRupeeRate = 0.8; // internal only (hidden)
    final double rewardAmount = widget.coins * coinToRupeeRate;
    final enteredAmount =
        double.tryParse(withdrawCoinsController.text.trim()) ?? 0;

    final bool isAmountValid = enteredAmount >= minWithdrawAmount;

    Widget glassCard({required Widget child}) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: child,
      );
    }

    InputDecoration inputDecoration(String hint) {
      return InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      );
    }

    return Scaffold(
      bottomNavigationBar: const BottomBannerAd(),
      backgroundColor: Colors.deepPurple,
      appBar: AppBar(
        title: const Text(
          'Quizzy2Earn',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.deepPurple,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.deepPurple, // 👈 fixes black top
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity, // 🔥 THIS FIXES EVERYTHING
        decoration: const BoxDecoration(
          gradient: appBackgroundGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // 🔹 Reward Info
                glassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Estimated Reward',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '₹ ${rewardAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),

                // 🔹 Amount
                glassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Enter withdrawal amount (₹)',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: withdrawCoinsController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Minimum ₹4000',
                          prefixText: '₹ ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isAmountValid ? Colors.grey : Colors.red,
                              width: 2,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isAmountValid ? Colors.grey : Colors.red,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      if (!isAmountValid && withdrawCoinsController.text.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            'Minimum withdraw amount is ₹4000',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),

                const Text(
                  'Choose Payout Method',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const SizedBox(height: 12),

                // 🔹 Radio buttons
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        value: 'UPI',
                        groupValue: selectedPayoutCategory,
                        activeColor: Colors.white,
                        title: const Text('UPI',
                            style: TextStyle(color: Colors.white)),
                        onChanged: (v) =>
                            setState(() => selectedPayoutCategory = v!),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        value: 'GiftCard',
                        groupValue: selectedPayoutCategory,
                        activeColor: Colors.white,
                        title: const Text('Gift Card',
                            style: TextStyle(color: Colors.white)),
                        onChanged: (v) =>
                            setState(() => selectedPayoutCategory = v!),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                if (selectedPayoutCategory == 'UPI')
                  glassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('UPI Method',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: selectedUpiMethod,
                          dropdownColor: Colors.deepPurple,
                          decoration: inputDecoration('Select UPI'),
                          items: const [
                            DropdownMenuItem(
                                value: 'GPay', child: Text('GPay')),
                            DropdownMenuItem(
                                value: 'PhonePe', child: Text('PhonePe')),
                            DropdownMenuItem(
                                value: 'Paytm', child: Text('Paytm')),
                            DropdownMenuItem(
                                value: 'Direct Bank UPI',
                                child: Text('Direct Bank UPI')),
                          ],
                          onChanged: (v) =>
                              setState(() => selectedUpiMethod = v!),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: upiIdController,
                          style: const TextStyle(color: Colors.white),
                          decoration: inputDecoration('Enter UPI ID'),
                        ),
                      ],
                    ),
                  ),

                if (selectedPayoutCategory == 'GiftCard')
                  glassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Gift Card Brand',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: selectedGiftCard,
                          dropdownColor: Colors.deepPurple,
                          decoration: inputDecoration('Select Brand'),
                          items: const [
                            DropdownMenuItem(
                                value: 'Amazon', child: Text('Amazon')),
                            DropdownMenuItem(
                                value: 'Flipkart', child: Text('Flipkart')),
                            DropdownMenuItem(
                                value: 'Myntra', child: Text('Myntra')),
                            DropdownMenuItem(
                                value: 'Croma', child: Text('Croma')),
                          ],
                          onChanged: (v) =>
                              setState(() => selectedGiftCard = v!),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: giftCardEmailController,
                          style: const TextStyle(color: Colors.white),
                          decoration: inputDecoration('Enter Email'),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 6),

                // Terms
                Row(
                  children: [
                    Checkbox(
                      value: agreedToTerms,
                      activeColor: Colors.white,
                      checkColor: Colors.deepPurple,
                      onChanged: (v) =>
                          setState(() => agreedToTerms = v!),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TermsConditionsScreen(
                                currentTermsVersion:
                                widget.currentTermsVersion,
                              ),
                            ),
                          );
                        },
                        child: const Text(
                          'I agree to Terms & Conditions',
                          style: TextStyle(
                            color: Colors.white,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: widget.hasPendingWithdraw ||
                        !agreedToTerms ||
                        !isAmountValid
                        ? null
                        : () {

                      widget.onShowAdThen(() async {

                        final enteredAmount =
                        double.tryParse(withdrawCoinsController.text.trim());

                        if (enteredAmount == null ||
                            enteredAmount < minWithdrawAmount) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Enter valid amount')),
                          );
                          return;
                        }

                        String payoutMethod;
                        String payoutDetail;

                        if (selectedPayoutCategory == 'UPI') {
                          if (upiIdController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Enter UPI ID')),
                            );
                            return;
                          }
                          payoutMethod = 'UPI';
                          payoutDetail = upiIdController.text.trim();
                        } else {
                          if (giftCardEmailController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Enter Email ID')),
                            );
                            return;
                          }
                          payoutMethod = 'GiftCard';
                          payoutDetail = giftCardEmailController.text.trim();
                        }

                        // ✅ SAVE TERMS AGREEMENT
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .update({
                            'agreedToTerms': true,
                            'agreedTermsVersion': widget.currentTermsVersion,
                            'termsAgreedAt': FieldValue.serverTimestamp(),
                          });
                        }

                        Navigator.pop(context);

                        widget.onWithdraw(
                          enteredAmount,
                          payoutMethod,
                          payoutDetail,
                        );
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.deepPurple,
                      disabledBackgroundColor: Colors.white, // 🔥 when button is disabled
                      disabledForegroundColor: Colors.grey,  // text when disabled
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      widget.hasPendingWithdraw
                          ? 'Withdrawal Pending'
                          : 'Withdraw',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),

                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TermsConditionsScreen extends StatefulWidget {
  final bool forceAgree;
  final String currentTermsVersion;

  const TermsConditionsScreen({
    super.key,
    this.forceAgree = false,
    required this.currentTermsVersion,
  });

  @override
  State<TermsConditionsScreen> createState() =>
      _TermsConditionsScreenState();
}

class _TermsConditionsScreenState extends State<TermsConditionsScreen> {
  bool canAgree = false;
  bool isSaving = false;
  late final WebViewController _webController;

  @override
  void initState() {
    super.initState();

    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(
        Uri.parse('https://quizzy2earn.web.app/terms.html'),
      );

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => canAgree = true);
      }
    });
  }

  Future<void> _agreeToTerms() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => isSaving = true);

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({
      'agreedToTerms': true,
      'agreedTermsVersion': widget.currentTermsVersion,
      'termsAgreedAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      setState(() => isSaving = false);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          Expanded(
            child: WebViewWidget(controller: _webController),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (!canAgree || isSaving)
                  ? null
                  : _agreeToTerms,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                'I Agree',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EmailLoginScreen extends StatelessWidget {
  const EmailLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text('Email Login')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await FirebaseAuth.instance.signInWithEmailAndPassword(
                  email: emailController.text,
                  password: passwordController.text,
                );
                Navigator.pop(context);
              },
              child: const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}

class PhoneLoginScreen extends StatelessWidget {
  const PhoneLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final phoneController = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text('Phone Login')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number (+91XXXXXXXXXX)',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await FirebaseAuth.instance.verifyPhoneNumber(
                  phoneNumber: phoneController.text,
                  verificationCompleted: (credential) async {
                    await FirebaseAuth.instance.signInWithCredential(credential);
                  },
                  verificationFailed: (e) {},
                  codeSent: (id, token) {},
                  codeAutoRetrievalTimeout: (id) {},
                );
              },
              child: const Text('Send OTP'),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileTab extends StatefulWidget {
  final Function(VoidCallback) onSaveWithAd;

  const ProfileTab({
    super.key,
    required this.onSaveWithAd,
  });

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  bool emailVerified = false;
  bool emailEditable = true;

  String email = '';
  String dob = '';
  String gender = '';

  final TextEditingController dobController = TextEditingController();
  String selectedGender = 'Male';

  @override
  void initState() {
    super.initState();
    loadUserProfile();
  }

  Future<void> loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        nameController.text = data['name'] ?? '';
        emailController.text = data['email'] ?? '';
        emailVerified = data['emailVerified'] ?? false;
        emailEditable = data['emailEditable'] ?? true;
        phoneController.text = data['phone'] ?? '';
        dob = data['dob'] ?? '';
        gender = data['gender'] ?? 'Male';

        dobController.text = dob;
        selectedGender = gender;
      });
      // ✅ CHECK IF USER VERIFIED FROM EMAIL LINK
      await user.reload();

      if (user.emailVerified && !emailVerified) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'emailVerified': true,
          'emailEditable': false,
          'emailVerifiedAt': FieldValue.serverTimestamp(),
        });

        setState(() {
          emailVerified = true;
          emailEditable = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget cardInput({required Widget child}) {
      return Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.deepPurple.shade50,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurple.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: child,
      );
    }

    InputDecoration inputStyle(String label, IconData icon) {
      return InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.deepPurple),
        border: InputBorder.none,
      );
    }

    return SafeArea(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [

            /// 🔝 Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.logout, color: Colors.deepPurple),
                      onPressed: logoutUser,
                    ),
                  ),
                  const Text(
                    'My Profile',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                ],
              ),
            ),

            /// 🔽 Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [

                    /// Avatar
                    Container(
                      height: 110,
                      width: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Colors.deepPurple.shade200,
                            Colors.deepPurple.shade400,
                          ],
                        ),
                      ),
                      child: const Icon(Icons.person, size: 60, color: Colors.white),
                    ),

                    const SizedBox(height: 16),

                    /// Email
                    cardInput(
                      child: TextField(
                        controller: emailController,
                        readOnly: !emailEditable,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Email ID',
                          prefixIcon: const Icon(Icons.email, color: Colors.deepPurple),
                          border: InputBorder.none,
                          suffixIcon: emailVerified
                              ? const Icon(Icons.verified, color: Colors.green)
                              : const Icon(Icons.warning, color: Colors.orange),
                        ),
                      ),
                    ),

                    if (!emailVerified)
                      TextButton(
                        onPressed: () async {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            await user.sendEmailVerification();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Verification link sent to your email'),
                              ),
                            );
                          }
                        },
                        child: const Text(
                          'Send Verification Link',
                          style: TextStyle(
                            color: Colors.orange,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),

                    const SizedBox(height: 10),

                    /// Inputs
                    cardInput(
                      child: TextField(
                        controller: nameController,
                        decoration: inputStyle('Full Name', Icons.person),
                      ),
                    ),

                    cardInput(
                      child: TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: inputStyle('Phone Number', Icons.phone),
                      ),
                    ),

                    cardInput(
                      child: TextField(
                        controller: dobController,
                        readOnly: true,
                        decoration: inputStyle('Date of Birth', Icons.calendar_today),
                        onTap: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime(2000),
                            firstDate: DateTime(1920),
                            lastDate: DateTime.now(),
                          );

                          if (pickedDate != null) {
                            dobController.text =
                            '${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}';
                          }
                        },
                      ),
                    ),

                    cardInput(
                      child: DropdownButtonFormField<String>(
                        value: selectedGender,
                        items: const [
                          DropdownMenuItem(value: 'Male', child: Text('Male')),
                          DropdownMenuItem(value: 'Female', child: Text('Female')),
                          DropdownMenuItem(value: 'Other', child: Text('Other')),
                        ],
                        onChanged: (value) {
                          setState(() => selectedGender = value!);
                        },
                        decoration: inputStyle('Gender', Icons.people),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            /// 💾 Fixed Save Button (never hides under banner)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (!emailVerified) {
                      showDialog(
                        context: context,
                        builder: (_) => const AlertDialog(
                          title: Text('Verify Email Required'),
                          content: Text(
                            'Please verify your email before saving profile.',
                          ),
                        ),
                      );
                      return;
                    }

                    widget.onSaveWithAd(() {
                      saveProfile();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'Save Profile',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget profileItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 16),
      ),
    );
  }

  Future<void> saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({
      'name': nameController.text.trim(),
      'phone': phoneController.text.trim(),
      'dob': dobController.text.trim(),
      'gender': selectedGender,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated')),
    );
  }

  Future<void> logoutUser() async {
    await FirebaseAuth.instance.signOut();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (_) => false,
    );
  }
}