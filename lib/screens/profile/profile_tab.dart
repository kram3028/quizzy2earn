import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizzy2earn/core/app_router.dart';
import 'package:quizzy2earn/core/navigation_service.dart';

class ProfileTab extends StatefulWidget {
  final Function(VoidCallback) onSaveWithAd;

  const ProfileTab({
    super.key,
    required this.onSaveWithAd,
  });

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  bool emailVerified = false;
  bool emailEditable = true;

  String email = '';
  String dob = '';
  String gender = '';

  final TextEditingController dobController = TextEditingController();
  String selectedGender = 'Male';

  @override
  void initState() {
    super.initState();
    loadUserProfile();
  }

  Future<void> loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        nameController.text = data['name'] ?? '';
        emailController.text = data['email'] ?? '';
        emailVerified = data['emailVerified'] ?? false;
        emailEditable = data['emailEditable'] ?? true;
        phoneController.text = data['phone'] ?? '';
        dob = data['dob'] ?? '';
        gender = data['gender'] ?? 'Male';

        dobController.text = dob;
        selectedGender = gender;
      });
      // ✅ CHECK IF USER VERIFIED FROM EMAIL LINK
      await user.reload();

      if (user.emailVerified && !emailVerified) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'emailVerified': true,
          'emailEditable': false,
          'emailVerifiedAt': FieldValue.serverTimestamp(),
        });

        setState(() {
          emailVerified = true;
          emailEditable = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget cardInput({required Widget child}) {
      return Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.deepPurple.shade50,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurple.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: child,
      );
    }

    InputDecoration inputStyle(String label, IconData icon) {
      return InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.deepPurple),
        border: InputBorder.none,
      );
    }

    return SafeArea(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [

            /// 🔝 Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.logout, color: Colors.deepPurple),
                      onPressed: logoutUser,
                    ),
                  ),
                  const Text(
                    'My Profile',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                ],
              ),
            ),

            /// 🔽 Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [

                    /// Avatar
                    Container(
                      height: 110,
                      width: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Colors.deepPurple.shade200,
                            Colors.deepPurple.shade400,
                          ],
                        ),
                      ),
                      child: const Icon(Icons.person, size: 60, color: Colors.white),
                    ),

                    const SizedBox(height: 16),

                    /// Email
                    cardInput(
                      child: TextField(
                        controller: emailController,
                        readOnly: !emailEditable,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Email ID',
                          prefixIcon: const Icon(Icons.email, color: Colors.deepPurple),
                          border: InputBorder.none,
                          suffixIcon: emailVerified
                              ? const Icon(Icons.verified, color: Colors.green)
                              : const Icon(Icons.warning, color: Colors.orange),
                        ),
                      ),
                    ),

                    if (!emailVerified)
                      TextButton(
                        onPressed: () async {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            await user.sendEmailVerification();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Verification link sent to your email'),
                              ),
                            );
                          }
                        },
                        child: const Text(
                          'Send Verification Link',
                          style: TextStyle(
                            color: Colors.orange,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),

                    const SizedBox(height: 10),

                    /// Inputs
                    cardInput(
                      child: TextField(
                        controller: nameController,
                        decoration: inputStyle('Full Name', Icons.person),
                      ),
                    ),

                    cardInput(
                      child: TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: inputStyle('Phone Number', Icons.phone),
                      ),
                    ),

                    cardInput(
                      child: TextField(
                        controller: dobController,
                        readOnly: true,
                        decoration: inputStyle('Date of Birth', Icons.calendar_today),
                        onTap: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime(2000),
                            firstDate: DateTime(1920),
                            lastDate: DateTime.now(),
                          );

                          if (pickedDate != null) {
                            dobController.text =
                            '${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}';
                          }
                        },
                      ),
                    ),

                    cardInput(
                      child: DropdownButtonFormField<String>(
                        value: selectedGender,
                        items: const [
                          DropdownMenuItem(value: 'Male', child: Text('Male')),
                          DropdownMenuItem(value: 'Female', child: Text('Female')),
                          DropdownMenuItem(value: 'Other', child: Text('Other')),
                        ],
                        onChanged: (value) {
                          setState(() => selectedGender = value!);
                        },
                        decoration: inputStyle('Gender', Icons.people),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            /// 💾 Fixed Save Button (never hides under banner)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (!emailVerified) {
                      showDialog(
                        context: context,
                        builder: (_) => const AlertDialog(
                          title: Text('Verify Email Required'),
                          content: Text(
                            'Please verify your email before saving profile.',
                          ),
                        ),
                      );
                      return;
                    }

                    widget.onSaveWithAd(() {
                      saveProfile();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'Save Profile',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget profileItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 16),
      ),
    );
  }

  Future<void> saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({
      'name': nameController.text.trim(),
      'phone': phoneController.text.trim(),
      'dob': dobController.text.trim(),
      'gender': selectedGender,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated')),
    );
  }

  Future<void> logoutUser() async {
    await FirebaseAuth.instance.signOut();

    NavigationService.pushAndRemoveAll(AppRouter.welcome);
  }
}