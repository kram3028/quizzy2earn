import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quizzy2earn/core/app_router.dart';
import 'package:quizzy2earn/core/navigation_service.dart';

class LevelsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> questions;

  const LevelsScreen({super.key, required this.questions});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final completedLevels =
        List<int>.from(data['completedLevels'] ?? []);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Select Level'),
            backgroundColor: Colors.deepPurple,
          ),
          body: GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemCount: 30,
            itemBuilder: (context, index) {
              final level = index + 1;
              final isLocked = completedLevels.contains(level);

              return GestureDetector(
                onTap: isLocked
                    ? null
                    : () {
                  NavigationService.pushNamed(
                    AppRouter.quizLevel,
                    args: {
                      'level': level,
                      'questions': questions,
                    },
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isLocked
                        ? Colors.grey.shade300
                        : Colors.deepPurple.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      'Level $level',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isLocked
                            ? Colors.grey
                            : Colors.deepPurple,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
