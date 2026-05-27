import 'package:demo_p/features/auth/provider/auth_provider.dart';
import 'package:demo_p/features/auth/view/login_page.dart';
import 'package:demo_p/features/auth/view/session_displaced_dialog.dart';
import 'package:demo_p/features/game/view/game_screen.dart';
import 'package:demo_p/features/video_call/view/therapist_mobile_home_screen.dart';
import 'package:demo_p/features/video_call/view/video_call_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  // Guard so we only open the dialog once per displacement event.
  // ref.listen with ChangeNotifierProvider passes the same mutable object for
  // both previous and next, so we can't use previous/next comparison.
  // Instead we watch isSessionDisplaced directly and gate with this flag.
  bool _dialogShowing = false;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    if (auth.isSessionDisplaced && !_dialogShowing) {
      _dialogShowing = true;
      // Defer until after the current build frame completes.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        SessionDisplacedDialog.show(context, () async {
          if (mounted) Navigator.of(context, rootNavigator: true).pop();
          _dialogShowing = false;
          await ref.read(authProvider).logout();
        });
      });
    }

    if (auth.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (auth.isAuthenticated) {
      if (auth.session?.isTherapist ?? false) {
        return const TherapistMobileHomeScreen();
      }

      return const VideoCallWrapper(child: GameScreen());
    }

    return const LoginPage();
  }
}
