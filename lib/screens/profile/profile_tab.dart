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
  final TextEditingController dobController = TextEditingController();

  final FocusNode nameFocus = FocusNode();
  final FocusNode phoneFocus = FocusNode();

  bool emailVerified = false;
  bool emailEditable = true;
  int resendSeconds = 0;
  bool isSending = false;
  bool autoCheckStarted = false;

  String email = '';
  String dob = '';
  String gender = '';
  String selectedGender = 'Male';

  int coinsAvailable = 0;
  int streak = 0;
  int activeDays = 0;

  String? validateProfile() {
    if (nameController.text.trim().isEmpty) {
      return "Please enter your name";
    }

    if (phoneController.text.trim().isEmpty) {
      return "Please enter phone number";
    }

    if (phoneController.text.trim().length < 10) {
      return "Enter valid phone number";
    }

    if (dobController.text.trim().isEmpty) {
      return "Please select date of birth";
    }

    if (selectedGender.isEmpty) {
      return "Please select gender";
    }

    if (!emailVerified) {
      return "Please verify your email first";
    }

    return null; // ✅ valid
  }

  @override
  void initState() {
    super.initState();
    nameFocus.addListener(() {
      if (mounted) setState(() {});
    });
    phoneFocus.addListener(() {
      if (mounted) setState(() {});
    });
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

        // Fetch stats
        coinsAvailable = (data['coinsAvailable'] as num?)?.toInt() ?? 0;
        activeDays = (data['activeDays'] as num?)?.toInt() ?? 0;
        final daily = data['dailyLogin'] as Map<String, dynamic>?;
        streak = (daily?['streak'] as num?)?.toInt() ?? 0;
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
    if (!emailVerified && !autoCheckStarted) {
      autoCheckStarted = true;
      startAutoCheck();
    }
  }

  void startCooldown() {
    resendSeconds = 30;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;

      setState(() {
        resendSeconds--;
      });

      return resendSeconds > 0;
    });
  }

  void startAutoCheck() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 3));

      if (!mounted) return false;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // 🛑 STOP IF ALREADY VERIFIED (IMPORTANT)
      if (emailVerified) return false;

      await user.reload();

      if (user.emailVerified) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'emailVerified': true,
          'emailEditable': false,
          'emailVerifiedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          setState(() {
            emailVerified = true;
            emailEditable = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email verified successfully 🎉'),
              backgroundColor: Colors.green,
            ),
          );
        }

        autoCheckStarted = false; // 🔥 RESET FLAG
        return false;
      }

      return true;
    });
  }

  Future<void> _sendVerificationEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => isSending = true);
    try {
      await user.sendEmailVerification();
    } catch (e) {
      if (!mounted) return;
      setState(() => isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending email: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => isSending = false);
    startCooldown();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Verification link sent'),
        backgroundColor: Colors.green,
      ),
    );
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text("Didn't receive email?"),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("📩 Check Spam folder"),
            SizedBox(height: 6),
            Text("📥 Move email to Inbox"),
            SizedBox(height: 6),
            Text("⭐ Add us to contacts"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    resendSeconds = 0;
    nameFocus.dispose();
    phoneFocus.dispose();
    super.dispose();
  }

  String getInitials(String name) {
    if (name.trim().isEmpty) return '';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.deepPurple.shade50, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderChip(String genderVal, IconData icon) {
    final isSelected = selectedGender == genderVal;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedGender = genderVal;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    Colors.deepPurple.shade400,
                    Colors.deepPurple.shade600,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.deepPurple.shade50,
            width: 1.5,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: Colors.deepPurple.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            else
              BoxShadow(
                color: Colors.deepPurple.withOpacity(0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.deepPurple.shade400,
            ),
            const SizedBox(width: 6),
            Text(
              genderVal,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget cardInput({required Widget child, bool isFocused = false}) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: isFocused ? Colors.white : Colors.deepPurple.shade50.withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isFocused ? Colors.deepPurple.shade400 : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isFocused
                  ? Colors.deepPurple.withOpacity(0.15)
                  : Colors.deepPurple.withOpacity(0.04),
              blurRadius: isFocused ? 14 : 8,
              offset: const Offset(0, 4),
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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.deepPurple.shade50.withOpacity(0.4),
              Colors.white,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            /// 🔽 Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    /// Avatar Section
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          height: 120,
                          width: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Colors.deepPurple.shade300,
                                Colors.indigo.shade400,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.deepPurple.withOpacity(0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          height: 112,
                          width: 112,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                        Container(
                          height: 104,
                          width: 104,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Colors.deepPurple.shade400,
                                Colors.indigo.shade600,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: getInitials(nameController.text).isNotEmpty
                              ? Text(
                                  getInitials(nameController.text),
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 1,
                                  ),
                                )
                              : const Icon(Icons.person, size: 54, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      nameController.text.trim().isNotEmpty
                          ? nameController.text.trim()
                          : 'Guest User',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      emailController.text.trim().isNotEmpty
                          ? emailController.text.trim()
                          : 'No Email Provided',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 20),

                    /// Stats Dashboard Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.monetization_on,
                            iconColor: Colors.amber,
                            value: coinsAvailable.toString(),
                            label: 'Coins',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.local_fire_department,
                            iconColor: Colors.orange,
                            value: '$streak Days',
                            label: 'Streak',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.calendar_month,
                            iconColor: Colors.blue,
                            value: '$activeDays Days',
                            label: 'Active',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    /// Email field
                    cardInput(
                      child: TextField(
                        controller: emailController,
                        readOnly: !emailEditable,
                        style: const TextStyle(
                          color: Colors.black87,
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

                    /// Email Verification Alert Card
                    if (!emailVerified) ...[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 18),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.orange.shade50,
                              Colors.amber.shade50,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.orange.shade100, width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
                                const SizedBox(width: 8),
                                Text(
                                  'Email Unverified',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.orange.shade900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Verify your email to secure your account and claim daily mission rewards.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange.shade900.withOpacity(0.8),
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: (resendSeconds > 0 || isSending)
                                    ? null
                                    : _sendVerificationEmail,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange.shade800,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  resendSeconds > 0
                                      ? 'Resend in $resendSeconds s'
                                      : 'Send Verification Link',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    /// Full Name Field
                    cardInput(
                      isFocused: nameFocus.hasFocus,
                      child: TextField(
                        controller: nameController,
                        focusNode: nameFocus,
                        decoration: inputStyle('Full Name', Icons.person),
                      ),
                    ),

                    /// Phone Number Field
                    cardInput(
                      isFocused: phoneFocus.hasFocus,
                      child: TextField(
                        controller: phoneController,
                        focusNode: phoneFocus,
                        keyboardType: TextInputType.phone,
                        decoration: inputStyle('Phone Number', Icons.phone),
                      ),
                    ),

                    /// DOB Field
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

                    /// Gender Chip Selection
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 8),
                        child: Text(
                          'Gender',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple.shade800,
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(child: _buildGenderChip('Male', Icons.male)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildGenderChip('Female', Icons.female)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildGenderChip('Other', Icons.transgender)),
                      ],
                    ),

                    const SizedBox(height: 24),

                    /// Account settings section with Log Out tile
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 8),
                        child: Text(
                          'Account Actions',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple.shade800,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.deepPurple.shade50, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurple.withOpacity(0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.logout, color: Colors.red.shade600, size: 20),
                        ),
                        title: const Text(
                          'Log Out',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          'Sign out of your account securely',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
                        onTap: logoutUser,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            /// 💾 Fixed Gradient Save Button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.deepPurple,
                      Colors.indigo.shade600,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    final error = validateProfile();

                    if (error != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(error),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    widget.onSaveWithAd(() {
                      saveProfile();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
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

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    final dailyMissionRef =
        userRef.collection('missions').doc('daily');

    final weeklyMissionRef =
        userRef.collection('missions').doc('weekly');

    try {
      /// ✅ 1️⃣ Save profile
      await userRef.update({
        'name': nameController.text.trim(),
        'phone': phoneController.text.trim(),
        'dob': dobController.text.trim(),
        'gender': selectedGender,
      });

      /// 🔥 ADD THIS BLOCK HERE (EXACT PLACE)
      if (nameController.text.isNotEmpty &&
          phoneController.text.isNotEmpty &&
          dobController.text.isNotEmpty &&
          selectedGender.isNotEmpty) {
        await userRef.set({
          'profileSaved': true,
        }, SetOptions(merge: true));
      }

      /// ✅ 2️⃣ Check email verified again (important)
      await user.reload();
      final isVerified = user.emailVerified;

      /// ✅ 3️⃣ Update DAILY mission (email + profile)
      await dailyMissionRef.set({
        'profileSaved': true,
        'emailVerified': isVerified,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      /// ✅ 4️⃣ Update WEEKLY mission (retention tracking)
      await weeklyMissionRef.set({
        'daysActive': FieldValue.increment(1),
      }, SetOptions(merge: true));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> logoutUser() async {
    await FirebaseAuth.instance.signOut();

    NavigationService.pushAndRemoveAll(AppRouter.welcome);
  }
}