package com.quizzy2earn.app.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.quizzy2earn.app.data.model.PaymentMethod
import com.quizzy2earn.app.data.model.QuizCategory
import com.quizzy2earn.app.data.model.QuizQuestion
import com.quizzy2earn.app.data.model.SpinReward
import com.quizzy2earn.app.data.repository.QuizRepository
import com.quizzy2earn.app.data.repository.UserDataRepository
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlin.random.Random

sealed class AppScreen {
    object Home : AppScreen()
    object Surveys : AppScreen()
    object BonusCenter : AppScreen()
    object Wallet : AppScreen()
    object Profile : AppScreen()
    data class CategoryLevels(val category: QuizCategory) : AppScreen()
    data class ActiveQuiz(val category: QuizCategory, val level: Int) : AppScreen()
    object DailySpin : AppScreen()
    data class Redeem(val method: PaymentMethod) : AppScreen()
    object WithdrawHistory : AppScreen()
    object InviteEarn : AppScreen()
    object Faq : AppScreen()
    object Support : AppScreen()
    object Terms : AppScreen()
}

class MainViewModel : ViewModel() {

    // Repository flows
    val coins = UserDataRepository.coins
    val quizzesPlayed = UserDataRepository.quizzesPlayed
    val correctAnswers = UserDataRepository.correctAnswers
    val spinsRemaining = UserDataRepository.spinsRemainingToday
    val levelProgressMap = UserDataRepository.levelProgressMap
    val transactions = UserDataRepository.transactions
    val withdrawals = UserDataRepository.withdrawals
    val currentStreakDay = UserDataRepository.currentStreakDay
    val streakClaimedToday = UserDataRepository.streakClaimedToday
    val referralsCount = UserDataRepository.referralsCount
    val myReferralCode = UserDataRepository.myReferralCode

    // Navigation Stack
    private val _currentScreen = MutableStateFlow<AppScreen>(AppScreen.Home)
    val currentScreen: StateFlow<AppScreen> = _currentScreen.asStateFlow()

    private val screenStack = mutableListOf<AppScreen>(AppScreen.Home)

    fun navigateTo(screen: AppScreen) {
        screenStack.add(screen)
        _currentScreen.value = screen
    }

    fun navigateBack(): Boolean {
        if (screenStack.size > 1) {
            screenStack.removeAt(screenStack.lastIndex)
            _currentScreen.value = screenStack.last()
            return true
        }
        return false
    }

    // Active Quiz Play State
    private var quizTimerJob: Job? = null
    val quizTimeLimitSeconds = 25

    private val _activeCategory = MutableStateFlow<QuizCategory?>(null)
    val activeCategory: StateFlow<QuizCategory?> = _activeCategory.asStateFlow()

    private val _activeLevel = MutableStateFlow(1)
    val activeLevel: StateFlow<Int> = _activeLevel.asStateFlow()

    private val _quizQuestions = MutableStateFlow<List<QuizQuestion>>(emptyList())
    val quizQuestions: StateFlow<List<QuizQuestion>> = _quizQuestions.asStateFlow()

    private val _currentQuestionIndex = MutableStateFlow(0)
    val currentQuestionIndex: StateFlow<Int> = _currentQuestionIndex.asStateFlow()

    private val _selectedAnswerIndex = MutableStateFlow<Int?>(null)
    val selectedAnswerIndex: StateFlow<Int?> = _selectedAnswerIndex.asStateFlow()

    private val _isAnswerSubmitted = MutableStateFlow(false)
    val isAnswerSubmitted: StateFlow<Boolean> = _isAnswerSubmitted.asStateFlow()

    private val _timerRemaining = MutableStateFlow(quizTimeLimitSeconds)
    val timerRemaining: StateFlow<Int> = _timerRemaining.asStateFlow()

    private val _currentScore = MutableStateFlow(0)
    val currentScore: StateFlow<Int> = _currentScore.asStateFlow()

    private val _hiddenOptions = MutableStateFlow<Set<Int>>(emptySet())
    val hiddenOptions: StateFlow<Set<Int>> = _hiddenOptions.asStateFlow()

    private val _is5050Used = MutableStateFlow(false)
    val is5050Used: StateFlow<Boolean> = _is5050Used.asStateFlow()

    private val _isQuizCompleted = MutableStateFlow(false)
    val isQuizCompleted: StateFlow<Boolean> = _isQuizCompleted.asStateFlow()

    fun startQuiz(category: QuizCategory, level: Int) {
        _activeCategory.value = category
        _activeLevel.value = level
        _quizQuestions.value = QuizRepository.getQuestionsForLevel(category.id, level)
        _currentQuestionIndex.value = 0
        _selectedAnswerIndex.value = null
        _isAnswerSubmitted.value = false
        _currentScore.value = 0
        _hiddenOptions.value = emptySet()
        _is5050Used.value = false
        _isQuizCompleted.value = false
        navigateTo(AppScreen.ActiveQuiz(category, level))
        startTimer()
    }

    private fun startTimer() {
        quizTimerJob?.cancel()
        _timerRemaining.value = quizTimeLimitSeconds
        quizTimerJob = viewModelScope.launch {
            while (_timerRemaining.value > 0 && !_isAnswerSubmitted.value) {
                delay(1000)
                _timerRemaining.value -= 1
            }
            if (_timerRemaining.value == 0 && !_isAnswerSubmitted.value) {
                // Time up! Auto submit with no selection (missed)
                submitAnswer(-1)
            }
        }
    }

