// login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth_provider.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
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

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(authProvider.notifier).login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logged in successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      context.go('/home');

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email address first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent! Check your inbox.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send reset email: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      // Note: Google OAuth requires additional setup in Supabase
      // This is a placeholder for the implementation
      // You need to:
      // 1. Enable Google provider in Supabase dashboard
      // 2. Add google_sign_in package to pubspec.yaml
      // 3. Configure OAuth credentials
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google sign-in requires Supabase OAuth setup. Please use email/password for now.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google sign-in failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF9C27B0), // Purple
              Color(0xFF673AB7), // Deep Purple
              Color(0xFF3F51B5), // Indigo
              Color(0xFF2196F3), // Blue
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Logo and Title
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // App Title
                  const Text(
                    'EthioEntrance ✨',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Subtitle
                  const Text(
                    'Excel in your entrance exams',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Your journey to academic excellence starts here',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white60,
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // White Card Container
                  Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Email Field
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.email_outlined, 
                                      size: 20, 
                                      color: Colors.purple.shade300,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Email Address',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _emailController,
                                  decoration: InputDecoration(
                                    hintText: 'Enter your email',
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                    prefixIcon: Icon(Icons.email, 
                                      color: Colors.grey.shade400,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF9C27B0),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your email';
                                    }
                                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                                      return 'Please enter a valid email';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            
                            // Password Field
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.lock_outline, 
                                      size: 20, 
                                      color: Colors.purple.shade300,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Password',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _passwordController,
                                  decoration: InputDecoration(
                                    hintText: '••••••',
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                    prefixIcon: Icon(Icons.lock, 
                                      color: Colors.grey.shade400,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword 
                                          ? Icons.visibility_off 
                                          : Icons.visibility,
                                        color: Colors.grey.shade400,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF9C27B0),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  obscureText: _obscurePassword,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your password';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            
                            // Sign In Button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _submitForm,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                                child: Ink(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF9C27B0), Color(0xFF2196F3)],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Container(
                                    alignment: Alignment.center,
                                    child: _isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          'Sign In',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Forgot Password
                            TextButton(
                              onPressed: _handleForgotPassword,
                              child: Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  color: Colors.purple.shade400,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Divider
                            Row(
                              children: [
                                Expanded(child: Divider(color: Colors.grey.shade300)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    'OR CONTINUE WITH',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider(color: Colors.grey.shade300)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // Google Sign In Button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: OutlinedButton.icon(
                                onPressed: _isLoading ? null : _handleGoogleSignIn,
                                icon: const FaIcon(
                                  FontAwesomeIcons.google,
                                  size: 20,
                                  color: Colors.black87,
                                ),
                                label: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'Continue with Google',
                                        style: TextStyle(
                                          color: Colors.black87,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.grey.shade300),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // Don't have account
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Don't have an account? ",
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => context.go('/signup'),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Sign Up',
                                    style: TextStyle(
                                      color: Colors.purple.shade400,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // Terms and Privacy
                            Text(
                              'By continuing, you agree to our Terms of Service and Privacy Policy',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 11,
                              ),
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
