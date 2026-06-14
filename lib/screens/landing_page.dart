import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

// Screens enumeration
enum AuthScreenState {
  welcome,
  login,
  register,
  forgotPassword,
  savedAccounts,
}

class AuthLandingPage extends StatefulWidget {
  const AuthLandingPage({super.key});

  @override
  State<AuthLandingPage> createState() => _AuthLandingPageState();
}

class _AuthLandingPageState extends State<AuthLandingPage> {
  AuthScreenState _currentState = AuthScreenState.welcome;

  // Controllers
  final _loginInputController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  final _regNicknameController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regConfirmPasswordController = TextEditingController();
  final _regRefCodeController = TextEditingController();
  String _regGender = "MALE"; // MALE, FEMALE
  String _selectedGuestAvatar = "avatar_1";
  String _selectedRegisterAvatar = "avatar_1";
  int? _regBirthDay;
  int? _regBirthMonth;
  int? _regBirthYear;

  final _forgotEmailController = TextEditingController();
  final _forgotCodeController = TextEditingController();
  final _forgotNewPasswordController = TextEditingController();

  // Options
  bool _rememberMe = true;
  bool _obscureLoginPassword = true;
  bool _obscureRegPassword = true;
  bool _obscureRegConfirmPassword = true;
  bool _obscureForgotNewPassword = true;

