// ignore_for_file: deprecated_member_use

import 'package:chat/auth/auth_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _dotsController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _dotsAnimation;

  @override
  void initState() {
    super.initState();
    
    // Set system UI overlay style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    // Initialize animation controllers
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _dotsController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Initialize animations
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _dotsAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _dotsController,
      curve: Curves.easeInOut,
    ));

    // Start animations
    _startAnimations();
    
    // Navigate to main app after delay
    Timer(const Duration(seconds: 3), () {
      _navigateToMain();
    });
  }

  void _startAnimations() {
    _fadeController.forward();
    
    Timer(const Duration(milliseconds: 300), () {
      _scaleController.forward();
    });
    
    Timer(const Duration(milliseconds: 800), () {
      _dotsController.forward();
    });
  }

  void _navigateToMain() {
    // Replace this with your main app navigation
    // For example:
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AuthWrapper()),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF6B46C1),
              Color(0xFF553C9A),
              Color(0xFF4C1D95),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Animated background decorations
              _buildBackgroundDecorations(),
              
              // Main content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo/Icon
                    AnimatedBuilder(
                      animation: _scaleAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.chat_bubble_rounded,
                                size: 60,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // App name
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: const Text(
                        'Cihuy',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Loading dots
                    AnimatedBuilder(
                      animation: _dotsAnimation,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _dotsAnimation.value,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildDot(0),
                              const SizedBox(width: 8),
                              _buildDot(1),
                              const SizedBox(width: 8),
                              _buildDot(2),
                            ],
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 60),
                    
                    // Tagline
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          Container(
                            width: 60,
                            height: 2,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Chat. Connect.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Celebrate.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: 60,
                            height: 2,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _dotsController,
      builder: (context, child) {
        final delay = index * 0.2;
        final animationValue = (_dotsController.value - delay).clamp(0.0, 1.0);
        final scale = 0.5 + (animationValue * 0.5);
        
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6 + (animationValue * 0.4)),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  Widget _buildBackgroundDecorations() {
    return Stack(
      children: [
        // Top left decoration
        Positioned(
          top: 60,
          left: 30,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                  width: 1,
                ),
              ),
              child: Center(
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Colors.white54,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
        
        // Top right circle
        Positioned(
          top: 100,
          right: 80,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        
        // Bottom right decoration
        Positioned(
          bottom: 200,
          right: 40,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.white38,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
        
        // Bottom left circle
        Positioned(
          bottom: 100,
          left: 60,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        
        // Additional decorative elements
        Positioned(
          top: 250,
          left: 120,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        
        Positioned(
          bottom: 300,
          right: 120,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              width: 25,
              height: 25,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ],
    );
  }
}