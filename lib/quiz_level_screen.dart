import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:just_audio/just_audio.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:quizzy2earn/core/app_router.dart';
import 'ads/ad_helper.dart';
import 'package:confetti/confetti.dart';

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
  late ConfettiController _confettiController;
  int currentIndex = 0;
  bool showResult = false;
  bool lastCorrect = false;
  String correctAnswer = '';
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();

    final startIndex = (widget.level - 1) * 6;
    final endIndex = startIndex + 6;

    // ✅ SAFETY CHECK (VERY IMPORTANT)
    if (startIndex >= widget.questions.length) {
      // 🔥 NEVER EMPTY (fallback)
      levelQuestions = widget.questions.take(6).toList();
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

    _audioPlayer.setLoopMode(LoopMode.off);

    _resultAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));

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
    _confettiController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> addCoin() async {

    final callable =
    FirebaseFunctions.instance.httpsCallable('claimGameReward');

    await callable.call({
      "coins": 1,
      "source": "quiz"
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

    final callable =
    FirebaseFunctions.instance.httpsCallable('claimGameReward');

    await callable.call({
      "coins": coins,
      "source": "quiz_bonus"
    });

  }

  void checkAnswer(String selected) {

    final q = levelQuestions[currentIndex];

    String clean(String text) {
      return text
          .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim()
          .toLowerCase();
    }

    final selectedClean = clean(selected);
    final correctClean = clean(q['correctAnswer']);

    final isCorrect = selectedClean == correctClean;

    questionCounterForAd++;

    // 👉 Show ad every 6 questions
    if (questionCounterForAd % 6 == 0 && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback =
          FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _loadInterstitialAd();

              _handleResult(isCorrect, q);
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _loadInterstitialAd();

              _handleResult(isCorrect, q);
            },
          );

      _interstitialAd!.show();
    } else {
      _handleResult(isCorrect, q);
    }
    debugPrint("SELECTED: $selected");
    debugPrint("CORRECT: ${q['correctAnswer']}");
    debugPrint("RESULT: $isCorrect");
  }

  String _cleanOption(String text) {
    return text
        .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '') // remove hidden chars
        .replaceAll(RegExp(r'\s+'), ' ') // normalize spaces
        .trim();
  }

  void _handleResult(bool isCorrect, Map<String, dynamic> q) async {

    // ✅ GIVE COIN IF CORRECT
    if (isCorrect) {
      addCoin();

      // 🔊 PLAY COIN SOUND
      await _audioPlayer.setAsset('assets/sounds/coin.mp3');
      await _audioPlayer.play();

      // 🎉 CONFETTI TRIGGER
      _confettiController.play();
    }

    setState(() {
      lastCorrect = isCorrect;
      correctAnswer = q['correctAnswer'];
      showResult = true;
    });
    _resultAnimController.forward(from: 0); // 🔥 ADD THIS
  }

  void _showRewardedAd() {

    if (_rewardedAd == null || rewardTaken) return;

    _rewardedAd!.fullScreenContentCallback =
        FullScreenContentCallback(
          onAdDismissedFullScreenContent: (ad) {
            ad.dispose();
            _loadRewardedAd(); // preload next
          },
          onAdFailedToShowFullScreenContent: (ad, error) {
            ad.dispose();
            _loadRewardedAd();
          },
        );

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) async {

        // ✅ GIVE BONUS COINS
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

      // ✅ SAFE NAVIGATION (NO POP FIRST)
      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRouter.levels,
            (route) => route.isFirst,
        arguments: {'questions': widget.questions},
      );
    }
  }

  Future<void> completeLevel() async {
    final user = FirebaseAuth.instance.currentUser!;
    final userRef =
    FirebaseFirestore.instance.collection('users').doc(user.uid);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snapshot = await tx.get(userRef);
      final data = snapshot.data();
      if (data == null) return;

      final today = DateTime.now().toString().substring(0, 10);

      /// ✅ TODAY LEVELS
      List<int> playedToday = [];
      if (data['playedLevelsToday'] is List) {
        playedToday = (data['playedLevelsToday'] as List)
            .map((e) => int.tryParse(e.toString()) ?? 0)
            .where((e) => e > 0)
            .toList();
      }

      /// ✅ PERMANENT LEVELS
      List<int> playedAll = [];
      if (data['playedLevels'] is List) {
        playedAll = (data['playedLevels'] as List)
            .map((e) => int.tryParse(e.toString()) ?? 0)
            .where((e) => e > 0)
            .toList();
      }

      int maxUnlockedLevel = data['maxUnlockedLevel'] ?? 10;

      /// ✅ CHECK IF NEW LEVEL (🔥 IMPORTANT FIX)
      final isNewLevel = !playedAll.contains(widget.level);

      /// ✅ ADD LEVEL SAFELY
      if (!playedToday.contains(widget.level)) {
        playedToday.add(widget.level);
      }

      if (isNewLevel) {
        playedAll.add(widget.level);
      }

      /// ✅ UPDATE USER (🔥 FIXED QUIZ COUNT)
      tx.update(userRef, {
        'playedLevelsToday': playedToday,
        'playedLevels': playedAll,
        'lastPlayedDate': today,
        'maxUnlockedLevel': maxUnlockedLevel,

        'coinsAvailable': data['coinsAvailable'],
        'coinsLocked': data['coinsLocked'],

        // 🔥 KEY FIX → NO DUPLICATE COUNT
        'quizCount': isNewLevel
            ? FieldValue.increment(1)
            : data['quizCount'] ?? 0,
      });
    });

    /// ❌ REMOVED OLD INCREMENT (IMPORTANT)
    /// DO NOT ADD quizCount.increment here anymore

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
    final safeLength = levelQuestions.isEmpty ? 1 : levelQuestions.length;
    final progress = (currentIndex + 1) / safeLength;

    return PopScope(
      canPop: false, // 🔥 block system back

      onPopInvokedWithResult: (didPop, result) {

        // ❌ BLOCK EXIT DURING QUIZ
        if (currentIndex < levelQuestions.length - 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("⚠️ Complete all questions to exit"),
            ),
          );
          return;
        }

        // ✅ ALLOW EXIT AFTER FINISH
        Navigator.pop(context);
      },

      child: Scaffold(
        backgroundColor: const Color(0xFF1E1E2C),

        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text('Level ${widget.level}'),
          backgroundColor: Colors.deepPurple,
          centerTitle: true,
        ),

        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: showResult
                ? FadeTransition(
              opacity: _resultFade,
              child: ScaleTransition(
                scale: Tween(begin: 0.8, end: 1.0)
                    .animate(_resultAnimController),
                child: buildResultUI(),
              ),
            )
                : buildQuestionUI(progress),
          ),
        ),
      ),
    );
  }

  /// ------------------ QUESTION UI ------------------

  Widget buildQuestionUI(double progress) {
    if (levelQuestions.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white,),
      );
    }
    final q = levelQuestions[currentIndex];

    final questionNumber = currentIndex + 1;

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
          child: Column( // ✅ FIXED
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [

              /// 🔥 QUESTION NUMBER
              Text(
                'Q$questionNumber',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              /// QUESTION TEXT
              Text(
                q['question'],
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        const SizedBox(height: 30),

        /// Options
        ...q['options'].map<Widget>((opt) {
          debugPrint("OPTION RAW: [$opt]");
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
                  _cleanOption(opt),
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
    return Stack(
      alignment: Alignment.center,
      children: [

        /// 🎉 CONFETTI (FIXED POSITION)
        if (lastCorrect)
          Positioned.fill(
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.orange,
                Colors.purple,
              ],
            ),
          ),

        /// MAIN CONTENT CENTERED
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              /// ICON
              if (lastCorrect)
                SizedBox(
                  height: 150,
                  child: Lottie.asset(
                    'assets/animations/coin.json',
                    repeat: false,
                  ),
                )
              else
                Icon(
                  Icons.cancel,
                  size: 110,
                  color: Colors.redAccent,
                ),

              const SizedBox(height: 20),

              /// TITLE
              Text(
                lastCorrect ? 'Correct!' : 'Wrong!',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 10),

              /// RESULT TEXT
              if (lastCorrect)
                const Text(
                  '+1 Coin Added 💰',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),

              if (!lastCorrect)
                Text(
                  'Correct: $correctAnswer',
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 18,
                  ),
                ),

              const SizedBox(height: 30),

              /// 🎁 REWARD BUTTON
              if (_rewardedAd != null && !rewardTaken)
                ElevatedButton.icon(
                  icon: const Icon(Icons.ondemand_video),
                  label: const Text('Watch Ad & Get +2 Coins'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 24),
                  ),
                  onPressed: _showRewardedAd,
                ),

              const SizedBox(height: 20),

              /// NEXT BUTTON
              ElevatedButton(
                onPressed: nextQuestion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(
                      vertical: 14, horizontal: 40),
                ),
                child: const Text('Next'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}