import 'package:flutter_test/flutter_test.dart';
import 'package:turno_advmobprog/models/product.dart';
import 'package:turno_advmobprog/providers/cart_provider.dart';

void main() {
  test('cart updates quantity and discounted subtotal within stock', () {
    final cart = CartProvider();
    final product = Product.fromJson({
      'id': 1,
      'title': 'Test product',
      'price': 100,
      'discountPercentage': 10,
      'stock': 2,
    });

    cart.addProduct(product);
    cart.addProduct(product);
    cart.addProduct(product);

    expect(cart.itemCount, 2);
    expect(cart.subtotal, 180);
    expect(cart.items.single.quantity, 2);

    cart.decreaseQuantity(product.id);
    expect(cart.itemCount, 1);
    expect(cart.subtotal, 90);

    cart.decreaseQuantity(product.id);
    expect(cart.items, isEmpty);
    expect(cart.subtotal, 0);
  });
}
