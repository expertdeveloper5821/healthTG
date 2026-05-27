import 'dart:async';
import 'package:demo_p/core/constants/app_colors.dart';
import 'package:demo_p/core/widgets/main_wrapper.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;

  const OtpScreen({super.key, required this.phoneNumber});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  int seconds = 20;
  Timer? timer;
  bool isError = false;

  final TextEditingController pinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  void startTimer() {
    seconds = 20;
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (seconds == 0) {
        timer.cancel();
      } else {
        setState(() => seconds--);
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
 final defaultPinTheme = PinTheme(
  width: 63,
  height: 79,
  textStyle: const TextStyle(
    fontSize: 36, 
    fontWeight: FontWeight.w400, 
    fontFamily: 'Inter',
    height: 1.5,
    color: Colors.white,
  ),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(15),
    border: Border.all(color: const Color(0xFFD8DADC)),
  ),
);
final errorPinTheme = defaultPinTheme.copyDecorationWith(
  border: Border.all(color: const Color(0xFFEB4335)), 
);

    return Scaffold(
      backgroundColor:AppColors.backgroundright,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 39,
                      height: 39,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF6C6C6C)),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ), 
          
                const SizedBox(height: 40),
          
    
                const Text(
                  "Enter code",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Color(0XFFF9F9F9),
                  ),
                ),
          
                const SizedBox(height: 10),
          
                /// DESCRIPTION
                Text(
                  "We’ve sent an SMS with an activation code to your phone ${widget.phoneNumber}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: Colors.white,
                  ),
                ),
          const SizedBox(height: 40),
          Pinput(
            controller: pinController,
            length: 4,
            defaultPinTheme: defaultPinTheme,
            errorPinTheme: errorPinTheme,
              forceErrorState: isError,
            onCompleted: (pin) {
              if (pin == "1234") {
                setState(() => isError = false);
          
                Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const MainWrapper(),
          ),
                );
              } else {
                setState(() => isError = true);
              }
            },
          ),
          
                const SizedBox(height: 10),
          
             if (isError)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                "Wrong code, please try again",
                style: TextStyle(color: Color(0xFFEB4335)),
              ),
            ),
          
                 const SizedBox(height: 20),
          
                if (!isError)
            Text(
              seconds == 0
          ? "Send code again"
          : "Send code again 00:${seconds.toString().padLeft(2, '0')}",
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                height: 1.25,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          
                const SizedBox(height: 40),
          
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
            if (pinController.text == "1234") {
              setState(() => isError = false);
          
              Navigator.push(
                context,
                MaterialPageRoute(
          builder: (context) => const MainWrapper(),
                ),
              );
            } else {
              setState(() => isError = true);
            }
          },
                    child: const Text(
                      "Verify",
                      style: TextStyle(
                        color: Color(0xFF1E2021),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
          
             
          const SizedBox(height: 20),
   
          GestureDetector(
          onTap: seconds == 0
              ? () {
          startTimer();
          pinController.clear(); 
          setState(() => isError = false); 
                }
              : null,
            child: RichText(
              text: TextSpan(
                style: TextStyle(
          fontSize: 16,
          fontFamily: 'Inter',
            color: Color(0xFF38BBE1),
                ),
                children: const [
          TextSpan(text: "I didn’t receive a code  "),
          TextSpan(
            text: "Resend",
            style: TextStyle(
              color: Color(0xFF38BBE1),
              fontWeight: FontWeight.w600,
            ),
          ),
                ],
              ),
            ),
          ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}