import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

// --- USER MODEL ---
class User {
  String firstName;
  String lastName;
  String mobileNumber;
  String dob;
  String email;
  String password;
  String schoolName;
  String role;
  String? id;

  User({
    required this.firstName,
    required this.lastName,
    required this.mobileNumber,
    required this.dob,
    required this.email,
    required this.password,
    required this.schoolName,
    required this.role,
    this.id,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      mobileNumber: json['mobileNumber'],
      dob: json['dob'],
      email: json['email'],
      password: '',
      schoolName: json['schoolName'],
      role: json['role'],
    );
  }

 

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'mobileNumber': mobileNumber,
      // Some backends expect 'phone' instead of 'mobileNumber'. Send both.
      'phone': mobileNumber,
      'dob': dob,
      'email': email,
      'password': password,
      'schoolName': schoolName,
      'role': role,
    };
  }

  // API base URL
  // Priority:
  // 1) --dart-define=API_BASE_URL=... (e.g., your LAN IP for physical device)
  // 2) Android emulator default: http://10.0.2.2:3000
  // 3) Desktop/iOS simulator default: http://localhost:3000
  static String? _runtimeBaseUrl; // set at runtime from app UI
  static void setRuntimeBaseUrl(String url) {
    _runtimeBaseUrl = url.trim();
  }
  static String get _baseUrl {
    if (_runtimeBaseUrl != null && _runtimeBaseUrl!.isNotEmpty) return _runtimeBaseUrl!;
    const fromDefine = String.fromEnvironment('API_BASE_URL');
    if (fromDefine.isNotEmpty) return fromDefine;
    if (Platform.isAndroid) return 'http://10.0.2.2:3000';
    return 'http://localhost:3000';
  }

  static Future<bool> doesEmailExist(String email) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/check-email'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'email': email}),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['exists'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> doesPhoneExist(String phone) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/check-phone'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'phone': phone}),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['exists'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> createUser(User newUser) async {
    try {
      // Primary attempt: /api/users
      var response = await http
          .post(
            Uri.parse('$_baseUrl/api/users'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(newUser.toJson()),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 201) return true;

      // If endpoint not found or method not allowed, try fallback /users
      if (response.statusCode == 404 || response.statusCode == 405) {
        response = await http
            .post(
              Uri.parse('$_baseUrl/users'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(newUser.toJson()),
            )
            .timeout(const Duration(seconds: 10));
        if (response.statusCode == 201) return true;
      }
      // Debug logging to help diagnose signup failures
      // ignore: avoid_print
      print('Signup failed: status=${response.statusCode} body=${response.body}');
      return false;
    } catch (e) {
      return false;
    }
  }

  // Returns null on success, or a human-readable error message from backend/exception on failure
  static Future<String?> createUserDetailed(User newUser) async {
    try {
      var response = await http
          .post(
            Uri.parse('$_baseUrl/api/users'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(newUser.toJson()),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 201) return null;
      if (response.statusCode == 404 || response.statusCode == 405) {
        response = await http
            .post(
              Uri.parse('$_baseUrl/users'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(newUser.toJson()),
            )
            .timeout(const Duration(seconds: 10));
        if (response.statusCode == 201) return null;
      }
      final body = response.body;
      return body.isNotEmpty ? body : 'Signup failed with status ${response.statusCode}';
    } catch (e) {
      return 'Signup error: $e';
    }
  }

  static Future<User?> login(String identifier, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/login'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'identifier': identifier, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final userMap = data['user'];
        return User(
          firstName: userMap['firstName'],
          lastName: userMap['lastName'],
          mobileNumber: userMap['mobileNumber'],
          dob: userMap['dob'],
          email: userMap['email'],
          password: password,
          schoolName: userMap['schoolName'],
          role: userMap['role'],
          id: userMap['_id'],
        );
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> resetPassword(String phone, String newPassword) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/reset-password'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'phone': phone, 'newPassword': newPassword}),
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

// --- AUTH SERVICE SHIM (routes calls to User static methods) ---
class _AuthService {
  static String get _baseUrl => User._baseUrl;

  static Future<bool> doesEmailExist(String email) =>
      User.doesEmailExist(email);

  static Future<bool> doesPhoneExist(String phone) =>
      User.doesPhoneExist(phone);

  static Future<bool> createUser(User newUser) =>
      User.createUser(newUser);

  static Future<User?> login(String identifier, String password) =>
      User.login(identifier, password);

  static Future<bool> resetPassword(String phone, String newPassword) =>
      User.resetPassword(phone, newPassword);


      // Returns null on success, or a human-readable error message on failure
static Future<String?> createUserDetailed(User newUser) async {
  try {
    // Try /api/users first
    var response = await http
        .post(
          Uri.parse('$_baseUrl/api/users'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(newUser.toJson()),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 201) return null;

    // Fallback /users if /api/users not found or method not allowed
    if (response.statusCode == 404 || response.statusCode == 405) {
      response = await http
          .post(
            Uri.parse('$_baseUrl/users'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(newUser.toJson()),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 201) return null;
    }

    final body = response.body;
    return body.isNotEmpty ? body : 'Signup failed with status ${response.statusCode}';
  } catch (e) {
    return 'Signup error: $e';
  }
}

  // Lightweight reachability check that does NOT require a specific /health endpoint.
  // Accepts any 2xx-4xx status as "reachable" to avoid false negatives when the
  // endpoint path differs.
  static Future<bool> ping() async {
    final String base = _baseUrl;
    final List<Uri> candidates = [
      // Try common health route
      Uri.parse(base.endsWith('/') ? '${base}health' : '$base/health'),
      // Try base URL (may return 404, still means server reachable)
      Uri.parse(base),
    ];
    for (final uri in candidates) {
      try {
        final res = await http.get(uri).timeout(const Duration(seconds: 3));
        if (res.statusCode >= 200 && res.statusCode < 500) return true;
      } catch (_) {}
    }
    // Fallback: quick POST to /login (will likely return 400/401 if reachable)
    try {
      final res = await http
          .post(
            Uri.parse(base.endsWith('/') ? '${base}login' : '$base/login'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'identifier': 'ping', 'password': 'ping'}),
          )
          .timeout(const Duration(seconds: 3));
      if (res.statusCode >= 200 && res.statusCode < 500) return true;
    } catch (_) {}
    return false;
  }
}

// --- CENTRALIZED CONSTANTS ---
class AppColors {
  static const Color primary = Color(0xFF0D47A1);
  static const Color primaryLight = Colors.orange;
  static const Color secondary = Color(0xFF42A5F5);
  static const Color background = Colors.white;
  static const Color cardBackground = Colors.white;
  static const Color textPrimary = Color(0xFF0D47A1);
  static const Color textSecondary = Color(0xFF42A5F5);
  static const Color accentGold = Colors.amber;
  static const Color accentGreen = Colors.green;
  static const Color accentOrange = Colors.orange;
  static const Color accentRed = Colors.red;
}

class AppRoutes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot_password';
  static const String otpVerification = '/otp_verification';
  static const String createNewPassword = '/create_new_password';
  static const String home = '/';
  static const String about = '/about';
  static const String contact = '/contact';
  static const String playLearn = '/playLearn';
  static const String myBadges = '/myBadges';
  static const String toolkit = '/toolkit';
  static const String schoolDrills = '/schoolDrills';
  static const String weather = '/weather';
  static const String virtualMap = '/virtualMap';
  static const String help = '/help';
}

// --- MAIN APPLICATION SETUP ---
void main() {
  // TEMP: force LAN API for physical device
  User.setRuntimeBaseUrl('http://10.47.124.171:3000');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sankalp App',
      theme: ThemeData(
        fontFamily: 'Poppins',
        primarySwatch: Colors.blue,
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
      ),
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash: (context) => const SplashScreen(),
        AppRoutes.login: (context) => const LoginScreen(),
        AppRoutes.signup: (context) => const SignUpScreen(),
        AppRoutes.forgotPassword: (context) => const ForgotPasswordScreen(),
        AppRoutes.otpVerification: (context) => OtpVerificationScreen(
          phoneNumber: ModalRoute.of(context)!.settings.arguments as String,
        ),
        AppRoutes.createNewPassword: (context) => CreateNewPasswordScreen(
          phoneNumber: ModalRoute.of(context)!.settings.arguments as String,
        ),
        // Shared screens for Student role grid shortcuts
        AppRoutes.playLearn: (context) => const PlayLearnScreen(),
        AppRoutes.myBadges: (context) => const MyBadgesScreen(),
        AppRoutes.toolkit: (context) => const EmergencyToolkitScreen(),
        AppRoutes.schoolDrills: (context) => const DrillsStudentScreen(),
        AppRoutes.weather: (context) => const WeatherScreen(),
        AppRoutes.virtualMap: (context) => const VirtualMapScreen(),
        AppRoutes.help: (context) => const HelpScreen(),
        // Informational routes
        AppRoutes.about: (context) => const AboutUsScreen(),
        AppRoutes.contact: (context) => const ContactUsScreen(),
      },
    );
  }
}

// --- WIDGET: SPLASH SCREEN ---
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _textController;
  late final Animation<double> _animation;
  String _displayedText = '';
  final String _fullText = 'SANKALP';
  final int _totalDuration = 3;
  late final Duration _letterDuration;

  @override
  void initState() {
    super.initState();
    _letterDuration = Duration(milliseconds: (_totalDuration * 1000) ~/ _fullText.length);

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _animation = CurvedAnimation(
      parent: _textController,
      curve: Curves.easeIn,
    );

    _animateText();
  }

  void _animateText() async {
    for (int i = 0; i < _fullText.length; i++) {
      await Future.delayed(_letterDuration, () {
        if (!mounted) return;
        setState(() {
          _displayedText += _fullText[i];
        });
      });
    }

    if (!mounted) return;
    _textController.forward();
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    _navigateToLogin();
  }

  void _navigateToLogin() {
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepOrange,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: const [
                Icon(
                  Icons.shield_rounded,
                  size: 100,
                  color: Colors.white,
                ),
                Icon(
                  Icons.local_fire_department_rounded,
                  size: 60,
                  color: Colors.red,
                ),
                Icon(
                  Icons.personal_injury_rounded,
                  size: 60,
                  color: Colors.white,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              _displayedText,
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 10),
            if (_displayedText.length == _fullText.length)
              FadeTransition(
                opacity: _animation,
                child: const Text(
                  'Be a Disaster Hero',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --- WIDGET: LOGIN SCREEN ---
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordObscured = true;
  bool _isLoading = false;

  Future<bool> _isBackendReachable() => _AuthService.ping();

  Future<void> _login() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      final user = await _AuthService.login(
        _identifierController.text.trim(),
        _passwordController.text.trim(),
      );

      if (!mounted) return;

      setState(() => _isLoading = false);

      if (user != null) {
        if (user.role == 'student') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => StudentHomeScreen(user: user)),
          );
        } else if (user.role == 'staff') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => StaffHomeScreen(user: user)),
          );
        } else if (user.role == 'authority') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => AuthorityHomeScreen(user: user)),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => SankalpHomeScreen(user: user)),
          );
        }
      } else {
        final base = _AuthService._baseUrl;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed. Check credentials or server at $base'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepOrange,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text(
                    'Welcome to SANKALP',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your safety companion.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  const SizedBox(height: 48),
                  TextFormField(
                    controller: _identifierController,
                    enableInteractiveSelection: false,
                    keyboardType: TextInputType.text,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Email or Phone Number',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email or phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _isPasswordObscured,
                    enableInteractiveSelection: false,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(_isPasswordObscured
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => _isPasswordObscured = !_isPasswordObscured),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.deepOrange,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.deepOrange)
                        : const Text(
                      'Login',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account?",
                          style: TextStyle(color: Colors.white)),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.signup),
                        child: const Text('Sign Up',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  Container(
                    alignment: Alignment.center,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.forgotPassword);
                      },
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'API: ' + _AuthService._baseUrl,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
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

