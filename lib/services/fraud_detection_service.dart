import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FraudDetectionService {

  /// 🔥 Generate device fingerprint
  static Future<Map<String, dynamic>> generateDeviceFingerprint() async {
    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final android = await deviceInfo.androidInfo;

      return {
        'platform': 'Android',
        'deviceModel': android.model,
        'brand': android.brand,
        'device': android.device,
        'hardware': android.hardware,
        'fingerprint': android.fingerprint,
        'isPhysical': android.isPhysicalDevice,
      };
    }

    if (Platform.isIOS) {
      final ios = await deviceInfo.iosInfo;

      return {
        'platform': 'iOS',
        'deviceModel': ios.utsname.machine,
        'isPhysical': ios.isPhysicalDevice,
      };
    }

    return {};
  }

  /// 🔥 Save fingerprint to Firestore
  static Future<void> saveFingerprint() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final data = await generateDeviceFingerprint();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({
      'deviceInfo': data,
      'fingerprintUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 🔥 Multi-account detection
  static Future<bool> detectMultiAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final device = await generateDeviceFingerprint();

    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('deviceInfo.fingerprint',
        isEqualTo: device['fingerprint'])
        .get();

    return query.docs.length > 1;
  }

  /// 🔥 Fraud risk scoring
  static Future<int> calculateRiskScore() async {
    int score = 0;

    final isMulti = await detectMultiAccount();

    if (isMulti) score += 70;

    final device = await generateDeviceFingerprint();

    if (device['isPhysical'] == false) {
      score += 30; // emulator risk
    }

    return score;
  }
}
