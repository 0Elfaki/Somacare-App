// Product Category Enum - kept for UI compatibility
enum ProductCategory {
  all,
  medicines,
  supplements,
  firstAid,
  personalCare,
  devices,
}

/// Product model for medical store items.
///
/// Maps to Supabase `products` table.
class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final double? originalPrice;
  final String image;
  final ProductCategory category;
  final bool inStock;
  final double rating;
  final int reviewCount;
  final bool prescriptionRequired;

  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.originalPrice,
    required this.image,
    required this.category,
    this.inStock = true,
    this.rating = 4.5,
    this.reviewCount = 0,
    this.prescriptionRequired = false,
  });

  /// Parse from Supabase row.
  factory Product.fromMap(Map<String, dynamic> data) {
    return Product(
      id: data['id'] as String,
      name: data['name'] as String,
      description: data['description'] as String? ?? '',
      price: (data['price'] as num).toDouble(),
      originalPrice: data['original_price'] != null
          ? (data['original_price'] as num).toDouble()
          : null,
      image: data['image_url'] as String? ?? '',
      category: _categoryFromString(data['category'] as String?),
      inStock: data['in_stock'] as bool? ?? true,
      rating: (data['rating'] as num?)?.toDouble() ?? 4.5,
      reviewCount: data['review_count'] as int? ?? 0,
      prescriptionRequired: data['prescription_required'] as bool? ?? false,
    );
  }

  /// Convert to map for Supabase insert/update.
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'price': price,
    'original_price': originalPrice,
    'image_url': image,
    'category': category.name,
    'in_stock': inStock,
    'rating': rating,
    'review_count': reviewCount,
    'prescription_required': prescriptionRequired,
  };

  /// Create a copy with optional modifications.
  Product copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    double? originalPrice,
    String? image,
    ProductCategory? category,
    bool? inStock,
    double? rating,
    int? reviewCount,
    bool? prescriptionRequired,
  }) => Product(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    price: price ?? this.price,
    originalPrice: originalPrice ?? this.originalPrice,
    image: image ?? this.image,
    category: category ?? this.category,
    inStock: inStock ?? this.inStock,
    rating: rating ?? this.rating,
    reviewCount: reviewCount ?? this.reviewCount,
    prescriptionRequired: prescriptionRequired ?? this.prescriptionRequired,
  );

  static ProductCategory _categoryFromString(String? category) {
    switch (category) {
      case 'medicines':
        return ProductCategory.medicines;
      case 'supplements':
        return ProductCategory.supplements;
      case 'firstAid':
        return ProductCategory.firstAid;
      case 'personalCare':
        return ProductCategory.personalCare;
      case 'devices':
        return ProductCategory.devices;
      default:
        return ProductCategory.medicines;
    }
  }
}

/// Cart item model for student's shopping cart.
///
/// Maps to Supabase `cart_items` table.
/// Also exported as CartItem for backwards compatibility.
class CartItemModel {
  final String id;
  final String studentId;
  final String productId;
  final int quantity;
  final DateTime createdAt;
  // Product details (joined from products table)
  final Product? product;

  const CartItemModel({
    required this.id,
    required this.studentId,
    required this.productId,
    required this.quantity,
    required this.createdAt,
    this.product,
  });

  /// Parse from Supabase row (cart_items table).
  factory CartItemModel.fromMap(Map<String, dynamic> data) {
    return CartItemModel(
      id: data['id'] as String,
      studentId: data['student_id'] as String,
      productId: data['product_id'] as String,
      quantity: data['quantity'] as int? ?? 1,
      createdAt: DateTime.parse(data['created_at'] as String),
      product: data['products'] != null
          ? Product.fromMap(data['products'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Convert to map for Supabase insert/update.
  Map<String, dynamic> toMap() => {
    'id': id,
    'student_id': studentId,
    'product_id': productId,
    'quantity': quantity,
  };

  /// Get total price for this cart item.
  double get total => (product?.price ?? 0) * quantity;

  /// Create a copy with optional modifications.
  CartItemModel copyWith({
    String? id,
    String? studentId,
    String? productId,
    int? quantity,
    DateTime? createdAt,
    Product? product,
  }) => CartItemModel(
    id: id ?? this.id,
    studentId: studentId ?? this.studentId,
    productId: productId ?? this.productId,
    quantity: quantity ?? this.quantity,
    createdAt: createdAt ?? this.createdAt,
    product: product ?? this.product,
  );
}

/// Order model for student purchases.
///
/// Maps to Supabase `orders` table.
class OrderModel {
  final String id;
  final String studentId;
  final List<OrderItem> items;
  final double totalAmount;
  final String status;
  final DateTime createdAt;

  const OrderModel({
    required this.id,
    required this.studentId,
    required this.items,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
  });

  /// Parse from Supabase row.
  factory OrderModel.fromMap(Map<String, dynamic> data) {
    final itemsJson = data['items'] as List<dynamic>? ?? [];
    final items = itemsJson
        .map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
        .toList();

    return OrderModel(
      id: data['id'] as String,
      studentId: data['student_id'] as String,
      items: items,
      totalAmount: (data['total_amount'] as num).toDouble(),
      status: data['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(data['created_at'] as String),
    );
  }

  /// Convert to map for Supabase insert.
  Map<String, dynamic> toMap() => {
    'id': id,
    'student_id': studentId,
    'items': items.map((item) => item.toMap()).toList(),
    'total_amount': totalAmount,
    'status': status,
  };
}

/// Individual item within an order.
class OrderItem {
  final String productId;
  final String productName;
  final double price;
  final int quantity;

  const OrderItem({
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
  });

  factory OrderItem.fromMap(Map<String, dynamic> data) {
    return OrderItem(
      productId: data['product_id'] as String,
      productName: data['product_name'] as String,
      price: (data['price'] as num).toDouble(),
      quantity: data['quantity'] as int,
    );
  }

  Map<String, dynamic> toMap() => {
    'product_id': productId,
    'product_name': productName,
    'price': price,
    'quantity': quantity,
  };

  double get total => price * quantity;
}
