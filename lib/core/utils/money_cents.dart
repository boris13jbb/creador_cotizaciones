/// Dinero en centavos enteros para evitar errores de `double`.
class MoneyCents implements Comparable<MoneyCents> {
  final int cents;

  const MoneyCents(this.cents);

  static const zero = MoneyCents(0);

  /// Convierte decimal a centavos con redondeo bancario half-up.
  factory MoneyCents.fromDecimal(num value) {
    final scaled = (value.toDouble() * 100);
    final rounded = scaled >= 0
        ? (scaled + 0.5).floor()
        : (scaled - 0.5).ceil();
    return MoneyCents(rounded);
  }

  factory MoneyCents.tryParse(dynamic value) {
    if (value == null) return MoneyCents.zero;
    if (value is MoneyCents) return value;
    if (value is int) return MoneyCents(value);
    if (value is num) return MoneyCents.fromDecimal(value);
    final parsed = num.tryParse(value.toString());
    if (parsed == null) return MoneyCents.zero;
    // Si el string parece centavos enteros sin decimal, úsalo directo.
    if (!value.toString().contains('.')) {
      return MoneyCents(parsed.round());
    }
    return MoneyCents.fromDecimal(parsed);
  }

  double get asDecimal => cents / 100.0;

  String format({String symbol = r'$'}) =>
      '$symbol${asDecimal.toStringAsFixed(2)}';

  MoneyCents operator +(MoneyCents other) => MoneyCents(cents + other.cents);

  MoneyCents operator -(MoneyCents other) => MoneyCents(cents - other.cents);

  MoneyCents operator -() => MoneyCents(-cents);

  /// Aplica porcentaje en basis points (10000 = 100%).
  MoneyCents percentBps(int bps) {
    // (cents * bps) / 10000 con half-up
    final raw = cents * bps;
    final q = raw ~/ 10000;
    final r = raw.abs() % 10000;
    final adj = r >= 5000 ? (raw >= 0 ? 1 : -1) : 0;
    return MoneyCents(q + adj);
  }

  bool get isNegative => cents < 0;

  @override
  int compareTo(MoneyCents other) => cents.compareTo(other.cents);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MoneyCents && other.cents == cents;

  @override
  int get hashCode => cents.hashCode;

  @override
  String toString() => 'MoneyCents($cents)';
}
