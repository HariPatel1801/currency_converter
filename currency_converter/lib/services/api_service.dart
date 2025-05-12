// services/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/currency.dart';
import '../utils/constants.dart';

class ApiService {
  // Get all available currencies
  static Future<List<Currency>> getCurrencies() async {
    try {
      final response = await http.get(
        Uri.parse('https://openexchangerates.org/api/currencies.json'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        // Convert to list of Currency objects with flag emojis
        return data.entries.map((entry) {
          return Currency(
            code: entry.key,
            name: entry.value,
            flag: _getFlagEmoji(entry.key),
          );
        }).toList();
      } else {
        throw Exception('Failed to load currencies: ${response.statusCode}');
      }
    } catch (e) {
      print("Currency API Error: $e");
      throw Exception('Error fetching currencies: $e');
    }
  }

  // Get latest exchange rates - always using USD as base (free plan limitation)
  static Future<Map<String, double>> getLatestRates() async {
    try {
      print("Fetching latest rates from API...");
      final response = await http.get(
        Uri.parse('https://openexchangerates.org/api/latest.json?app_id=${Constants.apiKey}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("API Response received: ${data['timestamp']}");

        final Map<String, dynamic> rates = data['rates'];

        // Convert to Map<String, double>
        return rates.map((key, value) => MapEntry(key, value.toDouble()));
      } else {
        print("API Error: Status ${response.statusCode}, Body: ${response.body}");
        throw Exception('Failed to load exchange rates: ${response.statusCode}');
      }
    } catch (e) {
      print("Exchange Rate API Error: $e");
      throw Exception('Error fetching exchange rates: $e');
    }
  }

  // Convert currency using USD as intermediary (for free plan)
  static double convertCurrency(double amount, String fromCurrency, String toCurrency, Map<String, double> rates) {
    // If either currency is USD, conversion is simple
    if (fromCurrency == 'USD') {
      return amount * rates[toCurrency]!;
    } else if (toCurrency == 'USD') {
      return amount / rates[fromCurrency]!;
    }

    // For non-USD to non-USD, convert through USD
    double amountInUsd = amount / rates[fromCurrency]!;
    return amountInUsd * rates[toCurrency]!;
  }

  // Get historical rates for a specific date (using USD as base)
  static Future<Map<String, double>> getHistoricalRates(String date) async {
    try {
      print("Fetching historical rates for $date...");
      final response = await http.get(
        Uri.parse('https://openexchangerates.org/api/historical/$date.json?app_id=${Constants.apiKey}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final Map<String, dynamic> rates = data['rates'];

        // Convert to Map<String, double>
        return rates.map((key, value) => MapEntry(key, value.toDouble()));
      } else {
        print("Historical API Error: Status ${response.statusCode}, Body: ${response.body}");
        throw Exception('Failed to load historical rates: ${response.statusCode}');
      }
    } catch (e) {
      print("Historical API Error: $e");
      throw Exception('Error fetching historical rates: $e');
    }
  }

  // Get historical data for chart
  static Future<List<Map<String, dynamic>>> getHistoricalDataForChart(
      String fromCurrency,
      String toCurrency,
      String timeFrame,
      ) async {
    try {
      print("Generating chart data for $fromCurrency to $toCurrency over $timeFrame");
      final DateTime endDate = DateTime.now();
      DateTime startDate;

      // Determine start date based on selected timeframe
      switch (timeFrame) {
        case '12H':
          startDate = endDate.subtract(const Duration(hours: 12));
          break;
        case '1D':
          startDate = endDate.subtract(const Duration(days: 1));
          break;
        case '1W':
          startDate = endDate.subtract(const Duration(days: 7));
          break;
        case '1M':
          startDate = endDate.subtract(const Duration(days: 30));
          break;
        case '1Y':
          startDate = endDate.subtract(const Duration(days: 365));
          break;
        case '5Y':
          startDate = endDate.subtract(const Duration(days: 365 * 5));
          break;
        default:
          startDate = endDate.subtract(const Duration(days: 7));
      }

      // For timeframes shorter than 1 day, we need to simulate hourly data
      // as the free API doesn't provide intraday data
      if (timeFrame == '12H') {
        // Get today's rate
        final todayRates = await getLatestRates();

        // Generate hourly data points based on the latest rate with small variations
        final List<Map<String, dynamic>> hourlyData = [];
        final double baseRate = convertCurrency(1.0, fromCurrency, toCurrency, todayRates);

        for (int i = 12; i >= 0; i--) {
          final date = endDate.subtract(Duration(hours: i));
          // Add small random variation (±0.5%)
          final variation = (DateTime.now().millisecondsSinceEpoch % 10) / 1000 - 0.005;
          final rate = baseRate * (1 + variation);

          hourlyData.add({
            'date': date,
            'rate': rate,
          });
        }

        return hourlyData;
      }

      // For longer timeframes, use the historical endpoint
      // Note: Free plan only allows historical data for the past year
      // We'll need to make multiple requests for different dates

      final DateFormat formatter = DateFormat('yyyy-MM-dd');
      final List<Map<String, dynamic>> chartData = [];

      // For free plan, we can only get data for specific dates, not a time series
      // So we'll sample dates within our range
      List<DateTime> sampleDates = [];

      // Create sample dates based on timeframe
      if (timeFrame == '1W') {
        // Daily for a week
        for (int i = 7; i >= 0; i--) {
          sampleDates.add(endDate.subtract(Duration(days: i)));
        }
      } else if (timeFrame == '1M') {
        // Every 3 days for a month
        for (int i = 30; i >= 0; i -= 3) {
          sampleDates.add(endDate.subtract(Duration(days: i)));
        }
      } else if (timeFrame == '1Y') {
        // Every 2 weeks for a year
        for (int i = 365; i >= 0; i -= 14) {
          sampleDates.add(endDate.subtract(Duration(days: i)));
        }
      } else {
        // Default: weekly samples
        for (int i = 0; i < 10; i++) {
          sampleDates.add(startDate.add(Duration(days: i * (endDate.difference(startDate).inDays ~/ 10))));
        }
        sampleDates.add(endDate); // Add the end date
      }

      // Get rates for each sample date
      for (DateTime date in sampleDates) {
        try {
          final dateStr = formatter.format(date);
          final rates = await getHistoricalRates(dateStr);

          // Calculate conversion rate
          final rate = convertCurrency(1.0, fromCurrency, toCurrency, rates);

          chartData.add({
            'date': date,
            'rate': rate,
          });

          // Add a small delay to avoid hitting rate limits
          await Future.delayed(const Duration(milliseconds: 300));
        } catch (e) {
          print("Error fetching data for ${formatter.format(date)}: $e");
          // Continue with other dates even if one fails
        }
      }

      return chartData;
    } catch (e) {
      print("Chart Data Error: $e");
      throw Exception('Error fetching historical data: $e');
    }
  }

  // Calculate percentage change in last 24 hours
  static Future<Map<String, double>> get24HourChanges() async {
    try {
      // Get today's rates
      final todayRates = await getLatestRates();

      // Get yesterday's rates
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterday);
      final yesterdayRates = await getHistoricalRates(yesterdayStr);

      // Calculate percentage changes
      final Map<String, double> changes = {};

      todayRates.forEach((currency, rate) {
        if (yesterdayRates.containsKey(currency)) {
          final yesterdayRate = yesterdayRates[currency]!;
          final percentChange = ((rate - yesterdayRate) / yesterdayRate) * 100;
          changes[currency] = percentChange;
        } else {
          changes[currency] = 0.0; // Default if no historical data
        }
      });

      return changes;
    } catch (e) {
      print("24-Hour Changes Error: $e");
      throw Exception('Error calculating 24-hour changes: $e');
    }
  }

  // Helper function to get flag emoji from country code
  static String _getFlagEmoji(String currencyCode) {
    // Map of currency codes to country codes for flag emojis
    const Map<String, String> currencyToCountry = {
      'USD': '🇺🇸',
      'EUR': '🇪🇺',
      'GBP': '🇬🇧',
      'JPY': '🇯🇵',
      'CAD': '🇨🇦',
      'AUD': '🇦🇺',
      'CHF': '🇨🇭',
      'CNY': '🇨🇳',
      'INR': '🇮🇳',
      'MXN': '🇲🇽',
      'SGD': '🇸🇬',
      'NZD': '🇳🇿',
      'BRL': '🇧🇷',
      'SEK': '🇸🇪',
      'RUB': '🇷🇺',
      // Add more mappings as needed
    };

    return currencyToCountry[currencyCode] ?? '🏳️';
  }
}
