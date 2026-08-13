import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/profile_repository.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.userId,
    required this.profileRepository,
    required this.onComplete,
    this.initialProfile,
  });

  final String userId;
  final ProfileRepository profileRepository;
  final ValueChanged<UserProfile> onComplete;
  final UserProfile? initialProfile;

  bool get isEditing => initialProfile != null;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.initialProfile?.displayName ?? '',
  );

  Gender? _gender;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _gender = widget.initialProfile?.gender;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final isNameValid = _formKey.currentState?.validate() ?? false;
    if (!isNameValid || _gender == null) {
      setState(() {
        _errorMessage = _gender == null ? 'Please select an option' : null;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final displayName = _nameController.text.trim();
    final gender = _gender!;

    try {
      await widget.profileRepository.saveProfile(
        userId: widget.userId,
        displayName: displayName,
        gender: gender,
      );
      if (!mounted) return;
      widget.onComplete(
        UserProfile(id: widget.userId, displayName: displayName, gender: gender),
      );
    } catch (error, stackTrace) {
      debugPrint('Onboarding error: $error\n$stackTrace');
      if (!mounted) return;
      setState(
        () => _errorMessage = 'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: widget.isEditing
          ? AppBar(title: const Text('Edit profile'))
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!widget.isEditing) ...[
                      Text(
                        'Welcome to AIDA',
                        style: theme.textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                    ],
                    Text(
                      'What should I call you?',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: const Key('displayNameField'),
                      controller: _nameController,
                      enabled: !_isSubmitting,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Your name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Please enter a name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'How do you identify?',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    RadioGroup<Gender>(
                      groupValue: _gender,
                      onChanged: (value) {
                        if (_isSubmitting) return;
                        setState(() => _gender = value);
                      },
                      child: Column(
                        children: Gender.values
                            .map(
                              (gender) => RadioListTile<Gender>(
                                key: Key('genderOption_${gender.value}'),
                                title: Text(gender.label),
                                value: gender,
                                contentPadding: EdgeInsets.zero,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      key: const Key('onboardingSubmitButton'),
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Text(widget.isEditing ? 'Save' : 'Continue'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
