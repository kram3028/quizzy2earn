import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'withdraw_history.dart';

class WithdrawTab extends StatelessWidget {
  final Map<String, dynamic>? latestWithdrawRequest;
  final ConfettiController confettiController;

  const WithdrawTab({
    super.key,
    required this.latestWithdrawRequest,
    required this.confettiController,
  });

  @override
  Widget build(BuildContext context) {
    if (latestWithdrawRequest == null) {
      return const Center(
        child: Text(
          'No withdrawal request found.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final status = latestWithdrawRequest!['status'];
    final amount =
    (latestWithdrawRequest!['requestedAmount'] as num).toDouble();
    final payoutMethod = latestWithdrawRequest!['payoutMethod'];
    final payoutDetail = latestWithdrawRequest!['payoutDetail'];

    String statusText;

    if (status == 'paid') {
      statusText = payoutMethod == 'GiftCard'
          ? '✅ Gift Card sent to $payoutDetail'
          : '✅ Paid to $payoutDetail';
    } else if (status == 'rejected') {
      statusText = payoutMethod == 'GiftCard'
          ? '❌ Gift Card rejected'
          : '❌ Payment rejected';
    } else {
      statusText = payoutMethod == 'GiftCard'
          ? '⏳ Gift Card pending'
          : '⏳ UPI pending';
    }

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Withdrawal Status',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 16),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.deepPurple,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '₹${amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 26,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: status == 'paid'
                      ? Colors.green.shade50
                      : status == 'rejected'
                      ? Colors.red.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(statusText),
              ),

              const SizedBox(height: 24),

              const WithdrawHistory(),
            ],
          ),
        ),

        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: confettiController,
          ),
        ),
      ],
    );
  }
}
