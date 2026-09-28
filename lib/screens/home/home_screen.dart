import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:quizzy2earn/core/app_router.dart';
import 'package:quizzy2earn/core/navigation_service.dart';
import 'package:quizzy2earn/screens/referral/invite_earn_screen.dart';
import '../bonus/bonus_center_screen.dart';
import 'package:quizzy2earn/config/app_config.dart';

import '../../ads/ad_helper.dart';
import '../../widgets/bottom_banner_ad.dart';
import '../wallet/wallet_tab.dart';
import '../withdraw/withdraw_tab.dart';
import '../withdraw/withdraw_service.dart';
import '../../services/fraud_detection_service.dart';
import '../profile/profile_tab.dart';
import '../survey/survey_screen.dart';

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
  String? userName;
  int activeDays = 0;
  int streak = 0;
  Map<String, dynamic>? dailyMissionData;
  int selectedTabIndex = 0;
  StreamSubscription<DocumentSnapshot>? userSubscription;
  StreamSubscription<QuerySnapshot>? withdrawSubscription;
  StreamSubscription<DocumentSnapshot>? dailyMissionSubscription;
  Map<String, dynamic>? latestWithdrawRequest;
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
  int adWatchCount = 0;
  DateTime? lastAdTime;

  final String sheetUrl =
      'https://script.google.com/macros/s/AKfycbx2INUKrRWYjmyGCQBjP180T_RLZcLwKfn_vA1NLMGmEV52-5B3udzdSI4NEPcY9l58/exec';

  List<Map<String, dynamic>> questions = [];

  @override
  void initState() {
    super.initState();

    loadQuestionsFromSheet(); // ❓ Load quiz questions

    FraudDetectionService.enforceBlockIfNeeded();
    FraudDetectionService.updateFraudScore();

    startUserRealtimeListener();

    startWithdrawRealtimeListener();

    startDailyMissionRealtimeListener(); // 👈 Listen to daily missions

    saveFcmToken();

    FraudDetectionService.saveFingerprint();

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

    resetDailyMissionIfNeeded();

    saveIpAddress();
  }

  static Future<void> saveIpAddress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final res = await http.get(Uri.parse("https://api64.ipify.org?format=json"));
    final ip = jsonDecode(res.body)['ip'];

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);

    try {
      await userRef.update({'lastIp': ip});
    } catch (e) {
      await userRef.set({'lastIp': ip}, SetOptions(merge: true));
    }
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

  Future<void> resetDailyMissionIfNeeded() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final today = DateTime.now().toIso8601String().split("T")[0];

    final dailyRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('missions')
        .doc('daily');

    final snap = await dailyRef.get();

    /// 🔥 If first time OR new day → reset mission
    if (!snap.exists || snap['date'] != today) {

      // 🔥 TRACK ACTIVE DAY (ONLY ONCE PER DAY)
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      try {
        await userRef.update({
          'activeDays': FieldValue.increment(1),
        });
      } catch (e) {
        await userRef.set({
          'activeDays': 1,
        }, SetOptions(merge: true));
      }

      await dailyRef.set({
        'date': today,
        'quizCompleted': 0,
        'spinUsed': 0,
        'appOpened': true,
        'profileSaved': false,
        'rewardClaimed': false,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  void _showRewardedInterstitialThen(VoidCallback onContinue) {
    final now = DateTime.now();

    // ❌ Too many ads in short time
    if (lastAdTime != null &&
        now.difference(lastAdTime!).inSeconds < 10) {
      debugPrint("🚫 Ad blocked (too frequent)");
      onContinue();
      return;
    }

    // ❌ Daily limit (app: 50 ads)
    if (adWatchCount >= 50) {
      debugPrint("🚫 Ad limit reached");
      onContinue();
      return;
    }

    // ✅ Update counters
    adWatchCount++;
    lastAdTime = now;

    // 👇 EXISTING CODE STARTS HERE
    if (_rewardedInterstitialAd != null) {
      _rewardedInterstitialAd!.fullScreenContentCallback =
          FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _loadRewardedInterstitialAd();
              onContinue();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _loadRewardedInterstitialAd();
              onContinue();
            },
          );

      _rewardedInterstitialAd!.show(
        onUserEarnedReward: (ad, reward) {
          debugPrint('User watched rewarded interstitial');
        },
      );
    } else {
      onContinue();
    }
  }

  Future<void> loadQuestionsFromSheet() async {
    final response = await http.get(Uri.parse(sheetUrl));

    if (response.statusCode != 200) return;

    final List<dynamic> jsonList = jsonDecode(response.body);

    final today = DateTime.now().toString().substring(0, 10);

    List<Map<String, dynamic>> todayQuestions = [];
    List<Map<String, dynamic>> oldQuestions = [];

    for (final item in jsonList) {
      if (!isValidQuestion(item)) continue;

      // 🔥 SAFE CLEAN FUNCTION
      String clean(dynamic text) {
        return (text ?? '')
            .toString()
            .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
      }

      final q = {
        'id': clean(item['id']),
        'question': clean(item['question']),

        // ✅ FIXED: USE ARRAY INSTEAD OF option1,2,3,4
        'options': [
          clean(item['option1']),
          clean(item['option2']),
          clean(item['option3']),
          clean(item['option4']),
        ],

        // ✅ FIXED KEY NAME (VERY IMPORTANT)
        'correctAnswer': clean(item['answer']),

        'reference': clean(item['reference']),
        'difficulty': clean(item['difficulty'] ?? 'medium'),
        'date': clean(item['date']),
      };

      if (q['date'] == today) {
        todayQuestions.add(q);
      } else {
        oldQuestions.add(q);
      }
    }

    List<Map<String, dynamic>> finalQuestions = [];

    // 🔥 LOAD ALL QUESTIONS
    finalQuestions = [...todayQuestions, ...oldQuestions];

    // 🔀 Shuffle
    finalQuestions.shuffle();

    /// 🎯 BALANCE DIFFICULTY
    finalQuestions = balanceQuestions(finalQuestions);

    if (!mounted) return;

    setState(() {
      questions = finalQuestions;
    });
  }

  List<Map<String, dynamic>> balanceQuestions(List<Map<String, dynamic>> questions) {
    List<Map<String, dynamic>> easy = [];
    List<Map<String, dynamic>> medium = [];
    List<Map<String, dynamic>> hard = [];

    for (var q in questions) {
      switch (q['difficulty']) {
        case 'easy':
          easy.add(q);
          break;
        case 'hard':
          hard.add(q);
          break;
        default:
          medium.add(q);
      }
    }

    easy.shuffle();
    medium.shuffle();
    hard.shuffle();

    return [
      ...easy.take(20),
      ...medium.take(50),
      ...hard.take(30),
    ];
  }

  @override
  void dispose() {
    userSubscription?.cancel();
    withdrawSubscription?.cancel();
    dailyMissionSubscription?.cancel();

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

      if (!mounted) return;

      final daily = data['dailyLogin'] as Map<String, dynamic>?;

      setState(() {
        coinsAvailable = (data['coinsAvailable'] as num?)?.toInt() ?? 0;
        coinsLocked = (data['coinsLocked'] as num?)?.toInt() ?? 0;
        userName = data['name'] as String?;
        activeDays = (data['activeDays'] as num?)?.toInt() ?? 0;
        streak = (daily?['streak'] as num?)?.toInt() ?? 0;
      });
      debugPrint("CoinsAvailable: ${data['coinsAvailable']}");
    });
  }

  void startDailyMissionRealtimeListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    dailyMissionSubscription?.cancel();

    dailyMissionSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('missions')
        .doc('daily')
        .snapshots()
        .listen((doc) {
      if (!mounted) return;
      if (!doc.exists) return;

      setState(() {
        dailyMissionData = doc.data();
      });
    });
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

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);

    try {
      await userRef.update({'fcmToken': token});
    } catch (e) {
      await userRef.set({'fcmToken': token}, SetOptions(merge: true));
    }
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

    // ❌ Basic empty check
    if (question.isEmpty ||
        option1.isEmpty ||
        option2.isEmpty ||
        option3.isEmpty ||
        option4.isEmpty ||
        answer.isEmpty) {
      return false;
    }

    // ✅ NEW FIX: answer must match one of options
    final options = [option1, option2, option3, option4];

    return options.any((opt) =>
    opt.toLowerCase().trim() == answer.toLowerCase().trim());
  }

  @override
  Widget build(BuildContext context) {
    Widget currentScreen;

    if (selectedTabIndex == 0) {
      currentScreen = buildHomeTab();

    } else if (selectedTabIndex == 1) {
      currentScreen = WalletTab(
        coinsAvailable: coinsAvailable,
        coinsLocked: coinsLocked,
        hasPendingWithdraw: hasPendingWithdraw,
        onShowAdThen: _showRewardedInterstitialThen,
        onWithdraw: (amount, payoutMethod, payoutDetail) async {
          try {
            await WithdrawService.createWithdrawRequest(
              amount: amount,
              payoutMethod: payoutMethod,
              payoutDetail: payoutDetail,
            );

            setState(() {
              selectedTabIndex = 2;
            });
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.toString())),
            );
          }
        },
      );

    } else if (selectedTabIndex == 2) {
      currentScreen = WithdrawTab(
        latestWithdrawRequest: latestWithdrawRequest,
        confettiController: _confettiController,
      );

    } else if (selectedTabIndex == 3) {
      currentScreen = buildProfileTab();

    } else if (selectedTabIndex == 4) {
      currentScreen = const BonusCenterScreen();

    } else {
      currentScreen = buildHomeTab();
    }

    return Scaffold(
      appBar: selectedTabIndex == 0
          ? null
          : AppBar(
              title: Text(
                selectedTabIndex == 1
                    ? 'My Wallet'
                    : selectedTabIndex == 2
                        ? 'Withdrawal Status'
                        : selectedTabIndex == 3
                            ? 'Profile'
                            : 'Bonus Center',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.deepPurple,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
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
              BottomNavigationBarItem(icon: Icon(Icons.card_giftcard), label: 'Bonus'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _animateItem({required int index, required Widget child}) {
    final start = (index * 0.1).clamp(0.0, 0.6);
    final end = (start + 0.4).clamp(0.0, 1.0);

    final Animation<double> fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _homeAnimController,
        curve: Interval(start, end, curve: Curves.easeOut),
      ),
    );

    final Animation<Offset> slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _homeAnimController,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      ),
    );

    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: slideAnimation,
        child: child,
      ),
    );
  }

  Widget _badge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyMissionTracker() {
    if (dailyMissionData == null) {
      return const SizedBox.shrink();
    }

    final quiz = (dailyMissionData!['quizCompleted'] as num?)?.toInt() ?? 0;
    final spin = (dailyMissionData!['spinUsed'] as num?)?.toInt() ?? 0;

    final double quizProgress = (quiz / 10).clamp(0.0, 1.0);
    final double spinProgress = (spin / 2).clamp(0.0, 1.0);
    final double overallProgress = (quizProgress + spinProgress) / 2.0;
    final int percent = (overallProgress * 100).toInt();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.stars, color: Colors.amber, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Daily Mission Tracker',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                '$percent%',
                style: TextStyle(
                  color: percent == 100 ? Colors.greenAccent : Colors.amberAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: overallProgress,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                percent == 100 ? Colors.greenAccent : Colors.amber,
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _missionItemMini(
                  icon: Icons.quiz,
                  title: 'Quiz Levels',
                  value: '$quiz/10',
                  isDone: quiz >= 10,
                  color: Colors.deepPurpleAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _missionItemMini(
                  icon: Icons.casino,
                  title: 'Daily Spins',
                  value: '$spin/2',
                  isDone: spin >= 2,
                  color: Colors.orangeAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _missionItemMini({
    required IconData icon,
    required String title,
    required String value,
    required bool isDone,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDone ? Colors.green.withOpacity(0.3) : Colors.white.withOpacity(0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: (isDone ? Colors.green : color).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDone ? Icons.check : icon,
              size: 16,
              color: isDone ? Colors.greenAccent : color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
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

  Widget _gridActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: colors.first.withOpacity(0.25),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 24, color: Colors.white),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 11,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildHomeTab() {
    void openLevels() {
      NavigationService.pushNamed(
        AppRouter.levels,
        args: {'questions': questions},
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
        NavigationService.pushNamed(AppRouter.spin);
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

    final displayStreak = streak;
    final displayActiveDays = activeDays;
    final displayUserName = userName?.trim().split(' ').first ?? 'Explorer';

    Widget header = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back,',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$displayUserName! 👋',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        Row(
          children: [
            if (displayStreak > 0)
              _badge(
                icon: Icons.local_fire_department,
                label: '$displayStreak',
                color: Colors.orange,
              ),
            const SizedBox(width: 8),
            _badge(
              icon: Icons.calendar_today,
              label: '$displayActiveDays d',
              color: Colors.blueAccent,
            ),
          ],
        ),
      ],
    );

    Widget walletCard = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.deepPurple.shade900.withOpacity(0.85),
            Colors.deepPurple.shade700.withOpacity(0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
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
                'TOTAL BALANCE',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      radius: 3,
                      backgroundColor: Colors.green,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Live',
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                '🪙',
                style: TextStyle(fontSize: 28),
              ),
              const SizedBox(width: 8),
              Text(
                '${coinsAvailable + coinsLocked}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Coins',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withOpacity(0.15), height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available Balance',
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '🟡 $coinsAvailable',
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Locked / Pending',
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '🔒 $coinsLocked',
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    selectedTabIndex = 1;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: const Row(
                    children: [
                      Text(
                        'Redeem',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, size: 14, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final List<Widget> items = [
      header,
      const SizedBox(height: 20),
      walletCard,
      const SizedBox(height: 24),
      if (dailyMissionData != null) ...[
        _buildDailyMissionTracker(),
        const SizedBox(height: 24),
      ],
      GestureDetector(
        onTap: handleStartQuiz,
        child: _gameCard(
          icon: Icons.quiz,
          title: 'Start Quiz',
          subtitle: 'Answer questions & earn coins',
          colors: const [Color(0xFF6A11CB), Color(0xFF2575FC)],
          trailingBadge: questions.isNotEmpty
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${questions.length} Qs',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : null,
        ),
      ),
      const SizedBox(height: 16),
      GestureDetector(
        onTap: handleOpenSpin,
        child: _gameCard(
          icon: Icons.casino,
          title: 'Daily Spin Wheel',
          subtitle: 'Spin & win bonus coins',
          colors: const [Color(0xFFFF9100), Color(0xFFFF3D00)],
        ),
      ),
      const SizedBox(height: 24),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'More Ways to Earn',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _gridActionCard(
                icon: Icons.group,
                title: 'Invite Friends',
                subtitle: 'Refer & earn coins',
                colors: const [Color(0xFF00B0FF), Color(0xFF00E5FF)],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const InviteEarnScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 14),
              _gridActionCard(
                icon: Icons.poll,
                title: 'Surveys',
                subtitle: 'Complete offerwalls',
                colors: const [Color(0xFF00E676), Color(0xFF00B0FF)],
                onTap: () {
                  if (!AppConfig.enableCPX) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Surveys coming soon"),
                      ),
                    );
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SurveyScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 16),
      _comingSoonCard(
        icon: Icons.extension,
        title: 'More Mini Games',
        subtitle: 'More features will be added regularly.',
      ),
    ];

    final List<Widget> animatedItems = [];
    int animationIndex = 0;

    for (var widget in items) {
      if (widget is SizedBox) {
        animatedItems.add(widget);
      } else {
        animatedItems.add(_animateItem(index: animationIndex, child: widget));
        animationIndex++;
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
      child: SafeArea(
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
                  children: animatedItems,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gameCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> colors,
    Widget? trailingBadge,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.first.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, size: 32, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (trailingBadge != null) ...[
                      const SizedBox(width: 8),
                      trailingBadge,
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.white,
            ),
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white38, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
              ],
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
          NavigationService.pushNamed(
            AppRouter.levels,
            args: {'questions': questions},
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
    NavigationService.pushNamed(
      AppRouter.reference,
      args: {'url': url},
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