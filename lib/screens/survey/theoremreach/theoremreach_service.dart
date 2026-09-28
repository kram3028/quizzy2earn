import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class TheoremReachService {
  TheoremReachService._();

  static const MethodChannel _channel =
  MethodChannel('com.quizzy2earn/theoremreach');

  // Reward Stream
  static final StreamController<int> _rewardController =
  StreamController<int>.broadcast();

  static Stream<int> get rewardStream =>
      _rewardController.stream;

  // Survey Wall Closed Stream
  static final StreamController<void> _closedController =
  StreamController<void>.broadcast();

  static Stream<void> get closedStream =>
      _closedController.stream;

  // Survey Availability Stream
  static final StreamController<bool> _availabilityController =
  StreamController<bool>.broadcast();

  static Stream<bool> get availabilityStream =>
      _availabilityController.stream;

  static bool _initialized = false;

  /// Initialize native callbacks.
  static void initialize() {
    if (_initialized) return;

    _initialized = true;

    _channel.setMethodCallHandler(_handleNativeCallbacks);
  }

  static Future<void> _handleNativeCallbacks(
      MethodCall call,
      ) async {
    switch (call.method) {
      case "onReward":
        final reward = call.arguments as int;

        debugPrint(
          "TheoremReach Reward: $reward",
        );

        _rewardController.add(reward);
        break;

      case "onRewardCenterOpened":
        debugPrint(
          "Reward Center Opened",
        );
        break;

      case "onRewardCenterClosed":
        debugPrint(
          "Reward Center Closed",
        );

        _closedController.add(null);
        break;

      case "onSurveyAvailable":
        final available =
        call.arguments as bool;

        debugPrint(
          "Survey Available: $available",
        );

        _availabilityController.add(
          available,
        );
        break;

      default:
        debugPrint(
          "Unknown callback: ${call.method}",
        );
    }
  }

  /// Open Reward Center
  static Future<bool> openSurveyWall({
    required String userId,
  }) async {
    initialize();

    try {
      final bool? result =
      await _channel.invokeMethod<bool>(
        "openTheoremReach",
        {
          "userId": userId,
        },
      );

      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception(
        "Failed to open TheoremReach: ${e.message}",
      );
    }
  }

  static void dispose() {
    _rewardController.close();
    _closedController.close();
    _availabilityController.close();
  }
}