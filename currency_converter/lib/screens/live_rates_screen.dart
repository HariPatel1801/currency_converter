import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/currency.dart';
import '../services/api_service.dart';
import '../widgets/currency_list_item.dart';

class LiveRatesScreen extends StatefulWidget {
  const LiveRatesScreen({Key? key}) : super(key: key);

  @override
  State<LiveRatesScreen> createState() => _LiveRatesScreenState();
}

class _LiveRatesScreenState extends State<LiveRatesScreen> {
  String _baseCurrency = 'USD';
  bool _isLoading = true;
  Map<String, double> _exchangeRates = {};
  Map<String, double> _rateChanges = {};
  DateTime _lastUpdated = DateTime.now();
  bool _isInverse = false;
  String _errorMessage = '';
  List<Currency> _currencies = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadCurrencies();
    await _fetchExchangeRates();
  }

  Future<void> _loadCurrencies() async {
    try {
      final currencies = await ApiService.getCurrencies();
      setState(() {
        _currencies = currencies;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not load currencies: $e';
      });
    }
  }

  Future<void> _fetchExchangeRates() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Get latest rates
      final rates = await ApiService.getLatestRates();

      // Get 24-hour changes
      final changes = await ApiService.get24HourChanges();

      setState(() {
        _exchangeRates = rates;
        _rateChanges = changes;
        _lastUpdated = DateTime.now();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching exchange rates: $e';
        _isLoading = false;
      });
    }
  }

  void _changeBaseCurrency(String currency) {
    setState(() {
      _baseCurrency = currency;
    });
    _fetchExchangeRates();
  }

  void _toggleInverse() {
    setState(() {
      _isInverse = !_isInverse;
    });
  }

  String _getCurrencyFlag(String currencyCode) {
    final currency = _currencies.firstWhere(
          (c) => c.code == currencyCode,
      orElse: () => Currency(code: currencyCode, name: currencyCode, flag: '🏳️'),
    );
    return currency.flag;
  }

  String _getCurrencyName(String currencyCode) {
    final currency = _currencies.firstWhere(
          (c) => c.code == currencyCode,
      orElse: () => Currency(code: currencyCode, name: currencyCode, flag: '🏳️'),
    );
    return currency.name;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _fetchExchangeRates,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Live exchange rates',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Compare 100+ currencies in real time & find the right moment to transfer funds',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('Inverse'),
                          Switch(
                            value: _isInverse,
                            onChanged: (value) {
                              setState(() {
                                _isInverse = value;
                              });
                            },
                          ),
                        ],
                      ),
                      Text(
                        'Last updated: ${DateFormat('HH:mm').format(_lastUpdated)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              color: isDarkMode ? const Color(0xFF0A1929) : const Color(0xFF0A1929),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              child: Row(
                children: [
                  Text(
                    _getCurrencyFlag(_baseCurrency),
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$_baseCurrency ${_getCurrencyName(_baseCurrency)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    '1',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _errorMessage.isNotEmpty
                  ? Center(
                child: Text(
                  _errorMessage,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              )
                  : ListView.builder(
                itemCount: _exchangeRates.length,
                itemBuilder: (context, index) {
                  final currency = _exchangeRates.keys.elementAt(index);
                  if (currency == _baseCurrency) return const SizedBox.shrink();

                  return CurrencyListItem(
                    currency: currency,
                    currencyName: _getCurrencyName(currency),
                    flag: _getCurrencyFlag(currency),
                    rate: _isInverse
                        ? 1 / _exchangeRates[currency]!
                        : _exchangeRates[currency]!,
                    change24h: _rateChanges[currency] ?? 0.0,
                    onTap: () => _changeBaseCurrency(currency),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
