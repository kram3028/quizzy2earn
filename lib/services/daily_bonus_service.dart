import 'package:cloud_functions/cloud_functions.dart';

class DailyBonusService {
  static Future<Map<String, dynamic>> claimDaily() async {
    final callable =
    FirebaseFunctions.instance.httpsCallable('claimDailyLogin');

    final result = await callable();

    return Map<String, dynamic>.from(result.data);
  }
}