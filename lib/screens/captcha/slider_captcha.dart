import 'package:flutter/material.dart';
import '../survey/cpx_webview_screen.dart';

class SliderCaptcha extends StatefulWidget {
  const SliderCaptcha({super.key});

  @override
  State<SliderCaptcha> createState() => _SliderCaptchaState();
}

class _SliderCaptchaState extends State<SliderCaptcha> {

  double value = 0;

  void verify() {
    if (value > 0.95) {

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const CPXWebViewScreen(),
        ),
      );

    } else {
      setState(() {
        value = 0;
      });
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

            const Icon(Icons.security,size:60,color:Colors.green),

            const SizedBox(height:20),

            const Text(
              "Slide to verify you are human",
              style: TextStyle(color: Colors.white,fontSize:18),
            ),

            const SizedBox(height:40),

            Slider(
              value: value,
              onChanged: (v){
                setState(() {
                  value = v;
                });
              },
              onChangeEnd: (v)=>verify(),
            )

          ],
        ),
      ),
    );
  }
}