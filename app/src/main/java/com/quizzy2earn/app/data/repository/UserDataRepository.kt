package com.quizzy2earn.app.data.repository

import com.quizzy2earn.app.data.model.DailyStreakDay
import com.quizzy2earn.app.data.model.LevelProgress
import com.quizzy2earn.app.data.model.PaymentMethod
import com.quizzy2earn.app.data.model.SpinReward
import com.quizzy2earn.app.data.model.TransactionType
import com.quizzy2earn.app.data.model.WalletTransaction
import com.quizzy2earn.app.data.model.WithdrawalRequest
import com.quizzy2earn.app.data.model.WithdrawalStatus
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.UUID

object UserDataRepository {

    // Balance & Stats
    private val _coins = MutableStateFlow(250) // Starting welcome coins
    val coins: StateFlow<Int> = _coins.asStateFlow()

    private val _quizzesPlayed = MutableStateFlow(0)
    val quizzesPlayed: StateFlow<Int> = _quizzesPlayed.asStateFlow()

    private val _correctAnswers = MutableStateFlow(0)
    val correctAnswers: StateFlow<Int> = _correctAnswers.asStateFlow()

    private val _spinsRemainingToday = MutableStateFlow(5)
    val spinsRemainingToday: StateFlow<Int> = _spinsRemainingToday.asStateFlow()

    // Level progression: map of "category_level" -> LevelProgress
    private val _levelProgressMap = MutableStateFlow<Map<String, LevelProgress>>(
        buildInitialLevelProgress()
    )
    val levelProgressMap: StateFlow<Map<String, LevelProgress>> = _levelProgressMap.asStateFlow()

    // Transactions
    private val _transactions = MutableStateFlow<List<WalletTransaction>>(
        listOf(
            WalletTransaction(
                id = UUID.randomUUID().toString().take(8),
                type = TransactionType.DAILY_CHECKIN,
                title = "Welcome Starter Bonus",
                amount = 250
            )
        )
    )
    val transactions: StateFlow<List<WalletTransaction>> = _transactions.asStateFlow()

    // Withdrawals
    private val _withdrawals = MutableStateFlow<List<WithdrawalRequest>>(emptyList())
    val withdrawals: StateFlow<List<WithdrawalRequest>> = _withdrawals.asStateFlow()

    // Daily streak: 7 days
    private val streakRewards = listOf(20, 40, 60, 80, 100, 150, 300)
    private val _currentStreakDay = MutableStateFlow(1)
    val currentStreakDay: StateFlow<Int> = _currentStreakDay.asStateFlow()

    private val _streakClaimedToday = MutableStateFlow(false)
    val streakClaimedToday: StateFlow<Boolean> = _streakClaimedToday.asStateFlow()

    // Referral Code
    val myReferralCode = "QUIZ7799"
    private val _referralsCount = MutableStateFlow(3)
    val referralsCount: StateFlow<Int> = _referralsCount.asStateFlow()

    val spinRewards = listOf(
        SpinReward(10, "10 Coins", 0xFFFFC107, 25),
        SpinReward(25, "25 Coins", 0xFF03A9F4, 20),
        SpinReward(50, "50 Coins", 0xFF4CAF50, 15),
        SpinReward(100, "100 Coins", 0xFF9C27B0, 10),
        SpinReward(15, "15 Coins", 0xFFFF5722, 20),
        SpinReward(200, "200 Coins", 0xFFE91E63, 6),
        SpinReward(5, "5 Coins", 0xFF607D8B, 30),
        SpinReward(500, "JACKPOT 500", 0xFFFF9800, 4)
    )

    private fun buildInitialLevelProgress(): Map<String, LevelProgress> {
        val map = mutableMapOf<String, LevelProgress>()
        QuizRepository.categories.forEach { cat ->
            for (lvl in 1..cat.totalLevels) {
                val key = "${cat.id}_$lvl"
                map[key] = LevelProgress(
                    levelNumber = lvl,
                    isUnlocked = (lvl == 1), // First level is unlocked
                    stars = 0,
                    highScore = 0
                )
            }
        }
        return map
    }

