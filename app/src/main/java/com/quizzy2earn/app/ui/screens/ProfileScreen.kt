package com.quizzy2earn.app.ui.screens

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.widget.Toast
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.quizzy2earn.app.ui.theme.*
import com.quizzy2earn.app.ui.viewmodel.AppScreen
import com.quizzy2earn.app.ui.viewmodel.MainViewModel

@Composable
fun ProfileScreen(viewModel: MainViewModel) {
    val coins by viewModel.coins.collectAsState()
    val quizzesPlayed by viewModel.quizzesPlayed.collectAsState()
    val correctAnswers by viewModel.correctAnswers.collectAsState()
    val referralsCount by viewModel.referralsCount.collectAsState()

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(DarkNavy)
            .padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
        contentPadding = PaddingValues(top = 16.dp, bottom = 96.dp)
    ) {
        // User Profile Header
        item {
            Card(
                shape = RoundedCornerShape(20.dp),
                colors = CardDefaults.cardColors(containerColor = SurfaceNavy),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(
                    modifier = Modifier.padding(20.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(72.dp)
                            .clip(CircleShape)
                            .background(GoldPrimary),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            Icons.Default.Person,
                            contentDescription = "Avatar",
                            tint = DarkNavy,
                            modifier = Modifier.size(42.dp)
                        )
                    }

                    Text(
                        text = "Trivia Master",
                        style = MaterialTheme.typography.titleLarge,
                        color = TextLight,
                        fontWeight = FontWeight.Bold
                    )

                    Surface(
                        shape = RoundedCornerShape(12.dp),
                        color = CardNavy
                    ) {
                        Text(
                            text = "UID: QZ-928471 • Verified Player",
                            color = AccentCyan,
                            fontSize = 12.sp,
                            modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp)
                        )
                    }

                    Divider(color = Color.White.copy(alpha = 0.1f))

                    // Player Stats Row
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceAround
                    ) {
                        ProfileStatItem(title = "Balance", value = "$coins", color = GoldPrimary)
                        ProfileStatItem(title = "Quizzes", value = "$quizzesPlayed", color = TextLight)
                        val acc = if (quizzesPlayed > 0) (correctAnswers * 100) / (quizzesPlayed * 5) else 0
                        ProfileStatItem(title = "Accuracy", value = "$acc%", color = AccentGreen)
                        ProfileStatItem(title = "Invited", value = "$referralsCount", color = AccentPurple)
                    }
                }
            }
        }

        // Account Options Menu
        item {
            Text(
                text = "Account & Information",
                style = MaterialTheme.typography.titleLarge,
                color = TextLight,
                fontWeight = FontWeight.Bold
            )
        }

        item {
            Card(
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = CardNavy),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column {
                    ProfileMenuRow(
                        icon = Icons.Default.GroupAdd,
                        title = "Invite & Earn 100 Coins",
                        subtitle = "Share code with friends for ongoing commissions",
                        onClick = { viewModel.navigateTo(AppScreen.InviteEarn) }
                    )
                    Divider(color = Color.White.copy(alpha = 0.05f))
                    ProfileMenuRow(
                        icon = Icons.Default.History,
                        title = "Withdrawal History",
                        subtitle = "Check payout request statuses",
                        onClick = { viewModel.navigateTo(AppScreen.WithdrawHistory) }
                    )
                    Divider(color = Color.White.copy(alpha = 0.05f))
                    ProfileMenuRow(
                        icon = Icons.Default.HelpOutline,
                        title = "Frequently Asked Questions",
                        subtitle = "How coin conversions & quizzes work",
                        onClick = { viewModel.navigateTo(AppScreen.Faq) }
                    )
                    Divider(color = Color.White.copy(alpha = 0.05f))
                    ProfileMenuRow(
                        icon = Icons.Default.SupportAgent,
                        title = "Help & Customer Support",
                        subtitle = "Submit an inquiry to our team",
                        onClick = { viewModel.navigateTo(AppScreen.Support) }
                    )
                    Divider(color = Color.White.copy(alpha = 0.05f))
                    ProfileMenuRow(
                        icon = Icons.Default.Policy,
                        title = "Terms & Fair Play Policy",
                        subtitle = "Anti-fraud guidelines and usage rules",
                        onClick = { viewModel.navigateTo(AppScreen.Terms) }
                    )
                }
            }
        }
    }
}

@Composable
fun ProfileStatItem(title: String, value: String, color: Color) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(text = value, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, color = color)
        Text(text = title, fontSize = 11.sp, color = TextMuted)
    }
}

