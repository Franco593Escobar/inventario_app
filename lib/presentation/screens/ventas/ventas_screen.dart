import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:inventario_app/presentation/providers/auth_provider.dart';
import 'package:inventario_app/presentation/screens/ventas/_facturacion_tab.dart';
import 'package:inventario_app/presentation/screens/ventas/_historial_tab.dart';
import 'package:inventario_app/presentation/screens/ventas/_cierre_caja_tab.dart';

class VentasScreen extends StatefulWidget {
  const VentasScreen({super.key});

  @override
  State<VentasScreen> createState() => _VentasScreenState();
}

class _VentasScreenState extends State<VentasScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final tipoComercio = auth.tipoComercio;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        title: const Text('Ventas'),
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.orange,
          tabs: const [
            Tab(icon: Icon(Icons.receipt_outlined), text: 'Facturación'),
            Tab(icon: Icon(Icons.history), text: 'Historial'),
            Tab(icon: Icon(Icons.calculate_outlined), text: 'Cierre de Caja'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          FacturacionTab(tipoComercio: tipoComercio),
          const HistorialTab(),
          const CierreCajaTab(),
        ],
      ),
    );
  }
}
