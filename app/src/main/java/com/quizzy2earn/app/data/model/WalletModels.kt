package com.quizzy2earn.app.data.model

enum class TransactionType {
    QUIZ_WIN,
    DAILY_SPIN,
    DAILY_CHECKIN,
    CAPTCHA_BONUS,
    SURVEY_REWARD,
    REFERRAL_BONUS,
    WITHDRAWAL
}

data class WalletTransaction(
    val id: String,
    val type: TransactionType,
    val title: String,
    val amount: Int, // positive for credits, negative for debits
    val timestamp: Long = System.currentTimeMillis()
)

enum class WithdrawalStatus {
    PENDING,
    APPROVED,
    COMPLETED,
    REJECTED
}

enum class PaymentMethod(val displayName: String, val minCoins: Int, val rateUsd: Double) {
    PAYPAL("PayPal", 1000, 1.00),
    UPI("UPI Transfer", 500, 0.50),
    PAYTM("Paytm Wallet", 500, 0.50),
    AMAZON("Amazon Gift Card", 2000, 2.00),
    GOOGLE_PLAY("Google Play Code", 2500, 2.50),
    CRYPTO_USDT("Crypto USDT (TRC-20)", 5000, 5.00)
}

data class WithdrawalRequest(
    val id: String,
    val paymentMethod: PaymentMethod,
    val accountDetail: String, // email, UPI id, or wallet address
    val coinsDebited: Int,
    val payoutAmountUsd: Double,
    val status: WithdrawalStatus,
    val requestTime: Long = System.currentTimeMillis()
)