// --- WIDGET: SIGN UP SCREEN ---
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _dobController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _schoolController = TextEditingController();

  bool _isPasswordObscured = true;
  bool _isLoading = false;
  DateTime? _selectedDate;
  String? _selectedRole;

  Future<bool> _isBackendReachable() => _AuthService.ping();

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _signUp() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isLoading = true);
    final email = _emailController.text.trim();
    final phone = _mobileController.text.trim();

    final emailExists = await _AuthService.doesEmailExist(email);
    if (!mounted) return;
    if (emailExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This email is already registered.'), backgroundColor: Colors.red),
      );
      setState(() => _isLoading = false);
      return;
    }

    final phoneExists = await _AuthService.doesPhoneExist(phone);
    if (!mounted) return;
    if (phoneExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This phone number is already registered.'), backgroundColor: Colors.red),
      );
      setState(() => _isLoading = false);
      return;
    }

    final newUser = User(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      mobileNumber: phone,
      dob: DateFormat('yyyy-MM-dd').format(_selectedDate!),
      email: email,
      password: _passwordController.text.trim(),
      schoolName: _schoolController.text.trim(),
      role: _selectedRole!,
    );
    final err = await _AuthService.createUserDetailed(newUser);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (err == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign up successful! Please log in.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      final msg = err.length > 200 ? err.substring(0, 200) + '…' : err;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign up failed: $msg'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _mobileController.dispose();
    _dobController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _schoolController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepOrange,
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTextFormField(controller: _firstNameController, label: 'First Name'),
                const SizedBox(height: 16),
                _buildTextFormField(controller: _lastNameController, label: 'Last Name'),
                const SizedBox(height: 16),
                _buildTextFormField(
                  controller: _mobileController,
                  label: 'Mobile Number',
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter your mobile number';
                    if (value.length != 10) return 'Mobile number must be 10 digits';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _dobController,
                  readOnly: true,
                  enableInteractiveSelection: false,
                  decoration: _inputDecoration('Date of Birth'),
                  onTap: () => _selectDate(context),
                  validator: (value) => value == null || value.isEmpty ? 'Please select your date of birth' : null,
                ),
                const SizedBox(height: 16),
                _buildTextFormField(
                  controller: _emailController,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter your email';
                    if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value)) return 'Please enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _isPasswordObscured,
                  enableInteractiveSelection: false,
                  decoration: _inputDecoration('Password').copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_isPasswordObscured ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                      onPressed: () => setState(() => _isPasswordObscured = !_isPasswordObscured),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d).{8,}$').hasMatch(value)) {
                      return 'Password must contain letters and numbers';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildTextFormField(controller: _schoolController, label: 'School/College Name'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: _inputDecoration('Role'),
                  items: ['student', 'staff', 'authority']
                      .map((role) => DropdownMenuItem(
                    value: role,
                    child: Text(role[0].toUpperCase() + role.substring(1)),
                  ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedRole = value;
                    });
                  },
                  validator: (value) => value == null ? 'Please select a role' : null,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _signUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.deepOrange,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.deepOrange)
                      : const Text('Sign Up', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                Text(
                  'API: ' + _AuthService._baseUrl,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  TextFormField _buildTextFormField({required TextEditingController controller, required String label, TextInputType keyboardType = TextInputType.text, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enableInteractiveSelection: false,
      decoration: _inputDecoration(label),
      validator: validator ?? (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your $label';
        }
        return null;
      },
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      labelText: label,
      border: OutlineInputBorder(
        borderSide: BorderSide.none,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

// --- WIDGET: FORGOT PASSWORD SCREEN ---
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  bool _isLoading = false;

  Future<void> _sendOtp() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      final phone = _mobileController.text.trim();

      final phoneExists = await _AuthService.doesPhoneExist(phone);
      if (!mounted) return;

      setState(() => _isLoading = false);

      if (phoneExists) {
        Navigator.pushNamed(context, AppRoutes.otpVerification, arguments: phone);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Simulated OTP (123456) sent to your number.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This phone number is not registered.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _mobileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepOrange,
      appBar: AppBar(
        title: const Text('Reset Password'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Enter your registered phone number to receive a verification code.',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  enableInteractiveSelection: false,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    labelText: 'Mobile Number',
                    border: OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your mobile number';
                    }
                    if (value.length != 10) {
                      return 'Mobile number must be 10 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _sendOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.deepOrange,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.deepOrange)
                      : const Text('Send OTP',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- WIDGET: OTP VERIFICATION SCREEN ---
class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  const OtpVerificationScreen({super.key, required this.phoneNumber});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<TextEditingController> _controllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 6; i++) {
      _controllers[i].addListener(() {
        if (_controllers[i].text.length == 1 && i < 5) {
          _focusNodes[i+1].requestFocus();
        }
      });
    }
  }

  void _verifyOtp() {
    final otp = _controllers.map((controller) => controller.text).join();
    if (otp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the complete 6-digit OTP.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (otp == '123456') {
        if (!mounted) return;
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.createNewPassword,
          arguments: widget.phoneNumber,
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid OTP. Please try again.'), backgroundColor: Colors.red),
        );
      }
    });
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepOrange,
      appBar: AppBar(
        title: const Text('Enter OTP'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter the 6-digit code sent to\n+91 ${widget.phoneNumber}',
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Form(
                key: _formKey,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(6, (index) {
                    return SizedBox(
                      width: 45,
                      height: 55,
                      child: TextFormField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        enableInteractiveSelection: false,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (value) {
                          if (value.isEmpty && index > 0) {
                            _focusNodes[index - 1].requestFocus();
                          }
                        },
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _verifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.deepOrange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.deepOrange)
                    : const Text('Verify',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- WIDGET: CREATE NEW PASSWORD SCREEN ---
class CreateNewPasswordScreen extends StatefulWidget {
  final String phoneNumber;
  const CreateNewPasswordScreen({super.key, required this.phoneNumber});

  @override
  State<CreateNewPasswordScreen> createState() => _CreateNewPasswordScreenState();
}

class _CreateNewPasswordScreenState extends State<CreateNewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;
  bool _isLoading = false;

  Future<void> _resetPassword() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);

      final success = await _AuthService.resetPassword(
        widget.phoneNumber,
        _passwordController.text,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password has been reset successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.login, (Route<dynamic> route) => false
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An error occurred. Could not reset password.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepOrange,
      appBar: AppBar(
        title: const Text('Create New Password'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Please create a new password for your account.',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _isPasswordObscured,
                  enableInteractiveSelection: false,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    labelText: 'New Password',
                    border: OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(_isPasswordObscured ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                      onPressed: () => setState(() => _isPasswordObscured = !_isPasswordObscured),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter a password';
                    if (value.length < 8) return 'Password must be at least 8 characters';
                    if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d).{8,}$').hasMatch(value)) {
                      return 'Password must contain letters and numbers';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _isConfirmPasswordObscured,
                  enableInteractiveSelection: false,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    labelText: 'Confirm New Password',
                    border: OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(_isConfirmPasswordObscured ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                      onPressed: () => setState(() => _isConfirmPasswordObscured = !_isConfirmPasswordObscured),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please confirm your password';
                    if (value != _passwordController.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _resetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.deepOrange,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.deepOrange)
                      : const Text('Reset Password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- REUSABLE PLACEHOLDER SCREEN ---
class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Text(
          'Welcome to the $title section!',
          style: const TextStyle(fontSize: 24, color: AppColors.textPrimary),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// --- NAVIGATION DRAWER WIDGET ---
class SankalpAppDrawer extends StatelessWidget {
  final User user;
  const SankalpAppDrawer({super.key, required this.user});

  void _navigateTo(BuildContext context, String routeName) {
    Navigator.pop(context);
    Navigator.pushNamed(context, routeName);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: const BoxDecoration(color: AppColors.primaryLight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${user.firstName} ${user.lastName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'SANKALP Menu',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit Profile'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => EditProfileScreen(user: user)));
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About Us'),
            onTap: () => _navigateTo(context, AppRoutes.about),
          ),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: const Text('Contact Us'),
            onTap: () => _navigateTo(context, AppRoutes.contact),
          ),
          ListTile(
            leading: const Icon(Icons.wb_sunny_outlined),
            title: const Text('Weather'),
            onTap: () => _navigateTo(context, AppRoutes.weather),
          ),
          ListTile(
            leading: const Icon(Icons.map_outlined),
            title: const Text('Virtual Map'),
            onTap: () => _navigateTo(context, AppRoutes.virtualMap),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help'),
            onTap: () => _navigateTo(context, AppRoutes.help),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () {
              Navigator.of(context).pushNamedAndRemoveUntil(
                  AppRoutes.login, (Route<dynamic> route) => false);
            },
          ),
        ],
      ),
    );
  }
}

// --- DEFAULT HOME (fallback) ---
class SankalpHomeScreen extends StatefulWidget {
  final User user;
  const SankalpHomeScreen({super.key, required this.user});

  @override
  State<SankalpHomeScreen> createState() => _SankalpHomeScreenState();
}

class _SankalpHomeScreenState extends State<SankalpHomeScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    HomeTab(),
    PlaceholderScreen(title: 'Profile'),
    PlaceholderScreen(title: 'Settings'),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryLight,
        elevation: 0,
        title: const Text('SANKALP',
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: SankalpAppDrawer(user: widget.user),
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: AppColors.primary,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

// --- HOME TAB CONTENT (DEFAULT GRID) ---
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: <Widget>[
            const SizedBox(height: 10),
            const Text(
              'Be a Disaster Hero - Learn, Play, Stay Safe!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 30),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                physics: const BouncingScrollPhysics(),
                children: <Widget>[
                  FeatureCard(
                    iconData: Icons.gamepad_rounded,
                    label: 'Play & Learn',
                    iconColor: AppColors.primaryLight,
                    routeName: AppRoutes.playLearn,
                  ),
                  FeatureCard(
                    iconData: Icons.star_rounded,
                    label: 'My Badges',
                    iconColor: AppColors.accentGold,
                    routeName: AppRoutes.myBadges,
                  ),
                  FeatureCard(
                    label: 'Emergency Toolkit',
                    customIcon: const SosIcon(),
                    routeName: AppRoutes.toolkit,
                  ),
                  FeatureCard(
                    iconData: Icons.calendar_today_rounded,
                    label: 'School Drills',
                    iconColor: AppColors.primaryLight,
                    routeName: AppRoutes.schoolDrills,
                  ),
                  FeatureCard(
                    iconData: Icons.wb_sunny_rounded,
                    label: 'Weather',
                    iconColor: AppColors.accentOrange,
                    routeName: AppRoutes.weather,
                  ),
                  FeatureCard(
                    iconData: Icons.help_outline_rounded,
                    label: 'Help',
                    iconColor: Colors.deepPurple,
                    routeName: AppRoutes.help,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- REUSABLE FEATURE CARD & CUSTOM ICON ---
class FeatureCard extends StatelessWidget {
  final String label;
  final IconData? iconData;
  final Color? iconColor;
  final Widget? customIcon;
  final String? routeName;
  final VoidCallback? onTapAction;

  const FeatureCard({
    super.key,
    required this.label,
    this.iconData,
    this.iconColor,
    this.customIcon,
    this.routeName,
    this.onTapAction,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          if (onTapAction != null) {
            onTapAction!();
          } else if (routeName != null) {
            Navigator.pushNamed(context, routeName!);
          }
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            customIcon ??
                Icon(iconData, size: 50, color: iconColor),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class SosIcon extends StatelessWidget {
  const SosIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: const BoxDecoration(
        color: AppColors.accentRed,
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Text(
          'SOS',
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// ================== ROLE: STUDENT ==================
class StudentHomeScreen extends StatefulWidget {
  final User user;
  const StudentHomeScreen({super.key, required this.user});
  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  int _index = 0;
  final _tabs = const [
    StudentHomeTab(),
    StudentProfileTab(),
    StudentSettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryLight,
        title: const Text('SANKALP - Student', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Profile',
            onPressed: () async {
              final updated = await Navigator.push<User>(context, MaterialPageRoute(builder: (_) => EditProfileScreen(user: widget.user)));
              if (updated != null) {
                setState(() {
                  // Replace tabs with updated user in Drawer via widget.user
                  // Easiest: recreate screen by pushing replacement, but here we just mutate local instance
                  widget.user.firstName = updated.firstName;
                  widget.user.lastName = updated.lastName;
                  widget.user.email = updated.email;
                  widget.user.mobileNumber = updated.mobileNumber;
                  widget.user.schoolName = updated.schoolName;
                });
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Help',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.help),
          ),
        ],
      ),
      drawer: SankalpAppDrawer(user: widget.user),
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class StudentHomeTab extends StatelessWidget {
  const StudentHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            FeatureCard(label: 'Play & Learn', iconData: Icons.extension_rounded, iconColor: AppColors.primaryLight,
                onTapAction: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PlayLearnScreen()))),
            FeatureCard(label: 'My Badges', iconData: Icons.emoji_events_rounded, iconColor: AppColors.accentGold,
                onTapAction: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MyBadgesScreen()))),
            FeatureCard(label: 'Emergency Toolkit', customIcon: const SosIcon(),
                onTapAction: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EmergencyToolkitScreen()))),
            FeatureCard(label: 'School Drills', iconData: Icons.campaign_rounded, iconColor: AppColors.primaryLight,
                onTapAction: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DrillsStudentScreen()))),
            FeatureCard(label: 'Weather', iconData: Icons.wb_sunny_rounded, iconColor: AppColors.accentOrange,
                onTapAction: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const WeatherScreen()))),
            FeatureCard(label: 'Help', iconData: Icons.help_outline_rounded, iconColor: Colors.deepPurple,
                onTapAction: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HelpScreen()))),
          ],
        ),
      ),
    );
  }
}

class StudentProfileTab extends StatelessWidget {
  const StudentProfileTab({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Profile details of current user'));
  }
}

class StudentSettingsTab extends StatelessWidget {
  const StudentSettingsTab({super.key});
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        SwitchListTile(value: true, onChanged: null, title: Text('Notifications')),
        SwitchListTile(value: false, onChanged: null, title: Text('Dark Mode')),
        ListTile(title: Text('About'), subtitle: Text('Sankalp v1.0.0')),
      ],
    );
  }
}

// Split screen for Play & Learn
class PlayLearnScreen extends StatelessWidget {
  const PlayLearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Play & Learn'), backgroundColor: AppColors.primaryLight, foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.videogame_asset_rounded),
                label: const Text('Play', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const GameHubScreen())),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.menu_book_rounded),
                label: const Text('Learn', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LearnDisastersScreen())),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Game hub + Quiz MVP
class GameHubScreen extends StatelessWidget {
  const GameHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Games'), backgroundColor: AppColors.primaryLight, foregroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.quiz_rounded),
            title: const Text('Earthquake Basics Quiz'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const QuizScreen(disasterType: 'earthquake'))),
          ),
          ListTile(
            leading: const Icon(Icons.quiz_outlined),
            title: const Text('Flood Safety Quiz'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const QuizScreen(disasterType: 'flood'))),
          ),
          ListTile(
            leading: const Icon(Icons.quiz_outlined),
            title: const Text('Fire Safety Quiz'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const QuizScreen(disasterType: 'fire'))),
          ),
          ListTile(
            leading: const Icon(Icons.quiz_outlined),
            title: const Text('Cyclone & Storm Quiz'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const QuizScreen(disasterType: 'cyclone'))),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.memory_rounded),
            title: const Text('Memory Match (Coming Soon)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ComingSoonScreen(title: 'Memory Match'))),
          ),
          ListTile(
            leading: const Icon(Icons.drag_indicator_rounded),
            title: const Text('Drag & Drop Classification (Coming Soon)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ComingSoonScreen(title: 'Drag & Drop Classification'))),
          ),
        ],
      ),
    );
  }
}

