import 'package:flutter/material.dart';
import 'package:quizzy2earn/core/app_router.dart';
import 'package:quizzy2earn/core/navigation_service.dart';
import 'package:quizzy2earn/screens/faq/faq_screen.dart';

class WalletTab extends StatelessWidget {
  final int coinsAvailable;
  final int coinsLocked;
  final bool hasPendingWithdraw;
  final String currentTermsVersion;

  final Function(VoidCallback) onShowAdThen;

  final Function(
      double amount,
      String payoutMethod,
      String payoutDetail,
      ) onWithdraw;

  const WalletTab({
    super.key,
    required this.coinsAvailable,
    required this.coinsLocked,
    required this.hasPendingWithdraw,
    required this.currentTermsVersion,
    required this.onWithdraw,
    required this.onShowAdThen,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        children: [
          const SizedBox(height: 10),

          /// 📅 Withdrawal notice
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '📅 Withdrawals are processed in the first week of every month',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(height: 20),

          /// 🎨 WALLET CARD
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.deepPurple.shade400,
                  Colors.deepPurple.shade700,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepPurple.withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'My Wallet',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 12),

                /// 💰 TOTAL COINS
                Text(
                  '${coinsAvailable + coinsLocked}',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 4),

                const Text(
                  'Total Coins',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 20),

                /// 🔹 AVAILABLE + LOCKED
                Row(
                  children: [
                    Expanded(
                      child: _walletStat(
                        icon: Icons.account_balance_wallet,
                        label: 'Available',
                        value: coinsAvailable.toString(),
                        color: Colors.greenAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _walletStat(
                        icon: Icons.lock,
                        label: 'Locked',
                        value: coinsLocked.toString(),
                        color: Colors.orangeAccent,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                const Text(
                  'Locked coins are under withdrawal review',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 15),

          /// 🔘 REDEEM BUTTON
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.redeem),
              label: Text(
                coinsAvailable < 5000
                    ? 'Minimum 5000 coins required'
                    : 'Redeem Coins',
                style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: coinsAvailable < 5000
                  ? null
                  : () {
                onShowAdThen(() {
                  NavigationService.pushNamed(
                    AppRouter.redeem,
                    args: {
                      'coins': coinsAvailable,
                      'hasPendingWithdraw': hasPendingWithdraw,
                      'currentTermsVersion': currentTermsVersion,
                      'onShowAdThen': onShowAdThen,
                      'onWithdraw': onWithdraw,
                    },
                  );
                });
              },
            ),
          ),

          const SizedBox(height: 10),

          const Text(
            'Rewards are processed securely',
            style: TextStyle(fontSize: 14, color: Colors.black45),
          ),

          const SizedBox(height: 20),

          /// ❓ FAQ / Help Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.deepPurple.withOpacity(0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Need help with withdrawals?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Check common questions about payment, pending withdrawals, and account safety.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 12),

                /// 🔘 FAQ BUTTON
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.help_outline),
                    label: const Text('Wallet FAQ'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FAQScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 🔹 Wallet stat widget
  Widget _walletStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}
