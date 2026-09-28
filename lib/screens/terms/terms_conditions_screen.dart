import 'package:flutter/material.dart';
import 'package:quizzy2earn/core/navigation_service.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TermsConditionsScreen extends StatefulWidget {
  final String type;
  final bool forceAgree;
  final String currentTermsVersion;

  const TermsConditionsScreen({
    super.key,
    required this.type,
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
  bool hasScrolledToBottom = false;
  double scrollProgress = 0.0;
  late final WebViewController _webController;

  @override
  void initState() {
    super.initState();

    final isPrivacy = widget.type == "privacy";

    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        "ScrollListener",
        onMessageReceived: (message) {
          if (message.message == "bottom") {
            setState(() {
              hasScrolledToBottom = true;
              scrollProgress = 100;
            });
          } else {
            final progress = double.tryParse(message.message);
            if (progress != null) {
              setState(() {
                scrollProgress = progress;
              });
            }
          }
        },
      )

      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            await _webController.runJavaScript("""
              function checkScroll() {
                var scrollTop = document.documentElement.scrollTop || document.body.scrollTop;
                var windowHeight = window.innerHeight;
                var fullHeight = document.documentElement.scrollHeight || document.body.scrollHeight;

                var progress = (scrollTop / (fullHeight - windowHeight)) * 100;
                if (progress > 100) progress = 100;

                ScrollListener.postMessage(progress.toString());

                if (scrollTop + windowHeight >= fullHeight - 10) {
                  ScrollListener.postMessage("bottom");
                }
              }

              setInterval(checkScroll, 300);
            """);
          },
        ),
      )

      ..loadRequest(
        Uri.parse(
          isPrivacy
              ? 'https://quizzy2earn-ea152.web.app/privacy.html'
              : 'https://quizzy2earn-ea152.web.app/terms.html',
        ),
      );

    Future.delayed(const Duration(seconds: 3), () async {
      await _webController.runJavaScriptReturningResult(
          "document.body.scrollHeight"
      );

      setState(() {
        hasScrolledToBottom = true;
      });
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => canAgree = true);
      }
    });
  }

  Future<void> _onAgree() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      NavigationService.goBack(true);
      return;
    }

    setState(() => isSaving = true);

    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      if (widget.type == "privacy") {
        // ✅ PRIVACY (WITH VERSION)
        await userRef.set({
          'agreedToPrivacy': true,
          'agreedPrivacyVersion': widget.currentTermsVersion,
          'privacyAgreedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        // ✅ TERMS (NO VERSION)
        await userRef.set({
          'agreedToTerms': true,
          'termsAgreedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      NavigationService.goBack(true);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save agreement')),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.type == "privacy"
            ? 'Privacy Policy'
            : 'Terms & Conditions'),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          Expanded(
            child: WebViewWidget(controller: _webController),
          ),
          LinearProgressIndicator(
            value: scrollProgress / 100,
            minHeight: 4,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(
              hasScrolledToBottom ? Colors.green : Colors.deepPurple,
            ),
          ),
          if (!hasScrolledToBottom)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                hasScrolledToBottom
                    ? "You can now agree ✅"
                    : "Scroll to bottom (${scrollProgress.toStringAsFixed(0)}%)",
                style: TextStyle(
                  color: hasScrolledToBottom ? Colors.green : Colors.redAccent,
                  fontSize: 12,
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (!canAgree || !hasScrolledToBottom || isSaving)
                  ? null
                  : _onAgree,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                'I Agree',
                style: TextStyle(fontSize: 16, color: Colors.yellow),
              ),
            ),
          ),
        ],
      ),
    );
  }
}