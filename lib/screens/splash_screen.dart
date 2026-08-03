import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_state.dart';

/// Animation d'ouverture avant WelcomeScreen (ou directement l'accueil
/// connecté) : le logo complet (avec tagline) apparaît en zoom léger + fondu
/// (ScaleTransition + FadeTransition, easeOutBack), puis courte pause avant
/// la navigation automatique. Une seule étape — pas de phase intermédiaire
/// avec l'aigle seul (retirée : peu convaincante à l'usage).
/// Le splash NATIF (flutter_native_splash, écran fixe avant que Flutter
/// démarre) est indépendant de cet écran et n'est pas concerné ici.
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  static const _leadIn = Duration(milliseconds: 300);
  static const _zoomFade = Duration(milliseconds: 1300); // logo complet : zoom + fondu
  static const _pause = Duration(milliseconds: 700); // pause sur le logo complet

  late final Duration _animDuration = _zoomFade + _pause;

  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: _animDuration);

    final zoomEnd = _zoomFade.inMilliseconds / _animDuration.inMilliseconds;

    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Interval(0.0, zoomEnd, curve: Curves.easeOutBack)),
    );

    _logoOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: _zoomFade.inMilliseconds.toDouble()),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: _pause.inMilliseconds.toDouble()),
    ]).animate(_controller);

    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Vérifie l'état d'authentification PENDANT l'animation (en parallèle),
    // pas après : AppStarted a déjà été déclenché à la création de l'AuthBloc
    // (voir main.dart) ; on attend juste sa résolution en tâche de fond.
    final authBloc = context.read<AuthBloc>();
    final authStateFuture = authBloc.state is AuthInitial
        ? authBloc.stream.firstWhere((s) => s is! AuthInitial)
        : Future.value(authBloc.state);

    await Future.delayed(_leadIn);
    if (!mounted) return;
    await _controller.forward();

    final authState = await authStateFuture;
    if (!mounted) return;

    if (authState is Authenticated) {
      Navigator.of(context).pushReplacementNamed('/client_home');
    } else {
      Navigator.of(context).pushReplacementNamed('/welcome');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _logoOpacity.value,
              child: Transform.scale(
                scale: _logoScale.value,
                child: Image.asset(
                  'assets/branding/logo_with_tagline_super_app.png',
                  width: MediaQuery.of(context).size.width * 0.65,
                  fit: BoxFit.contain,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}