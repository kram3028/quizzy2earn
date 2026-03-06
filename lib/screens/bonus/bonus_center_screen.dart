import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../ads/ad_helper.dart';
import '../../core/app_theme.dart';

class BonusCenterScreen extends StatefulWidget {
  const BonusCenterScreen({super.key});

  @override
  State<BonusCenterScreen> createState() => _BonusCenterScreenState();
}

class _BonusCenterScreenState extends State<BonusCenterScreen> {
  int weeklyEarned = 0;
  int currentStreak = 0;
  bool canClaimToday = false;
  Duration nextClaimTime = Duration.zero;

  String referralCode = '';
  int referralCount = 0;
  RewardedAd? _rewardedAd;
  bool rewardedAdReady = false;

  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    loadBonusData();
    _loadRewardedAd();
  }

  /// 🔹 LOAD ALL BONUS DATA
  Future<void> loadBonusData() async {
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();

    final data = doc.data();

    if (data == null) return;

    final daily = data['dailyLogin'] ?? {};
    final referral = data['referral'] ?? {};
    final bonus = data['bonus'] ?? {};

    currentStreak = daily['streak'] ?? 0;
    weeklyEarned = bonus['weeklyEarned'] ?? 0;
    referralCode = referral['code'] ?? '';
    referralCount = referral['totalReferrals'] ?? 0;

    final lastClaim = daily['lastClaim'] as Timestamp?;

    if (lastClaim == null) {
      canClaimToday = true;
    } else {
      final now = DateTime.now();
      final difference = now.difference(lastClaim.toDate());

      if (difference.inHours >= 24) {
        canClaimToday = true;
      } else {
        canClaimToday = false;
        nextClaimTime = Duration(hours: 24) - difference;
      }
    }

    if (mounted) setState(() {});
  }

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

  void _showAdThenClaim() {
    if (_rewardedAd != null && rewardedAdReady) {
      _rewardedAd!.fullScreenContentCallback =
          FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _loadRewardedAd();
              claimDailyBonus();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _loadRewardedAd();
              claimDailyBonus();
            },
          );

      _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {},
      );
    } else {
      // fallback if ad not ready
      claimDailyBonus();
    }
  }

  /// 🔥 DAILY LOGIN CLAIM
  Future<void> claimDailyBonus() async {
    if (!canClaimToday || user == null) return;

    final rewards = [10, 20, 30, 50, 80, 120, 150];

    final userRef =
    FirebaseFirestore.instance.collection('users').doc(user!.uid);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(userRef);
      final data = snap.data() ?? {};

      final daily = data['dailyLogin'] ?? {};
      final lastClaim = daily['lastClaim'] as Timestamp?;

      int streak = daily['streak'] ?? 0;

      /// Soft reset
      if (lastClaim != null) {
        final diff =
            DateTime.now().difference(lastClaim.toDate()).inHours;
        if (diff > 48) {
          streak = 0;
        }
      }

      streak = (streak + 1).clamp(1, 7);

      final reward = rewards[streak - 1];

      tx.update(userRef, {
        'coinsAvailable': FieldValue.increment(reward),
        'dailyLogin.streak': streak,
        'dailyLogin.lastClaim': FieldValue.serverTimestamp(),
        'bonus.weeklyEarned': FieldValue.increment(reward),
      });
    });

    await loadBonusData();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Daily bonus claimed!')),
    );
  }

  /// 🔥 GENERATE REFERRAL CODE
  Future<void> generateReferralIfNeeded() async {
    if (user == null || referralCode.isNotEmpty) return;

    final code = user!.uid.substring(0, 6).toUpperCase();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .set({
      'referral': {
        'code': code,
        'totalReferrals': 0,
      }
    }, SetOptions(merge: true));

    referralCode = code;
    setState(() {});
  }

  Future<void> shareReferral() async {
    if (referralCode.isEmpty) return;

    final message = '''
🎯 Join Quizzy2Earn and start earning real rewards!

Use my referral code: $referralCode

Download now:
https://play.google.com/store/apps/details?id=com.yourapp.quizzy2earn
''';

    await Share.share(message);
  }

  Future<void> copyReferralCode() async {
    if (referralCode.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: referralCode));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Referral code copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    generateReferralIfNeeded();

    return Scaffold(
      extendBodyBehindAppBar: true, // 🔥 full gradient behind status bar
      body: Container(
        decoration: const BoxDecoration(
          gradient: appBackgroundGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _summaryCard(),
                const SizedBox(height: 16),
                _dailyLoginCard(),
                const SizedBox(height: 16),
                _referralCard(),
                const SizedBox(height: 16),
                _missionCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ⭐ SUMMARY
  Widget _summaryCard() {
    return Card(
      child: ListTile(
        title: const Text("Bonus Coins Earned This Week"),
        trailing: Text(
          "$weeklyEarned",
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
    );
  }

  /// ⭐ DAILY LOGIN UI
  Widget _dailyLoginCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.white),
              SizedBox(width: 8),
              Text(
                "Daily Login Bonus",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "Current streak: $currentStreak days",
            style: const TextStyle(color: Colors.white),
          ),

          if (!canClaimToday)
            Text(
              "Next claim in ${nextClaimTime.inHours}h ${nextClaimTime.inMinutes % 60}m",
              style: const TextStyle(color: Colors.white70),
            ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canClaimToday ? _showAdThenClaim : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text("Claim Bonus"),
            ),
          ),
        ],
      ),
    );
  }

  /// ⭐ REFERRAL UI
  Widget _referralCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.group, color: Colors.white),
              SizedBox(width: 8),
              Text(
                "Invite & Earn",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            "Invite friends and earn rewards when they complete missions.",
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    referralCode,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.white),
                  onPressed: copyReferralCode,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.share),
              label: const Text("Invite Friends"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: shareReferral,
            ),
          ),
        ],
      ),
    );
  }

  /// ⭐ MISSIONS (REAL-TIME)
  Widget _missionCard() {
    if (user == null) return const SizedBox();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('missions')
          .doc('daily')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

        final quiz = data['quizCompleted'] ?? 0;
        final spin = data['spinUsed'] ?? 0;
        final profileSaved = data['profileSaved'] ?? false;
        final emailVerified = data['emailVerified'] ?? false;
        final appOpened = data['appOpened'] ?? false;

        return Card(
          color: Colors.transparent,
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Daily Missions",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 10),

                _missionItem(
                  "Complete 10 quiz levels ($quiz / 10)",
                  quiz >= 10,
                ),

                _missionItem(
                  "Use 2 daily spins ($spin / 2)",
                  spin >= 2,
                ),

                _missionItem(
                  "Verify email and save profile",
                  profileSaved && emailVerified,
                ),

                _missionItem(
                  "Open app 3 consecutive days",
                  appOpened,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _missionItem(String title, bool done) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            color: done ? Colors.greenAccent : Colors.white,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          if (!done) const Icon(Icons.lock, color: Colors.white70),
        ],
      ),
    );
  }
}