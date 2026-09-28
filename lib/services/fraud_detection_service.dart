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

      final isEmulator =
          !android.isPhysicalDevice ||
              android.brand.toLowerCase().contains("generic") ||
              android.model.toLowerCase().contains("sdk");

      return {
        'platform': 'Android',
        'deviceModel': android.model,
        'brand': android.brand,
        'device': android.device,
        'hardware': android.hardware,
        'fingerprint': android.fingerprint,

        'isPhysical': android.isPhysicalDevice,
        'isEmulator': isEmulator, // 🔥 ADD THIS

        'isEmulatorBrand': android.brand.toLowerCase().contains("generic"),
        'isEmulatorModel': android.model.toLowerCase().contains("sdk"),
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

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);

    try {
      await userRef.update({
        'deviceInfo': data,
        'fingerprintUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      await userRef.set({
        'deviceInfo': data,
        'fingerprintUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
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

    // ❗ If more than 1 account → BLOCK
    if (query.docs.length > 1) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'fraud': {
          'multiAccount': true,
          'isBlocked': true,
        }
      }, SetOptions(merge: true));

      return true;
    }

    return false;
  }

  /// 🔥 Fraud risk scoring
  static Future<int> calculateRiskScore() async {
    int score = 0;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;

    final isMulti = await detectMultiAccount();
    if (isMulti) score += 70;

    final device = await generateDeviceFingerprint();

    if (device['isPhysical'] == false) score += 40;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final fraudData = userDoc.data()?['fraud'] ?? {};

    if (fraudData['vpn'] == true) {
      score += 40;
    }

    if (device['isEmulatorBrand'] == true) score += 20;
    if (device['isEmulatorModel'] == true) score += 20;

    /// Add more signals later
    return score;
  }

  static Future<void> updateFraudScore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final score = await calculateRiskScore();

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'fraud': {
        'riskScore': score,
        'isSuspicious': score > 60,
        'isBlocked': score > 80,
        'lastChecked': FieldValue.serverTimestamp(),
      }
    });
  }

  static Future<void> enforceBlockIfNeeded() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final fraud = doc.data()?['fraud'];

    if (fraud != null && fraud['isBlocked'] == true) {
      await FirebaseAuth.instance.signOut();
      throw Exception("Account blocked due to suspicious activity");
    }
  }
}
