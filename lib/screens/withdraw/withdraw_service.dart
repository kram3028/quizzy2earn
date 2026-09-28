import 'package:cloud_functions/cloud_functions.dart';
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

    /// 🔎 FRAUD CHECK (keep this client-side)
    final risk = await FraudDetectionService.calculateRiskScore();

    if (risk >= 70) {
      throw Exception('Fraud risk detected. Withdraw blocked.');
    }

    /// 🔥 CALL CLOUD FUNCTION
    final callable = FirebaseFunctions.instance
        .httpsCallable('createWithdrawRequestSecure');

    try {
      final result = await callable.call({
        'amount': amount,
        'payoutMethod': payoutMethod,
        'payoutDetail': payoutDetail,
      });

      if (result.data['success'] != true) {
        throw Exception('Withdraw failed');
      }

    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? "Withdraw failed");
    }
  }
}