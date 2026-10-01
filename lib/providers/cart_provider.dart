import 'package:flutter/foundation.dart';

import '../models/cart.dart';
import '../models/product.dart';
import '../services/cart_service.dart';

class CartItem {
  final Product product;
  final int? stockLimit;
  int quantity;

  CartItem({required this.product, this.quantity = 1, this.stockLimit});

  double get unitPrice =>
      product.price * (1 - product.discountPercentage / 100);

  double get total => unitPrice * quantity;
}

class CartProvider extends ChangeNotifier {
  final Map<int, CartItem> _items = {};
  final CartService _cartService = CartService();
  int? _loadedDummyJsonUserId;

  bool isLoading = false;
  String? loadError;

  List<CartItem> get items => List.unmodifiable(_items.values);
  int get itemCount =>
      _items.values.fold(0, (total, item) => total + item.quantity);
  double get subtotal =>
      _items.values.fold(0, (total, item) => total + item.total);

  void addProduct(Product product) {
    final item = _items[product.id];
    if (item == null) {
      if (product.stock <= 0) return;
      _items[product.id] = CartItem(
        product: product,
        stockLimit: product.stock,
      );
    } else {
      increaseQuantity(product.id);
      return;
    }
    notifyListeners();
  }

  void increaseQuantity(int productId) {
    final item = _items[productId];
    if (item == null ||
        (item.stockLimit != null && item.quantity >= item.stockLimit!)) {
      return;
    }
    item.quantity++;
    notifyListeners();
  }

  Future<void> loadDummyJsonCart(int userId) async {
    if (_loadedDummyJsonUserId == userId || isLoading) return;

    final localItems = Map<int, CartItem>.from(_items);
    isLoading = true;
    loadError = null;
    notifyListeners();

    try {
      final carts = await _cartService.getCartsByUser(userId);
      _items.clear();

      if (carts.isNotEmpty) {
        for (final cartProduct in carts.first.products) {
          final product = _productFromCartProduct(cartProduct);
          final localItem = localItems.remove(product.id);
          _items[product.id] = CartItem(
            product: product,
            quantity: cartProduct.quantity + (localItem?.quantity ?? 0),
          );
        }
      }

      _items.addAll(localItems);
      _loadedDummyJsonUserId = userId;
    } catch (error) {
      loadError = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void decreaseQuantity(int productId) {
    final item = _items[productId];
    if (item == null) return;
    if (item.quantity <= 1) {
      _items.remove(productId);
    } else {
      item.quantity--;
    }
    notifyListeners();
  }

  Product _productFromCartProduct(CartProduct item) => Product.fromJson({
    'id': item.id,
    'title': item.title,
    'price': item.price,
    'discountPercentage': item.discountPercentage,
    'thumbnail': item.thumbnail,
  });
}
