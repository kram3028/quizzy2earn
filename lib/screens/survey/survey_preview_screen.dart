import 'package:flutter/material.dart';
import '../captcha/human_verification_screen.dart';

class SurveyPreviewScreen extends StatelessWidget {
  const SurveyPreviewScreen({super.key});

  Widget surveyCard({
    required String time,
    required int coins,
    required double rating,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [

          const Icon(Icons.poll, color: Colors.green),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              "$time survey\n⭐ Rating $rating",
              style: const TextStyle(color: Colors.white),
            ),
          ),

          Text(
            "$coins 🪙",
            style: const TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),

        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("Available Surveys"),
        backgroundColor: Colors.deepPurple,
      ),

      backgroundColor: const Color(0xFF1E1E2C),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            const Text(
              "🔥 High Paying Surveys",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            surveyCard(time: "5 min", coins: 60, rating: 4.3),
            surveyCard(time: "10 min", coins: 120, rating: 4.5),
            surveyCard(time: "20 min", coins: 280, rating: 4.8),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(

                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),

                onPressed: () {

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HumanVerificationScreen(),
                    ),
                  );

                },

                child: const Text(
                  "Open All Surveys",
                  style: TextStyle(fontSize: 16),
                ),

              ),
            ),

          ],
        ),
      ),
    );
  }
}