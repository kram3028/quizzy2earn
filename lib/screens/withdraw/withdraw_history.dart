import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';

class WithdrawHistory extends StatelessWidget {
  const WithdrawHistory({super.key});

  Color statusColor(String status) {
    switch (status) {
      case "paid":
        return Colors.green;
      case "rejected":
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String statusText(String status) {
    switch (status) {
      case "paid":
        return "Paid";
      case "rejected":
        return "Rejected";
      default:
        return "Pending";
    }
  }

  IconData statusIcon(String status) {
    switch (status) {
      case "paid":
        return Icons.check_circle;
      case "rejected":
        return Icons.cancel;
      default:
        return Icons.hourglass_bottom;
    }
  }

  Widget shimmerCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        height: 110,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget statusBadge(String status) {
    final color = statusColor(status);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(
            statusIcon(status),
            size: 16,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            statusText(status),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildWithdrawCard(BuildContext context, Map<String, dynamic> data) {
    final amount = data['requestedAmount'] ?? 0;
    final payout = data['payoutMethod'] ?? "";
    final status = data['status'] ?? "pending";
    final supportId = data['supportId'] ?? "N/A";
    final rejectReason = data['rejectReason'] ?? "";

    final timestamp = data['createdAtLocal'] ?? 0;
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);

    final dateText =
        "${date.day}/${date.month}/${date.year}";

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          /// Amount + Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "₹$amount",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              statusBadge(status),
            ],
          ),

          const SizedBox(height: 10),

          /// Date
          Row(
            children: [
              const Icon(Icons.calendar_today,
                  size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                dateText,
                style: const TextStyle(color: Colors.black87),
              ),
            ],
          ),

          const SizedBox(height: 6),

          /// Transaction ID + Copy Button
          Row(
            children: [
              const Icon(Icons.receipt_long,
                  size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  supportId,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(
                      ClipboardData(text: supportId));

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Transaction ID copied"),
                    ),
                  );
                },
                child: const Icon(
                  Icons.copy,
                  size: 18,
                  color: Colors.white,
                ),
              )
            ],
          ),

          const SizedBox(height: 6),

          /// Payout Method
          Row(
            children: [
              const Icon(Icons.account_balance_wallet,
                  size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                payout,
                style: const TextStyle(color: Colors.black87),
              ),
            ],
          ),
          if (status == "rejected" && rejectReason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    rejectReason,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget rejectionNoteBox() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            color: Colors.orange,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "If a withdrawal request is rejected, the reason will appear here.",
              maxLines: 2,
              style: TextStyle(
                color: Colors.orange.shade800,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('withdraw_requests')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAtLocal', descending: true)
          .limit(2)
          .snapshots(),
      builder: (context, snapshot) {

        /// Shimmer Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            children: List.generate(3, (index) => shimmerCard()),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text(
            "No withdrawal history",
            style: TextStyle(color: Colors.white),
          );
        }

        final docs = snapshot.data!.docs;

        return Column(
          children: [
            ...docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return buildWithdrawCard(context, data);
            }),

            rejectionNoteBox(),
          ],
        );
      },
    );
  }
}