class QuizScreen extends StatefulWidget {
  final String disasterType;
  const QuizScreen({super.key, required this.disasterType});
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  // Unique banks by disaster type. Fallback to 'general' and combined pool as needed.
  static const Map<String, List<Map<String, dynamic>>> _banks = {
    'earthquake': [
      {'q': 'During an earthquake, the safest action is:', 'options': ['Run outside immediately', 'Drop, Cover, and Hold On', 'Stand near windows', 'Use the elevator'], 'answer': 1},
      {'q': 'What should you turn off after an earthquake if you smell gas?', 'options': ['Electricity', 'Water', 'Gas supply', 'Internet'], 'answer': 2},
      {'q': 'What does “Drop, Cover, Hold On” refer to?', 'options': ['Flood response', 'Earthquake safety', 'Fire drill', 'Heatwave'], 'answer': 1},
      {'q': 'After a quake, check for:', 'options': ['Social media first', 'Injuries and hazards', 'New movies', 'Nothing'], 'answer': 1},
      {'q': 'For tsunami warnings after a big quake near coast:', 'options': ['Go to the beach', 'Move to higher ground', 'Wait at sea level', 'Swim'], 'answer': 1},
    ],
    'flood': [
      {'q': 'Flood safety: What should you avoid driving through?', 'options': ['Shallow puddles', 'Floodwaters', 'Dry roads', 'Bridges'], 'answer': 1},
      {'q': 'Best action during flash flood warnings:', 'options': ['Go to low areas', 'Move to higher ground', 'Wait it out in basement', 'Swim'], 'answer': 1},
      {'q': 'After a flood, avoid:', 'options': ['Floodwaters', 'Bottled water', 'Checking gas leaks', 'Listening to authorities'], 'answer': 0},
      {'q': 'If trapped in a car in rising water:', 'options': ['Drive fast', 'Abandon car and move to higher ground if safe', 'Open windows and wait', 'Call friends only'], 'answer': 1},
    ],
    'fire': [
      {'q': 'In a fire, you should:', 'options': ['Use elevator', 'Crawl low under smoke', 'Open all windows', 'Hide'], 'answer': 1},
      {'q': 'What to use for small kitchen grease fire?', 'options': ['Water', 'Lid to smother', 'Open door', 'Fan it'], 'answer': 1},
      {'q': 'If clothes catch fire:', 'options': ['Run fast', 'Stop, Drop, and Roll', 'Jump in place', 'Use fan'], 'answer': 1},
      {'q': 'Best way to plan evacuation at home:', 'options': ['No plan', 'Draw floor plan and practice', 'Hide plan', 'Only call neighbors'], 'answer': 1},
    ],
    'cyclone': [
      {'q': 'Cyclone preparation includes:', 'options': ['Ignoring alerts', 'Securing loose items outdoors', 'Leaving pets unattended', 'None'], 'answer': 1},
      {'q': 'During cyclone warnings you should:', 'options': ['Go sightseeing', 'Follow official instructions', 'Open all doors and windows', 'Ignore radio'], 'answer': 1},
      {'q': 'Storm surge means:', 'options': ['Strong wind only', 'Abnormal rise of sea level', 'Small waves', 'No risk'], 'answer': 1},
    ],
    'general': [
      {'q': 'Which item belongs in an emergency kit?', 'options': ['Candles only', 'Whistle and flashlight', 'Perishable food', 'None'], 'answer': 1},
      {'q': 'Where is the safest place to shelter during a tornado?', 'options': ['Near windows', 'Basement or interior room', 'Top floor', 'Car'], 'answer': 1},
      {'q': 'Best place to store emergency water is:', 'options': ['Open bucket', 'Sealed containers', 'Bathtub always filled', 'Garden hose'], 'answer': 1},
      {'q': 'Who to call for emergencies in India?', 'options': ['100/112', '900', '411', '808'], 'answer': 0},
      {'q': 'Evacuation bag should include:', 'options': ['Important documents', 'TV remote', 'Large mirror', 'Garden tools'], 'answer': 0},
      {'q': 'During lightning, avoid:', 'options': ['Open fields', 'Staying indoors', 'Rubber shoes', 'Small cars'], 'answer': 0},
      {'q': 'Heat safety includes:', 'options': ['Drink plenty of water', 'Wear heavy layers', 'Skip shade', 'Ignore cramps'], 'answer': 0},
      {'q': 'Emergency whistle code commonly used:', 'options': ['1 long blast', '3 short blasts', '2 long blasts', 'Continuous'], 'answer': 1},
      {'q': 'Food in emergency kit should be:', 'options': ['Perishable items', 'Non-perishable and easy to prepare', 'Frozen only', 'Restaurant meals'], 'answer': 1},
      {'q': 'Where to meet family after evacuation?', 'options': ['Random place', 'Pre-defined meeting point', 'Inside building', 'Nowhere'], 'answer': 1},
    ],
  };
  late final List<Map<String, dynamic>> _questions;
  int _index = 0;
  int _score = 0;
  int? _selected;

