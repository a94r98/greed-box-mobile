import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../config.dart';

class AuthLandingPage extends StatefulWidget {
  const AuthLandingPage({super.key});

  @override
  State<AuthLandingPage> createState() => _AuthLandingPageState();
}

class _AuthLandingPageState extends State<AuthLandingPage> {
  bool _isLoginMode = true;
  
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _refCodeController = TextEditingController();

  void _showSettingsDialog() {
    final controller = TextEditingController(text: AppConfig.baseUrl);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("إعدادات الخادم"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("يمكنك تعديل عنوان الخادم للاتصال المحلي أو الخارجي:"),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: "رابط الخادم",
                  border: OutlineInputBorder(),
                  hintText: "http://192.168.1.X:4000",
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("إلغاء"),
            ),
            ElevatedButton(
              onPressed: () async {
                final url = controller.text.trim();
                if (url.isNotEmpty) {
                  await AppConfig.setBaseUrl(url);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("تم تغيير عنوان الخادم إلى: $url")),
                    );
                  }
                }
              },
              child: const Text("حفظ"),
            ),
          ],
        );
      },
    );
  }

  void _submitAuth() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    bool success = false;

    if (_isLoginMode) {
      success = await auth.loginEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
    } else {
      success = await auth.registerEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _usernameController.text.trim(),
        _refCodeController.text.trim().isEmpty ? null : _refCodeController.text.trim(),
      );
    }

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? "حدث خطأ ما."),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _guestLogin() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.loginGuest();
    
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? "فشل الدخول السريع كزائر."),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black54),
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Neon Styled Logo title
              Text(
                "صناديق الطمع",
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).primaryColor,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                "GREED BOXES GAME",
                style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Inputs for Register / Login
              if (!_isLoginMode) ...[
                TextField(
                  controller: _usernameController,
                  style: const TextStyle(color: Colors.black87),
                  decoration: const InputDecoration(
                    labelText: "اسم اللاعب",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_rounded),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.black87),
                decoration: const InputDecoration(
                  labelText: "البريد الإلكتروني",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_rounded),
                ),
              ),
              const SizedBox(height: 16),
              
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.black87),
                decoration: const InputDecoration(
                  labelText: "كلمة المرور",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_rounded),
                ),
              ),
              
              if (!_isLoginMode) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _refCodeController,
                  style: const TextStyle(color: Colors.black87),
                  decoration: const InputDecoration(
                    labelText: "كود الدعوة (اختياري)",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.card_giftcard_rounded),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              
              auth.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _submitAuth,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        _isLoginMode ? "تسجيل الدخول" : "إنشاء حساب جديد",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
              
              const SizedBox(height: 12),
              
              TextButton(
                onPressed: () {
                  setState(() {
                    _isLoginMode = !_isLoginMode;
                  });
                },
                child: Text(
                  _isLoginMode ? "ليس لديك حساب؟ سجل الآن" : "لديك حساب بالفعل؟ سجل دخولك",
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
              
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text("أو", style: TextStyle(color: Colors.grey)),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
              ),

              // Play as Guest quick action button
              OutlinedButton(
                onPressed: _guestLogin,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.black12),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  "دخول سريع كزائر 🎮",
                  style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
