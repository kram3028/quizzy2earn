import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quizzy2earn/core/navigation_service.dart';
import 'ads/ad_helper.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'widgets/bottom_banner_ad.dart';

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
  final StreamController<int> controller = StreamController<int>();

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

  final List<int> rewards = [2, 3, 5, 8, 10, 0];

  @override
  void initState() {
    super.initState();
    checkDailyLimit();
    _loadRewardedAd();
    _loadInterstitialAd();
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
    controller.close();
    _interstitialAd?.dispose();
    _timer?.cancel();
    _glowController.dispose();
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
    final user = FirebaseAuth.instance.currentUser!;
    final ref =
    FirebaseFirestore.instance.collection('users').doc(user.uid);

    await ref.update({
      'coinsAvailable': FieldValue.increment(coins),
    });
  }

  void _spinWheel({required bool rewarded}) async {
    final index = Random().nextInt(rewards.length);
    controller.add(index);

    await Future.delayed(const Duration(seconds: 4));

    final coins = rewards[index];

    if (rewarded) {
      await useRewardedSpin();
    } else {
      await useFreeSpin();
    }

    Future<void> showResultDialog() async {
      if (coins > 0) {
        await _addCoins(coins);

        final user = FirebaseAuth.instance.currentUser!;
        final ref = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('daily_spin')
            .doc(todayDocId);

        await ref.update({
          'spinCoinsEarned': FieldValue.increment(coins),
        });

        spinCoinsToday += coins;
        totalCoins += coins;
      }

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('You Won!'),
          content: Text(
            coins > 0
                ? '🎉 You got $coins coins!'
                : '😅 Better luck next time!',
          ),
          actions: [
            TextButton(
              onPressed: () => NavigationService.goBack(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      setState(() {});
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
      showResultDialog();
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
      onUserEarnedReward: (_, __) {
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

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
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

    setState(() => freeSpinsUsed++);
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

    setState(() => rewardedSpinsUsed++);
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
    final hours = d.inHours.remainder(24);
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);

    return "${two(hours)}:${two(minutes)}:${two(seconds)}";
  }

  Duration getTimeUntilMidnight() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return tomorrow.difference(now);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      bottomNavigationBar: const BottomBannerAd(),
      appBar: AppBar(
        title: const Text('Daily Spin'),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
      ),

      // ✅ NEW BODY WITH STACK
        body: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [

                    /// TOP CARD
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.deepPurple.shade400,
                            Colors.deepPurple.shade700,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurple.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Today from Spin',
                                style: TextStyle(color: Colors.white70),
                              ),
                              Text(
                                '🟣 $spinCoinsToday Coins',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Wallet Coins',
                                style: TextStyle(color: Colors.white70),
                              ),
                              Text(
                                '🟡 $totalCoins Coins',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    /// GLOW WHEEL
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        height: 340,
                        child: AnimatedBuilder(
                          animation: _glowAnim,
                          builder: (context, _) {
                            return Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.deepPurple.withOpacity(_glowAnim.value),
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
                                    items: rewards.map((e) {
                                      return FortuneItem(
                                        child: Text(
                                          e == 0 ? 'TRY\nAGAIN' : '+$e\nCOINS',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        style: FortuneItemStyle(
                                          color: e == 0
                                              ? Colors.grey.shade700
                                              : Colors.deepPurple.shade400,
                                          borderColor: Colors.white,
                                          borderWidth: 2,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  const Positioned(
                                    top: 6,
                                    child: Icon(
                                      Icons.arrow_drop_down,
                                      size: 50,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ⏳ COUNTDOWN (ONLY AFTER FREE SPINS FINISHED)
                    if (!canUseFreeSpin)
                      Column(
                        children: [
                          const Text(
                            'Come back tomorrow in',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            formatTime(timeLeft),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 24),

                    /// 🎯 FREE SPIN BUTTON
                    SizedBox(
                      width: 220,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: canUseFreeSpin
                            ? () => _spinWheel(rewarded: false)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          disabledBackgroundColor: Colors.grey.shade400,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          canUseFreeSpin
                              ? 'Free Spin (${2 - freeSpinsUsed} left)'
                              : 'Free Spins Finished',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    /// 🎥 REWARDED SPIN BUTTON
                    SizedBox(
                      width: 220,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: canUseRewardedSpin ? _handleRewardedSpin : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          disabledBackgroundColor: Colors.grey.shade400,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          canUseRewardedSpin
                              ? 'Watch Ad Spin (${3 - rewardedSpinsUsed} left)'
                              : 'Finish Free Spins First',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
    );
  }
}
