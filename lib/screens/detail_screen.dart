import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// models
import '../models/product.dart';

// services
import '../services/cart_service.dart';
import '../services/currency_service.dart';
import '../services/user_service.dart';

// widgets
import '../widgets/custom_text.dart';
import '../widgets/php_price_text.dart';
import '../utils/error_message.dart';

// Lab Activity 2 - Enhancement 2: details page shown when a product card is tapped, displaying
// the full product info (images, price, description, specs, reviews) fetched
// from the API via the Product model.
class DetailScreen extends StatefulWidget {
  final Product product;
  const DetailScreen({super.key, required this.product});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final PageController _imageController = PageController();
  int _imageIndex = 0;

  @override
  void dispose() {
    _imageController.dispose();
    super.dispose();
  }

  // Lab Activity 4 - Enhancement 3: cart is scoped to the signed-in user's real id. dummyjson's
  // /carts/add simulates the update and returns the recomputed cart, but
  // does not persist it server-side.
  Future<void> _addToCart(BuildContext context, Product product) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final user = await UserService().getUser();
      final cart = await CartService().addToCart(
        userId: user.id,
        products: [
          {'id': product.id, 'quantity': 1},
        ],
      );
      String total;
      try {
        final rate = await CurrencyService().usdToPhpRate;
        total = CurrencyService.formatUsdAsPhp(cart.discountedTotal, rate);
      } catch (_) {
        total = 'PHP total unavailable';
      }
      messenger.showSnackBar(
        SnackBar(content: Text('${product.title} added · cart total $total')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final images = product.images.isNotEmpty
        ? product.images
        : [product.thumbnail];
    final discountedPrice =
        product.price * (1 - product.discountPercentage / 100);

    return Scaffold(
      appBar: AppBar(
        title: CustomText(
          text: product.title,
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
      // Lab Activity 3 - Enhancement 3: https://dummyjson.com/carts/add — adds this product
      // to the demo user's cart by passing its id/quantity to CartService.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.r),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _addToCart(context, product),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 10.h),
                child: CustomText(
                  text: 'Add to Cart',
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImageGallery(images),
              Padding(
                padding: EdgeInsets.all(16.r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText(
                      text: product.brand.isNotEmpty
                          ? '${product.brand} · ${product.category}'
                          : product.category,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                    ),
                    SizedBox(height: 6.h),
                    CustomText(
                      text: product.title,
                      fontSize: 22.sp,
                      fontWeight: FontWeight.bold,
                    ),
                    SizedBox(height: 10.h),
                    Row(
                      children: [
                        PhpPriceText(
                          usdAmount: discountedPrice,
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (product.discountPercentage > 0) ...[
                          SizedBox(width: 8.w),
                          PhpPriceText(
                            usdAmount: product.price,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontStyle: FontStyle.italic,
                              decoration: TextDecoration.lineThrough,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: CustomText(
                              text:
                                  '-${product.discountPercentage.toStringAsFixed(0)}%',
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 18.sp),
                        SizedBox(width: 4.w),
                        CustomText(
                          text:
                              '${product.rating.toStringAsFixed(2)} · ${product.reviews.length} reviews',
                          fontSize: 13.sp,
                        ),
                        SizedBox(width: 12.w),
                        CustomText(
                          text: product.availabilityStatus.isNotEmpty
                              ? product.availabilityStatus
                              : (product.stock > 0
                                    ? 'In Stock (${product.stock})'
                                    : 'Out of Stock'),
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    CustomText(
                      text: 'Description',
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                    ),
                    SizedBox(height: 6.h),
                    CustomText(text: product.description, fontSize: 14.sp),
                    if (product.tags.isNotEmpty) ...[
                      SizedBox(height: 16.h),
                      Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        children: product.tags
                            .map(
                              (tag) => Chip(
                                label: CustomText(text: tag, fontSize: 12.sp),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    SizedBox(height: 20.h),
                    CustomText(
                      text: 'Details',
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                    ),
                    SizedBox(height: 6.h),
                    _buildDetailRow('SKU', product.sku),
                    _buildDetailRow('Weight', '${product.weight} g'),
                    _buildDetailRow(
                      'Dimensions',
                      '${product.dimensions.width} x ${product.dimensions.height} x ${product.dimensions.depth} cm',
                    ),
                    _buildDetailRow(
                      'Minimum Order',
                      '${product.minimumOrderQuantity}',
                    ),
                    _buildDetailRow('Warranty', product.warrantyInformation),
                    _buildDetailRow('Shipping', product.shippingInformation),
                    _buildDetailRow('Return Policy', product.returnPolicy),
                    if (product.reviews.isNotEmpty) ...[
                      SizedBox(height: 20.h),
                      CustomText(
                        text: 'Reviews',
                        fontSize: 15.sp,
                        fontWeight: FontWeight.bold,
                      ),
                      SizedBox(height: 8.h),
                      ...product.reviews.map(
                        (review) => Padding(
                          padding: EdgeInsets.only(bottom: 12.h),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CustomText(
                                    text: review.reviewerName,
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  SizedBox(width: 8.w),
                                  Row(
                                    children: List.generate(
                                      5,
                                      (i) => Icon(
                                        i < review.rating
                                            ? Icons.star
                                            : Icons.star_border,
                                        color: Colors.amber,
                                        size: 14.sp,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4.h),
                              CustomText(text: review.comment, fontSize: 13.sp),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110.w,
            child: CustomText(
              text: label,
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: CustomText(text: value, fontSize: 13.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGallery(List<String> images) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        SizedBox(
          height: 280.h,
          width: double.infinity,
          child: PageView.builder(
            controller: _imageController,
            itemCount: images.length,
            onPageChanged: (index) => setState(() => _imageIndex = index),
            itemBuilder: (context, index) {
              return Image.network(
                images[index],
                fit: BoxFit.cover,
                width: double.infinity,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                },
                errorBuilder: (_, _, _) =>
                    Center(child: Icon(Icons.image, size: 48.sp)),
              );
            },
          ),
        ),
        if (images.length > 1)
          Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                images.length,
                (index) => Container(
                  margin: EdgeInsets.symmetric(horizontal: 3.w),
                  width: 6.w,
                  height: 6.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == _imageIndex
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
