import 'package:flutter/material.dart';
import 'survey_preview_screen.dart';
import 'package:quizzy2earn/config/app_config.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'theoremreach/theoremreach_service.dart';

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
                if (!AppConfig.enableCPX) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Surveys coming soon")),
                  );
                  return;
                }

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

            const SizedBox(height: 16),

            GestureDetector(
              onTap: () async {
                final user = FirebaseAuth.instance.currentUser;

                if (user == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Please login first."),
                    ),
                  );
                  return;
                }

                try {
                  final success = await TheoremReachService.openSurveyWall(
                    userId: user.uid,
                  );

                  debugPrint("TheoremReach Result: $success");
                } catch (e) {
                  debugPrint("TheoremReach Error: $e");

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString()),
                      ),
                    );
                  }
                }
              },

              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [
                      Colors.orange,
                      Colors.deepOrange,
                    ],
                  ),
                ),
                child: Row(
                  children: [

                    const Icon(
                      Icons.poll,
                      color: Colors.white,
                      size: 48,
                    ),

                    const SizedBox(width: 20),

                    const Expanded(
                      child: Text(
                        "TheoremReach\nComplete surveys & earn coins",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white,
                    ),
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