import 'dart:math';
import 'package:flutter/material.dart';
import '../survey/cpx_webview_screen.dart';

class TapCaptcha extends StatefulWidget {
  const TapCaptcha({super.key});

  @override
  State<TapCaptcha> createState() => _TapCaptchaState();
}

class _TapCaptchaState extends State<TapCaptcha> {

  double x = Random().nextDouble()*200;
  double y = Random().nextDouble()*400;

  void success(){

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const CPXWebViewScreen(),
      ),
    );

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("Human Verification"),
        backgroundColor: Colors.deepPurple,
      ),

      backgroundColor: const Color(0xFF1E1E2C),

      body: Stack(
        children: [

          const Center(
            child: Text(
              "Tap the green circle",
              style: TextStyle(color: Colors.white,fontSize:20),
            ),
          ),

          Positioned(
            left: x,
            top: y,
            child: GestureDetector(
              onTap: success,
              child: Container(
                width:60,
                height:60,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          )

        ],
      ),
    );
  }
}