  // Recovery code status
  String? _sentCode; // For local verification check

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.savedAccounts.isNotEmpty) {
        setState(() {
          _currentState = AuthScreenState.savedAccounts;
        });
      }
    });
  }

  // Handle Login submit
  void _submitLogin() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final input = _loginInputController.text.trim();
    final password = _loginPasswordController.text.trim();

    if (input.isEmpty || password.isEmpty) {
      _showErrorSnackBar(
          context, "يرجى إدخال البريد الإلكتروني/الـ ID وكلمة المرور.");
      return;
    }

    final success =
        await auth.loginEmail(input, password, rememberMe: _rememberMe);
    if (!mounted) return;
    if (!success) {
      _showErrorSnackBar(context, auth.errorMessage ?? "فشل تسجيل الدخول.");
    }
  }

  // Handle Register submit
  void _submitRegister() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final email = _regEmailController.text.trim();
    final nickname = _regNicknameController.text.trim();
    final password = _regPasswordController.text.trim();
    final confirmPassword = _regConfirmPasswordController.text.trim();
    final refCode = _regRefCodeController.text.trim();

    if (email.isEmpty ||
        nickname.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      _showErrorSnackBar(context, "يرجى ملء جميع الحقول المطلوبة.");
      return;
    }

    if (_regBirthDay == null ||
        _regBirthMonth == null ||
        _regBirthYear == null) {
      _showErrorSnackBar(context, "يرجى اختيار تاريخ ميلادك الكامل.");
      return;
    }

    if (!_isValidBirthDate(_regBirthYear!, _regBirthMonth!, _regBirthDay!)) {
      _showErrorSnackBar(context, "يرجى اختيار تاريخ ميلاد صحيح.");
      return;
    }

    final birthDate = DateTime(_regBirthYear!, _regBirthMonth!, _regBirthDay!);
    final age = _calculateAge(birthDate);
    if (age < 18) {
      _showErrorSnackBar(context, "يجب أن يكون العمر 18 سنة أو أكثر للتسجيل.");
      return;
    }

    if (password != confirmPassword) {
      _showErrorSnackBar(context, "كلمات المرور غير متطابقة.");
      return;
    }

    final username = _generateUsername(nickname, email);
    final success = await auth.registerEmail(
      email: email,
      password: password,
      username: username,
      displayNickname: nickname,
      age: age,
      gender: _regGender,
      avatar: _selectedRegisterAvatar,
      refCode: refCode.isEmpty ? null : refCode,
      rememberMe: _rememberMe,
    );

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("تم إنشاء حسابك بنجاح! مرحباً بك في صناديق الطمع."),
          backgroundColor: Color(0xFF06D6A0),
        ),
      );
    } else {
      _showErrorSnackBar(
          context, auth.errorMessage ?? "فشلت عملية إنشاء الحساب.");
    }
  }

  // Handle Password Recovery request
  void _submitRecoveryRequest() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final email = _forgotEmailController.text.trim();

    if (email.isEmpty) {
      _showErrorSnackBar(context, "يرجى إدخال البريد الإلكتروني أولاً.");
      return;
    }

    final mockCode = await auth.recoverPassword(email);
    if (!mounted) return;
    if (mockCode != null) {
      setState(() {
        _sentCode = mockCode;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text("تم إرسال كود التحقق. رمز التحقق الافتراضي هو: $mockCode"),
          duration: const Duration(seconds: 8),
          backgroundColor: const Color(0xFF06D6A0),
        ),
      );
    } else {
      _showErrorSnackBar(
          context, auth.errorMessage ?? "فشل إرسال كود الاستعادة.");
    }
  }

  // Handle Reset Password submit
  void _submitResetPassword() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final email = _forgotEmailController.text.trim();
    final code = _forgotCodeController.text.trim();
    final newPassword = _forgotNewPasswordController.text.trim();

    if (email.isEmpty || code.isEmpty || newPassword.isEmpty) {
      _showErrorSnackBar(context, "يرجى إدخال جميع الحقول المطلوبة.");
      return;
    }

    final success = await auth.resetPassword(email, code, newPassword);
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "تمت إعادة تعيين كلمة المرور بنجاح. يمكنك تسجيل الدخول الآن."),
          backgroundColor: Color(0xFF06D6A0),
        ),
      );
      setState(() {
        _currentState = AuthScreenState.login;
        _loginInputController.text = email;
        _loginPasswordController.clear();
      });
    } else {
      _showErrorSnackBar(
          context, auth.errorMessage ?? "فشل إعادة تعيين كلمة المرور.");
    }
  }

  // Quick Guest Login
  void _submitGuestLogin() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.loginGuest(avatar: _selectedGuestAvatar);
    if (!success && mounted) {
      _showErrorSnackBar(
          context, auth.errorMessage ?? "فشل تسجيل الدخول كضيف.");
    }
  }

  String _generateUsername(String displayNickname, String email) {
    final normalized = displayNickname
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '');
    var base = normalized.isNotEmpty
        ? normalized
        : email.split('@').first.replaceAll(RegExp(r'[^a-z0-9]+'), '');
    if (base.isEmpty) {
      base = 'player';
    }
    final suffix = math.Random().nextInt(9000) + 1000;
    return '$base$suffix';
  }

  int _calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    var age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  bool _isValidBirthDate(int year, int month, int day) {
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day;
  }

  Widget _buildAvatarSelection(
    String title,
    String selectedAvatar,
    void Function(String) onSelected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title,
            style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildAvatarChip('avatar_1', Icons.verified_rounded,
                selectedAvatar == 'avatar_1', onSelected),
            _buildAvatarChip('avatar_2', Icons.auto_awesome_rounded,
                selectedAvatar == 'avatar_2', onSelected),
            _buildAvatarChip('avatar_3', Icons.sports_esports_rounded,
                selectedAvatar == 'avatar_3', onSelected),
            _buildAvatarChip('avatar_4', Icons.flash_on_rounded,
                selectedAvatar == 'avatar_4', onSelected),
          ],
        ),
      ],
    );
  }

  Widget _buildAvatarChip(String id, IconData icon, bool selected,
      void Function(String) onSelected) {
    return GestureDetector(
      onTap: () => onSelected(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF9D4EDD).withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: selected
                  ? const Color(0xFF9D4EDD)
                  : Colors.white.withValues(alpha: 0.15),
              width: selected ? 2.2 : 1.2),
        ),
        child: Icon(icon,
            size: 30, color: selected ? const Color(0xFF9D4EDD) : Colors.white),
      ),
    );
  }

  Widget _buildSelectField<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          dropdownColor: const Color(0xFF190F2D),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          hint: Text(label, style: const TextStyle(color: Colors.white60)),
          onChanged: onChanged,
          items: items,
        ),
      ),
    );
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
                child: Text(message,
                    style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        backgroundColor: const Color(0xFFFF5E62),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: Stack(
        children: [
          // Premium animated background with floating gold coins and neon pulse
          const PremiumAuthBackground(),

          // Main view container
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24.0, vertical: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 20),
                        const GameLogoHeader(),
                        const SizedBox(height: 30),

                        // Main Form Card (Glassmorphism layout)
                        Expanded(
                          child: Center(
                            child: AnimatedSize(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              child: GlassCard(
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: _buildCurrentForm(auth),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // App Version Footer
                        const SizedBox(height: 20),
                        const Text(
                          "Greedy Box • Version 2.5.0",
                          style: TextStyle(
                              color: Colors.white30,
                              fontSize: 11,
                              letterSpacing: 1),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget rendering based on current state
  Widget _buildCurrentForm(AuthProvider auth) {
    if (auth.isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF007F))),
            SizedBox(height: 24),
            Text("جاري الاتصال بالسيرفر الآمن...",
                style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
          ],
        ),
      );
    }

    switch (_currentState) {
      case AuthScreenState.welcome:
        return _buildWelcomeView();
      case AuthScreenState.login:
        return _buildLoginView();
      case AuthScreenState.register:
        return _buildRegisterView();
      case AuthScreenState.forgotPassword:
        return _buildForgotPasswordView();
      case AuthScreenState.savedAccounts:
        return _buildSavedAccountsView(auth);
    }
  }

  // Helper gradient button builder
  Widget _buildGradientButton(
      {required String text,
      required IconData icon,
      required VoidCallback onPressed}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [Color(0xFF9D4EDD), Color(0xFFFF007F)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF007F).withValues(alpha: 0.3),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: Colors.white),
            const SizedBox(width: 8),
            Text(text,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ],
        ),
      ),
    );
  }

  // 1. WELCOME SCREEN
  Widget _buildWelcomeView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "أهلاً بك في عالم التحدي والثراء",
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          "اختر طريقة الدخول لتحدي الصناديق الذهبية",
          style: TextStyle(color: Colors.white60, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // Sign In Button
        _buildGradientButton(
          text: "تسجيل الدخول",
          icon: Icons.login_rounded,
          onPressed: () {
            setState(() {
              _currentState = AuthScreenState.login;
            });
          },
        ),
        const SizedBox(height: 16),

        // Create Account Button
        OutlinedButton(
          onPressed: () {
            setState(() {
              _currentState = AuthScreenState.register;
            });
          },
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFFF007F), width: 1.5),
            foregroundColor: const Color(0xFFFF007F),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_add_rounded, size: 20),
              SizedBox(width: 8),
              Text("إنشاء حساب جديد",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Divider
        Row(
          children: [
            Expanded(
                child: Divider(color: Colors.white.withValues(alpha: 0.15))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text("أو استكشف فوراً",
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12)),
            ),
            Expanded(
                child: Divider(color: Colors.white.withValues(alpha: 0.15))),
          ],
        ),
        const SizedBox(height: 24),

        // Guest image selection
        _buildAvatarSelection(
          "اختر صورة الزائر قبل الدخول",
          _selectedGuestAvatar,
          (avatar) => setState(() => _selectedGuestAvatar = avatar),
        ),
        const SizedBox(height: 20),

        // Play as Guest Mode
        ElevatedButton(
          onPressed: _submitGuestLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF190F2D),
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_circle_outline_rounded,
                  color: Color(0xFF06D6A0), size: 22),
              SizedBox(width: 8),
              Text("دخول سريع كزائر 🎮",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  // 2. LOGIN SCREEN
  Widget _buildLoginView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text("تسجيل الدخول للحساب",
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            textAlign: TextAlign.center),
        const SizedBox(height: 20),

        // Username / Email / ID input
        TextField(
          controller: _loginInputController,
          style: const TextStyle(color: Colors.white),
          decoration: _buildInputDecoration(
            label: "البريد الإلكتروني أو الـ ID المكون من 8 أرقام",
            icon: Icons.alternate_email_rounded,
          ),
        ),
        const SizedBox(height: 16),

        // Password input
        TextField(
          controller: _loginPasswordController,
          obscureText: _obscureLoginPassword,
          style: const TextStyle(color: Colors.white),
          decoration: _buildInputDecoration(
            label: "كلمة المرور",
            icon: Icons.lock_outline_rounded,
            suffix: IconButton(
              icon: Icon(
                _obscureLoginPassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: Colors.white60,
              ),
              onPressed: () {
                setState(() {
                  _obscureLoginPassword = !_obscureLoginPassword;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Remember Me & Forgot Password
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Checkbox(
                  value: _rememberMe,
                  activeColor: const Color(0xFFFF007F),
                  checkColor: Colors.white,
                  onChanged: (val) {
                    setState(() {
                      _rememberMe = val ?? true;
                    });
                  },
                ),
                const Text("تذكرني",
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _currentState = AuthScreenState.forgotPassword;
                });
              },
              child: const Text("نسيت كلمة المرور؟",
                  style: TextStyle(
                      color: Color(0xFFFF007F),
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Login Submit Button
        _buildGradientButton(
          text: "دخول",
          icon: Icons.login_rounded,
          onPressed: _submitLogin,
        ),
        const SizedBox(height: 16),

        // Cancel / Back Button
        TextButton(
          onPressed: () {
            setState(() {
              _currentState = AuthScreenState.welcome;
            });
          },
          child: const Text("الرجوع للقائمة الرئيسية",
              style: TextStyle(color: Colors.white38)),
        ),
      ],
    );
  }

  // 3. REGISTER SCREEN
  Widget _buildRegisterView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text("إنشاء حساب جديد",
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            textAlign: TextAlign.center),
        const SizedBox(height: 16),

        // Nickname
        TextField(
          controller: _regNicknameController,
          style: const TextStyle(color: Colors.white),
          decoration: _buildInputDecoration(
              label: "ادخل اسمك", icon: Icons.badge_outlined),
        ),
        const SizedBox(height: 12),

        // Avatar selection for new account
        _buildAvatarSelection(
          "اختر صورتك الشخصية",
          _selectedRegisterAvatar,
          (avatar) => setState(() => _selectedRegisterAvatar = avatar),
        ),
        const SizedBox(height: 12),

        // Birth date selectors
        Row(
          children: [
            Expanded(
              child: _buildSelectField<int>(
                label: "اليوم",
                value: _regBirthDay,
                items: List.generate(
                  31,
                  (index) => DropdownMenuItem<int>(
                    value: index + 1,
                    child: Text('${index + 1}',
                        style: const TextStyle(color: Colors.white)),
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _regBirthDay = val;
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSelectField<int>(
                label: "الشهر",
                value: _regBirthMonth,
                items: List.generate(
                  12,
                  (index) => DropdownMenuItem<int>(
                    value: index + 1,
                    child: Text(
                      [
                        'يناير',
                        'فبراير',
                        'مارس',
                        'أبريل',
                        'مايو',
                        'يونيو',
                        'يوليو',
                        'أغسطس',
                        'سبتمبر',
                        'أكتوبر',
                        'نوفمبر',
                        'ديسمبر',
                      ][index],
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _regBirthMonth = val;
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSelectField<int>(
                label: "السنة",
                value: _regBirthYear,
                items: List.generate(
                  81,
                  (index) {
                    final year = DateTime.now().year - 18 - index;
                    return DropdownMenuItem<int>(
                      value: year,
                      child: Text('$year',
                          style: const TextStyle(color: Colors.white)),
                    );
                  },
                ),
                onChanged: (val) {
                  setState(() {
                    _regBirthYear = val;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Gender selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _regGender,
              dropdownColor: const Color(0xFF190F2D),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _regGender = val;
                  });
                }
              },
              items: const [
                DropdownMenuItem(value: "MALE", child: Text("ذكر ♂")),
                DropdownMenuItem(value: "FEMALE", child: Text("أنثى ♀")),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Email
        TextField(
          controller: _regEmailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Colors.white),
          decoration: _buildInputDecoration(
              label: "البريد الإلكتروني", icon: Icons.email_outlined),
        ),
        const SizedBox(height: 12),

        // Password
        TextField(
          controller: _regPasswordController,
          obscureText: _obscureRegPassword,
          style: const TextStyle(color: Colors.white),
          decoration: _buildInputDecoration(
            label: "كلمة المرور",
            icon: Icons.lock_outline_rounded,
            suffix: IconButton(
              icon: Icon(
                _obscureRegPassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: Colors.white60,
              ),
              onPressed: () {
                setState(() {
                  _obscureRegPassword = !_obscureRegPassword;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Confirm Password
        TextField(
          controller: _regConfirmPasswordController,
          obscureText: _obscureRegConfirmPassword,
          style: const TextStyle(color: Colors.white),
          decoration: _buildInputDecoration(
            label: "تأكيد كلمة المرور",
            icon: Icons.lock_clock_outlined,
            suffix: IconButton(
              icon: Icon(
                _obscureRegConfirmPassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: Colors.white60,
              ),
              onPressed: () {
                setState(() {
                  _obscureRegConfirmPassword = !_obscureRegConfirmPassword;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Referral code
        TextField(
          controller: _regRefCodeController,
          style: const TextStyle(color: Colors.white),
          decoration: _buildInputDecoration(
              label: "كود الإحالة / كود الدعوة (اختياري)",
              icon: Icons.card_giftcard_rounded),
        ),
        const SizedBox(height: 12),

        // Remember me
        Row(
          children: [
            Checkbox(
              value: _rememberMe,
              activeColor: const Color(0xFFFF007F),
              checkColor: Colors.white,
              onChanged: (val) {
                setState(() {
                  _rememberMe = val ?? true;
                });
              },
            ),
            const Text("تذكرني على هذا الجهاز",
                style: TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 16),

        // Submit Button
        _buildGradientButton(
          text: "تسجيل الحساب",
          icon: Icons.person_add_rounded,
          onPressed: _submitRegister,
        ),
        const SizedBox(height: 12),

        // Back Button
        TextButton(
          onPressed: () {
            setState(() {
              _currentState = AuthScreenState.welcome;
            });
          },
          child: const Text("الرجوع للقائمة الرئيسية",
              style: TextStyle(color: Colors.white38)),
        ),
      ],
    );
  }

  // 4. FORGOT PASSWORD SCREEN
  Widget _buildForgotPasswordView() {
    final hasSentCode = _sentCode != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text("استعادة كلمة المرور",
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          hasSentCode
              ? "تم إرسال الكود. يرجى إدخال الرمز وكلمة المرور الجديدة."
              : "أدخل بريدك الإلكتروني المسجل لإرسال رمز تحقق الاستعادة.",
          style: const TextStyle(fontSize: 12, color: Colors.white60),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // Email field
        TextField(
          controller: _forgotEmailController,
          enabled: !hasSentCode,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Colors.white),
          decoration: _buildInputDecoration(
              label: "البريد الإلكتروني", icon: Icons.email_rounded),
        ),
        const SizedBox(height: 16),

        if (!hasSentCode) ...[
          _buildGradientButton(
            text: "إرسال رمز التحقق",
            icon: Icons.send_rounded,
            onPressed: _submitRecoveryRequest,
          ),
        ],

        if (hasSentCode) ...[
          // Verification code input
          TextField(
            controller: _forgotCodeController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: _buildInputDecoration(
                label: "رمز التحقق (6 أرقام)", icon: Icons.lock_clock_outlined),
          ),
          const SizedBox(height: 16),

          // New Password input
          TextField(
            controller: _forgotNewPasswordController,
            obscureText: _obscureForgotNewPassword,
            style: const TextStyle(color: Colors.white),
            decoration: _buildInputDecoration(
              label: "كلمة المرور الجديدة",
              icon: Icons.lock_outline_rounded,
              suffix: IconButton(
                icon: Icon(
                  _obscureForgotNewPassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: Colors.white60,
                ),
                onPressed: () {
                  setState(() {
                    _obscureForgotNewPassword = !_obscureForgotNewPassword;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 20),

          _buildGradientButton(
            text: "تحديث كلمة المرور والدخول",
            icon: Icons.save_rounded,
            onPressed: _submitResetPassword,
          ),
        ],

        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            setState(() {
              _sentCode = null;
              _currentState = AuthScreenState.login;
            });
          },
          child: const Text("الرجوع لتسجيل الدخول",
              style: TextStyle(color: Colors.white38)),
        ),
      ],
    );
  }

  // 5. SAVED ACCOUNTS SCREEN
  Widget _buildSavedAccountsView(AuthProvider auth) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text("الحسابات المحفوظة",
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        const Text(
          "اضغط على حسابك للدخول السريع والمباشر",
          style: TextStyle(fontSize: 12, color: Colors.white60),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: auth.savedAccounts.length,
            separatorBuilder: (context, index) =>
                const Divider(color: Colors.white12, height: 12),
            itemBuilder: (context, index) {
              final acc = auth.savedAccounts[index];
              final isGuestAcc = acc['role'] == 'GUEST';

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: CircleAvatar(
                  backgroundColor:
                      const Color(0xFF9D4EDD).withValues(alpha: 0.15),
                  child: Text(
                    (acc['displayNickname'] ?? acc['username'] ?? 'G')[0]
                        .toUpperCase(),
                    style: const TextStyle(
                        color: Color(0xFFFF007F), fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  acc['displayNickname'] ?? acc['username'] ?? "لاعب",
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("ID: ${acc['publicId']}",
                        style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                            fontFamily: "monospace")),
                    if (isGuestAcc)
                      const Text("حساب زائر مؤقت ⚠️",
                          style: TextStyle(color: Colors.amber, fontSize: 10)),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white30, size: 20),
                      onPressed: () {
                        auth.removeSavedAccount(acc['publicId']);
                      },
                    ),
                    Icon(
                        Directionality.of(context) == TextDirection.rtl
                            ? Icons.arrow_back_ios_rounded
                            : Icons.arrow_forward_ios_rounded,
                        color: const Color(0xFFFF007F),
                        size: 14),
                  ],
                ),
                onTap: () async {
                  final currentContext = context;
                  final success = await auth.loginWithSavedAccount(acc);
                  if (!currentContext.mounted) return;
                  if (!success) {
                    _showErrorSnackBar(currentContext,
                        auth.errorMessage ?? "انتهت صلاحية الحساب.");
                  }
                },
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        _buildGradientButton(
          text: "استخدم حساباً آخر",
          icon: Icons.person_search_rounded,
          onPressed: () {
            setState(() {
              _currentState = AuthScreenState.welcome;
            });
          },
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration(
      {required String label, required IconData icon, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 13),
      prefixIcon: Icon(icon, color: const Color(0xFF9D4EDD), size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFFF007F), width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
      ),
    );
  }
}

// ----------------------------------------------------
// UI COMPONENTS & BACKGROUNDS
// ----------------------------------------------------

// Premium Glassmorphism Card Container
class GlassCard extends StatelessWidget {
  final Widget child;
  const GlassCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF190F2D).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: const Color(0xFFFF007F).withValues(alpha: 0.05),
            blurRadius: 30,
            spreadRadius: 1,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: child,
      ),
    );
  }
}

// Neon Shiny Header Logo
class GameLogoHeader extends StatelessWidget {
  const GameLogoHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Shiny purple-pink chest icon representation
        Container(
          height: 80,
          width: 80,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF9D4EDD), Color(0xFFFF007F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF007F).withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 3,
                )
              ]),
          child: const Center(
            child: Icon(
              Icons.inventory_2_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Logo Text
        const Text(
          "GREEDY BOX",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 4,
            shadows: [
              Shadow(blurRadius: 10, color: Color(0xFFFF007F)),
              Shadow(blurRadius: 20, color: Color(0xFF9D4EDD)),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          "صناديق الطمع والذهب",
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.6),
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// Premium Background with floating Gold Coins and Glowing Orbs
class PremiumAuthBackground extends StatefulWidget {
  const PremiumAuthBackground({super.key});

  @override
  State<PremiumAuthBackground> createState() => _PremiumAuthBackgroundState();
}

class _PremiumAuthBackgroundState extends State<PremiumAuthBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  final List<_FloatingCoin> _coins = [];
  final _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // Create glowing orbs
    _particles.add(_Particle(
        color: const Color(0xFF9D4EDD),
        baseRadius: 120,
        xPercent: 0.1,
        yPercent: 0.2,
        speed: 0.4));
    _particles.add(_Particle(
        color: const Color(0xFFFF007F),
        baseRadius: 150,
        xPercent: 0.8,
        yPercent: 0.7,
        speed: 0.3));
    _particles.add(_Particle(
        color: const Color(0xFFE0A96D),
        baseRadius: 80,
        xPercent: 0.5,
        yPercent: 0.5,
        speed: 0.5));

    // Create floating gold coins
    for (int i = 0; i < 15; i++) {
      _coins.add(_FloatingCoin(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: 10 + _random.nextDouble() * 20,
        speed: 0.02 + _random.nextDouble() * 0.03,
        angle: _random.nextDouble() * math.pi * 2,
        rotationSpeed: 0.5 + _random.nextDouble() * 1.5,
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Update floats
        for (var coin in _coins) {
          coin.y -= coin.speed * 0.01;
          coin.angle += coin.rotationSpeed * 0.01;
          if (coin.y < -0.1) {
            coin.y = 1.1;
            coin.x = _random.nextDouble();
          }
        }
        return CustomPaint(
          painter: _BackgroundPainter(_particles, _coins, _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _Particle {
  final Color color;
  final double baseRadius;
  final double xPercent;
  final double yPercent;
  final double speed;

  _Particle(
      {required this.color,
      required this.baseRadius,
      required this.xPercent,
      required this.yPercent,
      required this.speed});
}

class _FloatingCoin {
  double x;
  double y;
  final double size;
  final double speed;
  double angle;
  final double rotationSpeed;

  _FloatingCoin(
      {required this.x,
      required this.y,
      required this.size,
      required this.speed,
      required this.angle,
      required this.rotationSpeed});
}

class _BackgroundPainter extends CustomPainter {
  final List<_Particle> particles;
  final List<_FloatingCoin> coins;
  final double animValue;

  _BackgroundPainter(this.particles, this.coins, this.animValue);

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background base gradient
    final rect = Offset.zero & size;
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF070210), Color(0xFF130728), Color(0xFF0C031A)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // Draw glowing orbs
    for (var p in particles) {
      final pX = size.width * p.xPercent +
          math.sin(animValue * math.pi * 2 * p.speed) * 40;
      final pY = size.height * p.yPercent +
          math.cos(animValue * math.pi * 2 * p.speed) * 40;
      final radius = p.baseRadius + math.sin(animValue * math.pi * 2) * 15;

      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            p.color.withValues(alpha: 0.35),
            p.color.withValues(alpha: 0.05),
            Colors.transparent
          ],
        ).createShader(Rect.fromCircle(center: Offset(pX, pY), radius: radius));

      canvas.drawCircle(Offset(pX, pY), radius, glowPaint);
    }

    // Draw gold coin vectors floating
    final coinPaint = Paint()..style = PaintingStyle.fill;
    for (var coin in coins) {
      final cx = size.width * coin.x;
      final cy = size.height * coin.y;

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(coin.angle);

      // Outer gold circle with glow
      final shadowRect = Rect.fromCenter(
          center: Offset.zero, width: coin.size, height: coin.size);
      coinPaint.shader = RadialGradient(
        colors: [
          const Color(0xFFFFD700),
          const Color(0xFFFFB703).withValues(alpha: 0.8),
          Colors.transparent
        ],
      ).createShader(shadowRect);
      canvas.drawCircle(Offset.zero, coin.size * 0.6, coinPaint);

      // Inner shiny metal circle
      coinPaint.shader = null;
      coinPaint.color = const Color(0xFFFFB703);
      canvas.drawCircle(Offset.zero, coin.size * 0.45, coinPaint);

      // Central symbol ($ sign or simple treasure block)
      coinPaint.color = const Color(0xFFD4AF37);
      canvas.drawRect(
          Rect.fromCenter(
              center: Offset.zero,
              width: coin.size * 0.15,
              height: coin.size * 0.45),
          coinPaint);
      canvas.drawRect(
          Rect.fromCenter(
              center: Offset.zero,
              width: coin.size * 0.45,
              height: coin.size * 0.15),
          coinPaint);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
