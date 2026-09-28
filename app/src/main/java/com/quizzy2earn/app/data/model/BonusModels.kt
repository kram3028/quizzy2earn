package com.quizzy2earn.app.data.model

data class SpinReward(
    val coins: Int,
    val label: String,
    val colorHex: Long,
    val probabilityWeight: Int
)

data class DailyStreakDay(
    val dayNumber: Int,
    val rewardCoins: Int,
    val isClaimed: Boolean,
    val isToday: Boolean
)

data class MathCaptcha(
    val operandA: Int,
    val operandB: Int,
    val operator: String,
    val correctAnswer: Int
)
