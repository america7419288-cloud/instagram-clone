// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/app_theme.dart';
import 'core/network/dio_client.dart';
import 'core/constants/app_constants.dart';
import 'features/auth/presentation/pages/register_page.dart';

// Temporary pages for testing
// We'll replace these with real pages later

class TestHomePage extends StatefulWidget {
  const TestHomePage({super.key, this.testConnection = true});

  final bool testConnection;

  @override
  State<TestHomePage> createState() => _TestHomePageState();
}

class _TestHomePageState extends State<TestHomePage> {
  String _status = 'Testing connection...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.testConnection) {
      _testConnection();
    } else {
      _status = 'Connection test skipped';
      _isLoading = false;
    }
  }

  Future<void> _testConnection() async {
    try {
      final dio = DioClient();
      final response = await dio.get('/test');

      setState(() {
        _status = response.data['message'] ?? 'Connected!';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Connection failed: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Instagram Clone'), centerTitle: true),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Instagram-like logo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: AppColors.instagramGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Instagram Clone',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              const Text(
                'Built with Flutter + Node.js',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 40),

              // Connection status
              if (_isLoading)
                const CircularProgressIndicator(color: AppColors.primary)
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Backend Connection:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _status,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              Text(
                'API: ${AppConstants.baseUrl}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() async {
  // Make sure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables if the file exists. A missing .env should not
  // stop the first frame from rendering during local development.
  await dotenv.load(fileName: '.env', isOptional: true);

  // Force portrait mode (like Instagram)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    // ProviderScope is needed for Riverpod
    const ProviderScope(child: MyApp()),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,

      // Themes
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light, // We'll make this dynamic later
      home: const RegisterPage(),
    );
  }
}
