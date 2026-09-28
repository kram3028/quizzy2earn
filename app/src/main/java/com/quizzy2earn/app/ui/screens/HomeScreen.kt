package com.quizzy2earn.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.quizzy2earn.app.data.model.QuizCategory
import com.quizzy2earn.app.data.repository.QuizRepository
import com.quizzy2earn.app.ui.theme.*
import com.quizzy2earn.app.ui.viewmodel.AppScreen
import com.quizzy2earn.app.ui.viewmodel.MainViewModel

@Composable
fun HomeScreen(viewModel: MainViewModel) {
    val coins by viewModel.coins.collectAsState()
    val spinsRemaining by viewModel.spinsRemaining.collectAsState()
    val streakDay by viewModel.currentStreakDay.collectAsState()
    val streakClaimed by viewModel.streakClaimedToday.collectAsState()
    val quizzesPlayed by viewModel.quizzesPlayed.collectAsState()
    val correctAnswers by viewModel.correctAnswers.collectAsState()

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(DarkNavy)
            .padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
        contentPadding = PaddingValues(top = 16.dp, bottom = 96.dp)
    ) {
        // App Header
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = "Quizzy2Earn",
                        style = MaterialTheme.typography.headlineMedium,
                        color = GoldPrimary,
                        fontWeight = FontWeight.ExtraBold
                    )
                    Text(
                        text = "Play, Learn & Cash Out",
                        style = MaterialTheme.typography.bodyMedium,
                        color = TextMuted
                    )
                }

                // Balance Chip
                Surface(
                    shape = RoundedCornerShape(24.dp),
                    color = CardNavy,
                    modifier = Modifier
                        .clickable { viewModel.navigateTo(AppScreen.Wallet) }
                        .testTag("home_balance_chip")
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.MonetizationOn,
                            contentDescription = "Coins",
                            tint = GoldPrimary,
                            modifier = Modifier.size(20.dp)
                        )
                        Text(
                            text = "$coins",
                            fontWeight = FontWeight.Bold,
                            color = TextLight,
                            fontSize = 16.sp
                        )
                    }
                }
            }
        }

        // Hero Balance & Quick Actions Card
        item {
            Card(
                shape = RoundedCornerShape(20.dp),
                colors = CardDefaults.cardColors(containerColor = SurfaceNavy),
                elevation = CardDefaults.cardElevation(defaultElevation = 4.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(
                            Brush.horizontalGradient(
                                colors = listOf(Color(0xFF1E293B), Color(0xFF334155))
                            )
                        )
                        .padding(20.dp)
                ) {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column {
                                Text(
                                    text = "Total Earnings",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = TextMuted
                                )
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                                ) {
                                    Text(
                                        text = "$coins Coins",
                                        style = MaterialTheme.typography.headlineLarge,
                                        color = GoldPrimary,
                                        fontWeight = FontWeight.Black
                                    )
                                    Surface(
                                        shape = RoundedCornerShape(8.dp),
                                        color = AccentGreen.copy(alpha = 0.2f)
                                    ) {
                                        Text(
                                            text = "≈ $${String.format("%.2f", coins / 1000.0)} USD",
                                            color = AccentGreen,
                                            fontWeight = FontWeight.Bold,
                                            fontSize = 12.sp,
                                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                                        )
                                    }
                                }
                            }
                        }

                        Divider(color = Color.White.copy(alpha = 0.1f))

                        // Quick Stats
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            StatMiniItem(label = "Quizzes", value = "$quizzesPlayed")
                            StatMiniItem(label = "Correct", value = "$correctAnswers")
                            val accuracy = if (quizzesPlayed > 0) (correctAnswers * 100) / (quizzesPlayed * 5) else 0
                            StatMiniItem(label = "Accuracy", value = "$accuracy%")
                        }

                        // Action Buttons inside Hero
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(10.dp)
                        ) {
                            Button(
                                onClick = { viewModel.navigateTo(AppScreen.DailySpin) },
                                colors = ButtonDefaults.buttonColors(containerColor = GoldPrimary),
                                shape = RoundedCornerShape(12.dp),
                                modifier = Modifier
                                    .weight(1f)
                                    .testTag("hero_spin_button")
                            ) {
                                Icon(
                                    Icons.Default.Refresh,
                                    contentDescription = "Spin Wheel",
                                    tint = DarkNavy,
                                    modifier = Modifier.size(18.dp)
                                )
                                Spacer(modifier = Modifier.width(6.dp))
                                Text(
                                    text = "Spin ($spinsRemaining)",
                                    color = DarkNavy,
                                    fontWeight = FontWeight.Bold
                                )
                            }

                            FilledTonalButton(
                                onClick = { viewModel.navigateTo(AppScreen.BonusCenter) },
                                shape = RoundedCornerShape(12.dp),
                                colors = ButtonDefaults.filledTonalButtonColors(
                                    containerColor = if (streakClaimed) CardNavy else AccentCyan,
                                    contentColor = if (streakClaimed) TextMuted else Color.Black
                                ),
                                modifier = Modifier
                                    .weight(1f)
                                    .testTag("hero_daily_bonus_button")
                            ) {
                                Icon(
                                    Icons.Default.CardGiftcard,
                                    contentDescription = "Daily Streak",
                                    modifier = Modifier.size(18.dp)
                                )
                                Spacer(modifier = Modifier.width(6.dp))
                                Text(
                                    text = if (streakClaimed) "Day $streakDay Done" else "Claim Day $streakDay",
                                    fontWeight = FontWeight.Bold
                                )
                            }
                        }
                    }
                }
            }
        }

        // Daily Spin Banner
        item {
            Card(
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = CardNavy),
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { viewModel.navigateTo(AppScreen.DailySpin) }
                    .testTag("home_spin_banner")
            ) {
                Row(
                    modifier = Modifier.padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(50.dp)
                            .clip(CircleShape)
                            .background(Brush.radialGradient(listOf(GoldPrimary, Color(0xFFE65100)))),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            Icons.Default.Casino,
                            contentDescription = "Wheel",
                            tint = Color.White,
                            modifier = Modifier.size(28.dp)
                        )
                    }

                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = "Daily Fortune Wheel",
                            style = MaterialTheme.typography.titleMedium,
                            color = TextLight,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            text = "Spin up to 500 Coins jackpot! $spinsRemaining free spins left.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = TextMuted
                        )
                    }

                    Icon(
                        Icons.Default.ChevronRight,
                        contentDescription = "Play",
                        tint = GoldPrimary
                    )
                }
            }
        }

        // Quiz Categories Section
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Quiz Arenas",
                    style = MaterialTheme.typography.titleLarge,
                    color = TextLight,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = "Earn 50+ per level",
                    style = MaterialTheme.typography.bodyMedium,
                    color = AccentCyan
                )
            }
        }

        // Categories List
        items(QuizRepository.categories) { category ->
            CategoryCardItem(
                category = category,
                onClick = { viewModel.navigateTo(AppScreen.CategoryLevels(category)) }
            )
        }

        // Referral & Bonus Teaser
        item {
            Card(
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = SurfaceNavy),
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { viewModel.navigateTo(AppScreen.InviteEarn) }
                    .testTag("home_invite_banner")
            ) {
                Row(
                    modifier = Modifier.padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(46.dp)
                            .clip(CircleShape)
                            .background(AccentPurple),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            Icons.Default.GroupAdd,
                            contentDescription = "Invite",
                            tint = Color.White,
                            modifier = Modifier.size(24.dp)
                        )
                    }

                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = "Invite Friends & Earn 100 Coins",
                            style = MaterialTheme.typography.titleMedium,
                            color = TextLight,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            text = "Get 10% lifetime referral rewards when they play quizzes!",
                            style = MaterialTheme.typography.bodyMedium,
                            color = TextMuted
                        )
                    }

                    Icon(
                        Icons.Default.ArrowForward,
                        contentDescription = "Go",
                        tint = AccentPurple
                    )
                }
            }
        }
    }
}

