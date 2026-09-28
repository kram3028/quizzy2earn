package com.quizzy2earn.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.quizzy2earn.app.data.model.TransactionType
import com.quizzy2earn.app.ui.theme.*
import com.quizzy2earn.app.ui.viewmodel.MainViewModel

data class SurveyOffer(
    val id: String,
    val provider: String,
    val title: String,
    val rewardCoins: Int,
    val timeMinutes: Int,
    val rating: Double,
    val color: Color
)

@Composable
fun SurveysScreen(viewModel: MainViewModel) {
    val surveyOffers = remember {
        listOf(
            SurveyOffer("s1", "CPX Research", "Consumer Habits & Shopping Feedback", 650, 10, 4.8, Color(0xFF0284C7)),
            SurveyOffer("s2", "BitLabs", "Technology & Mobile Gaming Trends", 1200, 15, 4.9, Color(0xFF7C3AED)),
            SurveyOffer("s3", "TheoremReach", "Brand Awareness & Beverage Preferences", 450, 6, 4.7, Color(0xFF059669)),
            SurveyOffer("s4", "BitLabs", "Global Travel & Entertainment Study", 850, 12, 4.6, Color(0xFFD97706)),
            SurveyOffer("s5", "CPX Research", "Quick Opinion Flash Poll", 250, 3, 4.9, Color(0xFFDC2626))
        )
    }

    var activeSurveyModal by remember { mutableStateOf<SurveyOffer?>(null) }
    var surveyCompletedMessage by remember { mutableStateOf<String?>(null) }

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
                text = "Surveys & Offers",
                style = MaterialTheme.typography.headlineMedium,
                color = GoldPrimary,
                fontWeight = FontWeight.ExtraBold
            )
            Text(
                text = "Share your opinion with global research partners to earn large coin rewards.",
                style = MaterialTheme.typography.bodyMedium,
                color = TextMuted
            )
        }

        // Provider Offerwalls Banner
        item {
            Card(
                shape = RoundedCornerShape(20.dp),
                colors = CardDefaults.cardColors(containerColor = SurfaceNavy),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(
                    modifier = Modifier.padding(18.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Text(
                        text = "Official Survey Partners",
                        style = MaterialTheme.typography.titleMedium,
                        color = TextLight,
                        fontWeight = FontWeight.Bold
                    )
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        PartnerBadge(name = "BitLabs", rating = "4.9★", color = Color(0xFF7C3AED))
                        PartnerBadge(name = "CPX Research", rating = "4.8★", color = Color(0xFF0284C7))
                        PartnerBadge(name = "TheoremReach", rating = "4.7★", color = Color(0xFF059669))
                    }
                }
            }
        }

        item {
            Text(
                text = "Available Studies",
                style = MaterialTheme.typography.titleLarge,
                color = TextLight,
                fontWeight = FontWeight.Bold
            )
        }

        items(surveyOffers) { offer ->
            SurveyCardItem(
                offer = offer,
                onClick = { activeSurveyModal = offer }
            )
        }
    }

    // Survey Simulation Dialog
    activeSurveyModal?.let { offer ->
        Dialog(onDismissRequest = { activeSurveyModal = null }) {
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
                            .size(60.dp)
                            .clip(CircleShape)
                            .background(offer.color),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            Icons.Default.Poll,
                            contentDescription = "Poll",
                            tint = Color.White,
                            modifier = Modifier.size(32.dp)
                        )
                    }

                    Text(
                        text = offer.provider,
                        style = MaterialTheme.typography.titleMedium,
                        color = AccentCyan,
                        fontWeight = FontWeight.Bold
                    )

                    Text(
                        text = offer.title,
                        style = MaterialTheme.typography.titleLarge,
                        color = TextLight,
                        fontWeight = FontWeight.Bold
                    )

                    Row(
                        horizontalArrangement = Arrangement.spacedBy(16.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.AccessTime, contentDescription = "Time", tint = TextMuted, modifier = Modifier.size(16.dp))
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("${offer.timeMinutes} mins", color = TextMuted, fontSize = 13.sp)
                        }
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.Star, contentDescription = "Rating", tint = GoldPrimary, modifier = Modifier.size(16.dp))
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("${offer.rating}", color = TextLight, fontSize = 13.sp, fontWeight = FontWeight.Bold)
                        }
                    }

                    Surface(
                        shape = RoundedCornerShape(14.dp),
                        color = CardNavy
                    ) {
                        Text(
                            text = "Reward: +${offer.rewardCoins} Coins",
                            color = GoldPrimary,
                            fontWeight = FontWeight.Bold,
                            fontSize = 16.sp,
                            modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
                        )
                    }

                    Text(
                        text = "Complete the questionnaire honestly to guarantee your full reward payout.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = TextMuted
                    )

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        OutlinedButton(
                            onClick = { activeSurveyModal = null },
                            shape = RoundedCornerShape(12.dp),
                            modifier = Modifier.weight(1f)
                        ) {
                            Text("Cancel", color = TextLight)
                        }

                        Button(
                            onClick = {
                                com.quizzy2earn.app.data.repository.UserDataRepository.addCoins(
                                    amount = offer.rewardCoins,
                                    type = TransactionType.SURVEY_REWARD,
                                    title = "Survey: ${offer.provider} - ${offer.title.take(15)}..."
                                )
                                activeSurveyModal = null
                            },
                            colors = ButtonDefaults.buttonColors(containerColor = GoldPrimary),
                            shape = RoundedCornerShape(12.dp),
                            modifier = Modifier
                                .weight(1.3f)
                                .testTag("start_survey_button")
                        ) {
                            Text("Start & Earn", color = DarkNavy, fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun PartnerBadge(name: String, rating: String, color: Color) {
    Surface(
        shape = RoundedCornerShape(12.dp),
        color = CardNavy,
        modifier = Modifier.width(100.dp)
    ) {
        Column(
            modifier = Modifier.padding(vertical = 10.dp, horizontal = 8.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = name,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Bold,
                color = color
            )
            Spacer(modifier = Modifier.height(2.dp))
            Text(
                text = rating,
                fontSize = 11.sp,
                color = TextLight,
                fontWeight = FontWeight.SemiBold
            )
        }
    }
}

@Composable
fun SurveyCardItem(offer: SurveyOffer, onClick: () -> Unit) {
    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = CardNavy),
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .testTag("survey_item_${offer.id}")
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(48.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(offer.color.copy(alpha = 0.2f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    Icons.Default.Assignment,
                    contentDescription = "Survey",
                    tint = offer.color,
                    modifier = Modifier.size(26.dp)
                )
            }

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = offer.provider,
                    fontSize = 12.sp,
                    color = offer.color,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = offer.title,
                    style = MaterialTheme.typography.titleMedium,
                    color = TextLight,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1
                )
                Spacer(modifier = Modifier.height(4.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        text = "⏱ ${offer.timeMinutes}m",
                        fontSize = 12.sp,
                        color = TextMuted
                    )
                    Text(text = "•", fontSize = 12.sp, color = TextMuted)
                    Text(
                        text = "★ ${offer.rating}",
                        fontSize = 12.sp,
                        color = GoldPrimary,
                        fontWeight = FontWeight.Bold
                    )
                }
            }

            Surface(
                shape = RoundedCornerShape(12.dp),
                color = GoldPrimary.copy(alpha = 0.15f)
            ) {
                Text(
                    text = "+${offer.rewardCoins}",
                    color = GoldPrimary,
                    fontWeight = FontWeight.Black,
                    fontSize = 14.sp,
                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp)
                )
            }
        }
    }
}
