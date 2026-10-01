import 'package:flutter/material.dart';

import '../services/currency_service.dart';

class PhpPriceText extends StatelessWidget {
  const PhpPriceText({
    super.key,
    required this.usdAmount,
    this.style,
    this.suffix = '',
  });

  final double usdAmount;
  final TextStyle? style;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<double>(
      future: CurrencyService().usdToPhpRate,
      builder: (context, snapshot) {
        final rate = snapshot.data;
        final text = snapshot.hasError
            ? 'PHP rate unavailable'
            : rate == null
            ? 'Loading price…'
            : '${CurrencyService.formatUsdAsPhp(usdAmount, rate)}$suffix';
        return Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        );
      },
    );
  }
}
