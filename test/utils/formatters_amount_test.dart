import 'package:flutter/services.dart';
import 'package:account_app/core/models/app_settings_model.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    Formatters.updateSettings(const AppSettings());
  });

  test('parses formatted amount with currency symbol and grouping', () {
    expect(Formatters.tryParseAmount('Rs 1,234'), 1234);
    expect(Formatters.safeParseDouble('1,000'), 1000);
  });

  test('formats input amounts without the currency symbol', () {
    expect(Formatters.formatAmountWithoutCurrency(1234), '1,234');
  });

  test('currency formatting has no decimals and parses locale separators', () {
    Formatters.updateSettings(const AppSettings(
      currencySymbol: '€',
      thousandSeparator: '.',
      decimalSeparator: ',',
      currencyBefore: false,
      decimalPlaces: 2,
    ));

    expect(Formatters.formatAmountWithoutCurrency(1234.5), '1.235');
    expect(Formatters.tryParseAmount('1.234,50 €'), 1235);
    expect(Formatters.tryParseAmount('1,234.50'), 1235);
    expect(Formatters.formatAmount(1234.5), '1.235');
    expect(Formatters.formatAmountWithCurrency(1234.5), '1.235 €');
    expect(Formatters.safeParseDouble('1.234,50 €'), 1234.5);
    expect(Formatters.decimalPlaces, 0);
  });

  test('returns null for text that is not an amount', () {
    expect(Formatters.tryParseAmount(''), isNull);
    expect(Formatters.tryParseAmount('not an amount'), isNull);
  });

  test('integer input strips the fractional part instead of concatenating it',
      () {
    const formatter = CurrencyInputFormatter();
    final value = formatter.formatEditUpdate(
      const TextEditingValue(),
      const TextEditingValue(
        text: '1,000.50',
        selection: TextSelection.collapsed(offset: 8),
      ),
    );

    expect(value.text, '1,000');
  });

  test('input grouping supports large numbers without integer overflow', () {
    const formatter = CurrencyInputFormatter(allowDecimals: false);
    final value = formatter.formatEditUpdate(
      const TextEditingValue(),
      const TextEditingValue(
        text: '123456789012345678901234',
        selection: TextSelection.collapsed(offset: 24),
      ),
    );

    expect(value.text, '123,456,789,012,345,678,901,234');
  });

  test('input formatter caps decimals and keeps the cursor by digit position',
      () {
    const formatter =
        CurrencyInputFormatter(allowDecimals: true, maxDecimalPlaces: 2);
    final value = formatter.formatEditUpdate(
      const TextEditingValue(),
      const TextEditingValue(
        text: '12345.6789',
        selection: TextSelection.collapsed(offset: 5),
      ),
    );

    expect(value.text, '12,345.67');
    expect(value.selection.extentOffset, 6);
  });
}
