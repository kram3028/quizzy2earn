import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/bottom_banner_ad.dart';

class ReferralProgressScreen extends StatelessWidget {
  const ReferralProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Referral Progress"),
        backgroundColor: Colors.deepPurple,
      ),

      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('referrals_list')
            .snapshots(),
        builder: (context, snapshot) {

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Colors.white,));
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text("No referrals yet"),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80), // 🔥 prevent overlap
            itemCount: docs.length,
            itemBuilder: (context, index) {

              final data = docs[index].data();

              final quiz = data['quizCount'] ?? 0;
              final coins = data['totalCoins'] ?? 0;
              final days = data['activeDays'] ?? 0;

              // 🔥 POPUP TRIGGER (SAFE)
              if (quiz > 0 && quiz % 10 == 0) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  showRewardPopup(context, "🎯 10 Quiz milestone reached!");
                });
              }

              if (coins > 0 && coins % 1000 == 0) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  showRewardPopup(context, "💰 ₹1000 milestone reached!");
                });
              }

              if (days > 0 && days % 3 == 0) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  showRewardPopup(context, "📅 3 Day activity milestone!");
                });
              }

              return _referralCard(data, quiz, coins, days);
            },
          );
        },
      ),

      /// 🔥 BOTTOM BANNER
      bottomNavigationBar: const BottomBannerAd(),
    );
  }

  Widget _referralCard(Map data, int quiz, int coins, int days) {

    bool isMilestone(int value, int step) {
      return value > 0 && value % step == 0;
    }

    final quizMilestone = isMilestone(quiz, 10);
    final coinMilestone = isMilestone(coins, 1000);
    final dayMilestone = isMilestone(days, 3);

    final userId = (data['userId'] ?? '').toString();
    final shortId = userId.length >= 6 ? userId.substring(0, 6) : userId;

    /// 🔥 QUIZ PROGRESS (RESET UI USING %)
    final quizCurrent = quiz % 10;
    final quizProgress = quizCurrent / 10;

    /// 🔥 EARNINGS PROGRESS
    final coinCurrent = coins % 1000;
    final coinProgress = coinCurrent / 1000;

    /// 🔥 ACTIVE DAYS PROGRESS
    final dayCurrent = days % 3;
    final dayProgress = dayCurrent / 3;

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// 👤 USER ID (SHORT)
            Text(
              "User: $shortId",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 12),

            /// 🎯 QUIZ PROGRESS
            _progress(
              "Quiz Progress",
              quizProgress.clamp(0, 1),
              "$quizCurrent / 10",
            ),

            /// 💰 EARNINGS PROGRESS
            _progress(
              "Earnings Progress",
              coinProgress.clamp(0, 1),
              "$coinCurrent / 1000",
            ),

            /// 📅 ACTIVE DAYS
            _progress(
              "Active Days",
              dayProgress.clamp(0, 1),
              "$dayCurrent / 3",
            ),

            const SizedBox(height: 10),

            /// ✅ STATUS
            Row(
              children: [
                _statusChip("Email", data['emailVerified'] ?? false),
                const SizedBox(width: 8),
                _statusChip("Profile", data['profileCompleted'] ?? false),
              ],
            ),

            const SizedBox(height: 10),

            if (quizMilestone || coinMilestone || dayMilestone)
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.emoji_events, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      "🎉 Reward Unlocked!",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _progress(String title, double value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title),
        const SizedBox(height: 4),
        LinearProgressIndicator(value: value.clamp(0, 1)),
        Text(label),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _statusChip(String text, bool status) {
    return Chip(
      label: Text(text),
      backgroundColor: status ? Colors.green : Colors.grey,
    );
  }

  void showRewardPopup(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("🎉 Reward Unlocked"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
}