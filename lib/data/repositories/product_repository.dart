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

  Stream<List<Product>> watchByTenant(String tenantId) {
    return _productosCollection
        .where('tenant_id', isEqualTo: tenantId)
        .orderBy('nombre')
        .snapshots()
        .map(
            (s) => s.docs.map((d) => Product.fromMap(d.id, d.data())).toList());
  }

  Future<void> createProduct(Product product) async {
    await _productosCollection.add(product
        .copyWith(
          id: '',
          fechaCreacion: product.fechaCreacion ?? DateTime.now(),
        )
        .toMap());
  }

  Future<void> updateProduct(Product product) async {
    await _productosCollection.doc(product.id).update(product.toMap());
  }

  Future<void> deleteProduct(String productId) async {
    await _productosCollection.doc(productId).delete();
  }
}
