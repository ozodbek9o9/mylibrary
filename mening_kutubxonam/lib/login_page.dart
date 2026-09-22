import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String? _errorMessage;
  String? _rawErrorDetails;
  bool _showTechnicalDetails = false;
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _runLogin(Future<void> Function() login) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _rawErrorDetails = null;
    });
    try {
      await login();
    } catch (error, stackTrace) {
      debugPrint('LOGIN_ERROR: $error');
      debugPrint('STACK_TRACE: $stackTrace');
      if (mounted) {
        final friendly = _friendlyError(error);
        if (friendly.isNotEmpty) {
          setState(() {
            _errorMessage = friendly;
            _rawErrorDetails = error.toString();
          });
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString();

    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'account-exists-with-different-credential':
          return "Bu email boshqa kirish usuli bilan ro'yxatdan o'tgan.";
        case 'network-request-failed':
          return "Internet aloqasini tekshirib qayta urinib ko'ring.";
        case 'operation-not-allowed':
          return "Firebase Console'da ushbu kirish usuli (Sign-in provider) yoqilmagan. Firebase Authentication bo'limidan yoqing.";
        case 'user-disabled':
          return "Ushbu foydalanuvchi hisobi bloklangan.";
        case 'invalid-credential':
        case 'invalid-verification-code':
        case 'invalid-verification-id':
          return "Kirish ma'lumotlari yaroqsiz.";
        case 'user-not-found':
          return "Bunday foydalanuvchi topilmadi. Avval ro'yxatdan o'ting.";
        case 'wrong-password':
          return "Kiritilgan parol noto'g'ri.";
        case 'email-already-in-use':
          return "Ushbu email bilan allaqachon hisob ochilgan.";
        case 'weak-password':
          return "Parol kamida 6 ta belgidan iborat bo'lsin.";
        case 'too-many-requests':
          return "Juda ko'p urinish qilindi. Birozdan keyin qayta urinib ko'ring.";
        default:
          return "Firebase xatosi (${error.code}): ${error.message ?? error.code}";
      }
    }

    if (error is PlatformException) {
      if (error.code == 'sign_in_canceled') {
        return '';
      }
      if (error.code == 'sign_in_failed' ||
          error.code == '10' ||
          error.code == '12500' ||
          message.contains('ApiException: 10')) {
        return "Google Sign-In sozlanmagan.\nFirebase Console'da Android ilovangizga SHA-1 kalitini qo'shishingiz kerak.";
      }
      if (error.code == 'network_error') {
        return "Internet aloqasi mavjud emas.";
      }
      if (error.code == 'channel-error') {
        return "Ilovani to'liq to'xtatib (Stop), qaytadan ishga tushiring (Hot Reload emas, to'liq Restart qiling).";
      }
      return "Tizim xatosi (${error.code}): ${error.message ?? ''}";
    }

    if (message.contains('SignInWithAppleNotSupportedException') ||
        message.contains('webAuthenticationOptions')) {
      return "Apple orqali kirish faqat iOS (iPhone/iPad) qurilmalarida qo'llab-quvvatlanadi.";
    }

    if (message.contains('canceled') ||
        message.contains('cancelled') ||
        message.contains('sign_in_canceled')) {
      return '';
    }

    if (message.contains('DEVELOPER_ERROR') ||
        message.contains('ApiException: 10') ||
        message.contains('sign_in_failed') ||
        message.contains('12500')) {
      return "Google Sign-In sozlanmagan.\nFirebase Console'da Android ilovangizga SHA-1 kalitini qo'shishingiz kerak.";
    }

    if (message.contains('network') ||
        message.contains('SocketException') ||
        message.contains('Failed host lookup')) {
      return "Internet aloqasini tekshirib qayta urinib ko'ring.";
    }

    if (message.contains('no-app') || message.contains('FirebaseApp')) {
      return "Firebase ilovaga to'liq ulanmagan. Ilovani qayta ishga tushiring.";
    }

    return "Kirishda xatolik yuz berdi: $message";
  }

  void _showSha1Dialog() {
    const sha1 = 'F7:97:00:57:06:60:F5:28:AD:91:52:C0:AC:30:8A:73:02:53:D1:AA';
    const sha256 =
        '99:65:59:10:F7:14:F3:7D:E1:3A:A1:A9:7A:E5:E9:C5:C0:84:4F:83:7A:02:8A:04:2D:33:00:F6:A0:40:D7:31';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.vpn_key, color: Color(0xff276fd1)),
            SizedBox(width: 8),
            Text('SHA-1 Kalitlari', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Google Sign-In ishlashi uchun Firebase Console -> Project Settings -> Your apps -> Android bo'limiga ushbu SHA-1 ni qo'shing:",
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              const Text(
                'SHA-1 barmoq izi:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 4),
              SelectableText(
                sha1,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Color(0xff102b63),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(const ClipboardData(text: sha1));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("SHA-1 nusxalandi!")),
                  );
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('SHA-1 dan nusxa olish'),
              ),
              const Divider(height: 24),
              const Text(
                'SHA-256 barmoq izi:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 4),
              SelectableText(
                sha256,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Color(0xff102b63),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Yopish'),
          ),
        ],
      ),
    );
  }

  void _handleAppleSignIn() {
    final isApplePlatform =
        !kIsWeb && (Platform.isIOS || Platform.isMacOS);

    if (!isApplePlatform) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Apple orqali kirish'),
          content: const Text(
            "Apple ID orqali kirish faqat iOS (iPhone/iPad) qurilmalarida qo'llab-quvvatlanadi.\n\nAndroid qurilmangizda Google, Email/Parol yoki Mehmon rejimidan foydalaning.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tushundim'),
            ),
          ],
        ),
      );
      return;
    }

    _runLogin(() async {
      await AuthService.instance.signInWithApple();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          final animVal = _animController.value;
          final floatOffset = 7.0 * math.sin(animVal * 2 * math.pi);

          return Stack(
            children: [
              // 1. Asosiy gradient fon
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xfff8faff),
                        Color(0xffedf4ff),
                        Color(0xfffdf2f4),
                      ],
                    ),
                  ),
                ),
              ),

              // 2. Harakatlanuvchi nurlar (glowing orbs) va yulduzchalar
              Positioned.fill(
                child: CustomPaint(
                  painter: _AmbientBackgroundPainter(animation: animVal),
                ),
              ),

              // 3. Asosiy kontent
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 36,
                          maxWidth: 430,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            children: [
                              const SizedBox(height: 10),

                              // Tepa nishon (Badge)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: const Color(0xffdbeafe),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xff3b82f6)
                                          .withValues(alpha: 0.08),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(
                                        color: Color(0xff10b981),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Elektron Kutubxona Portali',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xff1e3a8a),
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 18),

                              // Havoda suzuvchi App Icon va orqadagi nurli halo
                              Transform.translate(
                                offset: Offset(0, floatOffset),
                                child: Container(
                                  width: 132,
                                  height: 132,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xffc62828)
                                            .withValues(
                                                alpha: 0.20 +
                                                    0.08 *
                                                        math.sin(animVal *
                                                            2 *
                                                            math.pi)),
                                        blurRadius: 36,
                                        spreadRadius: 4,
                                      ),
                                      BoxShadow(
                                        color: const Color(0xff3b82f6)
                                            .withValues(
                                                alpha: 0.16 +
                                                    0.08 *
                                                        math.cos(animVal *
                                                            2 *
                                                            math.pi)),
                                        blurRadius: 28,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Image.asset(
                                    'assets/app_icon.png',
                                    width: 122,
                                    height: 122,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Sarlavha
                              Text(
                                'Mening\nkutubxonam',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.displaySmall?.copyWith(
                                  color: const Color(0xff0f2557),
                                  fontWeight: FontWeight.w900,
                                  height: 1.05,
                                  letterSpacing: -0.5,
                                ),
                              ),

                              const SizedBox(height: 14),

                              // Animatsiyali rangli gradient chiziq
                              Container(
                                width: 170,
                                height: 4,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  gradient: LinearGradient(
                                    colors: const [
                                      Color(0xff2563eb),
                                      Color(0xff60a5fa),
                                      Color(0xffef4444),
                                    ],
                                    begin: Alignment(-1.0 + 2.0 * animVal, 0.0),
                                    end: Alignment(1.0 + 2.0 * animVal, 0.0),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xff3b82f6)
                                          .withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 8),

                              const Text(
                                "Kitoblar va o'quvchilar boshqaruvi",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xff64748b),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.1,
                                ),
                              ),

                              const Spacer(),

                              // Pastki qismdagi Glassmorphism oynasi
                              ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                      sigmaX: 18, sigmaY: 18),
                                  child: Container(
                                    padding: const EdgeInsets.fromLTRB(
                                        18, 20, 18, 20),
                                    decoration: BoxDecoration(
                                      color: Colors.white
                                          .withValues(alpha: 0.82),
                                      borderRadius:
                                          BorderRadius.circular(24),
                                      border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.95),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xff0f172a)
                                              .withValues(alpha: 0.06),
                                          blurRadius: 24,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 32,
                                              height: 1,
                                              color: const Color(0xffcbd5e1),
                                            ),
                                            const Padding(
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 10),
                                              child: Text(
                                                'Davom etish uchun kiring',
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xff64748b),
                                                  letterSpacing: 0.2,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              width: 32,
                                              height: 1,
                                              color: const Color(0xffcbd5e1),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),

                                        // Google orqali kirish tugmasi
                                        _LoginButton(
                                          icon: const _GoogleMark(),
                                          label: 'Sign in with Google',
                                          onPressed: _isLoading
                                              ? null
                                              : () => _runLogin(() async {
                                                    await AuthService.instance
                                                        .signInWithGoogle();
                                                  }),
                                        ),
                                        const SizedBox(height: 12),

                                        // Apple orqali kirish tugmasi
                                        _LoginButton(
                                          icon: const Icon(
                                            Icons.apple,
                                            size: 30,
                                            color: Colors.black,
                                          ),
                                          label: 'Sign in with Apple',
                                          onPressed: _isLoading
                                              ? null
                                              : _handleAppleSignIn,
                                        ),

                                        if (_isLoading) ...[
                                          const SizedBox(height: 20),
                                          const CircularProgressIndicator(
                                              color: Color(0xff276fd1)),
                                        ],

                                        if (_errorMessage != null &&
                                            _errorMessage!.isNotEmpty) ...[
                                          const SizedBox(height: 16),
                                          Container(
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              color: const Color(0xffffebee),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                  color:
                                                      const Color(0xffffcdd2)),
                                            ),
                                            child: Column(
                                              children: [
                                                Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.error_outline,
                                                      color: Color(0xffb3261e),
                                                      size: 22,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        _errorMessage!,
                                                        style: const TextStyle(
                                                          color:
                                                              Color(0xffb3261e),
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          height: 1.35,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (_errorMessage!
                                                    .contains('SHA-1')) ...[
                                                  const SizedBox(height: 10),
                                                  SizedBox(
                                                    width: double.infinity,
                                                    child: ElevatedButton.icon(
                                                      onPressed:
                                                          _showSha1Dialog,
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        backgroundColor:
                                                            const Color(
                                                                0xffb3261e),
                                                        foregroundColor:
                                                            Colors.white,
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                        ),
                                                      ),
                                                      icon: const Icon(
                                                          Icons.vpn_key,
                                                          size: 16),
                                                      label: const Text(
                                                          "SHA-1 kalitini ko'rish va nusxalash"),
                                                    ),
                                                  ),
                                                ],
                                                if (_rawErrorDetails !=
                                                    null) ...[
                                                  const SizedBox(height: 8),
                                                  GestureDetector(
                                                    onTap: () {
                                                      setState(() {
                                                        _showTechnicalDetails =
                                                            !_showTechnicalDetails;
                                                      });
                                                    },
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          _showTechnicalDetails
                                                              ? Icons
                                                                  .arrow_drop_down
                                                                : Icons
                                                                  .arrow_right,
                                                          size: 18,
                                                          color: const Color(
                                                              0xff777777),
                                                        ),
                                                        const Text(
                                                          "Batafsil texnik xatolik",
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: Color(
                                                                0xff777777),
                                                            decoration:
                                                                TextDecoration
                                                                    .underline,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  if (_showTechnicalDetails) ...[
                                                    const SizedBox(height: 6),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              8),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                      ),
                                                      child: SelectableText(
                                                        _rawErrorDetails!,
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          fontFamily:
                                                              'monospace',
                                                          color:
                                                              Color(0xff444444),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AmbientBackgroundPainter extends CustomPainter {
  _AmbientBackgroundPainter({required this.animation});
  final double animation;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation * 2 * math.pi;

    // Glowing Orb 1: Soft Sky Blue
    final orb1Center = Offset(
      size.width * 0.18 + math.sin(t) * 35,
      size.height * 0.22 + math.cos(t) * 40,
    );
    final orb1Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xff93c5fd).withValues(alpha: 0.45),
          const Color(0xff93c5fd).withValues(alpha: 0.0),
        ],
      ).createShader(
          Rect.fromCircle(center: orb1Center, radius: size.width * 0.6));
    canvas.drawCircle(orb1Center, size.width * 0.6, orb1Paint);

    // Glowing Orb 2: Soft Rose/Ruby
    final orb2Center = Offset(
      size.width * 0.85 + math.cos(t) * 35,
      size.height * 0.42 + math.sin(t * 0.8) * 40,
    );
    final orb2Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xfffca5a5).withValues(alpha: 0.40),
          const Color(0xfffca5a5).withValues(alpha: 0.0),
        ],
      ).createShader(
          Rect.fromCircle(center: orb2Center, radius: size.width * 0.65));
    canvas.drawCircle(orb2Center, size.width * 0.65, orb2Paint);

    // Glowing Orb 3: Bottom Indigo Glow
    final orb3Center = Offset(
      size.width * 0.45 + math.sin(t * 1.2) * 45,
      size.height * 0.82 + math.cos(t * 0.9) * 35,
    );
    final orb3Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xffc7d2fe).withValues(alpha: 0.45),
          const Color(0xffc7d2fe).withValues(alpha: 0.0),
        ],
      ).createShader(
          Rect.fromCircle(center: orb3Center, radius: size.width * 0.55));
    canvas.drawCircle(orb3Center, size.width * 0.55, orb3Paint);

    // Floating Stardust Particles
    final particlePaint = Paint()..style = PaintingStyle.fill;
    final particles = [
      const Offset(0.18, 0.12),
      const Offset(0.82, 0.18),
      const Offset(0.1, 0.42),
      const Offset(0.9, 0.58),
      const Offset(0.25, 0.68),
      const Offset(0.72, 0.76),
      const Offset(0.48, 0.32),
      const Offset(0.65, 0.9),
      const Offset(0.35, 0.88),
    ];

    for (int i = 0; i < particles.length; i++) {
      final p = particles[i];
      final phase = i * 0.85;
      final yOffset =
          ((p.dy - (animation * 0.22) + phase) % 1.0) * size.height;
      final xOffset = (p.dx + math.sin(t + phase) * 0.035) * size.width;
      final opacity =
          ((math.sin(t + phase) + 1) / 2 * 0.45 + 0.15).clamp(0.0, 1.0);
      particlePaint.color =
          (i % 2 == 0 ? const Color(0xff3b82f6) : const Color(0xffef4444))
              .withValues(alpha: opacity);
      canvas.drawCircle(
          Offset(xOffset, yOffset), 2.2 + (i % 3) * 0.8, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientBackgroundPainter oldDelegate) => true;
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final Widget icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff0f172a).withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xffe2e8f0), width: 1.2),
            ),
            child: Row(
              children: [
                const SizedBox(width: 20),
                SizedBox(width: 32, child: Center(child: icon)),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xff0f172a),
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 15,
                  color: Color(0xff94a3b8),
                ),
                const SizedBox(width: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'G',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Color(0xff4285f4),
            ),
          ),
          TextSpan(
            text: '•',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xffea4335),
            ),
          ),
        ],
      ),
    );
  }
}
