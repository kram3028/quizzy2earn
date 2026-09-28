package com.quizzy2earn.app.ui.screens

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.quizzy2earn.app.data.model.LevelProgress
import com.quizzy2earn.app.data.model.QuizCategory
import com.quizzy2earn.app.ui.theme.*
import com.quizzy2earn.app.ui.viewmodel.AppScreen
import com.quizzy2earn.app.ui.viewmodel.MainViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CategoryLevelsScreen(
    category: QuizCategory,
    viewModel: MainViewModel
) {
    BackHandler {
        viewModel.navigateBack()
    }

    val progressMap by viewModel.levelProgressMap.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text(category.name, fontWeight = FontWeight.Bold, color = TextLight)
                        Text("Select Level", fontSize = 12.sp, color = TextMuted)
                    }
                },
                navigationIcon = {
                    IconButton(onClick = { viewModel.navigateBack() }) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back", tint = TextLight)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = DarkNavy)
            )
        },
        containerColor = DarkNavy
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(16.dp)
        ) {
            // Category Summary Banner
            Card(
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = SurfaceNavy),
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 16.dp)
            ) {
                Row(
                    modifier = Modifier.padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(48.dp)
                            .clip(CircleShape)
                            .background(GoldPrimary),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            Icons.Default.EmojiEvents,
                            contentDescription = "Trophy",
                            tint = DarkNavy,
                            modifier = Modifier.size(28.dp)
                        )
                    }
                    Column {
                        Text(
                            text = "Level Rewards",
                            style = MaterialTheme.typography.titleMedium,
                            color = TextLight,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            text = "Score 3 stars to maximize bonus coins!",
                            style = MaterialTheme.typography.bodyMedium,
                            color = TextMuted
                        )
                    }
                }
            }

            LazyVerticalGrid(
                columns = GridCells.Fixed(3),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
                modifier = Modifier.fillMaxSize()
            ) {
                items((1..category.totalLevels).toList()) { lvl ->
                    val key = "${category.id}_$lvl"
                    val progress = progressMap[key] ?: LevelProgress(lvl, lvl == 1, 0, 0)

                    LevelCardItem(
                        levelNumber = lvl,
                        progress = progress,
                        baseReward = category.baseRewardCoins,
                        onClick = {
                            if (progress.isUnlocked) {
                                viewModel.startQuiz(category, lvl)
                            }
                        }
                    )
                }
            }
        }
    }
}

