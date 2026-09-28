import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:quizzy2earn/screens/referral/referral_progress_screen.dart';
import 'package:flutter/services.dart';
import '../../widgets/bottom_banner_ad.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';

import '../../core/app_theme.dart';

class InviteEarnScreen extends StatefulWidget {
  const InviteEarnScreen({super.key});

  @override
  State<InviteEarnScreen> createState() => _InviteEarnScreenState();
}

class _InviteEarnScreenState extends State<InviteEarnScreen> {

  final user = FirebaseAuth.instance.currentUser;

  String referralCode = '';
  int referralCount = 0;
  bool referralAlreadyUsed = false;

  StreamSubscription? referralSub;
  StreamSubscription? userSub;

  final TextEditingController referralInputController = TextEditingController();
  bool applyingReferral = false;

  Map<String, dynamic>? userData;

  @override
  void initState() {
    super.initState();
    listenReferralData();
    generateReferralIfNeeded();
  }

  @override
  void dispose() {
    referralSub?.cancel();
    userSub?.cancel();
    super.dispose();
  }

  void listenReferralData() {
    if (user == null) return;

    // 🔥 Referral stats (subcollection)
    referralSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('referral')
        .doc('main')
        .snapshots()
        .listen((doc) {

      if (!mounted) return; // 🔥 FIX

      final data = doc.data();
      if (data == null) return;

      final newCount = data['totalReferrals'];

      setState(() {
        referralCode = data['code'] ?? '';

        // 🔥 IMPORTANT FIX → prevent overwrite with 0
        if (newCount != null && newCount >= referralCount) {
          referralCount = newCount;
        }
      });
      print("Referral Count Firestore: ${data['totalReferrals']}");
    });

    // 🔥 User data (earnings + referredBy)
    userSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .snapshots()
        .listen((doc) {

      if (!mounted) return; // 🔥 FIX

      final data = doc.data();
      if (data == null) return;

      setState(() {
        userData = data;
        referralAlreadyUsed = data['referredBy'] != null;
      });
    });
  }

  /// 🔥 Generate referral code if missing
  Future<void> generateReferralIfNeeded() async {
    if (user == null || referralCode.isNotEmpty) return;

    final code = user!.uid.substring(0, 6).toUpperCase();

    final db = FirebaseFirestore.instance;

    // ✅ Save in user subcollection
    await db
        .collection('users')
        .doc(user!.uid)
        .collection('referral')
        .doc('main')
        .set({
      'code': code,
    }, SetOptions(merge: true));

    // ✅ SAVE GLOBAL LOOKUP (🔥 IMPORTANT)
    await db.collection('referral_codes').doc(code).set({
      'uid': user!.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    referralCode = code;
    setState(() {});
  }

  /// 🔥 Apply referral
  Future<void> applyReferralCode() async {
    final code = referralInputController.text.trim().toUpperCase();

    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter referral code")),
      );
      return;
    }

    setState(() => applyingReferral = true);

    try {
      final callable = FirebaseFunctions.instance
          .httpsCallable('applyReferralCode');

      await callable.call({
        "code": code,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Referral applied successfully 🎉")),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }

    setState(() => applyingReferral = false);
  }

  /// 🔥 Share
  Future<void> shareReferral() async {
    if (referralCode.isEmpty) return;

    final message = '''
🎯 Join Quizzy2Earn and start earning rewards!

Use my referral code: $referralCode

Download now:
https://play.google.com/store/apps/details?id=com.quizzy2earn.app
''';

    await Share.share(message);
  }

  /// 🔥 Copy
  Future<void> copyReferralCode() async {
    if (referralCode.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: referralCode));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Copied to clipboard")),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("Invite & Earn"),
        backgroundColor: Colors.deepPurple,
      ),

      body: Container(
        decoration: const BoxDecoration(
          gradient: appBackgroundGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [

                _earningsCard(userData ?? {}),

                const SizedBox(height: 10),

                _statsCard(),

                const SizedBox(height: 16),

                _applyCodeCard(),

                const SizedBox(height: 16),

                _shareCard(),

                const SizedBox(height: 16),

                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ReferralProgressScreen(),
                      ),
                    );
                  },
                  child: const Text("View Referral Progress 🔥"),
                ),

                const SizedBox(height: 80), // 🔥 space for ad
              ],
            ),
          ),
        ),
      ),

      /// 🔥 BOTTOM BANNER
      bottomNavigationBar: const BottomBannerAd(),
    );
  }

  Widget _statsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text(
            "Your Referrals",
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            "$referralCount",
            style: const TextStyle(
              fontSize: 28,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _earningsCard(Map<String, dynamic> userData) {
    final earningsRaw = userData['earnings'];

    Map<String, dynamic> earnings = {};

    if (earningsRaw is Map) {
      earnings = Map<String, dynamic>.from(earningsRaw);
    }

    final referral = (earnings['referralCoins'] ?? 0) as int;

    final total =
        (earnings['referralCoins'] ?? 0) +
            (earnings['surveyCoins'] ?? 0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "💰 Your Earnings",
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 10),
          _earnRow("Total Earned", total),
          _earnRow("Referral Earnings", referral),
        ],
      ),
    );
  }

  Widget _earnRow(String title, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70)),
          Text("$value 🟡", style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _applyCodeCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          const Text(
            "Have a referral code?",
            style: TextStyle(color: Colors.white70),
          ),

          const SizedBox(height: 10),

          if (!referralAlreadyUsed) ...[
            TextField(
              controller: referralInputController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Enter code",
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.black.withOpacity(0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: applyingReferral ? null : applyReferralCode,
                child: applyingReferral
                    ? const CircularProgressIndicator(color: Colors.white,)
                    : const Text("Apply Code"),
              ),
            ),
          ] else ...[
            const Text(
              "Referral already applied ✅",
              style: TextStyle(color: Colors.greenAccent),
            ),
          ],
        ],
      ),
    );
  }

  Widget _shareCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [

          const Text(
            "Your Referral Code",
            style: TextStyle(color: Colors.white70),
          ),

          const SizedBox(height: 10),

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
              ),
              onPressed: shareReferral,
            ),
          ),
        ],
      ),
    );
  }
}