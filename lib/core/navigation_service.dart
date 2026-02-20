import 'package:flutter/material.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
  GlobalKey<NavigatorState>();

  static Future<dynamic>? pushNamed(String route, {Object? args}) {
    return navigatorKey.currentState
        ?.pushNamed(route, arguments: args);
  }

  static void pushReplacement(String route, {Object? args}) {
    navigatorKey.currentState
        ?.pushReplacementNamed(route, arguments: args);
  }

  static void goBack([dynamic result]) {
    navigatorKey.currentState?.pop(result);
  }

  static void pushAndRemoveAll(String route, {Object? args}) {
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      route,
          (route) => false,
      arguments: args,
    );
  }
}
