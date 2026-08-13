import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth_gate.dart';
import 'services/ai_provider_controller.dart';
import 'services/ai_service.dart';
import 'services/auth_service.dart';
import 'services/chat_repository.dart';
import 'services/edge_function_ai_service.dart';
import 'services/profile_repository.dart';
import 'services/supabase_auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (error) {
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
    runApp(
      StartupErrorApp(
        message: 'Missing configuration: ${missingConfiguration.join(', ')}',
      ),
    );
    return;
  }

  try {
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
  } catch (error) {
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

  runApp(
    AidaApp(
      aiProviderController: aiProviderController,
      chatRepository: ChatRepository(Supabase.instance.client),
      authService: SupabaseAuthService(Supabase.instance.client),
      profileRepository: SupabaseProfileRepository(Supabase.instance.client),
    ),
  );
}

class AidaApp extends StatefulWidget {
  const AidaApp({
    super.key,
    required this.aiProviderController,
    required this.chatRepository,
    required this.authService,
    required this.profileRepository,
  });

  final AiProviderController aiProviderController;
  final MessageRepository chatRepository;
  final AuthService authService;
  final ProfileRepository profileRepository;

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
    return MaterialApp(
      title: 'AIDA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: AuthGate(
        authService: widget.authService,
        aiProviderController: widget.aiProviderController,
        chatRepository: widget.chatRepository,
        profileRepository: widget.profileRepository,
      ),
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
