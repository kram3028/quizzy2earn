import 'package:flutter/material.dart';
import 'package:quizzy2earn/core/navigation_service.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TermsConditionsScreen extends StatefulWidget {
  final bool forceAgree;
  final String currentTermsVersion;

  const TermsConditionsScreen({
    super.key,
    this.forceAgree = false,
    required this.currentTermsVersion,
  });

  @override
  State<TermsConditionsScreen> createState() =>
      _TermsConditionsScreenState();
}

class _TermsConditionsScreenState extends State<TermsConditionsScreen> {
  bool canAgree = false;
  bool isSaving = false;
  late final WebViewController _webController;

  @override
  void initState() {
    super.initState();

    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(
        Uri.parse('https://quizzy2earn-ea152.web.app/terms.html'),
      );

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => canAgree = true);
      }
    });
  }

  Future<void> _agreeToTerms() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      NavigationService.goBack(true);
      return;
    }

    setState(() => isSaving = true);

    try {

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'agreedToTerms': true,
        'agreedTermsVersion': widget.currentTermsVersion,
      }, SetOptions(merge: true));

      NavigationService.goBack(true);

    } catch (e) {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save agreement')),
      );

    } finally {

      if (mounted) {
        setState(() => isSaving = false);
      }

    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          Expanded(
            child: WebViewWidget(controller: _webController),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (!canAgree || isSaving)
                  ? null
                  : _agreeToTerms,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                'I Agree',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}