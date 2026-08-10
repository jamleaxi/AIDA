import 'package:flutter/foundation.dart';

import 'ai_service.dart';

class AiProviderController extends ChangeNotifier {
  AiProviderController({
    required Map<AiProvider, AiService> services,
    required AiProvider initialProvider,
  })  : _services = Map.unmodifiable(services),
        _current = initialProvider {
    assert(
      _services.containsKey(_current),
      'initialProvider must have a configured service',
    );
  }

  final Map<AiProvider, AiService> _services;
  AiProvider _current;

  AiProvider get current => _current;

  List<AiProvider> get availableProviders => _services.keys.toList();

  AiService get activeService => _services[_current]!;

  void select(AiProvider provider) {
    if (provider == _current || !_services.containsKey(provider)) return;
    _current = provider;
    notifyListeners();
  }

  void closeAll() {
    for (final service in _services.values) {
      service.close();
    }
  }
}
