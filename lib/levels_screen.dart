import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quizzy2earn/core/app_router.dart';
import 'package:quizzy2earn/core/navigation_service.dart';
import 'package:quizzy2earn/core/question_service.dart';

class LevelsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> questions;

  const LevelsScreen({super.key, required this.questions});

  @override
  State<LevelsScreen> createState() => _LevelsScreenState();
}

class _LevelsScreenState extends State<LevelsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Widget _animateItem({required int index, required Widget child}) {
    final start = (index * 0.05).clamp(0.0, 0.5);
    final end = (start + 0.35).clamp(0.0, 1.0);

    final Animation<double> fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(start, end, curve: Curves.easeOut),
      ),
    );

    final Animation<Offset> slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      ),
    );

    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: slideAnimation,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(),
      builder: (context, snapshot) {

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF1E1E2C),
            body: Center(child: CircularProgressIndicator(color: Colors.white,)),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return const Scaffold(
            backgroundColor: Color(0xFF1E1E2C),
            body: Center(child: Text('Error loading levels', style: TextStyle(color: Colors.white))),
          );
        }

        final data = (snapshot.data!.data() ?? {}) as Map<String, dynamic>;

        final today = DateTime.now().toIso8601String().split('T')[0];
        final lastPlayedDate = data['lastPlayedDate'] ?? '';

        /// ✅ PERMANENT PLAYED LEVELS
        List<int> playedLevels = [];
        if (data['playedLevels'] is List) {
          playedLevels = (data['playedLevels'] as List)
              .map((e) => int.tryParse(e.toString()) ?? 0)
              .where((e) => e > 0)
              .toList();
        }

        /// ✅ TODAY PLAYED
        List<int> playedToday = [];
        if (data['playedLevelsToday'] is List) {
          playedToday = (data['playedLevelsToday'] as List)
              .map((e) => int.tryParse(e.toString()) ?? 0)
              .where((e) => e > 0)
              .toList();
        }

        int maxUnlockedLevel = data['maxUnlockedLevel'] ?? 10;

        debugPrint("LAST DATE: $lastPlayedDate");
        debugPrint("TODAY: $today");
        debugPrint("PLAYED TODAY: ${playedToday.length}");
        debugPrint("MAX BEFORE: $maxUnlockedLevel");

        /// 🔥 NEW DAY (RUN ONLY ONCE)
        if (lastPlayedDate.isNotEmpty && lastPlayedDate != today) {
          debugPrint("🔥 NEW DAY TRIGGERED");

          int newMaxUnlockedLevel = playedLevels.length + 10;

          if (newMaxUnlockedLevel > 100) {
            newMaxUnlockedLevel = 100;
          }

          FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({
            'maxUnlockedLevel': newMaxUnlockedLevel,
            'playedLevelsToday': [],
            'lastPlayedDate': today,
          });

          maxUnlockedLevel = newMaxUnlockedLevel;
          playedToday = [];
        }

        return Scaffold(
          extendBodyBehindAppBar: false,
          appBar: AppBar(
            title: const Text(
              'Select Level',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E1E2C), Color(0xFF2A2A40)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              children: [
                // Top Progress Card
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Daily Level Limit',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${playedToday.length}/10 played',
                              style: TextStyle(
                                color: playedToday.length >= 10 ? Colors.orangeAccent : Colors.greenAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: (playedToday.length / 10).clamp(0.0, 1.0),
                            backgroundColor: Colors.white.withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              playedToday.length >= 10 ? Colors.orangeAccent : Colors.deepPurpleAccent,
                            ),
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Levels Cleared:',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${playedLevels.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Grid of levels
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: 100, // Limit to 100 levels since maxUnlockedLevel is capped at 100
                    itemBuilder: (context, index) {
                      final level = index + 1;

                      final isCompleted = playedLevels.contains(level);
                      final isLocked = level > maxUnlockedLevel || (!isCompleted && playedToday.length >= 10);

                      Widget tile;

                      if (isCompleted) {
                        // State 1: Completed level
                        tile = Container(
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.green.withOpacity(0.3), width: 1.5),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '$level',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Completed',
                                    style: TextStyle(
                                      color: Colors.greenAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const Positioned(
                                top: 6,
                                right: 6,
                                child: Icon(Icons.check_circle, size: 16, color: Colors.greenAccent),
                              ),
                            ],
                          ),
                        );
                      } else if (isLocked) {
                        // State 2: Locked level
                        tile = Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Text(
                                '$level',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white.withOpacity(0.2),
                                  fontSize: 18,
                                ),
                              ),
                              Positioned(
                                bottom: 8,
                                child: Icon(Icons.lock, size: 14, color: Colors.white.withOpacity(0.3)),
                              ),
                            ],
                          ),
                        );
                      } else {
                        // State 3: Available level
                        tile = Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6A11CB).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
                          ),
                          child: Center(
                            child: Text(
                              '$level',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        );
                      }

                      return _animateItem(
                        index: index,
                        child: GestureDetector(
                          onTap: isLocked || isCompleted
                              ? null
                              : () {
                                  final preparedQuestions = QuestionService.prepareQuestions(
                                    rawQuestions: widget.questions,
                                    userId: user.uid,
                                    date: today,
                                  );

                                  NavigationService.pushNamed(
                                    AppRouter.quizLevel,
                                    args: {
                                      'level': level,
                                      'questions': preparedQuestions,
                                    },
                                  );
                                },
                          child: tile,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}