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

import '../../ads/ad_helper.dart';
import '../../widgets/bottom_banner_ad.dart';
import '../wallet/wallet_tab.dart';
import '../withdraw/withdraw_tab.dart';
import '../withdraw/withdraw_service.dart';
import '../../services/fraud_detection_service.dart';
import '../profile/profile_tab.dart';

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
        .set({
      'fcmToken': token,
    }, SetOptions(merge: true));
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
                NavigationService.goBack();
                NavigationService.pushNamed(
                  AppRouter.terms,
                  args: {
                    'forceAgree': true,
                    'currentTermsVersion': currentTermsVersion,
                  }
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
      currentScreen = WalletTab(
        coinsAvailable: coinsAvailable,
        coinsLocked: coinsLocked,
        hasPendingWithdraw: hasPendingWithdraw,
        currentTermsVersion: currentTermsVersion,
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