    fun addCoins(amount: Int, type: TransactionType, title: String) {
        _coins.value += amount
        val newTx = WalletTransaction(
            id = UUID.randomUUID().toString().take(8),
            type = type,
            title = title,
            amount = amount
        )
        _transactions.value = listOf(newTx) + _transactions.value
    }

    fun completeQuizLevel(
        categoryId: String,
        levelNumber: Int,
        score: Int,
        totalQuestions: Int,
        coinsEarned: Int,
        starsEarned: Int
    ) {
        _quizzesPlayed.value += 1
        _correctAnswers.value += score

        if (coinsEarned > 0) {
            addCoins(
                coinsEarned,
                TransactionType.QUIZ_WIN,
                "Quiz: ${categoryId.replaceFirstChar { it.uppercase() }} Lvl $levelNumber ($score/$totalQuestions)"
            )
        }

        // Update current level progress and unlock next level
        val currentKey = "${categoryId}_$levelNumber"
        val existing = _levelProgressMap.value[currentKey]
        val updatedCurrent = (existing ?: LevelProgress(levelNumber, true, 0, 0)).copy(
            stars = maxOf(existing?.stars ?: 0, starsEarned),
            highScore = maxOf(existing?.highScore ?: 0, score)
        )

        val updatedMap = _levelProgressMap.value.toMutableMap()
        updatedMap[currentKey] = updatedCurrent

        // Unlock next level if stars >= 1
        if (starsEarned >= 1 && levelNumber < 10) {
            val nextKey = "${categoryId}_${levelNumber + 1}"
            val nextLevel = updatedMap[nextKey]
            if (nextLevel != null) {
                updatedMap[nextKey] = nextLevel.copy(isUnlocked = true)
            }
        }
        _levelProgressMap.value = updatedMap
    }

    fun claimDailyStreak(): Boolean {
        if (_streakClaimedToday.value) return false
        val day = _currentStreakDay.value
        val reward = streakRewards.getOrElse(day - 1) { 50 }
        addCoins(reward, TransactionType.DAILY_CHECKIN, "Day $day Streak Check-In")
        _streakClaimedToday.value = true
        _currentStreakDay.value = if (day >= 7) 1 else day + 1
        return true
    }

    fun recordDailySpin(reward: SpinReward): Boolean {
        if (_spinsRemainingToday.value <= 0) return false
        _spinsRemainingToday.value -= 1
        addCoins(reward.coins, TransactionType.DAILY_SPIN, "Lucky Wheel: ${reward.label}")
        return true
    }

    fun solveCaptchaReward(coinsReward: Int = 15, taskName: String = "Math Captcha"): Boolean {
        addCoins(coinsReward, TransactionType.CAPTCHA_BONUS, "Security Verification: $taskName")
        return true
    }

    fun submitWithdrawal(method: PaymentMethod, accountDetail: String, coinsAmount: Int): Boolean {
        if (_coins.value < coinsAmount) return false
        val usdValue = (coinsAmount.toDouble() / method.minCoins) * method.rateUsd

        _coins.value -= coinsAmount
        val req = WithdrawalRequest(
            id = "WTH-" + UUID.randomUUID().toString().take(6).uppercase(),
            paymentMethod = method,
            accountDetail = accountDetail,
            coinsDebited = coinsAmount,
            payoutAmountUsd = usdValue,
            status = WithdrawalStatus.PENDING
        )
        _withdrawals.value = listOf(req) + _withdrawals.value

        val tx = WalletTransaction(
            id = req.id,
            type = TransactionType.WITHDRAWAL,
            title = "Payout Request (${method.displayName})",
            amount = -coinsAmount
        )
        _transactions.value = listOf(tx) + _transactions.value
        return true
    }

    fun addReferral() {
        _referralsCount.value += 1
        addCoins(100, TransactionType.REFERRAL_BONUS, "Friend Joined via Referral")
    }

    fun getStreakDays(): List<DailyStreakDay> {
        val currentDay = _currentStreakDay.value
        val claimed = _streakClaimedToday.value
        return streakRewards.mapIndexed { idx, reward ->
            val dayNum = idx + 1
            DailyStreakDay(
                dayNumber = dayNum,
                rewardCoins = reward,
                isClaimed = (dayNum < currentDay) || (dayNum == currentDay && claimed),
                isToday = (dayNum == currentDay)
            )
        }
    }
}
