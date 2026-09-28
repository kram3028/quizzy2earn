import 'dart:math';

class QuestionService {
  static List<Map<String, dynamic>> prepareQuestions({
    required List<Map<String, dynamic>> rawQuestions,
    required String userId,
    required String date,
  }) {
    final seed = userId.hashCode + date.hashCode;
    final random = Random(seed);

    final questions = List<Map<String, dynamic>>.from(rawQuestions);

    questions.shuffle(random);

    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];

      // ✅ GET OPTIONS (NEW STRUCTURE)
      final options = List<String>.from(q['options'] ?? [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();

      // ❗ SAFETY (avoid empty)
      if (options.isEmpty) continue;

      // 🔀 SHUFFLE OPTIONS
      options.shuffle(Random(seed + i));

      // ✅ ASSIGN BACK
      questions[i]['options'] = options;
      questions[i]['correctAnswer'] =
          q['correctAnswer']?.toString().trim() ?? '';
    }

    return questions;
  }
}