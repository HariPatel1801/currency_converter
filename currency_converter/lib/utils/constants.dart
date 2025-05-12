class Constants {
  // API configuration
  static const String apiKey = 'c1b93647dc7a49b68e2e31ebc8d4c9f1'; // Replace with your actual API key
  static const String apiBaseUrl = 'https://data.fixer.io/api';

  // Default currencies
  static const List<Map<String, String>> defaultCurrencies = [
    {'code': 'USD', 'name': 'US Dollar', 'flag': '🇺🇸'},
    {'code': 'EUR', 'name': 'Euro', 'flag': '🇪🇺'},
    {'code': 'GBP', 'name': 'British Pound', 'flag': '🇬🇧'},
    {'code': 'JPY', 'name': 'Japanese Yen', 'flag': '🇯🇵'},
    {'code': 'CAD', 'name': 'Canadian Dollar', 'flag': '🇨🇦'},
    {'code': 'AUD', 'name': 'Australian Dollar', 'flag': '🇦🇺'},
    {'code': 'CHF', 'name': 'Swiss Franc', 'flag': '🇨🇭'},
    {'code': 'CNY', 'name': 'Chinese Yuan', 'flag': '🇨🇳'},
    {'code': 'INR', 'name': 'Indian Rupee', 'flag': '🇮🇳'},
    {'code': 'MXN', 'name': 'Mexican Peso', 'flag': '🇲🇽'},
    {'code': 'SGD', 'name': 'Singapore Dollar', 'flag': '🇸🇬'},
    {'code': 'NZD', 'name': 'New Zealand Dollar', 'flag': '🇳🇿'},
    {'code': 'BRL', 'name': 'Brazilian Real', 'flag': '🇧🇷'},
    {'code': 'SEK', 'name': 'Swedish Krona', 'flag': '🇸🇪'},
    {'code': 'RUB', 'name': 'Russian Ruble', 'flag': '🇷🇺'},
  ];

  // Time frame options
  static const List<String> timeFrames = ['12H', '1D', '1W', '1M', '1Y', '5Y', '10Y'];
}
