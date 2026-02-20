import 'package:flutter/material.dart';
import '../screens/auth/welcome_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/terms/terms_conditions_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/create_account_screen.dart';
import '../levels_screen.dart';
import '../quiz_level_screen.dart';
import '../daily_spin_screen.dart';
import '../main.dart';
import '../screens/withdraw/redeem_screen.dart';

class AppRouter {
  static const String welcome = '/welcome';
  static const String home = '/home';
  static const String terms = '/terms';
  static const String login = '/login';
  static const String createAccount = '/createAccount';
  static const String levels = '/levels';
  static const String spin = '/spin';
  static const String reference = '/reference';
  static const String redeem = '/redeem';
  static const String quizLevel = '/quiz-level';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case welcome:
        return MaterialPageRoute(builder: (_) => const WelcomeScreen());

      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());

      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
        
      case createAccount:
        return MaterialPageRoute(builder: (_) => const CreateAccountScreen());

      case levels:
        final args = settings.arguments as Map?;
        return MaterialPageRoute(
          builder: (_) => LevelsScreen(
            questions: args?['questions'] ?? [],
          ),
        );

      case quizLevel:
        final args = settings.arguments as Map;
        return MaterialPageRoute(
          builder: (_) => QuizLevelScreen(
            level: args['level'],
            questions: args['questions'],
          ),
        );

      case spin:
        return MaterialPageRoute(
          builder: (_) => const DailySpinScreen(),
        );

      case reference:
        final args = settings.arguments as Map?;
        return MaterialPageRoute(
          builder: (_) => ReferenceWebView(
            url: args?['url'] ?? '',
          ),
        );

      case AppRouter.redeem:
        final args = settings.arguments as Map?;
        return MaterialPageRoute(
          builder: (_) => RedeemScreen(
            coins: args?['coins'] ?? 0,
            hasPendingWithdraw: args?['hasPendingWithdraw'] ?? false,
            currentTermsVersion: args?['currentTermsVersion'] ?? "1.0",
            onShowAdThen: args?['onShowAdThen'],
            onWithdraw: args?['onWithdraw'],
          ),
        );

      case terms:
        final args = settings.arguments as Map?;
        return MaterialPageRoute(
          builder: (_) => TermsConditionsScreen(
            forceAgree: args?['forceAgree'] ?? false,
            currentTermsVersion: args?['currentTermsVersion'] ?? "1.0",
          ),
        );

      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Page not found')),
          ),
        );
    }
  }
}
