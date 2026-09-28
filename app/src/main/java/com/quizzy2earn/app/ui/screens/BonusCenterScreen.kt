package com.quizzy2earn.app.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
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
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.quizzy2earn.app.data.model.DailyStreakDay
import com.quizzy2earn.app.ui.theme.*
import com.quizzy2earn.app.ui.viewmodel.MainViewModel
import kotlin.random.Random

@Composable
fun BonusCenterScreen(viewModel: MainViewModel) {
    val streakClaimed by viewModel.streakClaimedToday.collectAsState()
    val streakDays = viewModel.getStreakDays()

    // Captcha Mini-Game State
    var activeCaptchaType by remember { mutableStateOf<String?>("math") }
    var mathOpA by remember { mutableIntStateOf(14) }
    var mathOpB by remember { mutableIntStateOf(28) }
    var mathInput by remember { mutableStateOf("") }
    var mathMessage by remember { mutableStateOf<String?>(null) }

    // Tap challenge state
    var tapTargetCount by remember { mutableIntStateOf(5) }
    var currentTaps by remember { mutableIntStateOf(0) }
    var tapCompleted by remember { mutableStateOf(false) }

    // Slider challenge state
    var sliderTarget by remember { mutableFloatStateOf(65f) }
    var currentSliderValue by remember { mutableFloatStateOf(20f) }
    var sliderCompleted by remember { mutableStateOf(false) }

    fun refreshMath() {
        mathOpA = Random.nextInt(10, 50)
        mathOpB = Random.nextInt(5, 45)
        mathInput = ""
        mathMessage = null
    }

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(DarkNavy)
            .padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
        contentPadding = PaddingValues(top = 16.dp, bottom = 96.dp)
    ) {
        item {
            Text(
                text = "Bonus Center",
                style = MaterialTheme.typography.headlineMedium,
                color = GoldPrimary,
                fontWeight = FontWeight.ExtraBold
            )
            Text(
                text = "Claim daily streaks and solve micro-challenges for free coins!",
                style = MaterialTheme.typography.bodyMedium,
                color = TextMuted
            )
        }

        // Daily 7-Day Streak Card
        item {
            Card(
                shape = RoundedCornerShape(20.dp),
                colors = CardDefaults.cardColors(containerColor = SurfaceNavy),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(10.dp)
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(40.dp)
                                    .clip(CircleShape)
                                    .background(GoldPrimary),
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(
                                    Icons.Default.CardGiftcard,
                                    contentDescription = "Streak",
                                    tint = DarkNavy,
                                    modifier = Modifier.size(24.dp)
                                )
                            }
                            Column {
                                Text(
                                    text = "7-Day Check-in Streak",
                                    style = MaterialTheme.typography.titleMedium,
                                    color = TextLight,
                                    fontWeight = FontWeight.Bold
                                )
                                Text(
                                    text = "Come back daily to unlock Day 7 Mega Bonus!",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = TextMuted
                                )
                            }
                        }
                    }

                    // 7-day row
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        streakDays.forEach { day ->
                            StreakDayPill(day = day)
                        }
                    }

                    // Claim Button
                    Button(
                        onClick = { viewModel.claimDailyStreak() },
                        enabled = !streakClaimed,
                        colors = ButtonDefaults.buttonColors(containerColor = GoldPrimary),
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(48.dp)
                            .testTag("claim_daily_streak_button")
                    ) {
                        Text(
                            text = if (streakClaimed) "Claimed For Today" else "Claim Today's Bonus",
                            color = DarkNavy,
                            fontWeight = FontWeight.Bold,
                            fontSize = 15.sp
                        )
                    }
                }
            }
        }

        // Section header for Verification Puzzles
        item {
            Text(
                text = "Instant Coin Captchas",
                style = MaterialTheme.typography.titleLarge,
                color = TextLight,
                fontWeight = FontWeight.Bold
            )
            Text(
                text = "Solve human verification puzzles to secure your account & earn +15 coins",
                style = MaterialTheme.typography.bodyMedium,
                color = TextMuted
            )
        }

        // Tabs to switch Captcha Type
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                CaptchaTabChip(
                    title = "Math Captcha",
                    isSelected = activeCaptchaType == "math",
                    onClick = { activeCaptchaType = "math" }
                )
                CaptchaTabChip(
                    title = "Tap Speed",
                    isSelected = activeCaptchaType == "tap",
                    onClick = { activeCaptchaType = "tap" }
                )
                CaptchaTabChip(
                    title = "Slider Match",
                    isSelected = activeCaptchaType == "slider",
                    onClick = { activeCaptchaType = "slider" }
                )
            }
        }

        // Active Captcha Mini Game
        item {
            Card(
                shape = RoundedCornerShape(20.dp),
                colors = CardDefaults.cardColors(containerColor = SurfaceNavy),
                modifier = Modifier.fillMaxWidth()
            ) {
                Box(modifier = Modifier.padding(20.dp)) {
                    when (activeCaptchaType) {
                        "math" -> {
                            Column(
                                horizontalAlignment = Alignment.CenterHorizontally,
                                verticalArrangement = Arrangement.spacedBy(14.dp),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Text(
                                    text = "Solve the arithmetic equation:",
                                    style = MaterialTheme.typography.titleMedium,
                                    color = TextLight
                                )

                                Surface(
                                    shape = RoundedCornerShape(16.dp),
                                    color = CardNavy,
                                    modifier = Modifier.padding(vertical = 4.dp)
                                ) {
                                    Text(
                                        text = "$mathOpA  +  $mathOpB  =  ?",
                                        style = MaterialTheme.typography.headlineLarge,
                                        color = GoldPrimary,
                                        fontWeight = FontWeight.Black,
                                        modifier = Modifier.padding(horizontal = 24.dp, vertical = 12.dp)
                                    )
                                }

                                OutlinedTextField(
                                    value = mathInput,
                                    onValueChange = { mathInput = it.take(4) },
                                    label = { Text("Your Answer") },
                                    singleLine = true,
                                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                                    colors = OutlinedTextFieldDefaults.colors(
                                        focusedBorderColor = GoldPrimary,
                                        unfocusedBorderColor = CardNavy,
                                        focusedTextColor = TextLight,
                                        unfocusedTextColor = TextLight
                                    ),
                                    modifier = Modifier
                                        .fillMaxWidth(0.6f)
                                        .testTag("math_captcha_input")
                                )

                                mathMessage?.let { msg ->
                                    Text(
                                        text = msg,
                                        color = if (msg.contains("Correct")) AccentGreen else AccentRed,
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 14.sp
                                    )
                                }

                                Row(
                                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    OutlinedButton(
                                        onClick = { refreshMath() },
                                        shape = RoundedCornerShape(12.dp),
                                        modifier = Modifier.weight(1f)
                                    ) {
                                        Text("New Question", color = TextLight)
                                    }

                                    Button(
                                        onClick = {
                                            val expected = mathOpA + mathOpB
                                            if (mathInput.toIntOrNull() == expected) {
                                                viewModel.solveMathCaptcha(15)
                                                mathMessage = "Correct! +15 Coins added."
                                                refreshMath()
                                            } else {
                                                mathMessage = "Incorrect. Try again!"
                                            }
                                        },
                                        colors = ButtonDefaults.buttonColors(containerColor = GoldPrimary),
                                        shape = RoundedCornerShape(12.dp),
                                        modifier = Modifier
                                            .weight(1f)
                                            .testTag("submit_math_captcha_button")
                                    ) {
                                        Text("Verify", color = DarkNavy, fontWeight = FontWeight.Bold)
                                    }
                                }
                            }
                        }
                        "tap" -> {
                            Column(
                                horizontalAlignment = Alignment.CenterHorizontally,
                                verticalArrangement = Arrangement.spacedBy(14.dp),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Text(
                                    text = "Human Speed Test: Tap the target 5 times!",
                                    style = MaterialTheme.typography.titleMedium,
                                    color = TextLight,
                                    textAlign = TextAlign.Center
                                )

                                Text(
                                    text = "Progress: $currentTaps / $tapTargetCount",
                                    color = AccentCyan,
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 16.sp
                                )

                                Box(
                                    modifier = Modifier
                                        .size(100.dp)
                                        .clip(CircleShape)
                                        .background(if (tapCompleted) AccentGreen else GoldPrimary)
                                        .clickable(enabled = !tapCompleted) {
                                            currentTaps += 1
                                            if (currentTaps >= tapTargetCount) {
                                                tapCompleted = true
                                                viewModel.solveTapCaptcha(15)
                                            }
                                        }
                                        .testTag("tap_captcha_target"),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Icon(
                                        imageVector = if (tapCompleted) Icons.Default.Check else Icons.Default.TouchApp,
                                        contentDescription = "Tap",
                                        tint = DarkNavy,
                                        modifier = Modifier.size(48.dp)
                                    )
                                }

                                if (tapCompleted) {
                                    Text(
                                        text = "Success! +15 Coins rewarded.",
                                        color = AccentGreen,
                                        fontWeight = FontWeight.Bold
                                    )
                                    Button(
                                        onClick = {
                                            currentTaps = 0
                                            tapCompleted = false
                                        },
                                        colors = ButtonDefaults.buttonColors(containerColor = CardNavy),
                                        shape = RoundedCornerShape(12.dp)
                                    ) {
                                        Text("Play Again", color = TextLight)
                                    }
                                }
                            }
                        }
                        "slider" -> {
                            Column(
                                horizontalAlignment = Alignment.CenterHorizontally,
                                verticalArrangement = Arrangement.spacedBy(14.dp),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Text(
                                    text = "Align slider to target: ${sliderTarget.toInt()}%",
                                    style = MaterialTheme.typography.titleMedium,
                                    color = TextLight
                                )

                                Slider(
                                    value = currentSliderValue,
                                    onValueChange = {
                                        currentSliderValue = it
                                        sliderCompleted = false
                                    },
                                    valueRange = 0f..100f,
                                    colors = SliderDefaults.colors(
                                        thumbColor = GoldPrimary,
                                        activeTrackColor = GoldPrimary,
                                        inactiveTrackColor = CardNavy
                                    ),
                                    modifier = Modifier.fillMaxWidth()
                                )

                                Text(
                                    text = "Current: ${currentSliderValue.toInt()}%",
                                    color = TextMuted,
                                    fontWeight = FontWeight.Medium
                                )

                                Button(
                                    onClick = {
                                        if (kotlin.math.abs(currentSliderValue - sliderTarget) <= 4f) {
                                            sliderCompleted = true
                                            viewModel.solveSliderCaptcha(15)
                                            sliderTarget = Random.nextInt(20, 85).toFloat()
                                        }
                                    },
                                    colors = ButtonDefaults.buttonColors(containerColor = GoldPrimary),
                                    shape = RoundedCornerShape(12.dp),
                                    modifier = Modifier
                                        .fillMaxWidth(0.6f)
                                        .testTag("verify_slider_captcha_button")
                                ) {
                                    Text("Verify Position", color = DarkNavy, fontWeight = FontWeight.Bold)
                                }

                                if (sliderCompleted) {
                                    Text(
                                        text = "Target Matched! +15 Coins awarded.",
                                        color = AccentGreen,
                                        fontWeight = FontWeight.Bold
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun StreakDayPill(day: DailyStreakDay) {
    val bgColor = when {
        day.isClaimed -> AccentGreen.copy(alpha = 0.2f)
        day.isToday -> GoldPrimary.copy(alpha = 0.25f)
        else -> CardNavy
    }

    val borderColor = when {
        day.isClaimed -> AccentGreen
        day.isToday -> GoldPrimary
        else -> Color.Transparent
    }

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Surface(
            shape = RoundedCornerShape(12.dp),
            color = bgColor,
            modifier = Modifier
                .width(42.dp)
                .height(58.dp)
                .border(1.5.dp, borderColor, RoundedCornerShape(12.dp))
        ) {
            Column(
                modifier = Modifier.fillMaxSize(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                if (day.isClaimed) {
                    Icon(
                        Icons.Default.Check,
                        contentDescription = "Done",
                        tint = AccentGreen,
                        modifier = Modifier.size(18.dp)
                    )
                } else {
                    Text(
                        text = "+${day.rewardCoins}",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        color = if (day.isToday) GoldPrimary else TextLight
                    )
                }
            }
        }
        Text(
            text = "D${day.dayNumber}",
            fontSize = 11.sp,
            color = TextMuted,
            fontWeight = FontWeight.SemiBold
        )
    }
}

@Composable
fun CaptchaTabChip(title: String, isSelected: Boolean, onClick: () -> Unit) {
    Surface(
        shape = RoundedCornerShape(12.dp),
        color = if (isSelected) GoldPrimary else CardNavy,
        modifier = Modifier
            .clickable(onClick = onClick)
    ) {
        Text(
            text = title,
            color = if (isSelected) DarkNavy else TextLight,
            fontWeight = FontWeight.Bold,
            fontSize = 13.sp,
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp)
        )
    }
}
