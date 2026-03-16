import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {

  final TextEditingController messageController = TextEditingController();
  final TextEditingController transactionController = TextEditingController();

  String category = "Withdrawal Problem";

  bool loading = false;

  final List<String> categories = [
    "Withdrawal Problem",
    "Missing Coins",
    "Survey / Offerwall Issue",
    "Account Problem",
    "App Bug",
    "Other"
  ];

  Future<void> submitTicket() async {

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please describe your issue")),
      );
      return;
    }

    setState(() {
      loading = true;
    });

    final ticketRef =
    FirebaseFirestore.instance.collection('support_tickets').doc();

    final ticketId = "SUP-${DateTime.now().millisecondsSinceEpoch}";

    await ticketRef.set({
      "ticketId": ticketId,
      "userId": user.uid,
      "email": user.email,
      "category": category,
      "transactionId": transactionController.text.trim(),
      "message": messageController.text.trim(),
      "status": "open",
      "createdAt": FieldValue.serverTimestamp(),
    });

    setState(() {
      loading = false;
    });

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Support Ticket Created"),
        content: Text(
            "Your support request has been submitted.\n\nTicket ID: $ticketId"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Support"),
        backgroundColor: Colors.deepPurple,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Text(
              "Contact Support",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            /// EMAIL
            TextFormField(
              initialValue: user?.email ?? "",
              readOnly: true,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            /// CATEGORY
            DropdownButtonFormField<String>(
              value: category,
              decoration: const InputDecoration(
                labelText: "Issue Category",
                border: OutlineInputBorder(),
              ),
              items: categories.map((c) {
                return DropdownMenuItem(
                  value: c,
                  child: Text(c),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    category = value;
                  });
                }
              },
            ),

            const SizedBox(height: 16),

            /// TRANSACTION ID
            TextField(
              controller: transactionController,
              decoration: const InputDecoration(
                labelText: "Transaction ID (Optional)",
                border: OutlineInputBorder(),
                hintText: "Example: TX260309-00012",
              ),
            ),

            const SizedBox(height: 16),

            /// MESSAGE
            TextField(
              controller: messageController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: "Describe your issue",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),

            /// SUBMIT BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : submitTicket,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.deepPurple,
                ),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  "Submit Support Request",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              "Our support team usually responds within 24-48 hours.",
              style: TextStyle(color: Colors.black54),
            )
          ],
        ),
      ),
    );
  }
}