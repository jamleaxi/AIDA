import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth_gate.dart';
import 'screens/splash_screen.dart';
import 'services/ai_provider_controller.dart';
import 'services/ai_service.dart';
import 'services/auth_service.dart';
import 'services/chat_preferences_controller.dart';
import 'services/chat_repository.dart';
import 'services/edge_function_ai_service.dart';
import 'services/profile_repository.dart';
import 'services/supabase_auth_service.dart';
import 'services/theme_controller.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final splashStatus = ValueNotifier('Starting AIDA…');
  runApp(SplashScreen(status: splashStatus));

  final minimumSplash = Future<void>.delayed(const Duration(milliseconds: 900));

  try {
    await dotenv.load(fileName: '.env');
  } catch (error) {
    await minimumSplash;
    runApp(
      const StartupErrorApp(
        message:
            'Could not load .env. Copy .env.example to .env and add your configuration.',
      ),
    );
    return;
  }

  final supabaseUrl = dotenv.maybeGet('SUPABASE_URL')?.trim() ?? '';
  final supabaseKey = dotenv.maybeGet('SUPABASE_KEY')?.trim() ?? '';
  final providerName = dotenv.maybeGet('AI_PROVIDER')?.trim() ?? 'gemini';
  final provider = AiProvider.tryParse(providerName);

  if (provider == null) {
    await minimumSplash;
    runApp(
      StartupErrorApp(
        message:
            'Invalid AI_PROVIDER: "$providerName". Use "gemini" or "groq".',
      ),
    );
    return;
  }

  final missingConfiguration = <String>[
    if (supabaseUrl.isEmpty) 'SUPABASE_URL',
    if (supabaseKey.isEmpty) 'SUPABASE_KEY',
  ];
  if (missingConfiguration.isNotEmpty) {
    await minimumSplash;
    runApp(
      StartupErrorApp(
        message: 'Missing configuration: ${missingConfiguration.join(', ')}',
      ),
    );
    return;
  }

  splashStatus.value = 'Connecting to services…';

  final themeController = ThemeController();
  final chatPreferencesController = ChatPreferencesController();

  try {
    await Future.wait([
      Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey),
      themeController.load(),
      chatPreferencesController.load(),
    ]);
  } catch (error) {
    await minimumSplash;
    runApp(const StartupErrorApp(message: 'Could not initialize the app.'));
    return;
  }

  final aiProviderController = AiProviderController(
    services: {
      AiProvider.gemini: EdgeFunctionAiService(
        Supabase.instance.client,
        AiProvider.gemini,
      ),
      AiProvider.groq: EdgeFunctionAiService(
        Supabase.instance.client,
        AiProvider.groq,
      ),
    },
    initialProvider: provider,
  );

  splashStatus.value = 'Almost ready…';
  await minimumSplash;
  runApp(
    AidaApp(
      aiProviderController: aiProviderController,
      chatRepository: ChatRepository(Supabase.instance.client),
      authService: SupabaseAuthService(Supabase.instance.client),
      profileRepository: SupabaseProfileRepository(Supabase.instance.client),
      themeController: themeController,
      chatPreferencesController: chatPreferencesController,
    ),
  );
}

class AidaApp extends StatefulWidget {
  AidaApp({
    super.key,
    required this.aiProviderController,
    required this.chatRepository,
    required this.authService,
    required this.profileRepository,
    ThemeController? themeController,
    ChatPreferencesController? chatPreferencesController,
  }) : themeController = themeController ?? ThemeController(),
       chatPreferencesController =
           chatPreferencesController ?? ChatPreferencesController();

  final AiProviderController aiProviderController;
  final MessageRepository chatRepository;
  final AuthService authService;
  final ProfileRepository profileRepository;
  final ThemeController themeController;
  final ChatPreferencesController chatPreferencesController;

  @override
  State<AidaApp> createState() => _AidaAppState();
}

class _AidaAppState extends State<AidaApp> {
  @override
  void dispose() {
    widget.aiProviderController.closeAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.themeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'AIDA',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(widget.themeController.effectiveAccent),
          darkTheme: AppTheme.dark(widget.themeController.effectiveAccent),
          themeMode: widget.themeController.mode,
          home: AuthGate(
            authService: widget.authService,
            aiProviderController: widget.aiProviderController,
            chatRepository: widget.chatRepository,
            profileRepository: widget.profileRepository,
            themeController: widget.themeController,
            chatPreferencesController: widget.chatPreferencesController,
          ),
        );
      },
    );
  }
}

class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(message, textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
    );
  }
}
