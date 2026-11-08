import 'package:account_app/core/models/app_settings_model.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    Formatters.updateSettings(const AppSettings());
  });

  test('parses formatted amount with currency symbol and grouping', () {
    expect(Formatters.tryParseAmount('Rs 1,234'), 1234);
  });

  test('formats input amounts without the currency symbol', () {
    expect(Formatters.formatAmountWithoutCurrency(1234), '1,234');
  });

  test('parses custom decimal and thousand separators', () {
    Formatters.updateSettings(const AppSettings(
      currencySymbol: '€',
      thousandSeparator: '.',
      decimalSeparator: ',',
      currencyBefore: false,
      decimalPlaces: 2,
    ));

    expect(Formatters.formatAmountWithoutCurrency(1234.5), '1.234,50');
    expect(Formatters.tryParseAmount('1.234,50 €'), 1234.5);
  });

  test('returns null for text that is not an amount', () {
    expect(Formatters.tryParseAmount(''), isNull);
    expect(Formatters.tryParseAmount('not an amount'), isNull);
  });
}
