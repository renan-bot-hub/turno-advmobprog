import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../models/cart.dart';

class CartService {
  // Lab Activity 3 - Enhancement 3: https://dummyjson.com/docs/carts documents GET
  // /carts/user/{userId} to scope the fetch to a single user's cart instead
  // of the full /carts list.
  Future<List<Cart>> getCartsByUser(int userId) async {
    if (userId <= 0) return [];
    try {
      final response = await http
          .get(Uri.parse('$host/carts/user/$userId'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List cartsJson = data['carts'] ?? [];
        return cartsJson.map((json) => Cart.fromJson(json)).toList();
      } else if (response.statusCode == 404) {
        // User has no saved cart on DummyJSON
        return [];
      } else {
        throw Exception(
          'Could not load your cart (error ${response.statusCode}). Please try again.',
        );
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Could not load your cart. Please try again.');
    }
  }

  // Lab Activity 3 - Enhancement 3: POST /carts/add simulates adding/updating a user's cart
  // by passing the full product => quantity list; dummyjson recomputes and
  // returns the cart (it does not persist server-side).
  Future<Cart> addToCart({
    required int userId,
    required List<Map<String, dynamic>> products,
  }) async {
    // Lab Activity 6: DummyJSON carts need a DummyJSON user id; Firebase
    // accounts don't have one (id 0), which DummyJSON rejects with a 404.
    if (userId <= 0) {
      throw Exception('The cart is only available for DummyJSON accounts.');
    }
    final response = await http
        .post(
          Uri.parse('$host/carts/add'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'userId': userId, 'products': products}),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Cart.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(
        'Could not update your cart (error ${response.statusCode}). Please try again.',
      );
    }
  }
}
