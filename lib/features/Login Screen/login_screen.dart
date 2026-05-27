import 'package:demo_p/core/constants/app_colors.dart';
import 'package:demo_p/features/Login%20Screen/consent_screen.dart';
import 'package:demo_p/features/Login%20Screen/otp_screen.dart';
import 'package:demo_p/features/Login%20Screen/permission_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String countryCode = "+91";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundright,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 40),

                      SizedBox(
                        height: 79,
                        width: 79,
                        child: Image.asset(
                          "assets/Images/logo.png",
                          fit: BoxFit.contain,
                        ),
                      ),

                      const Text(
                        "Health TG",
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        "Let's get started!",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        "Please confirm your number to continue",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0XFF707D8B),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Phone input
                      Container(
                        height: 45,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF888888)),
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: _showCountryPicker,
                              child: Row(
                                children: [
                                  Image.network(
                                    "https://flagcdn.com/w40/in.png",
                                    height: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    countryCode,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.keyboard_arrow_down,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: TextField(
                                style: TextStyle(color: Colors.white),
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  hintText: "Your Phone Number",
                                  hintStyle:
                                      TextStyle(color: Colors.white38),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF38BBE1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OtpScreen(
                                  phoneNumber: "$countryCode 1234567890",
                                ),
                              ),
                            );
                          },
                          child: const Text(
                            "Continue",
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF1E2021),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: Colors.white24,
                              thickness: 1,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              "Or Login with",
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: Colors.white24,
                              thickness: 1,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: _socialButton("assets/Images/google.svg"),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _socialButton("assets/Images/apple.svg"),
                          ),
                        ],
                      ),

                      const SizedBox(height: 50),

                      // ── Terms & Privacy text ──────────────────────────────
                      SizedBox(
                        width: 357,
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: Color(0xFF707D8B),
                              fontFamily: 'Mulish',
                              fontWeight: FontWeight.w400,
                            ),
                            children: [
                              const TextSpan(
                                text:
                                    "By clicking 'Continue' above, you acknowledge that you have read and understood, and agree to Health TG ",
                              ),

                              // Terms & Conditions → opens ConsentScreen
                              TextSpan(
                                text: "Terms & Conditions",
                                style: const TextStyle(
                                  color: Color(0xFFD0D1D1),
                                  decoration: TextDecoration.underline,
                                  fontWeight: FontWeight.w500,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PermissionScreen(),
                                      ),
                                    );
                                  },
                              ),

                              const TextSpan(text: " and "),

                              // Privacy Policy → also opens ConsentScreen
                              // (replace with a separate PrivacyPolicyScreen if needed)
                              TextSpan(
                                text: "Privacy Policy",
                                style: const TextStyle(
                                  color: Color(0xFFD0D1D1),
                                  decoration: TextDecoration.underline,
                                  fontWeight: FontWeight.w500,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const ConsentScreen(),
                                      ),
                                    );
                                  },
                              ),

                              const TextSpan(text: "."),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView(
          children: [
            ListTile(
              leading: Image.network("https://flagcdn.com/w40/in.png"),
              title: const Text("India (+91)"),
              onTap: () {
                setState(() => countryCode = "+91");
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Image.network("https://flagcdn.com/w40/us.png"),
              title: const Text("USA (+1)"),
              onTap: () {
                setState(() => countryCode = "+1");
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _socialButton(String icon) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x33DADADA)),
      ),
      child: Center(
        child: SvgPicture.asset(
          icon,
          height: 22,
        ),
      ),
    );
  }
}