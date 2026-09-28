/// ============================================================================
/// Quizzy2Earn - Advertisement Configuration
/// ============================================================================
///
/// This file controls which advertisement provider the app uses.
///
/// Supported providers:
///   • AdMob
///   • Unity Ads
///   • Both (AdMob → Unity fallback)
///   • None (Disable all ads)
///
/// Change ONLY `provider` below whenever you want to switch networks.
///
/// ============================================================================

enum AdProvider {
  /// Disable all advertisements.
  none,

  /// Google AdMob only.
  admob,

  /// Unity Ads only.
  unity,

  /// Try AdMob first.
  /// If unavailable, automatically use Unity.
  both,
}

class AdConfig {
  AdConfig._();

  //==========================================================================
  // ACTIVE AD PROVIDER
  //==========================================================================
  //
  // Change ONLY this value.
  //
  // AdProvider.none
  // AdProvider.admob
  // AdProvider.unity
  // AdProvider.both
  //
  //==========================================================================

  static const AdProvider provider = AdProvider.both;

  //==========================================================================
  // TEST MODE
  //==========================================================================
  //
  // true  = Test Ads
  // false = Live Ads
  //
  // IMPORTANT:
  // Keep this TRUE while developing.
  // Set FALSE before releasing production builds.
  //
  //==========================================================================

  static const bool testMode = true;

  //==========================================================================
  // LOGGING
  //==========================================================================
  //
  // Enable ad logs while debugging.
  //
  //==========================================================================

  static const bool enableLogs = true;

  //==========================================================================
  // FALLBACK
  //==========================================================================
  //
  // Only applies when provider == AdProvider.both
  //
  // Flow:
  //
  // AdMob Loaded?
  //      YES -> Show AdMob
  //      NO
  //        ↓
  // Unity Loaded?
  //      YES -> Show Unity
  //      NO
  //        ↓
  // Continue app without showing an ad.
  //
  //==========================================================================

  static const bool enableFallback = true;

  //==========================================================================
  // HELPERS
  //==========================================================================

  static bool get adsEnabled => provider != AdProvider.none;

  static bool get useAdMob =>
      provider == AdProvider.admob ||
          provider == AdProvider.both;

  static bool get useUnity =>
      provider == AdProvider.unity ||
          provider == AdProvider.both;

  static bool get useFallback =>
      provider == AdProvider.both && enableFallback;
}