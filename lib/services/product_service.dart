import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../models/product.dart';

class ProductService {
  Future<List<Product>> getAllProducts() async {
    final response = await http
        .get(Uri.parse('$host/products?limit=0'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final List productsJson = data['products'] ?? [];
      return productsJson.map((json) => Product.fromJson(json)).toList();
    } else {
      throw Exception(
        'Could not load products (error ${response.statusCode}). Please try again.',
      );
    }
  }

  // Lab Activity 3 - Enhancement 1: cart line items only carry a title/price/thumbnail
  // summary, so opening DetailScreen from the cart needs the full product
  // fetched by id.
  Future<Product> getProductById(int id) async {
    final response = await http
        .get(Uri.parse('$host/products/$id'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return Product.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(
        'Could not load this product (error ${response.statusCode}). Please try again.',
      );
    }
  }
}
