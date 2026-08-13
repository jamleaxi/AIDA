import 'package:flutter/foundation.dart';

import 'ai_service.dart';

/// Tracks which AI provider is active and transparently fails over to
/// another configured provider when the active one is unavailable.
class AiProviderController extends ChangeNotifier {
  AiProviderController({
    required Map<AiProvider, AiService> services,
    required AiProvider initialProvider,
  })  : _services = Map.unmodifiable(services),
        _current = initialProvider,
        _preferred = initialProvider {
    assert(
      _services.containsKey(_current),
      'initialProvider must have a configured service',
    );
  }

  final Map<AiProvider, AiService> _services;

  /// The provider currently serving replies. May differ from [preferred]
  /// after an automatic failover.
  AiProvider _current;

  /// The provider the user explicitly chose. Failover never changes this;
  /// only [select] does.
  AiProvider _preferred;

  /// Providers that failed their most recent request.
  final Set<AiProvider> _down = {};

  AiProvider get current => _current;

  AiProvider get preferred => _preferred;

  List<AiProvider> get availableProviders => _services.keys.toList();

  AiService get activeService => _services[_current]!;

  bool isDown(AiProvider provider) => _down.contains(provider);

  /// True only when every configured provider failed its last request.
  bool get allProvidersDown => _down.length == _services.length;

  /// Explicitly switches providers. This is the user's override: it always
  /// takes effect immediately and becomes the new preference for future
  /// failover.
  void select(AiProvider provider) {
    if (!_services.containsKey(provider)) return;
    if (provider == _current && provider == _preferred) return;
    _preferred = provider;
    _current = provider;
    notifyListeners();
  }

  /// Requests a reply from the current provider, automatically failing over
  /// to another configured provider if it's unavailable. On success, the
  /// provider that actually answered becomes [current].
  Future<String> generateReply(String userMessage) async {
    final order = [
      _current,
      for (final provider in _services.keys)
        if (provider != _current) provider,
    ];

    Object? lastError;
    StackTrace? lastStackTrace;

    for (final provider in order) {
      try {
        final reply = await _services[provider]!.generateReply(userMessage);
        final wasDown = _down.remove(provider);
        if (provider != _current || wasDown) {
          _current = provider;
          notifyListeners();
        }
        return reply;
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        if (_down.add(provider)) notifyListeners();
      }
    }

    Error.throwWithStackTrace(lastError!, lastStackTrace!);
  }

  void closeAll() {
    for (final service in _services.values) {
      service.close();
    }
  }
}
