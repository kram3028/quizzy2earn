import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

class UnityAdsHelper {
  UnityAdsHelper._();

  static const String gameId = '6144959';

  static const String rewardedPlacementId = 'Rewarded_Android';

  static const String interstitialPlacementId = 'Interstitial_Android';

  static const String bannerPlacementId = 'Banner_Android';

  static bool get testMode => true;

  static bool _initialized = false;

  static Future<void> initialize() async {

    if (_initialized) {
      developer.log(
        'Unity Ads already initialized',
        name: 'UnityAds',
      );
      return;
    }

    UnityAds.init(
      gameId: gameId,
      testMode: testMode,
      onComplete: () {

        _initialized = true;

        developer.log(
          'Unity Ads Initialized',
          name: 'UnityAds',
        );

        // Load the rewarded ad immediately after SDK initialization.
        loadBanner();

      },
      onFailed: (error, message) {
        developer.log(
          'Unity Ads Initialization Failed: $error - $message',
          name: 'UnityAds',
        );
      },
    );
  }

  static bool _rewardedLoaded = false;

  static bool get isRewardedLoaded => _rewardedLoaded;

  static Future<void> loadRewarded() async {
    developer.log(
      'Loading Rewarded Ad...',
      name: 'UnityAds',
    );

    UnityAds.load(
      placementId: rewardedPlacementId,
      onComplete: (placementId) {
        _rewardedLoaded = true;

        developer.log(
          'Rewarded Ad Loaded: $placementId',
          name: 'UnityAds',
        );
      },
      onFailed: (placementId, error, message) {
        _rewardedLoaded = false;

        developer.log(
          'Rewarded Load Failed: $placementId | $error | $message',
          name: 'UnityAds',
        );
      },
    );
  }

  static Future<void> loadBanner() async {
    developer.log(
      'Loading Banner...',
      name: 'UnityAds',
    );

    UnityAds.load(
      placementId: bannerPlacementId,
      onComplete: (placementId) {
        developer.log(
          'Banner Loaded: $placementId',
          name: 'UnityAds',
        );
      },
      onFailed: (placementId, error, message) {
        developer.log(
          'Banner Load Failed: $placementId | $error | $message',
          name: 'UnityAds',
        );
      },
    );
  }
}