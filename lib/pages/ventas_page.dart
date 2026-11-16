import 'package:flutter/material.dart';
import '../db/database.dart';
import '../theme.dart';
import '../utils.dart';

class VentasPage extends StatefulWidget {
  const VentasPage({super.key});
  @override
  State<VentasPage> createState() => _VentasPageState();
}

class _VentasPageState extends State<VentasPage> {
  List<Map<String, dynamic>> productos = [];
  List<Map<String, dynamic>> ventasHoy = [];
  int? productoId;
  bool porCaja = false;
  final cantCtl = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    cargar();
  }

  Future<void> cargar() async {
    final p = await Db.productos();
    final v = await Db.ventasDelDia(hoy());
    if (!mounted) return;
    setState(() {
      productos = p;
      ventasHoy = v;
      if (productoId == null && p.isNotEmpty) productoId = p.first['id'] as int;
    });
  }

  Future<void> registrar() async {
    final cant = int.tryParse(cantCtl.text) ?? 0;
    if (productoId == null || cant <= 0) return;
    final prod = productos.firstWhere((p) => p['id'] == productoId);
    final porCajaN = (prod['unidades_por_caja'] as num?)?.toInt() ?? 1;
    final unidades = porCaja ? cant * porCajaN : cant;
    await Db.registrarVenta(
        fecha: hoy(), producto: prod, unidades: unidades, porCaja: porCaja);
    cantCtl.text = '1';
    await cargar();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Venta registrada: $unidades unidades')));
  }

  String _n(Map<String, dynamic>? p, String k) =>
      p == null ? '' : (p[k] as num).round().toString();

  Future<void> productoDialog([Map<String, dynamic>? p]) async {
    final nombre = TextEditingController(text: p?['nombre'] as String? ?? '');
    final codigo = TextEditingController(text: p?['codigo'] as String? ?? '');
    final costo = TextEditingController(text: _n(p, 'costo'));
    final precio = TextEditingController(text: _n(p, 'precio'));
    final mayor = TextEditingController(text: _n(p, 'precio_mayorista'));
    final caja = TextEditingController(text: p == null ? '1' : _n(p, 'unidades_por_caja'));

    Widget campo(String t, TextEditingController c, {bool num = true}) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: TextField(
            controller: c,
            keyboardType: num ? TextInputType.number : TextInputType.text,
            decoration: InputDecoration(labelText: t),
          ),
        );

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(p == null ? 'Nuevo producto' : 'Editar producto'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              campo('Nombre', nombre, num: false),
              campo('Código de barras (opcional)', codigo, num: false),
              campo('Costo por unidad', costo),
              campo('Precio de venta', precio),
              campo('Precio mayorista', mayor),
              campo('Unidades por caja madre', caja),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Guardar')),
        ],
      ),
    );

    if (ok == true && nombre.text.trim().isNotEmpty) {
      await Db.guardarProducto({
        'nombre': nombre.text.trim(),
        'codigo': codigo.text.trim(),
        'costo': double.tryParse(costo.text) ?? 0,
        'precio': double.tryParse(precio.text) ?? 0,
        'precio_mayorista': double.tryParse(mayor.text) ?? 0,
        'unidades_por_caja': int.tryParse(caja.text) ?? 1,
      }, p?['id'] as int?);
      await cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => productoDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Producto'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  DropdownButtonFormField<int>(
                    value: productoId,
                    decoration: const InputDecoration(labelText: 'Producto'),
                    items: productos
                        .map((p) => DropdownMenuItem<int>(
                            value: p['id'] as int, child: Text(p['nombre'] as String)))
                        .toList(),
                    onChanged: (v) => setState(() => productoId = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Venta por caja madre'),
                    subtitle: const Text('Usa el precio mayorista'),
                    value: porCaja,
                    onChanged: (v) => setState(() => porCaja = v),
                  ),
                  TextField(
                    controller: cantCtl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: porCaja ? 'Cantidad de cajas' : 'Cantidad de unidades'),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: registrar,
                      icon: const Icon(Icons.check),
                      label: const Text('Registrar venta'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 12, 4, 4),
            child: Text('Ventas de hoy',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          if (ventasHoy.isEmpty) const ListTile(title: Text('Todavía no hay ventas hoy')),
          ...ventasHoy.map((v) => Card(
                child: ListTile(
                  leading: Icon(
                    (v['por_caja'] as num) == 1 ? Icons.inventory_2 : Icons.cake,
                    color: Estanque.agua,
                  ),
                  title: Text('${v['nombre']}'),
                  subtitle: Text('${v['unidades']} unidades'),
                  trailing: Text(pesos(v['total'] as num),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              )),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 16, 4, 4),
            child: Text('Productos (toca uno para editar costos y precios)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          ...productos.map((p) => Card(
                child: ListTile(
                  title: Text(p['nombre'] as String),
                  subtitle: Text(
                      'Costo ${pesos(p['costo'] as num)} · Venta ${pesos(p['precio'] as num)} · Mayorista ${pesos(p['precio_mayorista'] as num)}'),
                  trailing: const Icon(Icons.edit),
                  onTap: () => productoDialog(p),
                ),
              )),
        ],
      ),
    );
  }
}
