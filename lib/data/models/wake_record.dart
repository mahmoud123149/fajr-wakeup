/// How a fired alarm was resolved. Mirrors WakeEventStore outcome strings.
enum WakeOutcome {
  verified('VERIFIED', 'تم التحقق'),
  emergencyStop('EMERGENCY_STOP', 'إيقاف طارئ'),
  triggered('TRIGGERED', 'لم يُحسم');

  const WakeOutcome(this.key, this.arabicLabel);

  final String key;
  final String arabicLabel;

  static WakeOutcome fromKey(String? key) => WakeOutcome.values.firstWhere(
        (o) => o.key == key,
        orElse: () => WakeOutcome.triggered,
      );
}

/// A single Fajr wake-up / verification history entry.
class WakeRecord {
  const WakeRecord({
    this.id,
    required this.scheduled,
    required this.triggered,
    this.resolved,
    required this.outcome,
    this.confidence,
    this.attempts = 0,
    required this.recordedAt,
  });

  final int? id;
  final DateTime scheduled;
  final DateTime triggered;
  final DateTime? resolved;
  final WakeOutcome outcome;
  final double? confidence;
  final int attempts;
  final DateTime recordedAt;

  bool get succeeded => outcome == WakeOutcome.verified;

  /// Time from the alarm firing to the challenge being resolved.
  Duration? get challengeDuration => resolved?.difference(triggered);

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'scheduled_millis': scheduled.millisecondsSinceEpoch,
        'triggered_millis': triggered.millisecondsSinceEpoch,
        'resolved_millis': resolved?.millisecondsSinceEpoch,
        'outcome': outcome.key,
        'confidence': confidence,
        'attempts': attempts,
        'recorded_at': recordedAt.millisecondsSinceEpoch,
      };

  factory WakeRecord.fromMap(Map<String, dynamic> map) => WakeRecord(
        id: map['id'] as int?,
        scheduled: DateTime.fromMillisecondsSinceEpoch((map['scheduled_millis'] as num).toInt()),
        triggered: DateTime.fromMillisecondsSinceEpoch((map['triggered_millis'] as num).toInt()),
        resolved: map['resolved_millis'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch((map['resolved_millis'] as num).toInt()),
        outcome: WakeOutcome.fromKey(map['outcome'] as String?),
        confidence: (map['confidence'] as num?)?.toDouble(),
        attempts: (map['attempts'] as num?)?.toInt() ?? 0,
        recordedAt: DateTime.fromMillisecondsSinceEpoch((map['recorded_at'] as num).toInt()),
      );

  /// Build a record from a native JSONL hand-off object.
  factory WakeRecord.fromNativeJson(Map<String, dynamic> json) => WakeRecord(
        scheduled: DateTime.fromMillisecondsSinceEpoch((json['scheduledTimeMillis'] as num).toInt()),
        triggered: DateTime.fromMillisecondsSinceEpoch((json['triggeredTimeMillis'] as num).toInt()),
        resolved: json['resolvedTimeMillis'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch((json['resolvedTimeMillis'] as num).toInt()),
        outcome: WakeOutcome.fromKey(json['outcome'] as String?),
        confidence: (json['confidence'] as num?)?.toDouble(),
        attempts: (json['attempts'] as num?)?.toInt() ?? 0,
        recordedAt: DateTime.fromMillisecondsSinceEpoch(
            (json['recordedAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch),
      );
}

/// Aggregate statistics for the history screen.
class WakeStats {
  const WakeStats({
    required this.total,
    required this.verified,
    required this.emergency,
    required this.averageChallenge,
  });

  final int total;
  final int verified;
  final int emergency;
  final Duration? averageChallenge;

  double get successRate => total == 0 ? 0 : verified / total;
}
