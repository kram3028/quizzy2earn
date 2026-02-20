import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quizzy2earn/core/navigation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzy2earn/screens/terms/terms_conditions_screen.dart';

import '../../widgets/bottom_banner_ad.dart';
import 'package:quizzy2earn/core/app_theme.dart';
import 'package:quizzy2earn/core/app_router.dart';

class RedeemScreen extends StatefulWidget {
  final int coins;
  final bool hasPendingWithdraw;
  final String currentTermsVersion;
  final Function(VoidCallback) onShowAdThen;
  final Function(
      double amount,
      String payoutMethod,
      String payoutDetail,
      ) onWithdraw;

  const RedeemScreen({
    super.key,
    required this.coins,
    required this.hasPendingWithdraw,
    required this.currentTermsVersion,
    required this.onWithdraw,
    required this.onShowAdThen,
  });

  @override
  State<RedeemScreen> createState() => _RedeemScreenState();
}

class _RedeemScreenState extends State<RedeemScreen> {
  final TextEditingController upiIdController = TextEditingController();
  final TextEditingController giftCardEmailController = TextEditingController();
  final TextEditingController withdrawCoinsController = TextEditingController();
  static const double minWithdrawAmount = 4000;

  // 🟢 STEP 1: STATE VARIABLES
  String selectedPayoutCategory = 'UPI'; // UPI | GiftCard
  String selectedUpiMethod = 'GPay';
  String selectedGiftCard = 'Amazon';
  bool agreedToTerms = false;

  @override
  void initState() {
    super.initState();
    _showTermsIfFirstTime();
    withdrawCoinsController.addListener(() {
      setState(() {}); // rebuild to update red border + button state
    });
  }

  Future<void> _showTermsIfFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyShown = prefs.getBool('termsShown') ?? false;