  @override
  void initState() {
    super.initState();
    // Pick bank by disaster type, fallback to general, then combined pool; shuffle and take up to 15
    final type = widget.disasterType.toLowerCase();
    final base = _banks[type] ?? _banks['general']!;
    final combined = [
      ...(_banks['earthquake'] ?? const []),
      ...(_banks['flood'] ?? const []),
      ...(_banks['fire'] ?? const []),
      ...(_banks['cyclone'] ?? const []),
      ...(_banks['general'] ?? const []),
    ];
    final pool = (base.isNotEmpty && base.length >= 5) ? base : combined; // ensure enough variety
    final bankCopy = List<Map<String, dynamic>>.from(pool);
    bankCopy.shuffle();
    final take = bankCopy.take(15).map<Map<String, dynamic>>((q) {
      final opts = List<String>.from(q['options'] as List);
      final correctIndex = q['answer'] as int;
      final correctValue = opts[correctIndex];
      opts.shuffle();
      final newIndex = opts.indexOf(correctValue);
      return {
        'q': q['q'],
        'options': opts,
        'answer': newIndex,
      };
    }).toList();
    _questions = take;
  }

  void _next() async {
    if (_selected == _questions[_index]['answer']) _score++;
    if (_index < _questions.length - 1) {
      setState(() { _index++; _selected = null; });
    } else {
      try {
        await http.post(Uri.parse('${_AuthService._baseUrl}/quiz/submit'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'userId': 'TEMP', 'disasterType': widget.disasterType, 'score': _score, 'total': _questions.length}));
        // Award points and badge if high score
        await http.post(Uri.parse('${_AuthService._baseUrl}/gamification/award'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'userId': 'TEMP', 'points': _score, 'badge': _score >= 12 ? 'Quiz Whiz' : null}));
      } catch (_) {}
      if (!mounted) return;
      showDialog(context: context, builder: (context) => AlertDialog(
        title: const Text('Quiz Completed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Score: $_score / ${_questions.length}'),
            const SizedBox(height: 8),
            if (_score >= 12) const Text('Badge earned: Quiz Whiz 🏅'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.popUntil(context, (r) => r.isFirst), child: const Text('OK'))],
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _questions[_index];
    final options = q['options'] as List<String>;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.disasterType.toUpperCase()} Quiz')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(q['q'] as String, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...List.generate(options.length, (i) => RadioListTile<int>(
              value: i,
              groupValue: _selected,
              onChanged: (v) => setState(() => _selected = v),
              title: Text(options[i]),
            )),
            const Spacer(),
            ElevatedButton(onPressed: _selected == null ? null : _next, child: Text(_index == _questions.length - 1 ? 'Finish' : 'Next')),
          ],
        ),
      ),
    );
  }
}

// Generic Coming Soon placeholder screen for games
class ComingSoonScreen extends StatelessWidget {
  final String title;
  const ComingSoonScreen({super.key, required this.title});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(child: Text('Coming soon...', style: TextStyle(fontSize: 18))),
    );
  }
}

