import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quizzy2earn/core/navigation_service.dart';
import 'package:quizzy2earn/core/app_theme.dart';
import 'ads/ad_helper.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'widgets/bottom_banner_ad.dart';
import 'package:cloud_functions/cloud_functions.dart';

String get todayDocId {
  final now = DateTime.now();
  return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
}

class DailySpinScreen extends StatefulWidget {
  const DailySpinScreen({super.key});

  @override
  State<DailySpinScreen> createState() => _DailySpinScreenState();
}

class _DailySpinScreenState extends State<DailySpinScreen>
    with TickerProviderStateMixin {
  bool _isSpinning = false;
  late StreamController<int> controller;

  RewardedAd? _rewardedAd;
  int freeSpinsUsed = 0;
  int rewardedSpinsUsed = 0;
  bool loading = true;
  bool get canUseFreeSpin => freeSpinsUsed < 2;
// 🔥 Rewarded spins only AFTER free spins finished
  bool get canUseRewardedSpin =>
      freeSpinsUsed >= 2 && rewardedSpinsUsed < 3;
  int spinCoinsToday = 0;
  int totalCoins = 0;
  InterstitialAd? _interstitialAd;
  Duration timeLeft = Duration.zero;
  Timer? _timer;
  late AnimationController _glowController;
  late Animation<double> _glowAnim;
  final AudioPlayer _spinPlayer = AudioPlayer();

  final List<int> rewards = [2, 3, 5, 8, 10, 0];

  @override
  void initState() {
    super.initState();
    controller = StreamController<int>.broadcast();
    checkDailyLimit();
    _loadRewardedAd();
    _loadInterstitialAd();
    _spinPlayer.setAsset('assets/sounds/spin_wheel.mp3');
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _glowAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {

    _isSpinning = false;

    _timer?.cancel();
    _interstitialAd?.dispose();

    if (!controller.isClosed) {
      controller.close();
    }

    _glowController.dispose();
    _spinPlayer.stop();
    _spinPlayer.dispose();

    super.dispose();
  }

  bool rewardedAdReady = false;

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: AdHelper.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          rewardedAdReady = true;
        },
        onAdFailedToLoad: (error) {
          rewardedAdReady = false;
        },
      ),
    );
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: AdHelper.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          debugPrint('✅ Spin Interstitial Loaded');
        },
        onAdFailedToLoad: (_) {},
      ),
    );
  }

  Future<void> _addCoins(int coins) async {

    final callable =
    FirebaseFunctions.instance.httpsCallable('claimGameReward');

    await callable.call({
      "coins": coins,
      "source": "spin"
    });

  }

  Future<void> _spinWheel({required bool rewarded}) async {

    if (_isSpinning) return;

    _isSpinning = true;

    try {

      final index = Random().nextInt(rewards.length);

      debugPrint("Controller closed = ${controller.isClosed}");
      debugPrint("Selected index = $index");

      await _spinPlayer.seek(Duration.zero);

// START BOTH TOGETHER
      controller.add(index + rewards.length * 5);

      await _spinPlayer.play();

      await Future.delayed(const Duration(milliseconds: 6000));

      await _spinPlayer.stop();

      final coins = rewards[index];

      /// 🚀 SHOW RESULT IMMEDIATELY
      Future<void> showResultDialog() async {

        if (!mounted) return;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E2C),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(
                color: Color(0x26FFFFFF),
                width: 1.5,
              ),
            ),
            title: Row(
              children: [
                Icon(
                  coins > 0 ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded,
                  color: coins > 0 ? Colors.amber : Colors.grey,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Text(
                  coins > 0 ? 'You Won!' : 'Oops!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Text(
                  coins > 0
                      ? '🎉 You got $coins coins!'
                      : '😅 Better luck next time!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xE6FFFFFF),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => NavigationService.goBack(),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.deepPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: const Text(
                  'Great!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );

        /// 🔥 SAVE REWARD IN BACKGROUND
        if (coins > 0) {

          unawaited(_addCoins(coins));

          final user = FirebaseAuth.instance.currentUser!;
          final ref = FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('daily_spin')
              .doc(todayDocId);

          unawaited(
            ref.update({
              'spinCoinsEarned': FieldValue.increment(coins),
            }),
          );

          spinCoinsToday += coins;
          totalCoins += coins;
        }

        setState(() {});
      }

      /// 🔥 UPDATE SPIN COUNTER IN BACKGROUND
      if (rewarded) {
        unawaited(useRewardedSpin());
      } else {
        unawaited(useFreeSpin());
      }

    // 🎯 SHOW INTERSTITIAL ONLY AFTER 2nd FREE SPIN
    if (!rewarded && freeSpinsUsed == 2 && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback =
          FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _loadInterstitialAd();
              showResultDialog();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _loadInterstitialAd();
              showResultDialog();
            },
          );

      _interstitialAd!.show();
    } else {
      await showResultDialog();
    }
    } finally {
      _isSpinning = false;
    }
  }

  void _handleRewardedSpin() {
    if (!rewardedAdReady || _rewardedAd == null) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('No Ads Available'),
          content: const Text(
            'No ads available right now.\nPlease try again in a few seconds.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                NavigationService.goBack();
                _loadRewardedAd(); // try loading again
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    _rewardedAd!.fullScreenContentCallback =
        FullScreenContentCallback(
          onAdDismissedFullScreenContent: (ad) {
            ad.dispose();
            rewardedAdReady = false;
            _loadRewardedAd();
          },
        );

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        _spinWheel(rewarded: true);
      },
    );
  }

  Future<void> checkDailyLimit() async {
    final user = FirebaseAuth.instance.currentUser!;

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('daily_spin')
        .doc(todayDocId);

    final snap = await docRef.get();

    if (!snap.exists) {
      // ✅ First time today → create fresh record
      await docRef.set({
        'freeSpinsUsed': 0,
        'rewardedSpinsUsed': 0,
        'spinCoinsEarned': 0,
        'date': todayDocId,
      });

      freeSpinsUsed = 0;
      rewardedSpinsUsed = 0;
      spinCoinsToday = 0;

    } else {
      final data = snap.data()!;

      freeSpinsUsed = data['freeSpinsUsed'] ?? 0;
      rewardedSpinsUsed = data['rewardedSpinsUsed'] ?? 0;
      spinCoinsToday = data['spinCoinsEarned'] ?? 0;
    }

    // 🔥 ALWAYS load total wallet coins
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    totalCoins = userDoc.data()?['coinsAvailable'] ?? 0;

    if (!mounted) return;

    setState(() {
      loading = false;
    });
    if (freeSpinsUsed >= 2) {
      timeLeft = getTimeUntilMidnight();
      startMidnightCountdown();
    }
  }

  void startMidnightCountdown() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      final left = getTimeUntilMidnight();

      if (mounted) {
        setState(() {
          timeLeft = left;
        });
      }

      if (left.inSeconds <= 0) {
        _timer?.cancel();
        checkDailyLimit(); // refresh spins
      }
    });
  }

  Future<void> useFreeSpin() async {
    final user = FirebaseAuth.instance.currentUser!;
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('daily_spin')
        .doc(todayDocId);

    await ref.update({
      'freeSpinsUsed': FieldValue.increment(1),
    });

    /// 🔥 UPDATE DAILY MISSION
    await updateSpinMission();

    if (!mounted) return;

    setState(() {
      freeSpinsUsed++;
    });
  }

  Future<void> useRewardedSpin() async {
    final user = FirebaseAuth.instance.currentUser!;
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('daily_spin')
        .doc(todayDocId);

    await ref.update({
      'rewardedSpinsUsed': FieldValue.increment(1),
    });

    /// 🔥 UPDATE DAILY MISSION
    await updateSpinMission();

    if (!mounted) return;

    setState(() {
      rewardedSpinsUsed++;
    });
  }

  Future<void> updateSpinMission() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final dailyRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('missions')
        .doc('daily');

    await dailyRef.set({
      'spinUsed': FieldValue.increment(1),
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String formatTime(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    int hours = d.inHours;
    int minutes = d.inMinutes.remainder(60);
    int seconds = d.inSeconds.remainder(60);

    return "${two(hours)}:${two(minutes)}:${two(seconds)}";
  }

  Duration getTimeUntilMidnight() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return tomorrow.difference(now);
  }

  Color _getRewardColor(int value) {
    switch (value) {
      case 10:
        return const Color(0xFFFFD700); // Gold star color
      case 8:
        return const Color(0xFFFF4081); // Vibrant Pink
      case 5:
        return const Color(0xFF00E5FF); // Neon Cyan
      case 3:
        return const Color(0xFFE040FB); // Vibrant Purple
      case 2:
        return const Color(0xFF651FFF); // Indigo accent
      default:
        return const Color(0xFF455A64); // Cool Grey
    }
  }

  Widget _buildGlassInfoCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0x26FFFFFF),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0x1A000000),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpinButton({
    required String label,
    required VoidCallback? onPressed,
    required List<Color> gradientColors,
    required IconData icon,
  }) {
    final bool isDisabled = onPressed == null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 250,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        boxShadow: isDisabled
            ? []
            : [
                BoxShadow(
                  color: gradientColors.last.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: isDisabled
                ? LinearGradient(
                    colors: const [
                      Color(0x14FFFFFF),
                      Color(0x14FFFFFF),
                    ],
                  )
                : LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: isDisabled
                  ? const Color(0x1AFFFFFF)
                  : const Color(0x33FFFFFF),
              width: 1.5,
            ),
          ),
          child: Container(
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isDisabled ? Colors.white30 : Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDisabled ? Colors.white30 : Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: appBackgroundGradient,
          ),
          child: const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      bottomNavigationBar: const BottomBannerAd(),
      appBar: AppBar(
        title: const Text(
          'Daily Spin',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => NavigationService.goBack(),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: appBackgroundGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),

                  // TOP CARD (Info)
                  Row(
                    children: [
                      Expanded(
                        child: _buildGlassInfoCard(
                          title: 'Today Spin',
                          value: '$spinCoinsToday Coins',
                          icon: Icons.rotate_right_rounded,
                          iconColor: const Color(0xFFE040FB),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildGlassInfoCard(
                          title: 'Wallet Coins',
                          value: '$totalCoins Coins',
                          icon: Icons.monetization_on_rounded,
                          iconColor: const Color(0xFFFFD700),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // GLOW WHEEL
                  SizedBox(
                    height: 330,
                    child: AnimatedBuilder(
                      animation: _glowAnim,
                      builder: (context, _) {
                        return Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6A11CB).withValues(alpha: _glowAnim.value * 0.7),
                                blurRadius: 35,
                                spreadRadius: 6,
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              FortuneWheel(
                                selected: controller.stream,
                                animateFirst: false,
                                physics: CircularPanPhysics(),
                                duration: const Duration(milliseconds: 6000),
                                items: rewards.map((e) {
                                  return FortuneItem(
                                    child: Text(
                                      e == 0 ? 'TRY\nAGAIN' : '+$e\nCOINS',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    style: FortuneItemStyle(
                                      color: _getRewardColor(e),
                                      borderColor: const Color(0x66FFFFFF),
                                      borderWidth: 2,
                                    ),
                                  );
                                }).toList(),
                              ),
                              
                              // Indicator Pointer at the top
                              Positioned(
                                top: -6,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFFB300),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0x80FFB300),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.arrow_drop_down_sharp,
                                    size: 40,
                                    color: Colors.white,
                                  ),
                                ),
                              ),

                              // Center Hub / Pin
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E2C),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFFFB300),
                                    width: 3,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x4D000000),
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.star_rounded,
                                    color: Color(0xFFFFB300),
                                    size: 22,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // COUNTDOWN (ONLY AFTER FREE SPINS FINISHED)
                  if (!canUseFreeSpin)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0x33000000),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0x1AFFFFFF),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'NEXT SPIN REFILLS IN',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white70,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            formatTime(timeLeft),
                            style: const TextStyle(
                              fontSize: 22,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFFD700),
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 18),

                  // FREE SPIN BUTTON
                  _buildSpinButton(
                    label: canUseFreeSpin
                        ? 'Free Spin (${2 - freeSpinsUsed} left)'
                        : 'Free Spins Finished',
                    onPressed: canUseFreeSpin && !_isSpinning
                        ? () => _spinWheel(rewarded: false)
                        : null,
                    gradientColors: const [
                      Color(0xFF8E24AA),
                      Color(0xFFE91E63),
                    ],
                    icon: Icons.play_arrow_rounded,
                  ),

                  const SizedBox(height: 12),

                  // REWARDED SPIN BUTTON
                  _buildSpinButton(
                    label: canUseRewardedSpin
                        ? 'Watch Ad Spin (${3 - rewardedSpinsUsed} left)'
                        : 'Finish Free Spins First',
                    onPressed: canUseRewardedSpin && !_isSpinning
                        ? _handleRewardedSpin
                        : null,
                    gradientColors: const [
                      Color(0xFFFFB300),
                      Color(0xFFFF6F00),
                    ],
                    icon: Icons.play_circle_fill_rounded,
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
