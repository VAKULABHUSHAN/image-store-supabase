import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

// 👉 make sure this is already initialized in main.dart
final supabase = Supabase.instance.client;

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;

  Future<void> _signup() async {
    setState(() => _loading = true);

    try {
      final rawUser = _usernameController.text.trim();
      final email = rawUser.contains('@') ? rawUser : '$rawUser@imagestore.local';

      final res = await supabase.auth.signUp(
        email: email,
        password: _passwordController.text.trim(),
        data: {'username': rawUser},
      );

      if (res.user != null) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Account created! Please login')),
        );

        Navigator.pop(context); // 🔙 go back to login
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signup failed: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1A1A24);
    final secondaryTextColor = isDark ? Colors.white70 : const Color(0xFF555566);
    final iconColor = isDark ? Colors.white70 : const Color(0xFF666677);
    final cardBg = isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.85);
    final fieldBg = isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF0EFFF);
    final cardBorder = isDark ? Colors.white12 : Colors.black12;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryTextColor),
        actions: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (context, mode, _) {
              return IconButton(
                icon: Icon(
                  mode == ThemeMode.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: primaryTextColor,
                ),
                tooltip: mode == ThemeMode.dark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                onPressed: () {
                  themeNotifier.value =
                      mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
                },
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? const [
                    Color(0xFF6C63FF),
                    Color(0xFF3F3D56),
                    Color(0xFF1A1A24),
                  ]
                : const [
                    Color(0xFF6C63FF),
                    Color(0xFFD6D3FF),
                    Color(0xFFF0EFFF),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 60),

                Text(
                  "Create Account",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: primaryTextColor,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  "Join PersonaLens 🚀",
                  style: TextStyle(color: secondaryTextColor),
                ),

                const SizedBox(height: 40),

                // 🧊 Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cardBorder),
                    boxShadow: isDark
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                  ),
                  child: Column(
                    children: [
                      // 👤 Username
                      TextField(
                        controller: _usernameController,
                        style: TextStyle(color: primaryTextColor),
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.person, color: iconColor),
                          labelText: 'Username',
                          labelStyle: TextStyle(color: secondaryTextColor),
                          filled: true,
                          fillColor: fieldBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 🔒 Password
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: TextStyle(color: primaryTextColor),
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.lock, color: iconColor),
                          labelText: 'Password',
                          labelStyle: TextStyle(color: secondaryTextColor),
                          filled: true,
                          fillColor: fieldBg,

                          // 👁️ Eye Icon
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: iconColor,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),

                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 🚀 Signup Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _signup,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C63FF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 8,
                          ),
                          child: _loading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  "Sign Up",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 🔙 Back to Login
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Already have an account? Login",
                    style: TextStyle(color: secondaryTextColor),
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