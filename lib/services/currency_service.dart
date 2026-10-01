import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyService {
  static const _ratePreferenceKey = 'usd_to_php_rate';
  static final _pesoFormat = NumberFormat.currency(
    locale: 'en_PH',
    symbol: '₱',
    decimalDigits: 2,
  );
  static double? _cachedRate;
  static Future<double>? _rateRequest;

  Future<double> get usdToPhpRate {
    final cachedRate = _cachedRate;
    if (cachedRate != null) return Future.value(cachedRate);
    return _rateRequest ??= _loadUsdToPhpRate();
  }

  static String formatPhp(double amount) => _pesoFormat.format(amount);

  static String formatUsdAsPhp(double usdAmount, double exchangeRate) {
    return formatPhp(usdAmount * exchangeRate);
  }

  Future<double> _loadUsdToPhpRate() async {
    final preferences = await SharedPreferences.getInstance();
    try {
      final response = await http
          .get(Uri.https('open.er-api.com', '/v6/latest/USD'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw const FormatException('Exchange-rate service unavailable.');
      }

      final body = jsonDecode(response.body);
      final rates = body is Map<String, dynamic> ? body['rates'] : null;
      final rateValue = rates is Map ? rates['PHP'] : null;
      final rate = rateValue is num ? rateValue.toDouble() : null;
      if (body is! Map<String, dynamic> ||
          body['result'] != 'success' ||
          rate == null ||
          !rate.isFinite ||
          rate <= 0) {
        throw const FormatException('Invalid exchange-rate response.');
      }

      _cachedRate = rate;
      await preferences.setDouble(_ratePreferenceKey, rate);
      return rate;
    } catch (_) {
      final savedRate = preferences.getDouble(_ratePreferenceKey);
      if (savedRate != null && savedRate.isFinite && savedRate > 0) {
        _cachedRate = savedRate;
        return savedRate;
      }
      _rateRequest = null;
      rethrow;
    }
  }
}
