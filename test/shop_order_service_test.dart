import 'package:flutter_test/flutter_test.dart';
import 'package:account_app/features/order/services/shop_order_service.dart';

void main() {
  group('ShopOrderService.parseConfiguredAmount', () {
    test('parses configured amounts with currency symbols and separators', () {
      expect(ShopOrderService.parseConfiguredAmount('Rs. 1,250'), 1250);
      expect(ShopOrderService.parseConfiguredAmount('PKR 75.50'), 75.5);
      expect(ShopOrderService.parseConfiguredAmount('روپے ۱٬۲۵۰'), 1250);
    });

    test('parses Urdu and Arabic-Indic digits', () {
      expect(ShopOrderService.parseConfiguredAmount('روپے ۱۲۵۰'), 1250);
      expect(ShopOrderService.parseConfiguredAmount('١٢٥'), 125);
    });

    test('treats blank, free, invalid, and negative configurations as zero',
        () {
      expect(ShopOrderService.parseConfiguredAmount(''), 0);
      expect(ShopOrderService.parseConfiguredAmount('Free'), 0);
      expect(ShopOrderService.parseConfiguredAmount('???'), 0);
      expect(ShopOrderService.parseConfiguredAmount('-Rs. 20'), 0);
    });
  });
}
