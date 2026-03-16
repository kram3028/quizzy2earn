import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quizzy2earn/services/fraud_detection_service.dart';

class WithdrawService {
  static Future<void> createWithdrawRequest({
    required double amount, // ₹ amount
    required String payoutMethod,
    required String payoutDetail,
  }) async {

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('User not logged in');
    }

    /// 🔎 FRAUD CHECK
    final risk = await FraudDetectionService.calculateRiskScore();

    if (risk >= 70) {
      throw Exception('Fraud risk detected. Withdraw blocked.');
    }

    final db = FirebaseFirestore.instance;

    final userRef = db.collection('users').doc(user.uid);

    /// 🔹 READ COIN VALUE FROM FIRESTORE
    final configSnap =
    await db.collection('app_config').doc('coin_settings').get();

    if (!configSnap.exists) {
      throw Exception('Coin value config missing');
    }

    final config = configSnap.data() ?? {};

    final coinValue = (config['coinValue'] ?? 0.8).toDouble();

    /// convert ₹ → coins
    final coinsRequired = (amount / coinValue).ceil();

    await db.runTransaction((tx) async {

      final userSnap = await tx.get(userRef);

      if (!userSnap.exists) {
        throw Exception('User not found');
      }

      final data = userSnap.data() ?? {};

      final availableCoins = (data['coinsAvailable'] ?? 0).toInt();
      final lockedCoins = (data['coinsLocked'] ?? 0).toInt();

      /// 🔐 ANTI-FRAUD: prevent multiple withdraw
      if (lockedCoins > 0) {
        throw Exception('Pending withdrawal exists');
      }

      /// 🔐 CHECK BALANCE
      if (availableCoins < coinsRequired) {
        throw Exception('Insufficient balance');
      }

      /// 🔐 MAX LIMIT
      if (amount > 20000) {
        throw Exception('Maximum withdrawal limit exceeded');
      }

      /// 🔐 SUSPICIOUS USER
      if (data['suspended'] == true) {
        throw Exception('Account suspended');
      }

      /// 🔒 LOCK COINS (NOT ₹)
      tx.update(userRef, {
        'coinsAvailable': availableCoins - coinsRequired,
        'coinsLocked': lockedCoins + coinsRequired,
      });

      /// 🔥 CREATE WITHDRAW REQUEST
      final withdrawRef =
      db.collection('withdraw_requests').doc();

      tx.set(withdrawRef, {
        'userId': user.uid,

        /// ₹ amount requested
        'requestedAmount': amount,

        /// coins consumed
        'coinsUsed': coinsRequired,

        /// coin value used
        'coinValue': coinValue,

        'payoutMethod': payoutMethod,
        'payoutDetail': payoutDetail,
        'status': 'pending',
        'rejectReason': "",
        'coinsSettled': false,
        'createdAt': FieldValue.serverTimestamp(),
        'createdAtLocal': DateTime.now().millisecondsSinceEpoch,
      });

    });
  }
}