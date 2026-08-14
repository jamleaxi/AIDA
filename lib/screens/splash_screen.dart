import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Branded flash shown while the app initializes.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, required this.status});

  /// Human-readable init stage, updated live by `main()` while this screen
  /// is on screen (e.g. "Loading configuration…", "Connecting…").
  final ValueListenable<String> status;

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    final isDark = brightness == Brightness.dark;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: isDark ? AppTheme.dark() : AppTheme.light(),
      home: Scaffold(
        body: ValueListenableBuilder<String>(
          valueListenable: status,
          builder: (context, value, _) => SplashBody(status: value),
        ),
      ),
    );
  }
}

/// The branded logo + progress indicator, reusable as both the app's initial
/// splash and as the loading screen shown while later async work (e.g.
/// fetching the user's profile) is in flight.
class SplashBody extends StatefulWidget {
  const SplashBody({super.key, this.status});

  /// Optional status line shown under the progress bar. Omit to show just
  /// the logo and progress bar.
  final String? status;

  @override
  State<SplashBody> createState() => _SplashBodyState();
}

class _SplashBodyState extends State<SplashBody>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();

  late final _scale = Tween<double>(
    begin: 0.85,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
  late final _opacity = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.6, curve: Curves.easeOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    final isDark = brightness == Brightness.dark;
    final backgroundColor = isDark ? AidaColors.bgDark : AidaColors.bgLight;
    final statusColor = isDark
        ? Colors.white70
        : AidaColors.navy.withValues(alpha: 0.7);
    final trackColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : AidaColors.navy.withValues(alpha: 0.1);

    return ColoredBox(
      color: backgroundColor,
      child: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'lib/assets/aida-logo.png',
                  width: 220,
                  height: 220,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: 160,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      minHeight: 4,
                      backgroundColor: trackColor,
                      valueColor: const AlwaysStoppedAnimation(AidaColors.pink),
                    ),
                  ),
                ),
                if (widget.status != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    widget.status!,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
