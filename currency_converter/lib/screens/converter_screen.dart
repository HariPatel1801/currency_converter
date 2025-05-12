import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/currency.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../widgets/currency_selector.dart';
import '../widgets/rate_chart.dart';

class ConverterScreen extends StatefulWidget {
  const ConverterScreen({Key? key}) : super(key: key);

  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _amountController = TextEditingController(text: '1');
  late AnimationController _animationController;
  late Animation<double> _animation;

  String _fromCurrency = 'USD';
  String _toCurrency = 'EUR';
  double _convertedAmount = 0;
  bool _isLoading = false;
  String _errorMessage = '';
  Map<String, double> _exchangeRates = {};
  DateTime _lastUpdated = DateTime.now();
  String _selectedTimeFrame = '1D';
  bool _isInverse = false;

  List<Map<String, dynamic>> _chartData = [];
  double _minRate = 0;
  double _maxRate = 0;
  List<Currency> _currencies = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _loadCurrencies();
    _fetchExchangeRates();
    _fetchHistoricalData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrencies() async {
    try {
      final currencies = await ApiService.getCurrencies();
      setState(() {
        _currencies = currencies;
      });
    } catch (e) {
      // If API fails, use default currencies
      setState(() {
        _currencies = Constants.defaultCurrencies.map((c) =>
            Currency(code: c['code']!, name: c['name']!, flag: c['flag']!)
        ).toList();
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
      final rates = await ApiService.getLatestRates();
      setState(() {
        _exchangeRates = rates;
        _lastUpdated = DateTime.now();
        _convertCurrency();
        _isLoading = false;
      });
    } catch (e) {
      print("Error in _fetchExchangeRates: $e");
      setState(() {
        _errorMessage = 'Error fetching exchange rates: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchHistoricalData() async {
    try {
      final chartData = await ApiService.getHistoricalDataForChart(
          _fromCurrency,
          _toCurrency,
          _selectedTimeFrame
      );

      if (chartData.isNotEmpty) {
        double minRate = double.infinity;
        double maxRate = 0;

        for (var point in chartData) {
          final rate = _isInverse ? 1 / point['rate'] : point['rate'];
          if (rate < minRate) minRate = rate;
          if (rate > maxRate) maxRate = rate;
        }

        setState(() {
          _chartData = chartData;
          _minRate = minRate;
          _maxRate = maxRate;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching historical data: $e';
      });
    }
  }

  void _convertCurrency() {
    if (_amountController.text.isEmpty) {
      setState(() {
        _convertedAmount = 0;
      });
      return;
    }

    final double amount = double.tryParse(_amountController.text) ?? 0;

    if (_exchangeRates.isEmpty) {
      setState(() {
        _errorMessage = 'Exchange rates not available';
      });
      return;
    }

    try {
      double result;
      if (_isInverse) {
        // Convert from target currency to source currency
        result = ApiService.convertCurrency(amount, _toCurrency, _fromCurrency, _exchangeRates);
      } else {
        // Convert from source currency to target currency
        result = ApiService.convertCurrency(amount, _fromCurrency, _toCurrency, _exchangeRates);
      }

      setState(() {
        _convertedAmount = result;
        _errorMessage = '';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error converting currency: $e';
      });
    }
  }

  void _swapCurrencies() {
    _animationController.forward(from: 0.0);
    setState(() {
      final temp = _fromCurrency;
      _fromCurrency = _toCurrency;
      _toCurrency = temp;
      _convertCurrency();
      _fetchHistoricalData();
    });
  }

  void _updateTimeFrame(String timeFrame) {
    setState(() {
      _selectedTimeFrame = timeFrame;
    });
    _fetchHistoricalData();
  }

  void _toggleInverse() {
    setState(() {
      _isInverse = !_isInverse;
    });
    _convertCurrency();
    _fetchHistoricalData();
  }

  Future<void> _createRateAlert() async {
    final TextEditingController targetRateController = TextEditingController();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Rate Alert'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current rate: ${(_exchangeRates[_toCurrency]! / _exchangeRates[_fromCurrency]!).toStringAsFixed(6)}'),
            const SizedBox(height: 16),
            TextField(
              controller: targetRateController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Target Rate',
                hintText: 'Enter target rate for notification',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final targetRate = double.tryParse(targetRateController.text);
              if (targetRate != null) {
                Navigator.of(context).pop({
                  'fromCurrency': _fromCurrency,
                  'toCurrency': _toCurrency,
                  'targetRate': targetRate,
                });
              }
            },
            child: const Text('Create Alert'),
          ),
        ],
      ),
    );

    if (result != null) {
      // In a real app, you would save this alert to local storage or a backend
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Alert created: ${result['fromCurrency']} to ${result['toCurrency']} at ${result['targetRate']}'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Currency selection
            Row(
              children: [
                Expanded(
                  child: CurrencySelector(
                    title: 'From',
                    selectedCurrency: _fromCurrency,
                    currencies: _currencies,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _fromCurrency = value;
                          _convertCurrency();
                          _fetchHistoricalData();
                        });
                      }
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: RotationTransition(
                    turns: _animation,
                    child: IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.swap_horiz,
                          color: Colors.white,
                        ),
                      ),
                      onPressed: _swapCurrencies,
                      tooltip: 'Swap Currencies',
                    ),
                  ),
                ),
                Expanded(
                  child: CurrencySelector(
                    title: 'To',
                    selectedCurrency: _toCurrency,
                    currencies: _currencies,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _toCurrency = value;
                          _convertCurrency();
                          _fetchHistoricalData();
                        });
                      }
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Amount input field
            Container(
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[850] : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Amount',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Row(
                        children: [
                          const Text('Inverse'),
                          Switch(
                            value: _isInverse,
                            onChanged: (value) {
                              setState(() {
                                _isInverse = value;
                                _convertCurrency();
                                _fetchHistoricalData();
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    onChanged: (_) => _convertCurrency(),
                    decoration: InputDecoration(
                      hintText: 'Enter amount',
                      prefixIcon: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          _getCurrencyFlag(_isInverse ? _toCurrency : _fromCurrency),
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                    ),
                    style: const TextStyle(fontSize: 18),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Result display
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDarkMode
                      ? [Colors.blueAccent, Colors.blue.shade800]
                      : [Colors.blue, Colors.blue.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    _isLoading
                        ? 'Loading...'
                        : NumberFormat.currency(
                      locale: 'en_US',
                      symbol: _getCurrencySymbol(_isInverse ? _fromCurrency : _toCurrency),
                      decimalDigits: 2,
                    ).format(_convertedAmount),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isInverse
                        ? '${_amountController.text.isEmpty ? '0' : _amountController.text} ${_toCurrency} = ${_convertedAmount.toStringAsFixed(2)} ${_fromCurrency}'
                        : '${_amountController.text.isEmpty ? '0' : _amountController.text} ${_fromCurrency} = ${_convertedAmount.toStringAsFixed(2)} ${_toCurrency}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _createRateAlert,
                    icon: const Icon(Icons.notifications_active),
                    label: const Text('Create Rate Alert'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue.shade800,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Chart time period selector
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: Constants.timeFrames.length,
                itemBuilder: (context, index) {
                  final timeFrame = Constants.timeFrames[index];
                  final isSelected = timeFrame == _selectedTimeFrame;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ElevatedButton(
                      onPressed: () => _updateTimeFrame(timeFrame),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSelected ? Theme.of(context).primaryColor : (isDarkMode ? Colors.grey[800] : Colors.grey[200]),
                        foregroundColor: isSelected ? Colors.white : (isDarkMode ? Colors.white : Colors.black),
                        elevation: isSelected ? 2 : 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(timeFrame),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Exchange rate chart
            RateChart(
              chartData: _chartData,
              minRate: _minRate,
              maxRate: _maxRate,
              fromCurrency: _fromCurrency,
              toCurrency: _toCurrency,
              isInverse: _isInverse,
              isDarkMode: isDarkMode,
            ),

            const SizedBox(height: 16),

            // Exchange rate info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Exchange Rate',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      Text(
                        _isInverse && _exchangeRates.isNotEmpty
                            ? '1 $_toCurrency = ${(_exchangeRates[_fromCurrency]! / _exchangeRates[_toCurrency]!).toStringAsFixed(6)} $_fromCurrency'
                            : '1 $_fromCurrency = ${_exchangeRates.isNotEmpty ? (_exchangeRates[_toCurrency]! / _exchangeRates[_fromCurrency]!).toStringAsFixed(6) : '0'} $_toCurrency',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Last Updated',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      Text(
                        DateFormat('MMM dd, yyyy HH:mm').format(_lastUpdated),
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _errorMessage,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            const SizedBox(height: 24),

            // Disclaimer
            Text(
              'Disclaimer: Exchange rates are provided for informational purposes only. Actual rates may vary.',
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _getCurrencyFlag(String currencyCode) {
    final currency = _currencies.firstWhere(
          (c) => c.code == currencyCode,
      orElse: () => Currency(code: currencyCode, name: currencyCode, flag: '🏳️'),
    );
    return currency.flag;
  }

  String _getCurrencySymbol(String currencyCode) {
    switch (currencyCode) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'JPY':
        return '¥';
      case 'INR':
        return '₹';
      default:
        return currencyCode;
    }
  }
}
