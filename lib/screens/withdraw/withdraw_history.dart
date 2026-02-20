import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WithdrawHistory extends StatelessWidget {
  const WithdrawHistory({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('withdraw_requests')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'paid')
          .orderBy('createdAtLocal', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text('No withdrawal history');
        }

        return Column(
          children: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return ListTile(
              title: Text('₹${data['requestedAmount']}'),
              subtitle: Text(data['payoutMethod']),
            );
          }).toList(),
        );
      },
    );
  }
}