@Composable
fun ProfileMenuRow(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    title: String,
    subtitle: String,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Icon(icon, contentDescription = title, tint = GoldPrimary, modifier = Modifier.size(24.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(text = title, style = MaterialTheme.typography.titleMedium, color = TextLight, fontWeight = FontWeight.SemiBold)
            Text(text = subtitle, style = MaterialTheme.typography.bodyMedium, color = TextMuted, fontSize = 12.sp)
        }
        Icon(Icons.Default.ChevronRight, contentDescription = "Go", tint = TextMuted)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun InviteEarnScreen(viewModel: MainViewModel) {
    BackHandler {
        viewModel.navigateBack()
    }

    val context = LocalContext.current
    val referralCode = viewModel.myReferralCode
    val referralsCount by viewModel.referralsCount.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Invite & Earn", fontWeight = FontWeight.Bold, color = TextLight) },
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
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            item {
                Card(
                    shape = RoundedCornerShape(20.dp),
                    colors = CardDefaults.cardColors(containerColor = SurfaceNavy),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(
                        modifier = Modifier.padding(20.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .size(64.dp)
                                .clip(CircleShape)
                                .background(AccentPurple),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(Icons.Default.Share, contentDescription = "Share", tint = Color.White, modifier = Modifier.size(32.dp))
                        }

                        Text("Get 100 Coins Per Friend", style = MaterialTheme.typography.titleLarge, color = TextLight, fontWeight = FontWeight.Bold)
                        Text(
                            text = "Share your unique referral code. When a friend enters your code upon signup, you both get 100 instant bonus coins!",
                            style = MaterialTheme.typography.bodyMedium,
                            color = TextMuted,
                            textAlign = TextAlign.Center
                        )

                        // Referral Code Box
                        Surface(
                            shape = RoundedCornerShape(12.dp),
                            color = CardNavy,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    text = referralCode,
                                    style = MaterialTheme.typography.headlineMedium,
                                    color = GoldPrimary,
                                    fontWeight = FontWeight.Black
                                )

                                IconButton(
                                    onClick = {
                                        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                                        clipboard.setPrimaryClip(ClipData.newPlainText("Referral Code", referralCode))
                                        Toast.makeText(context, "Code copied to clipboard!", Toast.LENGTH_SHORT).show()
                                    },
                                    modifier = Modifier.testTag("copy_referral_code_button")
                                ) {
                                    Icon(Icons.Default.ContentCopy, contentDescription = "Copy", tint = TextLight)
                                }
                            }
                        }

                        Button(
                            onClick = {
                                val shareIntent = Intent(Intent.ACTION_SEND).apply {
                                    type = "text/plain"
                                    putExtra(Intent.EXTRA_TEXT, "Join me on Quizzy2Earn! Use my code $referralCode to get 100 bonus coins!")
                                }
                                context.startActivity(Intent.createChooser(shareIntent, "Share Referral Code"))
                            },
                            colors = ButtonDefaults.buttonColors(containerColor = GoldPrimary),
                            shape = RoundedCornerShape(12.dp),
                            modifier = Modifier.fillMaxWidth().height(48.dp)
                        ) {
                            Text("Share Referral Code", color = DarkNavy, fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }

            // Milestone Tracker
            item {
                Text("Referral Milestones", style = MaterialTheme.typography.titleMedium, color = TextLight, fontWeight = FontWeight.Bold)
            }

            item {
                Card(
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = CardNavy),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text("Invited Friends", color = TextMuted)
                            Text("$referralsCount Friends", color = AccentCyan, fontWeight = FontWeight.Bold)
                        }
                        LinearProgressIndicator(
                            progress = { (referralsCount / 10f).coerceIn(0f, 1f) },
                            modifier = Modifier.fillMaxWidth().height(8.dp).clip(RoundedCornerShape(4.dp)),
                            color = AccentPurple,
                            trackColor = SurfaceNavy
                        )
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text("1 Friend: +100", fontSize = 11.sp, color = TextMuted)
                            Text("5 Friends: +600", fontSize = 11.sp, color = TextMuted)
                            Text("10 Friends: +1500", fontSize = 11.sp, color = GoldPrimary, fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FaqScreen(viewModel: MainViewModel) {
    BackHandler {
        viewModel.navigateBack()
    }

    val faqs = listOf(
        "How do I earn coins?" to "You earn coins by answering quiz questions correctly, completing daily streaks in the Bonus Center, spinning the Lucky Fortune Wheel, and completing partner surveys.",
        "What is the conversion rate for coins?" to "1,000 Coins equal $1.00 USD. You can redeem via PayPal, UPI, Paytm, Amazon Gift Cards, Google Play credits, or Crypto USDT.",
        "How long do payouts take to process?" to "Withdrawal requests are processed manually within 24 to 48 business hours to ensure fair play verification.",
        "Can I use VPNs or automated bots?" to "No. Using VPNs, multiple accounts, or automated scripts violates our Fair Play policy and will lead to an immediate account suspension."
    )

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Frequently Asked Questions", fontWeight = FontWeight.Bold, color = TextLight) },
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
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            items(faqs) { (q, a) ->
                var expanded by remember { mutableStateOf(false) }
                Card(
                    shape = RoundedCornerShape(14.dp),
                    colors = CardDefaults.cardColors(containerColor = CardNavy),
                    modifier = Modifier.fillMaxWidth().clickable { expanded = !expanded }
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                            Text(text = q, style = MaterialTheme.typography.titleMedium, color = TextLight, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                            Icon(imageVector = if (expanded) Icons.Default.ExpandLess else Icons.Default.ExpandMore, contentDescription = "Toggle", tint = GoldPrimary)
                        }
                        AnimatedVisibility(visible = expanded) {
                            Column {
                                Spacer(modifier = Modifier.height(10.dp))
                                Text(text = a, style = MaterialTheme.typography.bodyMedium, color = TextMuted)
                            }
                        }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SupportScreen(viewModel: MainViewModel) {
    BackHandler {
        viewModel.navigateBack()
    }

    var subject by remember { mutableStateOf("") }
    var message by remember { mutableStateOf("") }
    var submitted by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Customer Support", fontWeight = FontWeight.Bold, color = TextLight) },
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
            modifier = Modifier.fillMaxSize().padding(padding).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Text("Submit a Help Ticket", style = MaterialTheme.typography.titleLarge, color = TextLight, fontWeight = FontWeight.Bold)
            Text("Our support agents usually respond within 12 hours.", style = MaterialTheme.typography.bodyMedium, color = TextMuted)

            OutlinedTextField(
                value = subject,
                onValueChange = { subject = it },
                label = { Text("Issue Subject") },
                singleLine = true,
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = GoldPrimary,
                    unfocusedBorderColor = CardNavy,
                    focusedTextColor = TextLight,
                    unfocusedTextColor = TextLight
                ),
                modifier = Modifier.fillMaxWidth().testTag("support_subject_input")
            )

            OutlinedTextField(
                value = message,
                onValueChange = { message = it },
                label = { Text("Detailed Description") },
                minLines = 4,
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = GoldPrimary,
                    unfocusedBorderColor = CardNavy,
                    focusedTextColor = TextLight,
                    unfocusedTextColor = TextLight
                ),
                modifier = Modifier.fillMaxWidth().testTag("support_message_input")
            )

            if (submitted) {
                Surface(
                    shape = RoundedCornerShape(12.dp),
                    color = AccentGreen.copy(alpha = 0.2f),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text(
                        text = "Ticket submitted successfully! Reference #TKT-${(1000..9999).random()}",
                        color = AccentGreen,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(14.dp)
                    )
                }
            }

            Button(
                onClick = {
                    if (subject.isNotBlank() && message.isNotBlank()) {
                        submitted = true
                        subject = ""
                        message = ""
                    }
                },
                colors = ButtonDefaults.buttonColors(containerColor = GoldPrimary),
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier.fillMaxWidth().height(48.dp).testTag("submit_ticket_button")
            ) {
                Text("Send Ticket", color = DarkNavy, fontWeight = FontWeight.Bold)
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TermsScreen(viewModel: MainViewModel) {
    BackHandler {
        viewModel.navigateBack()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Terms & Conditions", fontWeight = FontWeight.Bold, color = TextLight) },
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
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            item {
                Text("1. Eligibility & Accounts", style = MaterialTheme.typography.titleMedium, color = GoldPrimary, fontWeight = FontWeight.Bold)
                Text("Quizzy2Earn is open to all trivia enthusiasts worldwide. Only one registered account per physical user and per device is permitted.", color = TextMuted, fontSize = 13.sp)
            }
            item {
                Text("2. Fair Play & Security Rules", style = MaterialTheme.typography.titleMedium, color = GoldPrimary, fontWeight = FontWeight.Bold)
                Text("Automated answering bots, proxy connections, emulator scripts, or fraudulent survey responses are strictly prohibited and will lead to permanent wallet confiscation.", color = TextMuted, fontSize = 13.sp)
            }
            item {
                Text("3. Coin Values & Payouts", style = MaterialTheme.typography.titleMedium, color = GoldPrimary, fontWeight = FontWeight.Bold)
                Text("Coins have no cash value until a valid payout redemption threshold is met and approved by our security verification team.", color = TextMuted, fontSize = 13.sp)
            }
        }
    }
}
