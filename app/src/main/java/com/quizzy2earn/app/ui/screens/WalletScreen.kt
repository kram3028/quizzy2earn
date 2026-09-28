package com.quizzy2earn.app.ui.screens

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.quizzy2earn.app.data.model.*
import com.quizzy2earn.app.ui.theme.*
import com.quizzy2earn.app.ui.viewmodel.AppScreen
import com.quizzy2earn.app.ui.viewmodel.MainViewModel

@Composable
fun WalletScreen(viewModel: MainViewModel) {
    val coins by viewModel.coins.collectAsState()
    val transactions by viewModel.transactions.collectAsState()
    val withdrawals by viewModel.withdrawals.collectAsState()

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
                text = "Wallet & Rewards",
                style = MaterialTheme.typography.headlineMedium,
                color = GoldPrimary,
                fontWeight = FontWeight.ExtraBold
            )
            Text(
                text = "Convert your quiz coins into real cash or gift card payouts.",
                style = MaterialTheme.typography.bodyMedium,
                color = TextMuted
            )
        }

        // Balance Overview Card
        item {
            Card(
                shape = RoundedCornerShape(20.dp),
                colors = CardDefaults.cardColors(containerColor = SurfaceNavy),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(
                    modifier = Modifier.padding(20.dp),
                    verticalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    Text(text = "Available Balance", color = TextMuted, fontSize = 14.sp)
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            Icon(
                                Icons.Default.MonetizationOn,
                                contentDescription = "Coins",
                                tint = GoldPrimary,
                                modifier = Modifier.size(32.dp)
                            )
                            Text(
                                text = "$coins",
                                style = MaterialTheme.typography.headlineLarge,
                                color = TextLight,
                                fontWeight = FontWeight.Black
                            )
                        }

                        Surface(
                            shape = RoundedCornerShape(12.dp),
                            color = AccentGreen.copy(alpha = 0.2f)
                        ) {
                            Text(
                                text = "≈ $${String.format("%.2f", coins / 1000.0)} USD",
                                color = AccentGreen,
                                fontWeight = FontWeight.Bold,
                                fontSize = 15.sp,
                                modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp)
                            )
                        }
                    }

                    Divider(color = Color.White.copy(alpha = 0.1f))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(
                            text = "Conversion Rate:",
                            color = TextMuted,
                            fontSize = 13.sp
                        )
                        Text(
                            text = "1,000 Coins = $1.00 USD",
                            color = GoldPrimary,
                            fontWeight = FontWeight.Bold,
                            fontSize = 13.sp
                        )
                    }

                    if (withdrawals.isNotEmpty()) {
                        OutlinedButton(
                            onClick = { viewModel.navigateTo(AppScreen.WithdrawHistory) },
                            shape = RoundedCornerShape(12.dp),
                            modifier = Modifier
                                .fillMaxWidth()
                                .testTag("view_withdraw_history_button")
                        ) {
                            Icon(Icons.Default.History, contentDescription = "History", modifier = Modifier.size(18.dp))
                            Spacer(modifier = Modifier.width(8.dp))
                            Text("Withdrawal Requests (${withdrawals.size})", color = TextLight)
                        }
                    }
                }
            }
        }

        // Payout Methods Header
        item {
            Text(
                text = "Redeem Payouts",
                style = MaterialTheme.typography.titleLarge,
                color = TextLight,
                fontWeight = FontWeight.Bold
            )
        }

        // Payout Options
        items(PaymentMethod.values()) { method ->
            PaymentMethodCard(
                method = method,
                userCoins = coins,
                onClick = { viewModel.navigateTo(AppScreen.Redeem(method)) }
            )
        }

        // Transaction History Header
        item {
            Text(
                text = "Recent Transactions",
                style = MaterialTheme.typography.titleLarge,
                color = TextLight,
                fontWeight = FontWeight.Bold
            )
        }

        if (transactions.isEmpty()) {
            item {
                Text(
                    text = "No transactions yet. Complete quizzes to earn coins!",
                    color = TextMuted,
                    fontSize = 14.sp
                )
            }
        } else {
            items(transactions.take(10)) { tx ->
                TransactionRowItem(transaction = tx)
            }
        }
    }
}

