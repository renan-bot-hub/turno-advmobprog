import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/cart.dart';
import '../models/product.dart';
import '../services/cart_service.dart';
import '../widgets/custom_text.dart';
import 'detail_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CartService _cartService = CartService();
  late Future<List<Cart>> _cartFuture;

  @override
  void initState() {
    super.initState();
    // Enhancement 1: Render cart items from the new carts API endpoint.
    _cartFuture = _cartService.getAllCarts();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Cart>>(
      future: _cartFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No cart found'));
        }

        final cart = snapshot.data!.first;

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: cart.products.length,
                itemBuilder: (context, index) {
                  final cartProduct = cart.products[index];
                  return ListTile(
                    leading: Image.network(
                      cartProduct.thumbnail,
                      width: 50.w,
                      height: 50.h,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.image),
                    ),
                    title: CustomText(text: cartProduct.title, fontSize: 16.sp),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('\$${cartProduct.price}'),
                        Text('${cartProduct.discountPercentage}% off - \$${cartProduct.discountedTotal} total', style: TextStyle(fontSize: 10.sp)),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(4)),
                          child: Icon(Icons.add, size: 16.sp, color: Colors.orange),
                        ),
                        Text('${cartProduct.quantity}'),
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                          child: Icon(Icons.remove, size: 16.sp, color: Colors.grey),
                        ),
                      ],
                    ),
                    onTap: () {
                      // Enhancement 1: Make cart items clickable to open the detail screen.
                      final product = Product(
                        id: cartProduct.id,
                        title: cartProduct.title,
                        description: 'Description for ${cartProduct.title}',
                        category: '',
                        price: cartProduct.price,
                        discountPercentage: cartProduct.discountPercentage,
                        rating: 0,
                        stock: 0,
                        tags: [],
                        brand: '',
                        sku: '',
                        weight: 0,
                        dimensions: ProductDimensions(width: 0, height: 0, depth: 0),
                        warrantyInformation: '',
                        shippingInformation: '',
                        availabilityStatus: '',
                        reviews: [],
                        returnPolicy: '',
                        minimumOrderQuantity: 1,
                        meta: ProductMeta(createdAt: '', updatedAt: '', barcode: '', qrCode: ''),
                        images: [cartProduct.thumbnail],
                        thumbnail: cartProduct.thumbnail,
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProductDetailsScreen(product: product),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: EdgeInsets.all(16.r),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Subtotal:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
                      Text('\$${cart.discountedTotal}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp, color: Colors.orange)),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                      ),
                      onPressed: () {},
                      child: const Text('Confirm Order', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
