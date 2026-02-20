import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quizzy2earn/services/fraud_detection_service.dart';

class WithdrawService {
  static Future<void> createWithdrawRequest({
    required double amount,
    required String payoutMethod,
    required String payoutDetail,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    /// Fraud check
    final risk = await FraudDetectionService.calculateRiskScore();

    if (risk >=70) {
      throw Exception('Fraud risk detected. Withdraw blocked.');
    }

    final userRef =
    FirebaseFirestore.instance.collection('users').doc(user.uid);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);

      if (!userSnap.exists) {
        throw Exception('User not found');
      }

      final data = userSnap.data()!;

      final available = (data['coinsAvailable'] as num).toInt();
      final locked = (data['coinsLocked'] as num).toInt();

      /// 🔐 ANTI-FRAUD LAYER
      if (locked > 0) {
        throw Exception('Pending withdrawal exists');
      }

      if (available < amount) {
        throw Exception('Insufficient balance');
      }

      /// 🔐 MAX LIMIT PROTECTION
      if (amount > 20000) {
        throw Exception('Maximum withdrawal limit exceeded');
      }

      /// 🔐 SUSPICIOUS USER CHECK
      if (data['suspended'] == true) {
        throw Exception('Account suspended');
      }

      /// 🔒 LOCK COINS
      tx.update(userRef, {
        'coinsAvailable': available - amount,
        'coinsLocked': locked + amount,
      });

      /// 🔥 CREATE WITHDRAW
      final withdrawRef =
      FirebaseFirestore.instance.collection('withdraw_requests').doc();

      tx.set(withdrawRef, {
        'userId': user.uid,
        'requestedAmount': amount,
        'payoutMethod': payoutMethod,
        'payoutDetail': payoutDetail,
        'status': 'pending',
        'coinsSettled': false,
        'createdAt': FieldValue.serverTimestamp(),
        'createdAtLocal': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }
}