@Composable
fun PaymentMethodCard(
    method: PaymentMethod,
    userCoins: Int,
    onClick: () -> Unit
) {
    val canRedeem = userCoins >= method.minCoins
    val icon = when (method) {
        PaymentMethod.PAYPAL -> Icons.Default.AccountBalanceWallet
        PaymentMethod.UPI, PaymentMethod.PAYTM -> Icons.Default.QrCode
        PaymentMethod.AMAZON, PaymentMethod.GOOGLE_PLAY -> Icons.Default.CardGiftcard
        PaymentMethod.CRYPTO_USDT -> Icons.Default.CurrencyBitcoin
    }

    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = CardNavy),
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .testTag("payout_method_${method.name}")
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(46.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(SurfaceNavy),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = method.displayName,
                    tint = GoldPrimary,
                    modifier = Modifier.size(24.dp)
                )
            }

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = method.displayName,
                    style = MaterialTheme.typography.titleMedium,
                    color = TextLight,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = "Min: ${method.minCoins} Coins ($${String.format("%.2f", method.rateUsd)})",
                    style = MaterialTheme.typography.bodyMedium,
                    color = TextMuted
                )
            }

            Button(
                onClick = onClick,
                shape = RoundedCornerShape(10.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = if (canRedeem) GoldPrimary else SurfaceNavy,
                    contentColor = if (canRedeem) DarkNavy else TextMuted
                ),
                contentPadding = PaddingValues(horizontal = 14.dp, vertical = 6.dp)
            ) {
                Text(
                    text = "Redeem",
                    fontWeight = FontWeight.Bold,
                    fontSize = 13.sp
                )
            }
        }
    }
}

