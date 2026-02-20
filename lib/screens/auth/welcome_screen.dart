import 'package:flutter/material.dart';
import 'package:quizzy2earn/core/app_router.dart';
import 'package:quizzy2earn/core/navigation_service.dart';

import 'package:quizzy2earn/core/app_theme.dart';

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
                    NavigationService.pushNamed(AppRouter.createAccount);
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
                    NavigationService.pushNamed(AppRouter.login);
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