// Learn modules (dynamic): fetch materials from backend and show details
class LearnDisastersScreen extends StatefulWidget {
  const LearnDisastersScreen({super.key});
  @override
  State<LearnDisastersScreen> createState() => _LearnDisastersScreenState();
}

class _LearnDisastersScreenState extends State<LearnDisastersScreen> {
  static const List<String> _types = [
    'all', 'earthquake', 'flood', 'fire', 'cyclone', 'heatwave', 'landslide', 'tsunami', 'pandemic'
  ];
  String _selected = 'all';

  Future<List<dynamic>> _fetchMaterials(String type) async {
    final query = type == 'all' ? '' : '?disaster=$type';
    final res = await http.get(Uri.parse('${_AuthService._baseUrl}/materials$query'));
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
    return json.decode(res.body) as List<dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Learning Materials')),
      body: Column(
        children: [
          SizedBox(
            height: 54,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              scrollDirection: Axis.horizontal,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: _types.length,
              itemBuilder: (context, i) {
                final t = _types[i];
                final active = _selected == t;
                return ChoiceChip(
                  label: Text(t[0].toUpperCase() + t.substring(1)),
                  selected: active,
                  onSelected: (_) => setState(() => _selected = t),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _fetchMaterials(_selected),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                final materials = snap.data ?? const [];
                if (materials.isEmpty) {
                  return const Center(child: Text('No materials yet'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: materials.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final m = materials[i] as Map<String, dynamic>;
                    final title = (m['title'] ?? '').toString();
                    final dt = (m['disasterType'] ?? '').toString();
                    return ListTile(
                      leading: const Icon(Icons.menu_book_rounded),
                      title: Text(title.isEmpty ? '(Untitled)' : title),
                      subtitle: Text(dt.isEmpty ? 'General' : dt),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MaterialDetailScreen(material: m),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class MaterialDetailScreen extends StatelessWidget {
  final Map<String, dynamic> material;
  const MaterialDetailScreen({super.key, required this.material});

  @override
  Widget build(BuildContext context) {
    final sections = (material['sections'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text((material['title'] ?? '').toString())),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: sections.length,
        separatorBuilder: (context, __) => const Divider(),
        itemBuilder: (context, i) {
          final s = sections[i];
          final heading = (s['heading'] ?? '').toString();
          final body = (s['body'] ?? '').toString();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(heading, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              MarkdownBody(data: body.isEmpty ? '_' : body),
            ],
          );
        },
      ),
    );
  }
}

// ================== AUTHORITY: Manage Materials ==================
class AuthorityMaterialsScreen extends StatefulWidget {
  const AuthorityMaterialsScreen({super.key});
  @override
  State<AuthorityMaterialsScreen> createState() => _AuthorityMaterialsScreenState();
}

class _AuthorityMaterialsScreenState extends State<AuthorityMaterialsScreen> {
  String _filter = 'all';
  static const types = ['all','earthquake','flood','fire','cyclone','heatwave','landslide','tsunami','pandemic'];

  Future<List<Map<String, dynamic>>> _load() async {
    final q = _filter == 'all' ? '' : '?disaster=$_filter';
    final res = await http.get(Uri.parse('${_AuthService._baseUrl}/materials$q'));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}: ${res.body}');
    final list = (json.decode(res.body) as List).cast<Map<String, dynamic>>();
    return list;
  }

  void _openEditor({Map<String, dynamic>? material}) async {
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(
      builder: (_) => MaterialEditorScreen(material: material),
    ));
    if (saved == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Materials')),
      body: Column(
        children: [
          SizedBox(
            height: 54,
            child: ListView.separated(
              padding: const EdgeInsets.all(8),
              scrollDirection: Axis.horizontal,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: types.length,
              itemBuilder: (context, i) {
                final t = types[i];
                return ChoiceChip(
                  label: Text(t[0].toUpperCase() + t.substring(1)),
                  selected: _filter == t,
                  onSelected: (_) => setState(() => _filter = t),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _load(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                final items = snap.data ?? const [];
                if (items.isEmpty) return const Center(child: Text('No materials'));
                return RefreshIndicator(
                  onRefresh: () async { setState(() {}); },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final m = items[i];
                      final title = (m['title'] ?? '').toString();
                      final dt = (m['disasterType'] ?? '').toString();
                      return ListTile(
                        leading: const Icon(Icons.menu_book_rounded),
                        title: Text(title.isEmpty ? '(Untitled)' : title),
                        subtitle: Text(dt.isEmpty ? 'General' : dt),
                        trailing: IconButton(icon: const Icon(Icons.edit), onPressed: () => _openEditor(material: m)),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MaterialDetailScreen(material: m))),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class MaterialEditorScreen extends StatefulWidget {
  final Map<String, dynamic>? material;
  const MaterialEditorScreen({super.key, this.material});
  @override
  State<MaterialEditorScreen> createState() => _MaterialEditorScreenState();
}

class _MaterialEditorScreenState extends State<MaterialEditorScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  String _type = 'earthquake';
  final _before = TextEditingController();
  final _during = TextEditingController();
  final _after = TextEditingController();

  @override
  void initState() {
    super.initState();
    final m = widget.material;
    if (m != null) {
      _title.text = (m['title'] ?? '').toString();
      _type = (m['disasterType'] ?? 'earthquake').toString();
      final sections = (m['sections'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      String find(String h) => sections.firstWhere((s) => (s['heading'] ?? '').toString().toLowerCase() == h, orElse: () => const {}).cast<String, dynamic>()['body']?.toString() ?? '';
      _before.text = find('before');
      _during.text = find('during');
      _after.text = find('after');
    }
  }

  @override
  void dispose() {
    _title.dispose(); _before.dispose(); _during.dispose(); _after.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final payload = {
      'disasterType': _type,
      'title': _title.text.trim(),
      'sections': [
        {'heading': 'Before', 'body': _before.text.trim()},
        {'heading': 'During', 'body': _during.text.trim()},
        {'heading': 'After', 'body': _after.text.trim()},
      ],
    };
    try {
      http.Response res;
      if (widget.material == null) {
        res = await http.post(Uri.parse('${_AuthService._baseUrl}/materials'), headers: {'Content-Type': 'application/json'}, body: json.encode(payload));
      } else {
        final id = (widget.material!['_id'] ?? '').toString();
        res = await http.put(Uri.parse('${_AuthService._baseUrl}/materials/$id'), headers: {'Content-Type': 'application/json'}, body: json.encode(payload));
      }
      if (!mounted) return;
      if (res.statusCode >= 200 && res.statusCode < 300) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved'), backgroundColor: Colors.green));
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: ${res.statusCode}: ${res.body}'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.material == null ? 'New Material' : 'Edit Material')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              value: _type,
              items: const [
                DropdownMenuItem(value: 'earthquake', child: Text('Earthquake')),
                DropdownMenuItem(value: 'flood', child: Text('Flood')),
                DropdownMenuItem(value: 'fire', child: Text('Fire')),
                DropdownMenuItem(value: 'cyclone', child: Text('Cyclone')),
                DropdownMenuItem(value: 'heatwave', child: Text('Heatwave')),
                DropdownMenuItem(value: 'landslide', child: Text('Landslide')),
                DropdownMenuItem(value: 'tsunami', child: Text('Tsunami')),
                DropdownMenuItem(value: 'pandemic', child: Text('Pandemic')),
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
              decoration: const InputDecoration(labelText: 'Disaster Type'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Title required' : null,
            ),
            const SizedBox(height: 12),
            const Text('Before (Markdown supported)'),
            TextFormField(controller: _before, maxLines: 6, decoration: const InputDecoration(filled: true, border: OutlineInputBorder(borderSide: BorderSide.none))),
            const SizedBox(height: 12),
            const Text('During (Markdown supported)'),
            TextFormField(controller: _during, maxLines: 6, decoration: const InputDecoration(filled: true, border: OutlineInputBorder(borderSide: BorderSide.none))),
            const SizedBox(height: 12),
            const Text('After (Markdown supported)'),
            TextFormField(controller: _after, maxLines: 6, decoration: const InputDecoration(filled: true, border: OutlineInputBorder(borderSide: BorderSide.none))),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}

// My Badges MVP
class MyBadgesScreen extends StatelessWidget {
  const MyBadgesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Badges')),
      body: Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.emoji_events_rounded, size: 80, color: Colors.amber),
          SizedBox(height: 12),
          Text('Play and learn to earn badges and points!'),
        ],
      )),
    );
  }
}

// Emergency Toolkit MVP
class EmergencyToolkitScreen extends StatelessWidget {
  const EmergencyToolkitScreen({super.key});

  Future<void> _launchDialer() async {
    final uri = Uri.parse('tel:112'); // adjust for region
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      {'icon': Icons.phone_in_talk, 'label': 'Emergency Call', 'action': _launchDialer},
      {'icon': Icons.medical_services, 'label': 'First Aid (Coming Soon)', 'action': null},
      {'icon': Icons.share_location, 'label': 'Share Location (Coming Soon)', 'action': null},
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Toolkit')),
      body: ListView.separated(
        itemBuilder: (context, i) => ListTile(
          leading: Icon(items[i]['icon'] as IconData),
          title: Text(items[i]['label'] as String),
          onTap: items[i]['action'] as void Function()?,
        ),
        separatorBuilder: (context, __) => const Divider(),
        itemCount: items.length,
      ),
    );
  }
}

// Student Drills MVP (list + join)
class DrillsStudentScreen extends StatefulWidget {
  const DrillsStudentScreen({super.key});
  @override
  State<DrillsStudentScreen> createState() => _DrillsStudentScreenState();
}

class _DrillsStudentScreenState extends State<DrillsStudentScreen> {
  List<dynamic> _drills = [];
  bool _loading = true;

  Future<void> _load() async {
    try {
      final res = await http.get(Uri.parse('${_AuthService._baseUrl}/drills'));
      if (res.statusCode == 200) {
        setState(() { _drills = json.decode(res.body) as List; _loading = false; });
      } else { setState(() => _loading = false); }
    } catch (_) { setState(() => _loading = false); }
  }

  String? _currentUserId(BuildContext context) {
    // Try to fetch from Student home ancestor
    final st = context.findAncestorStateOfType<_StudentHomeScreenState>();
    return st?.widget.user.id;
  }

  Future<void> _join(String id) async {
    final uid = _currentUserId(context) ?? 'TEMP';
    await http.post(Uri.parse('${_AuthService._baseUrl}/drills/$id/join'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': uid}));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Joined drill')));
    _load();
  }

  @override
  void initState() { super.initState(); _load(); }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('School Drills')),
      body: ListView.separated(
        itemCount: _drills.length,
        separatorBuilder: (context, __) => const Divider(),
        itemBuilder: (context, i) {
          final d = _drills[i];
          return ListTile(
            title: Text(d['title'] ?? 'Untitled'),
            subtitle: Text('When: ${d['scheduledAt'] ?? 'TBD'}  •  Status: ${d['status']}'),
            trailing: ElevatedButton(onPressed: () => _join(d['_id']), child: const Text('Join')),
          );
        },
      ),
    );
  }
}

// Weather placeholder
class WeatherScreen extends StatelessWidget {
  const WeatherScreen({super.key});
  Future<List<Map<String, dynamic>>> _searchCities(String q) async {
    if (q.trim().isEmpty) return [];
    final uri = Uri.parse('https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeQueryComponent(q)}&count=5&language=en&format=json');
    final res = await http.get(uri);
    if (res.statusCode != 200) return [];
    final data = json.decode(res.body) as Map<String, dynamic>;
    final results = (data['results'] as List?) ?? [];
    return results.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>?> _fetchWeather(double lat, double lon) async {
    final uri = Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,wind_speed_10m&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=auto');
    final res = await http.get(uri);
    if (res.statusCode != 200) return null;
    return json.decode(res.body) as Map<String, dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    final q = TextEditingController();
    final ValueNotifier<List<Map<String, dynamic>>> cities = ValueNotifier([]);
    final ValueNotifier<Map<String, dynamic>?> weather = ValueNotifier(null);
    return Scaffold(
      appBar: AppBar(title: const Text('Weather')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: q,
              decoration: InputDecoration(
                hintText: 'Search city (e.g., Delhi) — Open-Meteo',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onSubmitted: (text) async {
                final results = await _searchCities(text);
                if (!context.mounted) return;
                cities.value = results;
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Row(children: [
                Expanded(
                  child: ValueListenableBuilder<List<Map<String, dynamic>>>(
                    valueListenable: cities,
                    builder: (context, list, _) {
                      if (list.isEmpty) {
                        return const Center(child: Text('Search a city to begin'));
                      }
                      return ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final c = list[i];
                          final name = (c['name'] ?? '').toString();
                          final country = (c['country'] ?? '').toString();
                          final lat = (c['latitude'] as num).toDouble();
                          final lon = (c['longitude'] as num).toDouble();
                          return ListTile(
                            leading: const Icon(Icons.location_on_outlined),
                            title: Text('$name, $country'),
                            subtitle: Text('lat: $lat, lon: $lon'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              final w = await _fetchWeather(lat, lon);
                              if (!context.mounted) return;
                              weather.value = {
                                'city': '$name, $country',
                                'lat': lat,
                                'lon': lon,
                                'data': w,
                              };
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                const VerticalDivider(width: 16),
                Expanded(
                  child: ValueListenableBuilder<Map<String, dynamic>?>(
                    valueListenable: weather,
                    builder: (context, w, _) {
                      if (w == null) return const Center(child: Text('Select a city to view weather'));
                      final data = (w['data'] as Map<String, dynamic>?) ?? {};
                      final current = (data['current'] as Map<String, dynamic>?) ?? {};
                      final daily = (data['daily'] as Map<String, dynamic>?) ?? {};
                      final List tempsMax = (daily['temperature_2m_max'] as List?) ?? [];
                      final List tempsMin = (daily['temperature_2m_min'] as List?) ?? [];
                      final List dates = (daily['time'] as List?) ?? [];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(w['city'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Text('Current: ${current['temperature_2m'] ?? '-'}°C, Wind: ${current['wind_speed_10m'] ?? '-'} km/h'),
                              const Divider(height: 20),
                              const Text('Next days', style: TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              ...List.generate(dates.length.clamp(0, 3), (i) {
                                final d = dates[i];
                                final tmax = tempsMax.length > i ? tempsMax[i] : '-';
                                final tmin = tempsMin.length > i ? tempsMin[i] : '-';
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Text('$d  •  max $tmax°C / min $tmin°C'),
                                );
                              }),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// Virtual Map: search city and open in external Google Maps
class VirtualMapScreen extends StatelessWidget {
  const VirtualMapScreen({super.key});
  Future<List<Map<String, dynamic>>> _searchCities(String q) async {
    if (q.trim().isEmpty) return [];
    final uri = Uri.parse('https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeQueryComponent(q)}&count=8&language=en&format=json');
    final res = await http.get(uri);
    if (res.statusCode != 200) return [];
    final data = json.decode(res.body) as Map<String, dynamic>;
    final results = (data['results'] as List?) ?? [];
    return results.cast<Map<String, dynamic>>();
  }

  @override
  Widget build(BuildContext context) {
    final q = TextEditingController();
    final ValueNotifier<List<Map<String, dynamic>>> cities = ValueNotifier([]);
    return Scaffold(
      appBar: AppBar(title: const Text('Virtual Map')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: q,
              decoration: InputDecoration(
                hintText: 'Search a place (Open‑Meteo geocoding)',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onSubmitted: (text) async {
                final results = await _searchCities(text);
                if (!context.mounted) return;
                cities.value = results;
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ValueListenableBuilder<List<Map<String, dynamic>>>(
                valueListenable: cities,
                builder: (context, list, _) {
                  if (list.isEmpty) return const Center(child: Text('Search a city to see results'));
                  return ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final c = list[i];
                      final name = (c['name'] ?? '').toString();
                      final admin = (c['admin1'] ?? '').toString();
                      final country = (c['country'] ?? '').toString();
                      final lat = (c['latitude'] as num).toDouble();
                      final lon = (c['longitude'] as num).toDouble();
                      return ListTile(
                        leading: const Icon(Icons.public),
                        title: Text('$name, ${admin.isEmpty ? country : admin}'),
                        subtitle: Text('lat: $lat, lon: $lon'),
                        trailing: const Icon(Icons.open_in_new),
                        onTap: () async {
                          final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url, mode: LaunchMode.externalApplication);
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Help screen with provider email
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  Future<void> _contact() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'techsavioursteam25@gmail.com',
      query: Uri.encodeFull('subject=SANKALP App Support&body=Describe your issue here...'),
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & FAQ')),
      body: ListView(
        children: [
          const ListTile(title: Text('How to play games?'), subtitle: Text('Go to Play & Learn > Play...')),
          const ListTile(title: Text('How to join drills?'), subtitle: Text('Open School Drills, tap Join...')),
          ListTile(leading: const Icon(Icons.mail_outline), title: const Text('Contact Provider'), onTap: _contact),
        ],
      ),
    );
  }
}

// --- ABOUT US ---
class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About Us')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(children: const [
          Text('SANKALP', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          SizedBox(height: 8),
          Text('Your safety companion for disaster preparedness, learning, and drills.'),
          SizedBox(height: 16),
          Text('Built by Tech Saviours Team.'),
        ]),
      ),
    );
  }
}

// --- CONTACT US ---
class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});
  Future<void> _contact() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'techsavioursteam25@gmail.com',
      query: Uri.encodeFull('subject=SANKALP Contact&body=Hello Team,'),
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact Us')),
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.mail_outline),
          label: const Text('Email Provider'),
          onPressed: _contact,
        ),
      ),
    );
  }
}

// --- EDIT PROFILE (MVP) ---
class EditProfileScreen extends StatefulWidget {
  final User user;
  const EditProfileScreen({super.key, required this.user});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _first;
  late final TextEditingController _last;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _school;

  @override
  void initState() {
    super.initState();
    _first = TextEditingController(text: widget.user.firstName);
    _last = TextEditingController(text: widget.user.lastName);
    _email = TextEditingController(text: widget.user.email);
    _phone = TextEditingController(text: widget.user.mobileNumber);
    _school = TextEditingController(text: widget.user.schoolName);
  }

  @override
  void dispose() {
    _first.dispose(); _last.dispose(); _email.dispose(); _phone.dispose(); _school.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _field(_first, 'First Name'),
          const SizedBox(height: 8),
          _field(_last, 'Last Name'),
          const SizedBox(height: 8),
          _field(_email, 'Email', type: TextInputType.emailAddress),
          const SizedBox(height: 8),
          _field(_phone, 'Mobile Number', type: TextInputType.phone),
          const SizedBox(height: 8),
          _field(_school, 'School/College Name'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              final body = {
                'firstName': _first.text.trim(),
                'lastName': _last.text.trim(),
                'email': _email.text.trim(),
                'mobileNumber': _phone.text.trim(),
                'schoolName': _school.text.trim(),
              };
              try {
                final uri = Uri.parse('${_AuthService._baseUrl}/users/${widget.user.id}');
                final res = await http.put(
                  uri,
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode(body),
                );
                if (res.statusCode == 200) {
                  final map = json.decode(res.body) as Map<String, dynamic>;
                  final u = map['user'] as Map<String, dynamic>;
                  final updated = User(
                    id: u['_id'],
                    firstName: u['firstName'] ?? widget.user.firstName,
                    lastName: u['lastName'] ?? widget.user.lastName,
                    mobileNumber: u['mobileNumber'] ?? widget.user.mobileNumber,
                    dob: u['dob'] ?? widget.user.dob,
                    email: u['email'] ?? widget.user.email,
                    password: '',
                    schoolName: u['schoolName'] ?? widget.user.schoolName,
                    role: u['role'] ?? widget.user.role,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile updated'), backgroundColor: Colors.green),
                  );
                  Navigator.pop(context, updated);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Update failed: HTTP ${res.statusCode}: ${res.body}'), backgroundColor: Colors.red),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Update error: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: c,
      keyboardType: type,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        labelText: label,
        border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ================== ROLE: STAFF ==================
class StaffHomeScreen extends StatefulWidget {
  final User user;
  const StaffHomeScreen({super.key, required this.user});
  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen> {
  int _index = 0;
  List<Widget> get _tabs => [
  const StaffHomeTab(),
  const StaffStudentsTab(),
  StaffDrillsTab(schoolName: widget.user.schoolName),
  const StudentProfileTab(),
  const StudentSettingsTab(),
];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SANKALP - Staff'),
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Profile',
            onPressed: () async {
              final updated = await Navigator.push<User>(context, MaterialPageRoute(builder: (_) => EditProfileScreen(user: widget.user)));
              if (updated != null) {
                setState(() {
                  widget.user.firstName = updated.firstName;
                  widget.user.lastName = updated.lastName;
                  widget.user.email = updated.email;
                  widget.user.mobileNumber = updated.mobileNumber;
                  widget.user.schoolName = updated.schoolName;
                });
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Help',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.help),
          ),
        ],
      ),
      drawer: SankalpAppDrawer(user: widget.user),
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Students'),
          BottomNavigationBarItem(icon: Icon(Icons.campaign_rounded), label: 'Drills'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class StaffHomeTab extends StatelessWidget {
  const StaffHomeTab({super.key});
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(16),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        FeatureCard(label: 'Learn', iconData: Icons.menu_book, iconColor: AppColors.primaryLight,
            onTapAction: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LearnDisastersScreen()))),
        FeatureCard(label: 'Emergency Toolkit', customIcon: const SosIcon(),
            onTapAction: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EmergencyToolkitScreen()))),
        FeatureCard(label: 'Student Badges', iconData: Icons.verified_rounded, iconColor: AppColors.accentGold, onTapAction: () {}),
        FeatureCard(
          label: 'Create Drills',
          iconData: Icons.campaign_rounded,
          iconColor: AppColors.primaryLight,
          onTapAction: () {
            final parent = context.findAncestorStateOfType<_StaffHomeScreenState>();
            parent?.setState(() { parent._index = 2; });
          },
        ),
        FeatureCard(label: 'Weather', iconData: Icons.wb_sunny_rounded, iconColor: AppColors.accentOrange,
            onTapAction: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const WeatherScreen()))),
        FeatureCard(label: 'Help', iconData: Icons.help_outline_rounded, iconColor: Colors.deepPurple,
            onTapAction: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HelpScreen()))),
      ],
    );
  }
}

class StaffStudentsTab extends StatefulWidget {
  const StaffStudentsTab({super.key});
  @override
  State<StaffStudentsTab> createState() => _StaffStudentsTabState();
}

class _StaffStudentsTabState extends State<StaffStudentsTab> {
  final _q = TextEditingController();
  String _role = 'all'; // all | student | staff | authority

  Future<List<Map<String, dynamic>>> _load(String schoolName) async {
    final uri = Uri.parse('${_AuthService._baseUrl}/dashboard/staff?schoolName=${Uri.encodeQueryComponent(schoolName)}');
    final res = await http.get(uri);
    if (res.statusCode != 200) throw Exception('Failed to load students');
    final data = json.decode(res.body) as Map<String, dynamic>;
    final list = (data['students'] as List?) ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  @override
  void dispose() { _q.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_StaffHomeScreenState>();
    final schoolName = state?.widget.user.schoolName ?? '';

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _load(schoolName),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        final data = snap.data ?? const [];
        // Apply search and role filter
        final q = _q.text.trim().toLowerCase();
        final filtered = data.where((s) {
          final role = (s['role'] ?? '').toString().toLowerCase();
          final name = ('${s['firstName'] ?? ''} ${s['lastName'] ?? ''}').toLowerCase();
          final email = (s['email'] ?? '').toString().toLowerCase();
          final phone = (s['mobileNumber'] ?? '').toString();
          final okRole = _role == 'all' || role == _role;
          final okText = q.isEmpty || name.contains(q) || email.contains(q) || phone.contains(q);
          return okRole && okText;
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                controller: _q,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search name, email, or phone',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _chip('All', 'all'),
                  _chip('Students', 'student'),
                  _chip('Staff', 'staff'),
                  _chip('Authority', 'authority'),
                ]),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No students match your filters'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final s = filtered[i];
                        final name = '${s['firstName'] ?? ''} ${s['lastName'] ?? ''}'.trim();
                        final email = (s['email'] ?? '').toString();
                        final phone = (s['mobileNumber'] ?? '').toString();
                        final role = (s['role'] ?? '').toString();
                        return ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.person)),
                          title: Text(name.isEmpty ? '(No name)' : name),
                          subtitle: Text([email, phone].where((e) => e.isNotEmpty).join(' • ')),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(role, style: const TextStyle(fontSize: 12)),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _chip(String label, String value) {
    final active = _role == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: active,
        onSelected: (_) => setState(() => _role = value),
      ),
    );
  }
}

class StaffDrillsTab extends StatefulWidget {
  final String schoolName;
  const StaffDrillsTab({super.key, required this.schoolName});
  @override
  State<StaffDrillsTab> createState() => _StaffDrillsTabState();
}

class _StaffDrillsTabState extends State<StaffDrillsTab> {
  final _title = TextEditingController();
  final _when = TextEditingController(); // free text for now (e.g., 2025-10-01 10:00)

  bool _loading = false;
  List<dynamic> _drills = [];

  Future<void> _fetch() async {
    try {
      final res = await http.get(Uri.parse('${_AuthService._baseUrl}/drills?schoolName=${Uri.encodeQueryComponent(widget.schoolName)}'));
      if (res.statusCode == 200) _drills = json.decode(res.body) as List<dynamic>;
      setState(() {});
    } catch (_) {}
  }

  Future<void> _create() async {
    final body = {
      'title': _title.text.trim(),
      'schoolName': widget.schoolName,
      'scheduledAt': _when.text.trim(),
      'status': 'scheduled',
    };
    setState(() => _loading = true);
    final res = await http.post(
      Uri.parse('${_AuthService._baseUrl}/drills'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );
    setState(() => _loading = false);
    if (!mounted) return;
    if (res.statusCode == 201) {
      _title.clear(); _when.clear();
      await _fetch();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Drill created'), backgroundColor: Colors.green));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to create drill'), backgroundColor: Colors.red));
    }
  }

  @override
  void initState() { super.initState(); _fetch(); }

  @override
  void dispose() { _title.dispose(); _when.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Create Drill', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _title,
            decoration: InputDecoration(
              filled: true, fillColor: Colors.white, labelText: 'Title',
              border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _when,
            decoration: InputDecoration(
              filled: true, fillColor: Colors.white, labelText: 'When (e.g., 2025-10-01 10:00)',
              border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _loading
                ? null
                : () {
                    final t = _title.text.trim();
                    final w = _when.text.trim();
                    if (t.isEmpty || w.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter title and when'), backgroundColor: Colors.red),
                      );
                      return;
                    }
                    _create();
                  },
            child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Create'),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Existing Drills', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              IconButton(onPressed: _fetch, icon: const Icon(Icons.refresh)),
            ],
          ),
          const SizedBox(height: 8),
          ..._drills.map((d) {
            final title = (d['title'] ?? '').toString();
            final whenRaw = (d['scheduledAt'] ?? '').toString();
            final status = (d['status'] ?? '').toString();
            String when = whenRaw;
            // Try friendly format if it's an ISO date
            try {
              if (whenRaw.isNotEmpty) {
                final dt = DateTime.tryParse(whenRaw);
                if (dt != null) {
                  when = DateFormat('yyyy-MM-dd HH:mm').format(dt.toLocal());
                }
              }
            } catch (_) {}
            return Card(
              child: ListTile(
                leading: const Icon(Icons.campaign_rounded),
                title: Text(title.isEmpty ? '(Untitled)' : title),
                subtitle: Text('When: $when'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: status == 'active' ? Colors.green.shade100 : (status == 'ended' ? Colors.grey.shade300 : Colors.orange.shade100),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(status.isEmpty ? 'scheduled' : status, style: const TextStyle(fontSize: 12)),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ================== ROLE: AUTHORITY ==================
class AuthorityHomeScreen extends StatefulWidget {
  final User user;
  const AuthorityHomeScreen({super.key, required this.user});
  @override
  State<AuthorityHomeScreen> createState() => _AuthorityHomeScreenState();
}

class _AuthorityHomeScreenState extends State<AuthorityHomeScreen> {
  int _index = 0;
  List<Widget> get _tabs => [
  AuthorityDashboardTab(user: widget.user),
  AuthoritySchoolsTab(user: widget.user),
  AuthorityProblemsTab(user: widget.user),
  const StudentProfileTab(),
  const StudentSettingsTab(),
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SANKALP - Authority'),
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Profile',
            onPressed: () async {
              final updated = await Navigator.push<User>(context, MaterialPageRoute(builder: (_) => EditProfileScreen(user: widget.user)));
              if (updated != null) {
                setState(() {
                  widget.user.firstName = updated.firstName;
                  widget.user.lastName = updated.lastName;
                  widget.user.email = updated.email;
                  widget.user.mobileNumber = updated.mobileNumber;
                  widget.user.schoolName = updated.schoolName;
                });
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.library_books),
            tooltip: 'Manage Materials',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthorityMaterialsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Help',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.help),
          ),
        ],
      ),
      drawer: SankalpAppDrawer(user: widget.user),
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.apartment), label: 'Schools'),
          BottomNavigationBarItem(icon: Icon(Icons.campaign_rounded), label: 'Problems'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class AuthorityDashboardTab extends StatelessWidget {
  final User user;
  const AuthorityDashboardTab({super.key, required this.user});

  Future<Map<String, dynamic>> _load(String school) async {
    final uri = Uri.parse(
      '${_AuthService._baseUrl}/authority/dashboard?schoolName=${Uri.encodeQueryComponent(school)}',
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) {
    throw Exception('HTTP ${res.statusCode}: ${res.body}');}
    return json.decode(res.body) as Map<String, dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _load(user.schoolName),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }

        final data = snap.data ?? const {};
        final List<dynamic> users = (data['users'] as List?) ?? const [];
        final drillsCount = data['drills'] ?? 0;
        final List<dynamic> quizzes = (data['quizzes'] as List?) ?? const [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'School: ${user.schoolName}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // KPI cards
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _metricCard('Drills Scheduled', drillsCount.toString(),
                      Icons.campaign_rounded, Colors.orange),
                  _metricCard('Roles', users.length.toString(),
                      Icons.people_alt_rounded, Colors.blue),
                  _metricCard('Quiz Types', quizzes.length.toString(),
                      Icons.quiz_rounded, Colors.purple),
                ],
              ),

              const SizedBox(height: 16),
              const Text('Users by Role', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),

              // Users by role
              ...users.map<Widget>((u) {
                final role = (u is Map && u['_id'] is Map)
                    ? ((u['_id'] as Map)['role'] ?? '').toString()
                    : '';
                final count = (u is Map ? (u['count'] ?? 0) : 0).toString();
                return ListTile(
                  leading: const Icon(Icons.badge),
                  title: Text(role.isEmpty ? '(unknown)' : role),
                  trailing: Text(count),
                );
              }),

              const SizedBox(height: 16),
              const Text('Quiz Averages', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),

              // Quiz averages
              ...quizzes.map<Widget>((q) {
                final type = (q is Map ? (q['_id'] ?? '') : '').toString();
                final avg = (q is Map && q['avgScore'] is num)
                    ? (q['avgScore'] as num).toStringAsFixed(1)
                    : '0.0';
                final attempts = (q is Map ? (q['attempts'] ?? 0) : 0).toString();
                return ListTile(
                  leading: const Icon(Icons.assessment),
                  title: Text(type.isEmpty ? '(unknown)' : type),
                  subtitle: Text('Avg: $avg'),
                  trailing: Text('Attempts: $attempts'),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _metricCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(value, style: const TextStyle(fontSize: 18)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AuthoritySchoolsTab extends StatelessWidget {
  final User user;
  const AuthoritySchoolsTab({super.key, required this.user});

  Future<List<dynamic>> _load(String school) async {
    final uri = Uri.parse('${_AuthService._baseUrl}/authority/activities?schoolName=${Uri.encodeQueryComponent(school)}');
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
    return json.decode(res.body) as List<dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _load(user.schoolName),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        final items = snap.data ?? [];
        if (items.isEmpty) return const Center(child: Text('No recent activities'));

        return ListView.separated(
          padding: const EdgeInsets.all(8),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final it = items[i] as Map<String, dynamic>;
            final action = (it['action'] ?? '').toString();
            final role = (it['role'] ?? '').toString();
            final when = (it['createdAt'] ?? '').toString();
            return ListTile(
              leading: const Icon(Icons.event_note),
              title: Text(action),
              subtitle: Text('$role  •  $when'),
            );
          },
        );
      },
    );
  }
}

class AuthorityProblemsTab extends StatefulWidget {
  final User user;
  const AuthorityProblemsTab({super.key, required this.user});
  @override
  State<AuthorityProblemsTab> createState() => _AuthorityProblemsTabState();
}

class _AuthorityProblemsTabState extends State<AuthorityProblemsTab> {
  final _title = TextEditingController();
  final _type = TextEditingController();
  final _before = TextEditingController();
  final _while = TextEditingController();
  final _after = TextEditingController();
  bool _loading = false;
  List<dynamic> _materials = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final res = await http.get(Uri.parse('${_AuthService._baseUrl}/materials'));
    if (res.statusCode == 200) {
      setState(() => _materials = json.decode(res.body) as List<dynamic>);
    }
  }

  Future<void> _create() async {
    setState(() => _loading = true);
    final body = {
      'disasterType': _type.text.trim(),
      'title': _title.text.trim(),
      'sections': [
        {'heading': 'Before', 'body': _before.text.trim()},
        {'heading': 'While', 'body': _while.text.trim()},
        {'heading': 'After', 'body': _after.text.trim()},
      ],
      'publishedBy': widget.user.id,
    };
    final res = await http.post(
      Uri.parse('${_AuthService._baseUrl}/materials'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );
    setState(() => _loading = false);
    if (!mounted) return;
    if (res.statusCode == 201) {
      _title.clear(); _type.clear(); _before.clear(); _while.clear(); _after.clear();
      await _fetch();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Problem statement added'), backgroundColor: Colors.green));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to add'), backgroundColor: Colors.red));
    }
  }

  @override
  void dispose() {
    _title.dispose(); _type.dispose(); _before.dispose(); _while.dispose(); _after.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Post Problem Statement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _field(_type, 'Disaster Type (e.g., earthquake)'),
          const SizedBox(height: 8),
          _field(_title, 'Title'),
          const SizedBox(height: 8),
          _field(_before, 'Precautions Before'),
          const SizedBox(height: 8),
          _field(_while, 'Precautions While'),
          const SizedBox(height: 8),
          _field(_after, 'Precautions After'),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _loading ? null : _create,
            child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Create'),
          ),
          const SizedBox(height: 16),
          const Text('Existing Materials', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ..._materials.map((m) {
            final mm = m as Map<String, dynamic>;
            final title = (mm['title'] ?? '').toString();
            final dt = (mm['disasterType'] ?? '').toString();
            return Card(child: ListTile(title: Text(title), subtitle: Text(dt)));
          })
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label) {
    return TextField(
      controller: c,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        labelText: label,
        border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
