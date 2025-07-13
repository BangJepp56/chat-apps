// ignore_for_file: avoid_print, deprecated_member_use, library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  _ForgotPasswordPageState createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final FocusNode _emailFocusNode = FocusNode();
  
  bool _isLoading = false;
  bool _emailSent = false;
  bool _isValidEmail = false;
  bool _canResend = true;
  int _resendCountdown = 0;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _emailController.addListener(_validateEmailInput);
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
    
    _animationController.forward();
  }

  void _validateEmailInput() {
    final email = _emailController.text.trim();
    final isValid = _isValidEmailFormat(email);
    if (isValid != _isValidEmail) {
      setState(() {
        _isValidEmail = isValid;
      });
    }
  }

  bool _isValidEmailFormat(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email);
  }

  // Send password reset email with improved error handling
  Future<void> _sendPasswordResetEmail() async {
    if (!_formKey.currentState!.validate()) return;

    // Haptic feedback
    HapticFeedback.lightImpact();

    setState(() {
      _isLoading = true;
    });

    try {
      await _auth.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      
      setState(() {
        _emailSent = true;
        _canResend = false;
        _resendCountdown = 60; // 60 detik countdown
      });
      
      _startResendCountdown();
      
      // Show success snackbar
      _showSnackBar(
        'Reset email sent successfully!',
        Colors.green,
        Icons.check_circle,
      );
      
    } on FirebaseAuthException catch (e) {
      String errorMessage = _getErrorMessage(e.code);
      _showSnackBar(errorMessage, Colors.red, Icons.error);
    } catch (e) {
      _showSnackBar(
        'Network error. Please check your connection.',
        Colors.red,
        Icons.wifi_off,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startResendCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_resendCountdown > 0 && mounted) {
        setState(() {
          _resendCountdown--;
        });
        _startResendCountdown();
      } else if (mounted) {
        setState(() {
          _canResend = true;
        });
      }
    });
  }

  // Enhanced error messages
  String _getErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been temporarily disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait before trying again.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      case 'operation-not-allowed':
        return 'Password reset is currently disabled.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  // Enhanced snackbar
  void _showSnackBar(String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // Enhanced email validation
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email address is required';
    }
    
    if (!_isValidEmailFormat(value)) {
      return 'Please enter a valid email address';
    }
    
    if (value.length > 254) {
      return 'Email address is too long';
    }
    
    return null;
  }

  // Resend email with rate limiting
  void _resendEmail() {
    if (!_canResend) return;
    
    HapticFeedback.lightImpact();
    setState(() {
      _emailSent = false;
    });
    _sendPasswordResetEmail();
  }

  // Go back to login
  void _goBackToLogin() {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
              Color(0xFF6B46C1),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - 
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Back Button
                        Align(
                          alignment: Alignment.topLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.arrow_back,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              onPressed: _goBackToLogin,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // Animated Content
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: Column(
                              children: [
                                // Logo Section
                                _buildLogoSection(),
                                
                                const SizedBox(height: 48),
                                
                                // Main Content
                                if (!_emailSent) ...[
                                  _buildEmailInput(),
                                  const SizedBox(height: 24),
                                  _buildSendButton(),
                                ] else ...[
                                  _buildSuccessState(),
                                  const SizedBox(height: 24),
                                  _buildResendButton(),
                                ],
                                
                                const SizedBox(height: 32),
                                
                                // Back to Login Link
                                _buildBackToLoginLink(),
                              ],
                            ),
                          ),
                        ),
                        
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoSection() {
    return Column(
      children: [
        // Logo with animated container
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: const Icon(
            Icons.lock_reset,
            size: 50,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        
        // Title
        const Text(
          'Forgot Password',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        
        // Description
        Text(
          _emailSent 
              ? 'We\'ve sent reset instructions to your email'
              : 'Don\'t worry! Enter your email and we\'ll send you reset instructions',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withOpacity(0.8),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEmailInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _emailFocusNode.hasFocus 
              ? Colors.white.withOpacity(0.5)
              : Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: TextFormField(
        controller: _emailController,
        focusNode: _emailFocusNode,
        style: const TextStyle(color: Colors.white),
        validator: _validateEmail,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => _sendPasswordResetEmail(),
        decoration: InputDecoration(
          hintText: 'Enter your email address',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.6),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          errorStyle: TextStyle(
            color: Colors.red[300],
            fontSize: 13,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 4, right: 12),
            child: Icon(
              Icons.email_outlined,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
          suffixIcon: _isValidEmail
              ? Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green[300],
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: _isValidEmail && !_isLoading
              ? [
                  const Color(0xFF8B5CF6),
                  const Color(0xFF7C3AED),
                ]
              : [
                  Colors.grey.withOpacity(0.3),
                  Colors.grey.withOpacity(0.3),
                ],
        ),
        boxShadow: _isValidEmail && !_isLoading
            ? [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : [],
      ),
      child: ElevatedButton(
        onPressed: (_isValidEmail && !_isLoading) ? _sendPasswordResetEmail : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Send Reset Instructions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildSuccessState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(40),
            ),
            child: Icon(
              Icons.mark_email_read,
              color: Colors.green[300],
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Check Your Email',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'We sent password reset instructions to:',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _emailController.text.trim(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Please check your inbox and follow the instructions to reset your password.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildResendButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: _canResend ? _resendEmail : null,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: _canResend 
                ? Colors.white.withOpacity(0.5)
                : Colors.white.withOpacity(0.2),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          _canResend 
              ? 'Resend Email'
              : 'Resend in ${_resendCountdown}s',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _canResend 
                ? Colors.white
                : Colors.white.withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildBackToLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Remember your password?",
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
          ),
        ),
        TextButton(
          onPressed: _goBackToLogin,
          child: const Text(
            'Back to Login',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }
}