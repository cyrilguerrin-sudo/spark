class FocusSession {
  final String id;
  final String objective;
  final List<String> blockedApps;
  final DateTime startTime;
  final bool isObjectiveChecked;

  const FocusSession({
    required this.id,
    required this.objective,
    required this.blockedApps,
    required this.startTime,
    this.isObjectiveChecked = false,
  });

  FocusSession copyWith({bool? isObjectiveChecked}) {
    return FocusSession(
      id: id,
      objective: objective,
      blockedApps: List.from(blockedApps),
      startTime: startTime,
      isObjectiveChecked: isObjectiveChecked ?? this.isObjectiveChecked,
    );
  }
}
