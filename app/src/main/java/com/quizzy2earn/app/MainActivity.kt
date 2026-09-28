package com.quizzy2earn.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.quizzy2earn.app.ui.screens.*
import com.quizzy2earn.app.ui.theme.CardNavy
import com.quizzy2earn.app.ui.theme.DarkNavy
import com.quizzy2earn.app.ui.theme.GoldPrimary
import com.quizzy2earn.app.ui.theme.Quizzy2EarnTheme
import com.quizzy2earn.app.ui.theme.TextLight
import com.quizzy2earn.app.ui.theme.TextMuted
import com.quizzy2earn.app.ui.viewmodel.AppScreen
import com.quizzy2earn.app.ui.viewmodel.MainViewModel

class MainActivity : ComponentActivity() {

    private val viewModel: MainViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        setContent {
            Quizzy2EarnTheme {
                MainAppScaffold(viewModel = viewModel)
            }
        }
    }
}

data class BottomNavItem(
    val title: String,
    val screen: AppScreen,
    val icon: ImageVector,
    val tag: String
)

@Composable
fun MainAppScaffold(viewModel: MainViewModel) {
    val currentScreen by viewModel.currentScreen.collectAsState()

    val bottomNavItems = listOf(
        BottomNavItem("Home", AppScreen.Home, Icons.Default.Home, "nav_home"),
        BottomNavItem("Surveys", AppScreen.Surveys, Icons.Default.Poll, "nav_surveys"),
        BottomNavItem("Bonus", AppScreen.BonusCenter, Icons.Default.CardGiftcard, "nav_bonus"),
        BottomNavItem("Wallet", AppScreen.Wallet, Icons.Default.AccountBalanceWallet, "nav_wallet"),
        BottomNavItem("Profile", AppScreen.Profile, Icons.Default.Person, "nav_profile")
    )

    val isTopLevelScreen = currentScreen in listOf(
        AppScreen.Home,
        AppScreen.Surveys,
        AppScreen.BonusCenter,
        AppScreen.Wallet,
        AppScreen.Profile
    )

    BackHandler(enabled = !isTopLevelScreen) {
        viewModel.navigateBack()
    }

    Scaffold(
        containerColor = DarkNavy,
        bottomBar = {
            if (isTopLevelScreen) {
                NavigationBar(
                    containerColor = CardNavy,
                    contentColor = TextLight,
                    tonalElevation = 8.dp
                ) {
                    bottomNavItems.forEach { item ->
                        val isSelected = (currentScreen == item.screen)
                        NavigationBarItem(
                            selected = isSelected,
                            onClick = {
                                if (currentScreen != item.screen) {
                                    viewModel.navigateTo(item.screen)
                                }
                            },
                            icon = {
                                Icon(
                                    imageVector = item.icon,
                                    contentDescription = item.title,
                                    tint = if (isSelected) GoldPrimary else TextMuted
                                )
                            },
                            label = {
                                Text(
                                    text = item.title,
                                    color = if (isSelected) GoldPrimary else TextMuted
                                )
                            },
                            colors = NavigationBarItemDefaults.colors(
                                indicatorColor = DarkNavy
                            ),
                            modifier = Modifier.testTag(item.tag)
                        )
                    }
                }
            }
        }
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(bottom = if (isTopLevelScreen) innerPadding.calculateBottomPadding() else 0.dp)
        ) {
            when (val screen = currentScreen) {
                is AppScreen.Home -> HomeScreen(viewModel = viewModel)
                is AppScreen.Surveys -> SurveysScreen(viewModel = viewModel)
                is AppScreen.BonusCenter -> BonusCenterScreen(viewModel = viewModel)
                is AppScreen.Wallet -> WalletScreen(viewModel = viewModel)
                is AppScreen.Profile -> ProfileScreen(viewModel = viewModel)
                is AppScreen.CategoryLevels -> CategoryLevelsScreen(category = screen.category, viewModel = viewModel)
                is AppScreen.ActiveQuiz -> ActiveQuizPlayScreen(category = screen.category, level = screen.level, viewModel = viewModel)
                is AppScreen.DailySpin -> DailySpinScreen(viewModel = viewModel)
                is AppScreen.Redeem -> RedeemScreen(method = screen.method, viewModel = viewModel)
                is AppScreen.WithdrawHistory -> WithdrawHistoryScreen(viewModel = viewModel)
                is AppScreen.InviteEarn -> InviteEarnScreen(viewModel = viewModel)
                is AppScreen.Faq -> FaqScreen(viewModel = viewModel)
                is AppScreen.Support -> SupportScreen(viewModel = viewModel)
                is AppScreen.Terms -> TermsScreen(viewModel = viewModel)
            }
        }
    }
}
