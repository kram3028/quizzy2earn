# Quizzy2Earn - Native Android App

A native Android trivia and rewards application built with **Kotlin** and **Jetpack Compose** following Material Design 3 guidelines.

## Features
- **Quiz Arenas**: 5 distinct trivia categories (General Knowledge, Science & Tech, History & Geography, Pop Culture, Sports) featuring 10 progressive difficulty levels, timer-based questions, 50:50 lifelines, and instant scoring feedback.
- **Daily Fortune Wheel**: Interactive physics-based animated Canvas wheel with customizable slice rewards and up to 500 Coins jackpot.
- **Bonus Center**: 7-day streak check-in bonus system and instant coin verification challenges (Math Captcha, Tap Speed, Precision Slider).
- **Survey Offerwalls**: High-paying integrated survey studies from partners (BitLabs, CPX Research, TheoremReach) with real-time coin reward crediting.
- **Wallet & Payouts**: Real-time coin-to-cash conversion ledger ($1.00 USD per 1,000 Coins) supporting multiple redemption channels (PayPal, UPI, Paytm, Amazon Gift Cards, Google Play, USDT Crypto).
- **Referral Program**: Unique user referral code generator, clipboard copying, Android share sheet intent, and tiered milestone earnings.
- **Account & Support**: FAQ accordion, ticket submission form, terms and fair play anti-fraud policies.

## Architecture
- **Language**: Kotlin 2.1.0
- **UI Framework**: Jetpack Compose with Material 3 (M3)
- **Architecture**: MVVM with unidirectional data flow (StateFlow / Coroutines)
- **Build System**: Gradle Kotlin DSL (`settings.gradle.kts`, `build.gradle.kts`, `gradle/libs.versions.toml`)
- **Compatibility**: Android 7.0+ (API 24 to API 35)
