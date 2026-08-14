import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/profile_repository.dart';

class EditGenderPage extends StatefulWidget {
  const EditGenderPage({
    super.key,
    required this.profile,
    required this.profileRepository,
  });

  final UserProfile profile;
  final ProfileRepository profileRepository;

  @override
  State<EditGenderPage> createState() => _EditGenderPageState();
}

class _EditGenderPageState extends State<EditGenderPage> {
  late Gender? _gender = widget.profile.gender;
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (_gender == null) {
      setState(() => _errorMessage = 'Please select an option');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final gender = _gender!;

    try {
      await widget.profileRepository.saveProfile(
        userId: widget.profile.id,
        displayName: widget.profile.displayName,
        gender: gender,
      );
      if (!mounted) return;
      Navigator.of(context).pop(
        UserProfile(
          id: widget.profile.id,
          displayName: widget.profile.displayName,
          gender: gender,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Change gender error: $error\n$stackTrace');
      if (!mounted) return;
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Change gender')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                    key: const Key('saveGenderButton'),
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
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
