import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class CPXWebViewScreen extends StatefulWidget {
  const CPXWebViewScreen({super.key});

  @override
  State<CPXWebViewScreen> createState() => _CPXWebViewScreenState();
}

class _CPXWebViewScreenState extends State<CPXWebViewScreen> {

  late WebViewController controller;

  final int appId = 31758;

  /// 🔑 Your CPX Secure Key
  final String secureKey = "FT9ohQpPv0Mh5pCBMknIGl6yngzjdDmA";

  String generateHash(String uid) {
    final bytes = utf8.encode("$uid-$secureKey");
    return md5.convert(bytes).toString();
  }

  Future<void> loadCPX() async {

    final user = FirebaseAuth.instance.currentUser!;
    final uid = user.uid;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    final name = userDoc.data()?['name'] ?? "User";
    final email = userDoc.data()?['email'] ?? "";

    final hash = generateHash(uid);

    final url =
        "https://offers.cpx-research.com/index.php"
        "?app_id=$appId"
        "&ext_user_id=$uid"
        "&secure_hash=$hash"
        "&username=$name"
        "&email=$email"
        "&subid_1=survey"
        "&subid_2=app";

    controller.loadRequest(Uri.parse(url));
  }

  @override
  void initState() {
    super.initState();

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);

    loadCPX();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("CPX Surveys"),
        backgroundColor: Colors.deepPurple,
      ),
      body: WebViewWidget(controller: controller),
    );
  }
}