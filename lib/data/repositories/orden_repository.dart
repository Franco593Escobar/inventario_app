import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:inventario_app/data/models/orden.dart';
import 'package:inventario_app/data/models/venta.dart';

class OrdenRepository {
  OrdenRepository()
      : _firestore = FirebaseFirestore.instanceFor(
          app: Firebase.app(),
          databaseURL: 'inventario-bdd',
        );

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('ordenes');

  /// Stream de órdenes abiertas del tenant, ordenadas por fecha ASC.
  Stream<List<Orden>> watchAbiertas(String tenantId) {
    return _col
        .where('tenant_id', isEqualTo: tenantId)
        .where('estado', isEqualTo: 'abierta')
        .orderBy('fecha_creacion', descending: false)
        .snapshots()
        .map((s) => s.docs.map((d) => Orden.fromMap(d.id, d.data())).toList());
  }

  /// Crea una nueva orden y retorna la orden con su id real de Firestore.
  Future<Orden> create(Orden orden) async {
    final ref = await _col.add(orden.toMap());
    return orden.copyWith(id: ref.id);
  }

  /// Actualiza los ítems de una orden existente.
  Future<void> updateItems(String ordenId, List<OrdenItem> items) async {
    await _col.doc(ordenId).update({
      'items': items.map((i) => i.toMap()).toList(),
    });
  }

  /// Finaliza el pago de una orden:
  /// 1. Crea una Venta en Firestore
  /// 2. Decrementa stock de cada producto
  /// 3. Marca la orden como 'pagada'
  Future<void> pagar(
    Orden orden,
    String metodoPago, {
    String? observaciones,
  }) async {
    final batch = _firestore.batch();

    // Guardar ítems actuales antes de pagar
    await _col.doc(orden.id).update({
      'items': orden.items.map((i) => i.toMap()).toList(),
    });

    final venta = Venta(
      id: '',
      tenantId: orden.tenantId,
      items: orden.items
          .map((i) => VentaItem(
                productoId: i.productoId,
                nombre: i.nombre,
                codigo: i.codigo,
                precio: i.precio,
                cantidad: i.cantidad,
                subtotal: i.subtotal,
                impuesto: i.impuesto,
              ))
          .toList(),
      subtotal: orden.subtotal,
      totalImpuesto: 0,
      total: orden.total,
      metodoPago: metodoPago,
      vendedor: orden.vendedor,
      estado: 'completada',
      fecha: DateTime.now(),
      observaciones: observaciones ??
          (orden.tipo == 'mesa'
              ? 'Mesa ${orden.numeroMesa}'
              : orden.tipo == 'domicilio'
                  ? 'Domicilio: ${orden.clienteNombre ?? ""}'
                  : null),
      creadoPor: orden.vendedor,
    );

    final ventaRef = _firestore.collection('ventas').doc();
    batch.set(ventaRef, venta.toMap());

    final prodCol = _firestore.collection('productos');
    for (final item in orden.items) {
      batch.update(prodCol.doc(item.productoId), {
        'stock': FieldValue.increment(-(item.cantidad.toInt())),
      });
    }

    batch.update(_col.doc(orden.id), {'estado': 'pagada'});
    await batch.commit();
  }

  /// Cancela una orden sin generar venta.
  Future<void> cancelar(String ordenId) async {
    await _col.doc(ordenId).update({'estado': 'cancelada'});
  }

  /// Actualiza las observaciones de una orden.
  Future<void> updateObservaciones(String ordenId, String obs) async {
    await _col.doc(ordenId).update({'observaciones': obs});
  }
}
