import 'product_model.dart';

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  double get lineTotal => product.price * quantity;
}

/// État du panier pour un seul commerce à la fois (comme RideDraft : un
/// objet Dart simple créé dans l'écran catalogue, passé par référence
/// mutable aux écrans suivants — pas de Provider/Bloc).
class Cart {
  final String merchantProfileId;
  final String merchantName;
  final List<CartItem> items = [];

  Cart({required this.merchantProfileId, required this.merchantName});

  void add(Product product) {
    final index = items.indexWhere((i) => i.product.id == product.id);
    if (index != -1) {
      items[index].quantity++;
    } else {
      items.add(CartItem(product: product));
    }
  }

  void remove(String productId) {
    items.removeWhere((i) => i.product.id == productId);
  }

  void updateQuantity(String productId, int quantity) {
    final index = items.indexWhere((i) => i.product.id == productId);
    if (index == -1) return;
    if (quantity <= 0) {
      items.removeAt(index);
    } else {
      items[index].quantity = quantity;
    }
  }

  int quantityFor(String productId) {
    for (final item in items) {
      if (item.product.id == productId) return item.quantity;
    }
    return 0;
  }

  double get subtotal => items.fold(0.0, (sum, i) => sum + i.lineTotal);
  int get totalItems => items.fold(0, (sum, i) => sum + i.quantity);
  bool get isEmpty => items.isEmpty;
}