@Composable
fun LevelCardItem(
    levelNumber: Int,
    progress: LevelProgress,
    baseReward: Int,
    onClick: () -> Unit
) {
    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = if (progress.isUnlocked) CardNavy else Color(0xFF172033)
        ),
        modifier = Modifier
            .fillMaxWidth()
            .aspectRatio(0.9f)
            .clickable(enabled = progress.isUnlocked, onClick = onClick)
            .testTag("level_item_$levelNumber")
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(8.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            if (progress.isUnlocked) {
                Text(
                    text = "LVL $levelNumber",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Black,
                    color = GoldPrimary
                )

                Spacer(modifier = Modifier.height(6.dp))

                // Stars rating
                Row(horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                    for (i in 1..3) {
                        Icon(
                            imageVector = if (i <= progress.stars) Icons.Default.Star else Icons.Default.StarBorder,
                            contentDescription = "Star",
                            tint = if (i <= progress.stars) GoldPrimary else TextMuted.copy(alpha = 0.5f),
                            modifier = Modifier.size(16.dp)
                        )
                    }
                }

                Spacer(modifier = Modifier.height(6.dp))

                Surface(
                    shape = RoundedCornerShape(8.dp),
                    color = Color.Black.copy(alpha = 0.3f)
                ) {
                    Text(
                        text = "+$baseReward",
                        color = AccentGreen,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                    )
                }
            } else {
                Icon(
                    imageVector = Icons.Default.Lock,
                    contentDescription = "Locked",
                    tint = TextMuted.copy(alpha = 0.6f),
                    modifier = Modifier.size(28.dp)
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = "LVL $levelNumber",
                    style = MaterialTheme.typography.bodyMedium,
                    color = TextMuted.copy(alpha = 0.6f),
                    fontWeight = FontWeight.Bold
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ActiveQuizPlayScreen(
    category: QuizCategory,
    level: Int,
    viewModel: MainViewModel
) {
    BackHandler {
        viewModel.navigateBack()
    }

    val questions by viewModel.quizQuestions.collectAsState()
    val currentIndex by viewModel.currentQuestionIndex.collectAsState()
    val selectedOption by viewModel.selectedAnswerIndex.collectAsState()
    val isSubmitted by viewModel.isAnswerSubmitted.collectAsState()
    val timerRemaining by viewModel.timerRemaining.collectAsState()
    val currentScore by viewModel.currentScore.collectAsState()
    val hiddenOptions by viewModel.hiddenOptions.collectAsState()
    val is5050Used by viewModel.is5050Used.collectAsState()
    val isQuizCompleted by viewModel.isQuizCompleted.collectAsState()

    val currentQuestion = questions.getOrNull(currentIndex)

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "${category.name} - Lvl $level",
                        fontWeight = FontWeight.Bold,
                        color = TextLight,
                        fontSize = 18.sp
                    )
                },
                navigationIcon = {
                    IconButton(onClick = { viewModel.navigateBack() }) {
                        Icon(Icons.Default.Close, contentDescription = "Exit Quiz", tint = TextLight)
                    }
                },
                actions = {
                    // 50:50 Lifeline Button
                    FilledTonalButton(
                        onClick = { viewModel.use5050Lifeline() },
                        enabled = !is5050Used && !isSubmitted,
                        shape = RoundedCornerShape(12.dp),
                        colors = ButtonDefaults.filledTonalButtonColors(
                            containerColor = if (is5050Used) CardNavy else AccentCyan,
                            contentColor = if (is5050Used) TextMuted else Color.Black
                        ),
                        modifier = Modifier
                            .padding(end = 12.dp)
                            .testTag("quiz_lifeline_5050")
                    ) {
                        Text(
                            text = if (is5050Used) "Used" else "50:50",
                            fontWeight = FontWeight.Black,
                            fontSize = 12.sp
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = DarkNavy)
            )
        },
        containerColor = DarkNavy
    ) { padding ->
        if (currentQuestion == null) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator(color = GoldPrimary)
            }
        } else {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .padding(16.dp),
                verticalArrangement = Arrangement.SpaceBetween
            ) {
                // Top Progress & Timer
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = "Question ${currentIndex + 1} of ${questions.size}",
                            style = MaterialTheme.typography.titleMedium,
                            color = TextLight,
                            fontWeight = FontWeight.Bold
                        )

                        // Timer Badge
                        val timerColor = if (timerRemaining <= 5) AccentRed else GoldPrimary
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(4.dp)
                        ) {
                            Icon(
                                Icons.Default.Timer,
                                contentDescription = "Timer",
                                tint = timerColor,
                                modifier = Modifier.size(18.dp)
                            )
                            Text(
                                text = "${timerRemaining}s",
                                color = timerColor,
                                fontWeight = FontWeight.Bold,
                                fontSize = 16.sp
                            )
                        }
                    }

                    // Linear Timer Progress Bar
                    val timerProgress = timerRemaining.toFloat() / viewModel.quizTimeLimitSeconds
                    LinearProgressIndicator(
                        progress = { timerProgress },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(6.dp)
                            .clip(RoundedCornerShape(3.dp)),
                        color = if (timerRemaining <= 5) AccentRed else GoldPrimary,
                        trackColor = SurfaceNavy
                    )
                }

                // Question Card
                Card(
                    shape = RoundedCornerShape(20.dp),
                    colors = CardDefaults.cardColors(containerColor = SurfaceNavy),
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 16.dp)
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(20.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text(
                            text = currentQuestion.question,
                            style = MaterialTheme.typography.titleLarge,
                            color = TextLight,
                            fontWeight = FontWeight.Bold,
                            textAlign = TextAlign.Center
                        )
                    }
                }

                // Answer Options List
                Column(
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                    modifier = Modifier.weight(1f, fill = false)
                ) {
                    currentQuestion.options.forEachIndexed { index, optionText ->
                        if (!hiddenOptions.contains(index)) {
                            QuizOptionButton(
                                optionLabel = ('A' + index).toString(),
                                text = optionText,
                                isSelected = (selectedOption == index),
                                isSubmitted = isSubmitted,
                                isCorrect = (index == currentQuestion.correctIndex),
                                onClick = {
                                    if (!isSubmitted) {
                                        viewModel.submitAnswer(index)
                                    }
                                }
                            )
                        }
                    }
                }

                // Bottom Next / Continue Button
                AnimatedVisibility(visible = isSubmitted) {
                    Button(
                        onClick = { viewModel.nextQuestion() },
                        colors = ButtonDefaults.buttonColors(containerColor = GoldPrimary),
                        shape = RoundedCornerShape(14.dp),
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(52.dp)
                            .testTag("quiz_next_button")
                    ) {
                        Text(
                            text = if (currentIndex + 1 < questions.size) "Next Question" else "See Results",
                            color = DarkNavy,
                            fontWeight = FontWeight.Bold,
                            fontSize = 16.sp
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Icon(
                            Icons.Default.ArrowForward,
                            contentDescription = "Next",
                            tint = DarkNavy
                        )
                    }
                }
            }
        }

        // Quiz Completion Results Dialog
        if (isQuizCompleted) {
            QuizResultsDialog(
                score = currentScore,
                total = questions.size,
                baseReward = category.baseRewardCoins,
                onRetry = {
                    viewModel.startQuiz(category, level)
                },
                onContinue = {
                    viewModel.navigateBack()
                }
            )
        }
    }
}

