import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final authService = Provider.of<AuthService>(context, listen: false);
    final success = await authService.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid credentials. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ─── Forgot Password Dialog ────────────────────────────────────────────────
  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController();
    final resetFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        bool isSending = false;
        bool emailSent = false;
        String? errorMessage;
        String sentToEmail = '';

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              title: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      emailSent
                          ? Icons.mark_email_read_outlined
                          : Icons.lock_reset,
                      color: Theme.of(context).primaryColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      emailSent ? 'Email Sent!' : 'Reset Password',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 360,
                child: emailSent
                    // ── Success state ──────────────────────────────────
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check_circle_outline,
                                color: Colors.green.shade600,
                                size: 40,
                              ),
                            ),
                            const SizedBox(height: 16),
                            RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 13.5,
                                  height: 1.6,
                                  color: Colors.grey[700],
                                ),
                                children: [
                                  const TextSpan(
                                      text:
                                          'Password reset link পাঠানো হয়েছে\n'),
                                  TextSpan(
                                    text: sentToEmail,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                  const TextSpan(
                                    text:
                                        '\n\nআপনার inbox (এবং spam folder) চেক করুন এবং link-এ click করে password reset করুন।',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Resend button
                            TextButton.icon(
                              onPressed: isSending
                                  ? null
                                  : () async {
                                      setDialogState(() => isSending = true);
                                      final authService =
                                          Provider.of<AuthService>(
                                        context,
                                        listen: false,
                                      );
                                      final result = await authService
                                          .sendPasswordReset(sentToEmail);
                                      setDialogState(() => isSending = false);

                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              result['success']
                                                  ? 'Reset link আবার পাঠানো হয়েছে!'
                                                  : result['message'],
                                            ),
                                            backgroundColor: result['success']
                                                ? Colors.green
                                                : Colors.red,
                                            duration:
                                                const Duration(seconds: 3),
                                          ),
                                        );
                                      }
                                    },
                              icon: isSending
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.refresh, size: 16),
                              label: const Text("Didn't receive it? Resend"),
                            ),
                          ],
                        ),
                      )
                    // ── Form state ─────────────────────────────────────
                    : Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'আপনার account-এর email address দিন। আমরা একটি password reset link পাঠাবো।',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13.5,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Form(
                              key: resetFormKey,
                              child: TextFormField(
                                controller: resetEmailController,
                                keyboardType: TextInputType.emailAddress,
                                autofocus: true,
                                enabled: !isSending,
                                onChanged: (_) {
                                  if (errorMessage != null) {
                                    setDialogState(() => errorMessage = null);
                                  }
                                },
                                decoration: InputDecoration(
                                  labelText: 'Email Address',
                                  hintText: 'example@email.com',
                                  prefixIcon:
                                      const Icon(Icons.email_outlined),
                                  // Server error message দেখানো
                                  errorText: errorMessage,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Email address দিন';
                                  }
                                  final emailRegex = RegExp(
                                    r'^[\w\.\+\-]+@[a-zA-Z0-9\-]+\.[a-zA-Z]{2,}$',
                                  );
                                  if (!emailRegex.hasMatch(value.trim())) {
                                    return 'Valid email address দিন';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
              ),
              actions: [
                if (emailSent)
                  // ── Success action ───────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Back to Login'),
                      ),
                    ),
                  )
                else ...[
                  // ── Form actions ─────────────────────────────────────
                  TextButton(
                    onPressed: isSending
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 8),
                    child: ElevatedButton(
                      onPressed: isSending
                          ? null
                          : () async {
                              // Client-side validation
                              if (!resetFormKey.currentState!.validate()) {
                                return;
                              }

                              setDialogState(() {
                                isSending = true;
                                errorMessage = null;
                              });

                              // ── Actual API call ──────────────────────
                              final authService = Provider.of<AuthService>(
                                context,
                                listen: false,
                              );
                              final result =
                                  await authService.sendPasswordReset(
                                resetEmailController.text.trim(),
                              );
                              // ────────────────────────────────────────

                              if (result['success']) {
                                setDialogState(() {
                                  sentToEmail =
                                      resetEmailController.text.trim();
                                  isSending = false;
                                  emailSent = true;
                                });
                              } else {
                                // Server থেকে আসা error দেখাও (যেমন "Email not found")
                                setDialogState(() {
                                  isSending = false;
                                  errorMessage = result['message'];
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                      child: isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          : const Text('Send Reset Link'),
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    ).then((_) => resetEmailController.dispose());
  }
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    size: 70,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Smart Expense Tracker',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Login to manage your finances',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            // ── Email ──────────────────────────────────
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                prefixIcon:
                                    const Icon(Icons.email_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!value.contains('@')) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // ── Password ───────────────────────────────
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon:
                                    const Icon(Icons.lock_outlined),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                  onPressed: () {
                                    setState(() => _obscurePassword =
                                        !_obscurePassword);
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),

                            // ── Forgot Password link ───────────────────
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _showForgotPasswordDialog,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Forgot Password?',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // ── Login button ───────────────────────────
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'Login',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // ── Sign Up link ───────────────────────────
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Don't have an account? ",
                                  style:
                                      TextStyle(color: Colors.grey[600]),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const SignupScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'Sign Up',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
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