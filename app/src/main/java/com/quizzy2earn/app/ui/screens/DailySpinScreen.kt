package com.quizzy2earn.app.ui.screens

import android.graphics.Paint
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Casino
import androidx.compose.material.icons.filled.MonetizationOn
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.quizzy2earn.app.data.model.SpinReward
import com.quizzy2earn.app.data.repository.UserDataRepository
import com.quizzy2earn.app.ui.theme.*
import com.quizzy2earn.app.ui.viewmodel.MainViewModel
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DailySpinScreen(viewModel: MainViewModel) {
    BackHandler {
        viewModel.navigateBack()
    }

    val spinsRemaining by viewModel.spinsRemaining.collectAsState()
    val isSpinning by viewModel.isSpinning.collectAsState()
    val wheelAngle by viewModel.wheelAngle.collectAsState()
    val wonReward by viewModel.spinResultReward.collectAsState()
    val rewards = UserDataRepository.spinRewards

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Lucky Fortune Wheel",
                        fontWeight = FontWeight.Bold,
                        color = TextLight
                    )
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
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            // Header stats
            Card(
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = SurfaceNavy),
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier.padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Column {
                        Text(
                            text = "Daily Free Spins",
                            style = MaterialTheme.typography.titleMedium,
                            color = TextLight,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            text = "Jackpot up to 500 Coins!",
                            style = MaterialTheme.typography.bodyMedium,
                            color = GoldPrimary
                        )
                    }

                    Surface(
                        shape = RoundedCornerShape(12.dp),
                        color = CardNavy
                    ) {
                        Text(
                            text = "$spinsRemaining Left",
                            color = if (spinsRemaining > 0) AccentGreen else AccentRed,
                            fontWeight = FontWeight.Bold,
                            fontSize = 14.sp,
                            modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp)
                        )
                    }
                }
            }

            // Wheel Container with Pointer Arrow
            Box(
                modifier = Modifier
                    .size(310.dp)
                    .padding(8.dp),
                contentAlignment = Alignment.Center
            ) {
                // Animated Rotating Wheel Canvas
                Canvas(
                    modifier = Modifier
                        .fillMaxSize()
                        .rotate(wheelAngle)
                ) {
                    val radius = size.minDimension / 2f
                    val center = Offset(size.width / 2f, size.height / 2f)
                    val segmentAngle = 360f / rewards.size

                    rewards.forEachIndexed { i, reward ->
                        val startAngle = i * segmentAngle
                        drawArc(
                            color = Color(reward.colorHex),
                            startAngle = startAngle,
                            sweepAngle = segmentAngle,
                            useCenter = true,
                            topLeft = Offset(center.x - radius, center.y - radius),
                            size = Size(radius * 2f, radius * 2f)
                        )

                        // Draw Text in Segment
                        val midAngleRad = ((startAngle + segmentAngle / 2f) * PI / 180f).toFloat()
                        val textDist = radius * 0.65f
                        val textX = center.x + textDist * cos(midAngleRad)
                        val textY = center.y + textDist * sin(midAngleRad)

                        drawIntoCanvas { canvas ->
                            val paint = Paint().apply {
                                color = android.graphics.Color.WHITE
                                textAlign = Paint.Align.CENTER
                                textSize = 32f
                                isFakeBoldText = true
                                isAntiAlias = true
                            }
                            canvas.nativeCanvas.save()
                            canvas.nativeCanvas.rotate(startAngle + segmentAngle / 2f + 90f, textX, textY)
                            canvas.nativeCanvas.drawText("${reward.coins}", textX, textY, paint)
                            canvas.nativeCanvas.restore()
                        }
                    }

                    // Outer border
                    drawCircle(
                        color = Color(0xFFFFD54F),
                        radius = radius,
                        center = center,
                        style = androidx.compose.ui.graphics.drawscope.Stroke(width = 8f)
                    )

                    // Inner Center Hub
                    drawCircle(
                        color = DarkNavy.copy(alpha = 0.9f),
                        radius = radius * 0.22f,
                        center = center
                    )
                    drawCircle(
                        color = Color(0xFFFFD54F),
                        radius = radius * 0.18f,
                        center = center
                    )
                }

                // Center Icon over Hub
                Icon(
                    imageVector = Icons.Default.Casino,
                    contentDescription = "Dice",
                    tint = DarkNavy,
                    modifier = Modifier.size(28.dp)
                )

                // Top Pointer Arrow (Stationary)
                Canvas(
                    modifier = Modifier
                        .size(32.dp)
                        .align(Alignment.TopCenter)
                        .offset(y = (-6).dp)
                ) {
                    val path = Path().apply {
                        moveTo(size.width / 2f, size.height)
                        lineTo(0f, 0f)
                        lineTo(size.width, 0f)
                        close()
                    }
                    drawPath(path = path, color = Color(0xFFEF4444))
                }
            }

            // Spin Action Button
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 16.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Button(
                    onClick = { viewModel.triggerSpinWheel() },
                    enabled = !isSpinning && spinsRemaining > 0,
                    colors = ButtonDefaults.buttonColors(containerColor = GoldPrimary),
                    shape = RoundedCornerShape(16.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(54.dp)
                        .testTag("spin_wheel_button")
                ) {
                    Icon(
                        Icons.Default.Casino,
                        contentDescription = "Spin",
                        tint = DarkNavy,
                        modifier = Modifier.size(22.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = if (isSpinning) "Spinning..." else if (spinsRemaining > 0) "SPIN TO WIN" else "No Spins Left Today",
                        color = DarkNavy,
                        fontWeight = FontWeight.Black,
                        fontSize = 17.sp
                    )
                }

                Text(
                    text = "Spins reset every 24 hours at midnight",
                    style = MaterialTheme.typography.bodyMedium,
                    color = TextMuted,
                    fontSize = 12.sp
                )
            }
        }

        // Won Reward Dialog
        wonReward?.let { reward ->
            SpinWinDialog(
                reward = reward,
                onDismiss = { viewModel.dismissSpinDialog() }
            )
        }
    }
}

@Composable
fun SpinWinDialog(
    reward: SpinReward,
    onDismiss: () -> Unit
) {
    Dialog(onDismissRequest = onDismiss) {
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
                Box(
                    modifier = Modifier
                        .size(72.dp)
                        .clip(CircleShape)
                        .background(GoldPrimary),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        Icons.Default.MonetizationOn,
                        contentDescription = "Coins",
                        tint = DarkNavy,
                        modifier = Modifier.size(42.dp)
                    )
                }

                Text(
                    text = "Congratulations!",
                    style = MaterialTheme.typography.headlineMedium,
                    color = TextLight,
                    fontWeight = FontWeight.Black
                )

                Text(
                    text = "You won ${reward.label} on the Fortune Wheel!",
                    style = MaterialTheme.typography.bodyLarge,
                    color = TextMuted,
                    textAlign = TextAlign.Center
                )

                Surface(
                    shape = RoundedCornerShape(16.dp),
                    color = CardNavy
                ) {
                    Text(
                        text = "+${reward.coins} Coins Added to Wallet",
                        color = GoldPrimary,
                        fontWeight = FontWeight.Bold,
                        fontSize = 16.sp,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp)
                    )
                }

                Button(
                    onClick = onDismiss,
                    colors = ButtonDefaults.buttonColors(containerColor = GoldPrimary),
                    shape = RoundedCornerShape(14.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(48.dp)
                        .testTag("claim_spin_reward_button")
                ) {
                    Text("Awesome!", color = DarkNavy, fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}