@Composable
fun TransactionRowItem(transaction: WalletTransaction) {
    Card(
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = CardNavy),
        modifier = Modifier.fillMaxWidth()
    ) {
        Row(
            modifier = Modifier.padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            val isCredit = transaction.amount > 0
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(CircleShape)
                    .background(if (isCredit) AccentGreen.copy(alpha = 0.2f) else AccentRed.copy(alpha = 0.2f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = if (isCredit) Icons.Default.Add else Icons.Default.Remove,
                    contentDescription = "Tx",
                    tint = if (isCredit) AccentGreen else AccentRed,
                    modifier = Modifier.size(18.dp)
                )
            }

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = transaction.title,
                    style = MaterialTheme.typography.bodyLarge,
                    color = TextLight,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1
                )
                Text(
                    text = transaction.type.name.replace("_", " "),
                    fontSize = 11.sp,
                    color = TextMuted
                )
            }

            Text(
                text = "${if (isCredit) "+" else ""}${transaction.amount}",
                fontWeight = FontWeight.Bold,
                fontSize = 15.sp,
                color = if (isCredit) AccentGreen else AccentRed
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RedeemScreen(
    method: PaymentMethod,
    viewModel: MainViewModel
) {
    BackHandler {
        viewModel.navigateBack()
    }

    val userCoins by viewModel.coins.collectAsState()
    var selectedCoinsAmount by remember { mutableIntStateOf(method.minCoins) }
    var accountInput by remember { mutableStateOf("") }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var isSubmittedSuccess by remember { mutableStateOf(false) }

    val usdValue = (selectedCoinsAmount.toDouble() / 1000.0)

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text("Redeem ${method.displayName}", fontWeight = FontWeight.Bold, color = TextLight)
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
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Summary Card
            Card(
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = SurfaceNavy),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Text("Selected Method", color = TextMuted, fontSize = 13.sp)
                    Text(method.displayName, style = MaterialTheme.typography.titleLarge, color = TextLight, fontWeight = FontWeight.Bold)
                    Divider(color = Color.White.copy(alpha = 0.1f))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text("Payout Value:", color = TextMuted)
                        Text("$${String.format("%.2f", usdValue)} USD", color = GoldPrimary, fontWeight = FontWeight.Bold)
                    }
                }
            }

            // Coin Options Tier Selection
            Text("Select Redemption Amount", style = MaterialTheme.typography.titleMedium, color = TextLight, fontWeight = FontWeight.Bold)
            val coinTiers = listOf(method.minCoins, method.minCoins * 2, method.minCoins * 5)
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                coinTiers.forEach { tier ->
                    val isSelected = selectedCoinsAmount == tier
                    Surface(
                        shape = RoundedCornerShape(12.dp),
                        color = if (isSelected) GoldPrimary else CardNavy,
                        modifier = Modifier
                            .weight(1f)
                            .clickable { selectedCoinsAmount = tier }
                    ) {
                        Column(
                            modifier = Modifier.padding(12.dp),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Text(
                                text = "$tier",
                                fontWeight = FontWeight.Bold,
                                color = if (isSelected) DarkNavy else TextLight,
                                fontSize = 15.sp
                            )
                            Text(
                                text = "$${String.format("%.2f", tier / 1000.0)}",
                                color = if (isSelected) DarkNavy else TextMuted,
                                fontSize = 12.sp
                            )
                        }
                    }
                }
            }

            // Account Details Input
            val labelText = when (method) {
                PaymentMethod.PAYPAL -> "PayPal Email Address"
                PaymentMethod.UPI -> "UPI ID (e.g. user@okhdfcbank)"
                PaymentMethod.PAYTM -> "Paytm Registered Mobile Number"
                PaymentMethod.AMAZON -> "Amazon Account Email"
                PaymentMethod.GOOGLE_PLAY -> "Google Play Email Address"
                PaymentMethod.CRYPTO_USDT -> "USDT Wallet Address (TRC-20)"
            }

            OutlinedTextField(
                value = accountInput,
                onValueChange = {
                    accountInput = it
                    errorMessage = null
                },
                label = { Text(labelText) },
                singleLine = true,
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = GoldPrimary,
                    unfocusedBorderColor = CardNavy,
                    focusedTextColor = TextLight,
                    unfocusedTextColor = TextLight
                ),
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("redeem_account_input")
            )

            errorMessage?.let { msg ->
                Text(text = msg, color = AccentRed, fontSize = 13.sp)
            }

            if (isSubmittedSuccess) {
                Surface(
                    shape = RoundedCornerShape(12.dp),
                    color = AccentGreen.copy(alpha = 0.2f),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text(
                        text = "Withdrawal request submitted successfully! Processing time: 24-48 hours.",
                        color = AccentGreen,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(14.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.weight(1f))

            Button(
                onClick = {
                    if (accountInput.isBlank()) {
                        errorMessage = "Please enter your destination account detail."
                        return@Button
                    }
                    if (userCoins < selectedCoinsAmount) {
                        errorMessage = "Insufficient coin balance. You need $selectedCoinsAmount coins."
                        return@Button
                    }
                    val ok = viewModel.submitWithdrawal(method, accountInput.trim(), selectedCoinsAmount)
                    if (ok) {
                        isSubmittedSuccess = true
                        accountInput = ""
                    }
                },
                colors = ButtonDefaults.buttonColors(containerColor = GoldPrimary),
                shape = RoundedCornerShape(14.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp)
                    .testTag("submit_redeem_button")
            ) {
                Text("Confirm Payout Request", color = DarkNavy, fontWeight = FontWeight.Bold, fontSize = 16.sp)
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WithdrawHistoryScreen(viewModel: MainViewModel) {
    BackHandler {
        viewModel.navigateBack()
    }

    val withdrawals by viewModel.withdrawals.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Withdrawal History", fontWeight = FontWeight.Bold, color = TextLight) },
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
        if (withdrawals.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding),
                contentAlignment = Alignment.Center
            ) {
                Text("No withdrawal requests yet.", color = TextMuted)
            }
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                items(withdrawals) { req ->
                    Card(
                        shape = RoundedCornerShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = CardNavy),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Column(
                            modifier = Modifier.padding(16.dp),
                            verticalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    text = req.paymentMethod.displayName,
                                    fontWeight = FontWeight.Bold,
                                    color = TextLight,
                                    fontSize = 16.sp
                                )
                                Surface(
                                    shape = RoundedCornerShape(8.dp),
                                    color = when (req.status) {
                                        WithdrawalStatus.PENDING -> Color(0xFFF59E0B).copy(alpha = 0.2f)
                                        WithdrawalStatus.COMPLETED -> AccentGreen.copy(alpha = 0.2f)
                                        else -> AccentRed.copy(alpha = 0.2f)
                                    }
                                ) {
                                    Text(
                                        text = req.status.name,
                                        color = when (req.status) {
                                            WithdrawalStatus.PENDING -> Color(0xFFF59E0B)
                                            WithdrawalStatus.COMPLETED -> AccentGreen
                                            else -> AccentRed
                                        },
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 11.sp,
                                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                                    )
                                }
                            }

                            Text(
                                text = "Account: ${req.accountDetail}",
                                color = TextMuted,
                                fontSize = 13.sp
                            )

                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Text(
                                    text = "ID: ${req.id}",
                                    color = TextMuted,
                                    fontSize = 12.sp
                                )
                                Text(
                                    text = "$${String.format("%.2f", req.payoutAmountUsd)} (${req.coinsDebited} Coins)",
                                    fontWeight = FontWeight.Bold,
                                    color = GoldPrimary,
                                    fontSize = 14.sp
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
