import 'package:flutter/material.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Wallet FAQ"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          FAQItem(
            question: "How do I withdraw my earnings?",
            answer:
            "Go to the Wallet section, enter your payment details, and submit a withdrawal request. It will be reviewed and processed monthly.",
          ),
          FAQItem(
            question: "What is the minimum withdrawal?",
            answer:
            "The minimum withdrawal amount is shown in the wallet screen and may change based on company policy.",
          ),
          FAQItem(
            question: "How long does withdrawal take?",
            answer:
            "Withdrawals are processed in the first week of each month after fraud and identity verification.",
          ),
          FAQItem(
            question: "Why is my withdrawal pending?",
            answer:
            "Requests are verified to prevent fraud. Processing time may vary depending on verification and payment partner conditions.",
          ),
          FAQItem(
            question: "Can my withdrawal be rejected?",
            answer:
            "Yes. Withdrawals may be rejected if fraud, multiple accounts, VPN usage, or policy violations are detected.",
          ),
          FAQItem(
            question: "Why did my coins decrease?",
            answer:
            "Coins may be adjusted if suspicious activity or system errors are found.",
          ),
          FAQItem(
            question: "How can I contact support?",
            answer:
            "You can contact support through the Help section or email support@quizzy2earn.com.",
          ),
        ],
      ),
    );
  }
}

class FAQItem extends StatelessWidget {
  final String question;
  final String answer;

  const FAQItem({
    super.key,
    required this.question,
    required this.answer,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(answer),
          ),
        ],
      ),
    );
  }
}