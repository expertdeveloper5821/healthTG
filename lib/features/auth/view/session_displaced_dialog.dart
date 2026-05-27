import 'package:flutter/material.dart';

class SessionDisplacedDialog extends StatelessWidget {
  const SessionDisplacedDialog({super.key, required this.onLogBackIn});

  final VoidCallback onLogBackIn;

  static Future<void> show(BuildContext context, VoidCallback onLogBackIn) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => SessionDisplacedDialog(onLogBackIn: onLogBackIn),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: const Color(0xFF424A5A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFF2A2E38),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.videocam,
                  color: Color(0xFFE91E8C),
                  size: 34,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Moved to another\ndevice',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Your session was transferred to a new device. '
                'You have been signed out here to keep your account secure.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: onLogBackIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5CB85C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Log Back In',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
