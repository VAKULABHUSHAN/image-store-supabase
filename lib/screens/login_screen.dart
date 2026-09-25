import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey      = GlobalKey<FormState>();

  bool _loading       = false;
  bool _obscure       = true;
  String? _error;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email:    _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      if (mounted) context.go('/upload');
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'An unexpected error occurred.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PLColors.shell,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Brand ────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: PLColors.live,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'PERSONALENS',
                        style: PLFonts.syne(
                          size: 18,
                          weight: FontWeight.w700,
                          letterSpacing: 0.18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Face-aware memory assistant',
                    textAlign: TextAlign.center,
                    style: PLFonts.mono(
                      size: 11,
                      color: PLColors.textLight,
                      letterSpacing: 0.06,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // ── Card ─────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: PLColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: PLColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A000000),
                          blurRadius: 24,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'SIGN IN',
                            style: PLFonts.syne(
                              size: 13,
                              letterSpacing: 0.18,
                              color: PLColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Email
                          _PLLabel('EMAIL'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            style: PLFonts.mono(color: PLColors.textPrimary),
                            decoration: const InputDecoration(
                              hintText: 'you@example.com',
                            ),
                            validator: (v) =>
                                (v == null || !v.contains('@'))
                                    ? 'Enter a valid email'
                                    : null,
                          ),
                          const SizedBox(height: 16),

                          // Password
                          _PLLabel('PASSWORD'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _passwordCtrl,
                            obscureText: _obscure,
                            style: PLFonts.mono(color: PLColors.textPrimary),
                            decoration: InputDecoration(
                              hintText: '••••••••',
                              suffixIcon: GestureDetector(
                                onTap: () =>
                                    setState(() => _obscure = !_obscure),
                                child: Icon(
                                  _obscure
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 18,
                                  color: PLColors.textLight,
                                ),
                              ),
                            ),
                            validator: (v) =>
                                (v == null || v.length < 6)
                                    ? 'Password must be 6+ chars'
                                    : null,
                          ),

                          if (_error != null) ...[
                            const SizedBox(height: 14),
                            _ErrorBanner(_error!),
                          ],

                          const SizedBox(height: 22),

                          // Sign-in button
                          SizedBox(
                            height: 46,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _signIn,
                              child: _loading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'SIGN IN',
                                      style: PLFonts.mono(
                                        size: 12,
                                        weight: FontWeight.w500,
                                        color: Colors.white,
                                        letterSpacing: 0.12,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Register link ────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account?",
                        style: PLFonts.mono(
                            size: 11, color: PLColors.textMuted),
                      ),
                      TextButton(
                        onPressed: () => context.go('/register'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: Text(
                          'Register',
                          style: PLFonts.syne(
                            size: 12,
                            color: PLColors.known,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _PLLabel extends StatelessWidget {
  final String text;
  const _PLLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: PLFonts.mono(
          size: 9,
          letterSpacing: 0.16,
          color: PLColors.textLight,
        ),
      );
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: PLColors.unknownBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: PLColors.unknown.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, size: 14, color: PLColors.unknown),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: PLFonts.mono(
                  size: 11,
                  color: PLColors.unknown,
                ),
              ),
            ),
          ],
        ),
      );
}