    fun use5050Lifeline() {
        if (_is5050Used.value || _isAnswerSubmitted.value) return
        val currentQ = _quizQuestions.value.getOrNull(_currentQuestionIndex.value) ?: return
        val incorrectIndices = (0..3).filter { it != currentQ.correctIndex }.shuffled()
        // Hide two incorrect options
        _hiddenOptions.value = incorrectIndices.take(2).toSet()
        _is5050Used.value = true
    }

    fun submitAnswer(optionIndex: Int) {
        if (_isAnswerSubmitted.value) return
        quizTimerJob?.cancel()
        _selectedAnswerIndex.value = optionIndex
        _isAnswerSubmitted.value = true

        val currentQ = _quizQuestions.value.getOrNull(_currentQuestionIndex.value)
        if (currentQ != null && optionIndex == currentQ.correctIndex) {
            _currentScore.value += 1
        }
    }

    fun nextQuestion() {
        val total = _quizQuestions.value.size
        if (_currentQuestionIndex.value + 1 < total) {
            _currentQuestionIndex.value += 1
            _selectedAnswerIndex.value = null
            _isAnswerSubmitted.value = false
            _hiddenOptions.value = emptySet()
            startTimer()
        } else {
            finishQuiz()
        }
    }

    private fun finishQuiz() {
        _isQuizCompleted.value = true
        val score = _currentScore.value
        val total = _quizQuestions.value.size
        val category = _activeCategory.value ?: return
        val level = _activeLevel.value

        val stars = when {
            score == total -> 3
            score >= (total * 0.6) -> 2
            score >= (total * 0.4) -> 1
            else -> 0
        }

        val coinsEarned = if (stars > 0) {
            score * 10 + (stars * 15)
        } else {
            score * 5
        }

        UserDataRepository.completeQuizLevel(
            categoryId = category.id,
            levelNumber = level,
            score = score,
            totalQuestions = total,
            coinsEarned = coinsEarned,
            starsEarned = stars
        )
    }

    // Daily Spin Wheel
    private val _isSpinning = MutableStateFlow(false)
    val isSpinning: StateFlow<Boolean> = _isSpinning.asStateFlow()

    private val _wheelAngle = MutableStateFlow(0f)
    val wheelAngle: StateFlow<Float> = _wheelAngle.asStateFlow()

    private val _spinResultReward = MutableStateFlow<SpinReward?>(null)
    val spinResultReward: StateFlow<SpinReward?> = _spinResultReward.asStateFlow()

    fun triggerSpinWheel() {
        if (_isSpinning.value || spinsRemaining.value <= 0) return
        _isSpinning.value = true
        _spinResultReward.value = null

        val rewards = UserDataRepository.spinRewards
        val chosenIndex = Random.nextInt(rewards.size)
        val chosenReward = rewards[chosenIndex]

        // 360 / 8 segments = 45 degrees per segment
        val segmentAngle = 360f / rewards.size
        val targetSegmentCenter = chosenIndex * segmentAngle + (segmentAngle / 2f)

        // Spin 5 to 7 full rotations plus offset to point top indicator (270 degrees in canvas coords)
        val extraRounds = 5 + Random.nextInt(3)
        val targetAngle = _wheelAngle.value + (extraRounds * 360f) + (360f - targetSegmentCenter) + 270f

        viewModelScope.launch {
            val startAngle = _wheelAngle.value
            val diff = targetAngle - startAngle
            val durationMs = 3800L
            val startTime = System.currentTimeMillis()

            while (System.currentTimeMillis() - startTime < durationMs) {
                val progress = (System.currentTimeMillis() - startTime).toFloat() / durationMs
                // Deceleration curve (Cubic Ease-Out)
                val easeOut = 1f - (1f - progress) * (1f - progress) * (1f - progress)
                _wheelAngle.value = startAngle + diff * easeOut
                delay(16)
            }
            _wheelAngle.value = targetAngle
            _isSpinning.value = false
            _spinResultReward.value = chosenReward
            UserDataRepository.recordDailySpin(chosenReward)
        }
    }

    fun dismissSpinDialog() {
        _spinResultReward.value = null
    }

    // Daily Check-In
    fun claimDailyStreak(): Boolean {
        return UserDataRepository.claimDailyStreak()
    }

    fun getStreakDays() = UserDataRepository.getStreakDays()

    // Captchas
    fun solveMathCaptcha(reward: Int): Boolean {
        return UserDataRepository.solveCaptchaReward(reward, "Math Challenge")
    }

    fun solveTapCaptcha(reward: Int): Boolean {
        return UserDataRepository.solveCaptchaReward(reward, "Tap Speed Challenge")
    }

    fun solveSliderCaptcha(reward: Int): Boolean {
        return UserDataRepository.solveCaptchaReward(reward, "Precision Slider")
    }

    // Withdrawals
    fun submitWithdrawal(method: PaymentMethod, accountDetail: String, coins: Int): Boolean {
        return UserDataRepository.submitWithdrawal(method, accountDetail, coins)
    }

    // Referral
    fun simulateFriendReferral() {
        UserDataRepository.addReferral()
    }
}