@Composable
fun QuizOptionButton(
    optionLabel: String,
    text: String,
    isSelected: Boolean,
    isSubmitted: Boolean,
    isCorrect: Boolean,
    onClick: () -> Unit
) {
    val borderColor by animateColorAsState(
        targetValue = when {
            isSubmitted && isCorrect -> AccentGreen
            isSubmitted && isSelected && !isCorrect -> AccentRed
            isSelected -> GoldPrimary
            else -> CardNavy
        }
    )

    val bgColor by animateColorAsState(
        targetValue = when {
            isSubmitted && isCorrect -> AccentGreen.copy(alpha = 0.2f)
            isSubmitted && isSelected && !isCorrect -> AccentRed.copy(alpha = 0.2f)
            isSelected -> GoldPrimary.copy(alpha = 0.15f)
            else -> CardNavy
        }
    )

    Surface(
        shape = RoundedCornerShape(14.dp),
        color = bgColor,
        modifier = Modifier
            .fillMaxWidth()
            .border(2.dp, borderColor, RoundedCornerShape(14.dp))
            .clickable(onClick = onClick)
            .testTag("quiz_option_$optionLabel")
    ) {
        Row(
            modifier = Modifier.padding(14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(34.dp)
                    .clip(CircleShape)
                    .background(borderColor.copy(alpha = 0.3f)),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = optionLabel,
                    fontWeight = FontWeight.Bold,
                    color = TextLight,
                    fontSize = 14.sp
                )
            }

            Text(
                text = text,
                style = MaterialTheme.typography.bodyLarge,
                color = TextLight,
                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                modifier = Modifier.weight(1f)
            )

            if (isSubmitted) {
                if (isCorrect) {
                    Icon(Icons.Default.CheckCircle, contentDescription = "Correct", tint = AccentGreen)
                } else if (isSelected) {
                    Icon(Icons.Default.Cancel, contentDescription = "Wrong", tint = AccentRed)
                }
            }
        }
    }
}

@Composable
fun QuizResultsDialog(
    score: Int,
    total: Int,
    baseReward: Int,
    onRetry: () -> Unit,
    onContinue: () -> Unit
) {
    val stars = when {
        score == total -> 3
        score >= (total * 0.6) -> 2
        score >= (total * 0.4) -> 1
        else -> 0
    }

    val earnedCoins = if (stars > 0) score * 10 + (stars * 15) else score * 5

    Dialog(onDismissRequest = onContinue) {
        Card(
            shape = RoundedCornerShape(24.dp),
            colors = CardDefaults.cardColors(containerColor = SurfaceNavy),
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                // Trophy or Alert Icon
                Box(
                    modifier = Modifier
                        .size(68.dp)
                        .clip(CircleShape)
                        .background(if (stars > 0) GoldPrimary else AccentRed.copy(alpha = 0.2f)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = if (stars > 0) Icons.Default.EmojiEvents else Icons.Default.MoodBad,
                        contentDescription = "Result",
                        tint = if (stars > 0) DarkNavy else AccentRed,
                        modifier = Modifier.size(36.dp)
                    )
                }

                Text(
                    text = if (stars > 0) "Level Completed!" else "Try Again!",
                    style = MaterialTheme.typography.headlineMedium,
                    color = TextLight,
                    fontWeight = FontWeight.Black
                )

                // Stars
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    for (i in 1..3) {
                        Icon(
                            imageVector = if (i <= stars) Icons.Default.Star else Icons.Default.StarBorder,
                            contentDescription = "Star",
                            tint = if (i <= stars) GoldPrimary else TextMuted.copy(alpha = 0.4f),
                            modifier = Modifier.size(32.dp)
                        )
                    }
                }

                Text(
                    text = "You scored $score out of $total questions correctly.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = TextMuted,
                    textAlign = TextAlign.Center
                )

                // Coin reward pill
                Surface(
                    shape = RoundedCornerShape(16.dp),
                    color = CardNavy
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Icon(
                            Icons.Default.MonetizationOn,
                            contentDescription = "Coins",
                            tint = GoldPrimary,
                            modifier = Modifier.size(24.dp)
                        )
                        Text(
                            text = "+$earnedCoins Coins Earned",
                            color = GoldPrimary,
                            fontWeight = FontWeight.Bold,
                            fontSize = 16.sp
                        )
                    }
                }

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    OutlinedButton(
                        onClick = onRetry,
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier.weight(1f)
                    ) {
                        Text("Retry", color = TextLight)
                    }

                    Button(
                        onClick = onContinue,
                        colors = ButtonDefaults.buttonColors(containerColor = GoldPrimary),
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier.weight(1f)
                    ) {
                        Text("Continue", color = DarkNavy, fontWeight = FontWeight.Bold)
                    }
                }
            }
        }
    }
}
