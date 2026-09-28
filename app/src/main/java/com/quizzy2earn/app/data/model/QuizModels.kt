package com.quizzy2earn.app.data.model

data class QuizQuestion(
    val id: String,
    val question: String,
    val options: List<String>,
    val correctIndex: Int,
    val explanation: String = ""
)

data class QuizCategory(
    val id: String,
    val name: String,
    val iconName: String,
    val description: String,
    val totalLevels: Int = 10,
    val baseRewardCoins: Int = 50
)

data class LevelProgress(
    val levelNumber: Int,
    val isUnlocked: Boolean,
    val stars: Int, // 0 to 3
    val highScore: Int
)

data class QuizResult(
    val categoryId: String,
    val levelNumber: Int,
    val score: Int,
    val totalQuestions: Int,
    val coinsEarned: Int,
    val stars: Int
)