@Composable
fun StatMiniItem(label: String, value: String) {
    Column {
        Text(text = label, style = MaterialTheme.typography.bodyMedium, color = TextMuted)
        Text(
            text = value,
            style = MaterialTheme.typography.titleLarge,
            color = TextLight,
            fontWeight = FontWeight.Bold
        )
    }
}

@Composable
fun CategoryCardItem(category: QuizCategory, onClick: () -> Unit) {
    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = CardNavy),
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .testTag("category_card_${category.id}")
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            val icon = when (category.id) {
                "science" -> Icons.Default.Science
                "history" -> Icons.Default.Public
                "entertainment" -> Icons.Default.Movie
                "sports" -> Icons.Default.SportsSoccer
                else -> Icons.Default.School
            }

            val iconBg = when (category.id) {
                "science" -> Color(0xFF0284C7)
                "history" -> Color(0xFFD97706)
                "entertainment" -> Color(0xFFDB2777)
                "sports" -> Color(0xFF16A34A)
                else -> Color(0xFF7C3AED)
            }

            Box(
                modifier = Modifier
                    .size(52.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(iconBg),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = category.name,
                    tint = Color.White,
                    modifier = Modifier.size(28.dp)
                )
            }

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = category.name,
                    style = MaterialTheme.typography.titleMedium,
                    color = TextLight,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = category.description,
                    style = MaterialTheme.typography.bodyMedium,
                    color = TextMuted,
                    maxLines = 1
                )
                Spacer(modifier = Modifier.height(4.dp))
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "${category.totalLevels} Levels",
                        fontSize = 12.sp,
                        color = AccentCyan,
                        fontWeight = FontWeight.SemiBold
                    )
                    Text(text = "•", color = TextMuted, fontSize = 12.sp)
                    Text(
                        text = "+${category.baseRewardCoins} Coins",
                        fontSize = 12.sp,
                        color = GoldPrimary,
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }

            Icon(
                Icons.Default.ChevronRight,
                contentDescription = "Select",
                tint = TextMuted
            )
        }
    }
}
