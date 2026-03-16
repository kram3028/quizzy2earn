import 'dart:math';
import 'package:flutter/material.dart';
import '../survey/cpx_webview_screen.dart';

class MathCaptcha extends StatefulWidget {
  const MathCaptcha({super.key});

  @override
  State<MathCaptcha> createState() => _MathCaptchaState();
}

class _MathCaptchaState extends State<MathCaptcha> {

  final int a = Random().nextInt(10)+1;
  final int b = Random().nextInt(10)+1;

  final TextEditingController controller = TextEditingController();

  void verify() {

    if (int.tryParse(controller.text) == a + b) {

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const CPXWebViewScreen(),
        ),
      );

    } else {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Wrong answer")),
      );

    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("Human Verification"),
        backgroundColor: Colors.deepPurple,
      ),

      backgroundColor: const Color(0xFF1E1E2C),

      body: Padding(
        padding: const EdgeInsets.all(30),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            const Icon(Icons.calculate,size:60,color:Colors.orange),

            const SizedBox(height:20),

            Text(
              "$a + $b = ?",
              style: const TextStyle(color: Colors.white,fontSize:28),
            ),

            const SizedBox(height:20),

            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                filled:true,
                fillColor: Colors.white,
              ),
            ),

            const SizedBox(height:20),

            ElevatedButton(
              onPressed: verify,
              child: const Text("Verify"),
            )

          ],
        ),
      ),
    );
  }
}