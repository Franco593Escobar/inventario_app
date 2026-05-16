import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:inventario_app/data/models/product.dart';

class ProductRepository {
  ProductRepository()
      : _firestore = FirebaseFirestore.instanceFor(
          app: Firebase.app(),
          databaseURL: 'inventario-bdd',
        );

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _productosCollection =>
      _firestore.collection('productos');

  Stream<List<Product>> watchProducts() {
    return _productosCollection.orderBy('nombre').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Product.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  Future<void> createProduct(Product product) async {
    await _productosCollection.add(product.toMap());
  }

  Future<void> updateProduct(Product product) async {
    await _productosCollection.doc(product.id).update(product.toMap());
  }

  Future<void> deleteProduct(String productId) async {
    await _productosCollection.doc(productId).delete();
  }
}
