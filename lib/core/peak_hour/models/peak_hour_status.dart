class PeakHourPeriod {
  const PeakHourPeriod({
    required this.start,
    required this.end,
  });

  final String start;
  final String end;

  factory PeakHourPeriod.fromJson(Map<String, dynamic> json) {
    return PeakHourPeriod(
      start: json['start']?.toString() ?? '',
      end: json['end']?.toString() ?? '',
    );
  }
}

class PeakHourStatus {
  const PeakHourStatus({
    required this.isPeakHour,
    required this.enabled,
    this.currentTime,
    this.peakHours = const [],
    this.currentPeriod,
    this.multiplier,
  });

  final bool isPeakHour;
  final bool enabled;
  final String? currentTime;
  final List<PeakHourPeriod> peakHours;
  final PeakHourPeriod? currentPeriod;
  final double? multiplier;

  bool get isPeakHourActive => enabled && isPeakHour;

  factory PeakHourStatus.fromJson(Map<String, dynamic> json) {
    final periodsRaw = json['peak_hours'];
    final periods = periodsRaw is List
        ? periodsRaw
            .whereType<Map>()
            .map(
              (e) => PeakHourPeriod.fromJson(
                e.map((k, v) => MapEntry(k.toString(), v)),
              ),
            )
            .where((p) => p.start.isNotEmpty && p.end.isNotEmpty)
            .toList(growable: false)
        : const <PeakHourPeriod>[];

    final currentPeriodRaw = json['current_period'];
    PeakHourPeriod? currentPeriod;
    if (currentPeriodRaw is Map) {
      currentPeriod = PeakHourPeriod.fromJson(
        currentPeriodRaw.map((k, v) => MapEntry(k.toString(), v)),
      );
    }

    return PeakHourStatus(
      isPeakHour: json['is_peak_hour'] == true,
      enabled: json['enabled'] != false,
      currentTime: json['current_time']?.toString(),
      peakHours: periods,
      currentPeriod: currentPeriod,
      multiplier: _asDouble(json['multiplier']),
    );
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}
