import 'package:flutter/material.dart';
import '../widgets/app_logo.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _errorMessage = null;
    });

    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Email tidak boleh kosong';
      });
      return;
    }

    if (password.isEmpty) {
      setState(() {
        _errorMessage = 'Password tidak boleh kosong';
      });
      return;
    }

    if (email == 'faiz@yalt.com' && password == 'ayamgoreng') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const HomeScreen(role: 'Admin'),
        ),
      );
    } else if (email == 'faiz@gmail.com' && password == 'ayamgoreng') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const HomeScreen(role: 'User'),
        ),
      );
    } else {
      setState(() {
        _errorMessage = 'Email atau password salah';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF007BFF);
    const borderColor = Color(0xFFE5E7EB);
    const placeholderColor = Color(0xFF9CA3AF);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 36.0, vertical: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top Header: Logo bulat (tanpa shadow/glow) & Teks "Yalt" font Roboto
                const AppLogo(size: 110),
                const SizedBox(height: 14),
                const Text(
                  'Yalt',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 44),

                // Error message banner jika ada error
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Color(0xFFDC2626),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 13,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Input Field: Email (Icon Email di kiri + input box)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 28,
                      child: Icon(
                        Icons.email_outlined,
                        size: 22,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: borderColor,
                            width: 1.2,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.centerLeft,
                        child: TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 15,
                            color: Color(0xFF111827),
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            hintText: 'Email',
                            hintStyle: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 15,
                              color: placeholderColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Input Field: Password (Icon Lock di kiri + input box + Eye icon toggle di kanan)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 28,
                      child: Icon(
                        Icons.lock,
                        size: 22,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: borderColor,
                            width: 1.2,
                          ),
                        ),
                        padding: const EdgeInsets.only(left: 14, right: 4),
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _handleLogin(),
                                style: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 15,
                                  color: Color(0xFF111827),
                                ),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  border: InputBorder.none,
                                  hintText: 'Password',
                                  hintStyle: TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 15,
                                    color: placeholderColor,
                                  ),
                                ),
                              ),
                            ),
                            // Simple Eye Icon toggle
                            IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 20,
                                color: const Color(0xFF6B7280),
                              ),
                              splashRadius: 18,
                              tooltip: _obscurePassword
                                  ? 'Tampilkan Password'
                                  : 'Sembunyikan Password',
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Tombol Biru "Login"
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Login',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
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
