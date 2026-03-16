import 'package:flutter/material.dart';
import 'survey_preview_screen.dart';

class SurveyScreen extends StatelessWidget {
  const SurveyScreen({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("Survey & Offerwalls"),
        backgroundColor: Colors.deepPurple,
      ),
      backgroundColor: const Color(0xFF1E1E2C),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            GestureDetector(
              onTap: () {

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SurveyPreviewScreen(),
                  ),
                );

              },

              child: Container(
                padding: const EdgeInsets.all(20),

                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [Colors.green, Colors.teal],
                  ),
                ),

                child: Row(
                  children: [

                    Image.asset(
                      "assets/images/logo-cpx-reserach.png",
                      width: 60,
                    ),

                    const SizedBox(width: 20),

                    const Expanded(
                      child: Text(
                        "CPX Research\nComplete surveys & earn coins",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const Icon(Icons.arrow_forward_ios,color: Colors.white)

                  ],
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }
}