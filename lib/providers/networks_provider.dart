import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/social_network.dart';
import '../core/constants.dart';
import '../services/storage_service.dart';

class NetworksNotifier extends StateNotifier<List<SocialNetwork>> {
  NetworksNotifier() : super(_loadFromStorage());

  // Lit l'état persisté depuis Hive (box déjà ouverte dans main()).
  static List<SocialNetwork> _loadFromStorage() {
    return _defaultNetworks.map((n) {
      return n.copyWith(
        isEnabled: StorageService.getNetworkEnabled(n.id),
        blockedUntil: StorageService.getNetworkBlockedUntil(n.id),
      );
    }).toList();
  }

  static final List<SocialNetwork> _defaultNetworks = [
    SocialNetwork(
      id: AppNetworks.instagram,
      name: AppNetworks.names[AppNetworks.instagram]!,
      iconPath: 'assets/images/instagram.png',
    ),
    SocialNetwork(
      id: AppNetworks.tiktok,
      name: AppNetworks.names[AppNetworks.tiktok]!,
      iconPath: 'assets/images/tiktok.png',
    ),
    SocialNetwork(
      id: AppNetworks.youtube,
      name: AppNetworks.names[AppNetworks.youtube]!,
      iconPath: 'assets/images/youtube.png',
    ),
  ];

  void toggleNetwork(String networkId) {
    state = [
      for (final n in state)
        if (n.id == networkId) n.copyWith(isEnabled: !n.isEnabled) else n,
    ];
    final updated = state.firstWhere((n) => n.id == networkId);
    StorageService.setNetworkEnabled(networkId, updated.isEnabled);
  }

  void blockNetwork(String networkId, Duration duration) {
    final until = DateTime.now().add(duration);
    state = [
      for (final n in state)
        if (n.id == networkId) n.copyWith(blockedUntil: until) else n,
    ];
    StorageService.setNetworkBlockedUntil(networkId, until);
  }

  void unblockNetwork(String networkId) {
    state = [
      for (final n in state)
        if (n.id == networkId) n.copyWith(clearBlock: true) else n,
    ];
    StorageService.setNetworkBlockedUntil(networkId, null);
  }

  List<SocialNetwork> get enabledNetworks =>
      state.where((n) => n.isEnabled).toList();
}

final networksProvider =
    StateNotifierProvider<NetworksNotifier, List<SocialNetwork>>(
  (ref) => NetworksNotifier(),
);
