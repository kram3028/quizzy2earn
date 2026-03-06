import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:quizzy2earn/core/navigation_service.dart';
import 'ads/ad_helper.dart';

class QuizLevelScreen extends StatefulWidget {
  final int level;
  final List<Map<String, dynamic>> questions;

  const QuizLevelScreen({
    super.key,
    required this.level,
    required this.questions,
  });

  @override
  State<QuizLevelScreen> createState() => _QuizLevelScreenState();
}

class _QuizLevelScreenState extends State<QuizLevelScreen>
    with SingleTickerProviderStateMixin {
  late List<Map<String, dynamic>> levelQuestions;
  RewardedAd? _rewardedAd;
  bool rewardTaken = false;
  InterstitialAd? _interstitialAd;
  int questionCounterForAd = 0;
  late AnimationController _resultAnimController;
  late Animation<double> _resultFade;
  int currentIndex = 0;
  bool showResult = false;
  bool lastCorrect = false;
  String correctAnswer = '';

  @override
  void initState() {
    super.initState();

    final startIndex = (widget.level - 1) * 6;
    final endIndex = startIndex + 6;

    // ✅ SAFETY CHECK (VERY IMPORTANT)
    if (startIndex >= widget.questions.length) {
      levelQuestions = [];
    } else {
      levelQuestions = widget.questions.sublist(
        startIndex,
        endIndex > widget.questions.length
            ? widget.questions.length
            : endIndex,
      );
    }

    _loadRewardedAd();

    _loadInterstitialAd();

    _resultAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _resultFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _resultAnimController,
        curve: Curves.easeIn,
      ),
    );
  }

  @override
  void dispose() {
    _resultAnimController.dispose();
    super.dispose();
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

  Future<void> addBonusCoins() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({
      'coinsAvailable': FieldValue.increment(2),
    });
  }

  Future<void> addCoinsToUser(int coins) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);

      if (!snap.exists) return;

      final currentCoins =
          (snap.data()?['coinsAvailable'] as num?)?.toInt() ?? 0;

      tx.update(ref, {
        'coinsAvailable': currentCoins + coins,
      });
    });
  }

  void checkAnswer(String selected) async {
    final q = levelQuestions[currentIndex];
    final isCorrect = selected == q['answer'];

    if (isCorrect) {
      await addCoin();
    }

    questionCounterForAd++;

    // 👉 If 6th question → show ad FIRST → then result
    if (questionCounterForAd % 6 == 0 && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback =
          FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _loadInterstitialAd(); // preload next

              setState(() {
                lastCorrect = isCorrect;
                correctAnswer = q['answer'];
                showResult = true;
              });
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _loadInterstitialAd();

              setState(() {
                lastCorrect = isCorrect;
                correctAnswer = q['answer'];
                showResult = true;
              });
            },
          );

      _interstitialAd!.show();
    } else {
      // 👉 Normal flow (no ad)
      setState(() {
        lastCorrect = isCorrect;
        correctAnswer = q['answer'];
        showResult = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _resultAnimController.forward(from: 0);
        }
      });
    }
  }

  void nextQuestion() async {
    if (currentIndex < levelQuestions.length - 1) {
      setState(() {
        showResult = false;
        rewardTaken = false;
        currentIndex++;
      });
    } else {
      await completeLevel();
      NavigationService.goBack();
    }
  }

  Future<void> completeLevel() async {
    final user = FirebaseAuth.instance.currentUser!;
    final userRef =
    FirebaseFirestore.instance.collection('users').doc(user.uid);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      tx.update(userRef, {
        'completedLevels': FieldValue.arrayUnion([widget.level]),
        'currentLevel': widget.level + 1,
      });
    });

    /// 🔥 UPDATE DAILY + WEEKLY QUIZ MISSIONS
    await updateQuizMission();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('🎉 Level ${widget.level} Completed!')),
    );
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: AdHelper.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          debugPrint('✅ Rewarded Loaded');
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          debugPrint('❌ Rewarded failed: $error');
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
          debugPrint('✅ Interstitial Loaded (Level)');
        },
        onAdFailedToLoad: (error) {
          debugPrint('❌ Interstitial failed: $error');
        },
      ),
    );
  }

  Future<void> updateQuizMission() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final dailyRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('missions')
        .doc('daily');

    final weeklyRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('missions')
        .doc('weekly');

    await FirebaseFirestore.instance.runTransaction((tx) async {
      tx.set(
        dailyRef,
        {
          'quizCompleted': FieldValue.increment(1),
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      tx.set(
        weeklyRef,
        {
          'quizCompleted': FieldValue.increment(1),
        },
        SetOptions(merge: true),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = (currentIndex + 1) / levelQuestions.length;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        title: Text('Level ${widget.level}'),
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
      ),
      body: levelQuestions.isEmpty
          ? _buildComingSoonUI()
          : Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: showResult
              ? FadeTransition(
            opacity: _resultFade,
            child: buildResultUI(),
          )
              : buildQuestionUI(progress),
        ),
      ),
    );
  }

  /// ------------------ QUESTION UI ------------------

  Widget buildQuestionUI(double progress) {
    final q = levelQuestions[currentIndex];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [

        /// Progress
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: Colors.white24,
            valueColor:
            const AlwaysStoppedAnimation<Color>(Colors.deepPurple),
          ),
        ),

        const SizedBox(height: 30),

        /// Question Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24),
          ),
          child: Text(
            q['question'],
            style: const TextStyle(
              fontSize: 20,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        const SizedBox(height: 30),

        /// Options
        ...q['options'].map<Widget>((opt) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: InkWell(
              onTap: () => checkAnswer(opt),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.deepPurple.shade400,
                      Colors.deepPurple.shade600,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Text(
                  opt,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  /// ------------------ RESULT UI ------------------

  Widget buildResultUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          lastCorrect ? Icons.check_circle : Icons.cancel,
          size: 100,
          color: lastCorrect ? Colors.green : Colors.red,
        ),
        const SizedBox(height: 20),
        Text(
          lastCorrect ? 'Correct Answer!' : 'Wrong Answer!',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        if (!lastCorrect)
          Text(
            'Correct: $correctAnswer',
            style: const TextStyle(
              color: Colors.orange,
              fontSize: 18,
            ),
          ),
        if (lastCorrect)
          const Text(
            '+1 Coin Added 💰',
            style: TextStyle(
              color: Colors.greenAccent,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        if (_rewardedAd != null && !rewardTaken)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.card_giftcard),
              label: const Text('Watch Ad & Get +2 Bonus Coins'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: (_rewardedAd == null || rewardTaken)
                  ? null
                  : () {
                _rewardedAd!.fullScreenContentCallback =
                    FullScreenContentCallback(
                      onAdDismissedFullScreenContent: (ad) {
                        ad.dispose();
                        _loadRewardedAd(); // preload next
                      },
                    );

                _rewardedAd!.show(
                  onUserEarnedReward: (ad, reward) async {
                    // ✅ ONLY HERE GIVE COINS
                    await addCoinsToUser(2);

                    setState(() {
                      rewardTaken = true;
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('+2 Bonus Coins Added 🎉'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        const SizedBox(height: 30),
        ElevatedButton(
          onPressed: nextQuestion,
          child: const Text('Next'),
        )
      ],
    );
  }

  Widget _buildComingSoonUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(
            Icons.lock_clock,
            size: 100,
            color: Colors.grey,
          ),
          SizedBox(height: 20),
          Text(
            'Level Coming Soon 🚀',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Come back tomorrow for new questions!',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}