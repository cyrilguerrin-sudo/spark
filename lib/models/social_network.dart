class SocialNetwork {
  final String id;
  final String name;
  final String iconPath;
  final bool isEnabled;
  final DateTime? blockedUntil;

  const SocialNetwork({
    required this.id,
    required this.name,
    required this.iconPath,
    this.isEnabled = false,
    this.blockedUntil,
  });

  bool get isCurrentlyBlocked =>
      blockedUntil != null && DateTime.now().isBefore(blockedUntil!);

  SocialNetwork copyWith({
    bool? isEnabled,
    DateTime? blockedUntil,
    bool clearBlock = false,
  }) {
    return SocialNetwork(
      id: id,
      name: name,
      iconPath: iconPath,
      isEnabled: isEnabled ?? this.isEnabled,
      blockedUntil: clearBlock ? null : (blockedUntil ?? this.blockedUntil),
    );
  }
}
