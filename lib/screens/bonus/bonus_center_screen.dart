import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
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

  bool emailVerified = false;
  bool profileSaved = false;

  bool emailRewardClaimed = false;
  bool profileRewardClaimed = false;

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
    emailVerified = data['emailVerified'] ?? false;
    profileSaved = data['profileSaved'] ?? false;

    final rewards = data['oneTimeRewards'] ?? {};

    emailRewardClaimed = rewards['emailVerifiedRewardClaimed'] ?? false;
    profileRewardClaimed = rewards['profileRewardClaimed'] ?? false;

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

    final callable =
    FirebaseFunctions.instance.httpsCallable('claimDailyLogin');

    await callable.call();

    await loadBonusData();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Daily bonus claimed!')),
    );

  }

  Future<void> _claimReward(String rewardType) async {

    try {

      final result = await FirebaseFunctions.instance
          .httpsCallable('claimOneTimeReward')
          .call({
        "rewardType": rewardType
      });

      final reward = result.data["reward"];

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("You received $reward coins 🎉")),
      );

      loadBonusData();

    } catch (e) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Reward already claimed or unavailable")),
      );

    }

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
                const SizedBox(height: 16),

                _oneTimeRewardsCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ⭐ SUMMARY
  Widget _summaryCard() {
    if (user == null) return const SizedBox();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
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

        final walletCoins = data['coinsAvailable'] ?? 0;
        final weekly = data['bonus']?['weeklyEarned'] ?? 0;

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [

                Column(
                  children: [
                    const Text(
                      "Weekly Earned",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "$weekly",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ],
                ),

                Container(
                  width: 1,
                  height: 40,
                  color: Colors.grey.shade300,
                ),

                Column(
                  children: [
                    const Text(
                      "Wallet Balance",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "$walletCoins",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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

  Widget _oneTimeRewardsCard() {

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
              Icon(Icons.card_giftcard, color: Colors.white),
              SizedBox(width: 8),
              Text(
                "One-Time Rewards",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          _oneTimeRewardItem(
            title: "Verify Email",
            completed: emailVerified,
            claimed: emailRewardClaimed,
            rewardType: "email",
            coins: 100,
          ),

          _oneTimeRewardItem(
            title: "Complete Profile",
            completed: profileSaved,
            claimed: profileRewardClaimed,
            rewardType: "profile",
            coins: 150,
          ),
        ],
      ),
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

  Widget _oneTimeRewardItem({
    required String title,
    required bool completed,
    required bool claimed,
    required String rewardType,
    required int coins,
  }) {
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
            completed ? Icons.check_circle : Icons.lock,
            color: completed ? Colors.greenAccent : Colors.white,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              "$title ($coins coins)",
              style: const TextStyle(color: Colors.white),
            ),
          ),

          if (claimed)
            const Text(
              "Claimed",
              style: TextStyle(color: Colors.greenAccent),
            )
          else
            ElevatedButton(
              onPressed: completed
                  ? () => _claimReward(rewardType)
                  : null,
              child: const Text("Claim"),
            ),
        ],
      ),
    );
  }
}