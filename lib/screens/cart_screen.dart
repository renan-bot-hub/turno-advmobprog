import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// models
import '../models/cart.dart';

// services
import '../services/cart_service.dart';
import '../services/product_service.dart';
import '../services/user_service.dart';
import '../utils/error_message.dart';

// screens
import 'detail_screen.dart';

// widgets
import '../widgets/custom_text.dart';
import '../widgets/php_price_text.dart';

// Cart tab (embedded in HomeScreen's PageView, no own Scaffold/AppBar).
// Lab Activity 3 - Enhancement 3: loads one user's cart via CartService.getCartsByUser and
// keeps totals in sync through CartService.addToCart when quantities change.
// Lab Activity 3 - Enhancement 1: tapping an item opens its full DetailScreen.
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<CartProduct> _items = [];
  double _discountedTotal = 0;
  int? _userId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  // Lab Activity 4 - Enhancement 3: cart is scoped to the signed-in user's real id (read
  // from the saved user data) instead of a hardcoded demo id.
  Future<void> _loadCart() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await UserService().getUser();
      final carts = await CartService().getCartsByUser(user.id);
      final cart = carts.isNotEmpty ? carts.first : null;
      if (!mounted) return;
      setState(() {
        _userId = user.id;
        _items = cart?.products ?? [];
        _discountedTotal = cart?.discountedTotal ?? 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorMessage(e);
        _loading = false;
      });
    }
  }

  // Lab Activity 3 - Enhancement 3: resubmits every line item with its new quantity to
  // /carts/add and refreshes totals from the recomputed response.
  Future<void> _changeQuantity(CartProduct item, int delta) async {
    final userId = _userId;
    if (userId == null) return;

    final newQuantity = item.quantity + delta;
    if (newQuantity < 1) return;

    final products = _items
        .map(
          (p) => {
            'id': p.id,
            'quantity': p.id == item.id ? newQuantity : p.quantity,
          },
        )
        .toList();

    try {
      final cart = await CartService().addToCart(
        userId: userId,
        products: products,
      );
      if (!mounted) return;
      setState(() {
        _items = cart.products;
        _discountedTotal = cart.discountedTotal;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage(e))));
    }
  }

  // Lab Activity 3 - Enhancement 1: cart items only carry a product summary, so the full
  // product is fetched by id before opening DetailScreen.
  Future<void> _openDetail(int productId) async {
    try {
      final product = await ProductService().getProductById(productId);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetailScreen(product: product)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomText(
                text: _error!,
                fontSize: 14.sp,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12.h),
              ElevatedButton.icon(
                onPressed: _loadCart,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadCart,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: 120.h),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 64.sp,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 12.h),
                  CustomText(text: 'Your cart is empty.', fontSize: 14.sp),
                  SizedBox(height: 12.h),
                  ElevatedButton.icon(
                    onPressed: _loadCart,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCart,
      child: Column(
        children: [
          Expanded(
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(16.r),
              itemCount: _items.length,
              separatorBuilder: (_, _) => SizedBox(height: 12.h),
              itemBuilder: (context, index) => _buildItemRow(_items[index]),
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildItemRow(CartProduct item) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(10.r),
        child: Row(
          children: [
            Expanded(
              // Lab Activity 3 - Enhancement 1: tap the item (image/text) to view its detail.
              child: InkWell(
                onTap: () => _openDetail(item.id),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8.r),
                      child: item.thumbnail.isNotEmpty
                          ? Image.network(
                              item.thumbnail,
                              width: 56.w,
                              height: 56.w,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return SizedBox(
                                  width: 56.w,
                                  height: 56.w,
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (_, _, _) => Container(
                                width: 56.w,
                                height: 56.w,
                                color: Colors.grey.shade200,
                                child: Icon(Icons.image, size: 24.sp),
                              ),
                            )
                          : Container(
                              width: 56.w,
                              height: 56.w,
                              color: Colors.grey.shade200,
                              child: Icon(Icons.image, size: 24.sp),
                            ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomText(
                            text: item.title,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4.h),
                          PhpPriceText(
                            usdAmount: item.price,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Row(
                            children: [
                              CustomText(
                                text:
                                    '${item.discountPercentage.toStringAsFixed(0)}% off · ',
                                fontSize: 11.sp,
                              ),
                              Expanded(
                                child: PhpPriceText(
                                  usdAmount: item.discountedTotal,
                                  suffix: ' total',
                                  style: TextStyle(fontSize: 11.sp),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 8.w),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => _changeQuantity(item, 1),
                  child: CircleAvatar(
                    radius: 12.r,
                    backgroundColor: Colors.amber,
                    child: Icon(Icons.add, size: 14.sp, color: Colors.black),
                  ),
                ),
                SizedBox(height: 4.h),
                CustomText(text: '${item.quantity}', fontSize: 13.sp),
                SizedBox(height: 4.h),
                InkWell(
                  onTap: () => _changeQuantity(item, -1),
                  child: CircleAvatar(
                    radius: 12.r,
                    backgroundColor: Colors.grey.shade300,
                    child: Icon(Icons.remove, size: 14.sp, color: Colors.black),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Column(
          children: [
            Row(
              children: [
                CustomText(text: 'Subtotal', fontSize: 14.sp),
                const Spacer(),
                PhpPriceText(
                  usdAmount: _discountedTotal,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            Row(
              children: [
                CustomText(text: 'Delivery Fee', fontSize: 14.sp),
                const Spacer(),
                CustomText(text: 'Free', fontSize: 14.sp),
              ],
            ),
            SizedBox(height: 16.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Order confirmed (demo)')),
                  );
                },
                child: CustomText(
                  text: 'Confirm Order',
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
