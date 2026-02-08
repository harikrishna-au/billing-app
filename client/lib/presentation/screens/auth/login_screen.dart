import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
// import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../config/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  // Development credentials - remove in production
  final _usernameController = TextEditingController(
    text: const bool.fromEnvironment('dart.vm.product') ? '' : 'admin003',
  );
  final _passwordController = TextEditingController(
    text: const bool.fromEnvironment('dart.vm.product') ? '' : 'admin',
  );
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      // Logic to close keyboard
      FocusManager.instance.primaryFocus?.unfocus();

      await ref.read(authProvider.notifier).login(
            _usernameController.text.trim(),
            _passwordController.text,
          );

      // Navigation is handled by router listenable in app_router.dart
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _LogoSection()
                    .animate()
                    .fadeIn(duration: 600.ms)
                    .slideY(begin: -0.2, end: 0),
                const SizedBox(height: 32),
                const _TextSection()
                    .animate()
                    .fadeIn(duration: 600.ms, delay: 200.ms)
                    .slideY(begin: 0.2, end: 0),
                const SizedBox(height: 32),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildUsernameField()
                          .animate()
                          .fadeIn(duration: 600.ms, delay: 400.ms)
                          .slideY(begin: 0.2, end: 0),
                      const SizedBox(height: 20),
                      _buildPasswordField()
                          .animate()
                          .fadeIn(duration: 600.ms, delay: 500.ms)
                          .slideY(begin: 0.2, end: 0),
                      const SizedBox(height: 12),
                      _buildForgotPassword()
                          .animate()
                          .fadeIn(duration: 600.ms, delay: 600.ms),
                      const SizedBox(height: 32),
                      _buildLoginButton(authState.isLoading).animate().scale(
                          delay: 600.ms,
                          duration: 400.ms,
                          curve: Curves.elasticOut),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUsernameField() {
    return _AnimatedInputField(
      controller: _usernameController,
      label: 'Username',
      placeholder: 'Enter your username',
      keyboardType: TextInputType.text,
      validator: Validators.required,
    );
  }

  Widget _buildPasswordField() {
    return _AnimatedInputField(
      controller: _passwordController,
      label: 'Password',
      placeholder: '••••••••',
      obscureText: !_isPasswordVisible,
      validator: Validators.required, // Or password validator
      suffixIcon: IconButton(
        icon: Icon(
          _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
          color: AppColors.textSecondary,
        ),
        onPressed: () {
          setState(() {
            _isPasswordVisible = !_isPasswordVisible;
          });
        },
      ),
    );
  }

  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () {},
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        child: const Text('Forgot Password?'),
      ),
    );
  }

  Widget _buildLoginButton(bool isLoading) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                'Login',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

class _LogoSection extends StatelessWidget {
  const _LogoSection();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF), // Light blue shade
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.account_balance_wallet_rounded,
          size: 48,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _TextSection extends StatelessWidget {
  const _TextSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Welcome Back',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A), // Slate 900
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Log in to access your POS terminal and manage transactions.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _AnimatedInputField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String placeholder;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  const _AnimatedInputField({
    required this.controller,
    required this.label,
    required this.placeholder,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
  });

  @override
  State<_AnimatedInputField> createState() => _AnimatedInputFieldState();
}

class _AnimatedInputFieldState extends State<_AnimatedInputField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      transform: Matrix4.identity()..scale(_isFocused ? 1.02 : 1.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            keyboardType: widget.keyboardType,
            obscureText: widget.obscureText,
            validator: widget.validator,
            style: GoogleFonts.inter(fontSize: 15),
            decoration: InputDecoration(
              hintText: widget.placeholder,
              suffixIcon: widget.suffixIcon,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 2),
              ),
              filled: true,
              fillColor: _isFocused
                  ? Colors.white
                  : const Color(0xFFF1F5F9), // Slight change on focus
            ),
          ),
        ],
      ),
    );
  }
}
