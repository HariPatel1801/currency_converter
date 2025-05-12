class ExchangeRate {
  final String fromCurrency;
  final String toCurrency;
  final double rate;
  final double change24h;
  final DateTime timestamp;

  ExchangeRate({
    required this.fromCurrency,
    required this.toCurrency,
    required this.rate,
    required this.change24h,
    required this.timestamp,
  });

  factory ExchangeRate.fromJson(Map<String, dynamic> json) {
    return ExchangeRate(
      fromCurrency: json['fromCurrency'],
      toCurrency: json['toCurrency'],
      rate: json['rate'].toDouble(),
      change24h: json['change24h'].toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}