    if (!alreadyShown) {
      await prefs.setBool('termsShown', true);

      if (!mounted) return;

      Future.microtask(() {
        NavigationService.pushNamed(
          AppRouter.terms,
          args: {
            'forceAgree': false,
            'currentTermsVersion': widget.currentTermsVersion,
          },
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double coinToRupeeRate = 0.8; // internal only (hidden)
    final double rewardAmount = widget.coins * coinToRupeeRate;
    final enteredAmount =
        double.tryParse(withdrawCoinsController.text.trim()) ?? 0;

    final bool isAmountValid = enteredAmount >= minWithdrawAmount;

    Widget glassCard({required Widget child}) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: child,
      );
    }

    InputDecoration inputDecoration(String hint) {
      return InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      );
    }

    return Scaffold(
      bottomNavigationBar: const BottomBannerAd(),
      backgroundColor: Colors.deepPurple,
      appBar: AppBar(
        title: const Text(
          'Quizzy2Earn',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.deepPurple,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.deepPurple, // 👈 fixes black top
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity, // 🔥 THIS FIXES EVERYTHING
        decoration: const BoxDecoration(
          gradient: appBackgroundGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // 🔹 Reward Info
                glassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Estimated Reward',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '₹ ${rewardAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),

                // 🔹 Amount
                glassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Enter withdrawal amount (₹)',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: withdrawCoinsController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Minimum ₹4000',
                          prefixText: '₹ ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isAmountValid ? Colors.grey : Colors.red,
                              width: 2,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isAmountValid ? Colors.grey : Colors.red,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      if (!isAmountValid && withdrawCoinsController.text.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            'Minimum withdraw amount is ₹4000',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),

                const Text(
                  'Choose Payout Method',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const SizedBox(height: 12),

                // 🔹 Radio buttons
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        value: 'UPI',
                        groupValue: selectedPayoutCategory,
                        activeColor: Colors.white,
                        title: const Text('UPI',
                            style: TextStyle(color: Colors.white)),
                        onChanged: (v) =>
                            setState(() => selectedPayoutCategory = v!),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        value: 'GiftCard',
                        groupValue: selectedPayoutCategory,
                        activeColor: Colors.white,
                        title: const Text('Gift Card',
                            style: TextStyle(color: Colors.white)),
                        onChanged: (v) =>
                            setState(() => selectedPayoutCategory = v!),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                if (selectedPayoutCategory == 'UPI')
                  glassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('UPI Method',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: selectedUpiMethod,
                          dropdownColor: Colors.deepPurple,
                          decoration: inputDecoration('Select UPI'),
                          items: const [
                            DropdownMenuItem(
                                value: 'GPay', child: Text('GPay')),
                            DropdownMenuItem(
                                value: 'PhonePe', child: Text('PhonePe')),
                            DropdownMenuItem(
                                value: 'Paytm', child: Text('Paytm')),
                            DropdownMenuItem(
                                value: 'Direct Bank UPI',
                                child: Text('Direct Bank UPI')),
                          ],
                          onChanged: (v) =>
                              setState(() => selectedUpiMethod = v!),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: upiIdController,
                          style: const TextStyle(color: Colors.white),
                          decoration: inputDecoration('Enter UPI ID'),
                        ),
                      ],
                    ),
                  ),

                if (selectedPayoutCategory == 'GiftCard')
                  glassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Gift Card Brand',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: selectedGiftCard,
                          dropdownColor: Colors.deepPurple,
                          decoration: inputDecoration('Select Brand'),
                          items: const [
                            DropdownMenuItem(
                                value: 'Amazon', child: Text('Amazon')),
                            DropdownMenuItem(
                                value: 'Flipkart', child: Text('Flipkart')),
                            DropdownMenuItem(
                                value: 'Myntra', child: Text('Myntra')),
                            DropdownMenuItem(
                                value: 'Croma', child: Text('Croma')),
                          ],
                          onChanged: (v) =>
                              setState(() => selectedGiftCard = v!),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: giftCardEmailController,
                          style: const TextStyle(color: Colors.white),
                          decoration: inputDecoration('Enter Email'),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 6),

                // Terms
                Row(
                  children: [
                    Checkbox(
                      value: agreedToTerms,
                      activeColor: Colors.white,
                      checkColor: Colors.deepPurple,
                      onChanged: (v) =>
                          setState(() => agreedToTerms = v!),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TermsConditionsScreen(
                                currentTermsVersion:
                                widget.currentTermsVersion,
                              ),
                            ),
                          );
                        },
                        child: const Text(
                          'I agree to Terms & Conditions',
                          style: TextStyle(
                            color: Colors.white,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: widget.hasPendingWithdraw ||
                        !agreedToTerms ||
                        !isAmountValid
                        ? null
                        : () {

                      widget.onShowAdThen(() async {

                        final enteredAmount =
                        double.tryParse(withdrawCoinsController.text.trim());

                        if (enteredAmount == null ||
                            enteredAmount < minWithdrawAmount) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Enter valid amount')),
                          );
                          return;
                        }

                        String payoutMethod;
                        String payoutDetail;

                        if (selectedPayoutCategory == 'UPI') {
                          if (upiIdController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Enter UPI ID')),
                            );
                            return;
                          }
                          payoutMethod = 'UPI';
                          payoutDetail = upiIdController.text.trim();
                        } else {
                          if (giftCardEmailController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Enter Email ID')),
                            );
                            return;
                          }
                          payoutMethod = 'GiftCard';
                          payoutDetail = giftCardEmailController.text.trim();
                        }

                        // ✅ SAVE TERMS AGREEMENT
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .update({
                            'agreedToTerms': true,
                            'agreedTermsVersion': widget.currentTermsVersion,
                            'termsAgreedAt': FieldValue.serverTimestamp(),
                          });
                        }

                        NavigationService.goBack();

                        widget.onWithdraw(
                          enteredAmount,
                          payoutMethod,
                          payoutDetail,
                        );
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.deepPurple,
                      disabledBackgroundColor: Colors.white, // 🔥 when button is disabled
                      disabledForegroundColor: Colors.grey,  // text when disabled
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      widget.hasPendingWithdraw
                          ? 'Withdrawal Pending'
                          : 'Withdraw',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),

                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}