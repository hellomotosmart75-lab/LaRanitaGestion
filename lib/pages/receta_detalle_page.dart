import 'package:flutter/material.dart';
import '../db/db_stock.dart';
import '../theme.dart';
import '../utils.dart';

class RecetaDetallePage extends StatefulWidget {
  final int recetaId;
  const RecetaDetallePage({super.key, required this.recetaId});

  @override
  State<RecetaDetallePage> createState() => _RecetaDetallePageState();
}

class _RecetaDetallePageState extends State<RecetaDetallePage> {
  Map<String, dynamic>? receta;
  List<Map<String, dynamic>> items = [];

  @override
  void initState() {
    super.initState();
    cargar();
  }

  Future<void> cargar() async {
    final r = await DbStock.receta(widget.recetaId);
    final it = await DbStock.items(widget.recetaId);
    if (!mounted) return;
    setState(() {
      receta = r;
      items = it;
    });
  }

  int get rinde => (receta?['rinde'] as num?)?.toInt() ?? 1;

  double get costoTanda => items.fold<double>(
      0.0,
      (a, i) =>
          a + ((i['cantidad'] as num) * (i['costo_unitario'] as num)).toDouble());

  double get costoUnidad => rinde > 0 ? costoTanda / rinde : 0.0;

  Future<void> agregarInsumo() async {
    final insumos = await DbStock.insumos();
    if (!mounted) return;
    if (insumos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Primero carga insumos en la pestaña Insumos')));
      return;
    }
    int? insumoId = insumos.first['id'] as int;
    final cant = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: const Text('Agregar insumo'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                DropdownButtonFormField<int>(
                  value: insumoId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Insumo'),
                  items: insumos
                      .map((i) => DropdownMenuItem<int>(
                          value: i['id'] as int,
                          child: Text('${i['nombre']} (${i['unidad'] ?? ''})')))
                      .toList(),
                  onChanged: (v) => setD(() => insumoId = v),
                ),
                TextField(
                  controller: cant,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Cantidad por tanda (en la unidad del insumo)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Agregar')),
          ],
        ),
      ),
    );

    final cantidad = aNum(cant.text);
    if (ok == true && insumoId != null && cantidad > 0) {
      await DbStock.agregarItem(widget.recetaId, insumoId!, cantidad);
      await cargar();
    }
  }

  Future<void> aplicarCosto() async {
    final pid = receta?['producto_id'] as int?;
    if (pid == null) return;
    await DbStock.aplicarCosto(pid, costoUnidad);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Costo actualizado: ${pesos(costoUnidad)} por unidad')));
  }

  Future<void> eliminarReceta() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Eliminar receta'),
        content: const Text('Se borrará la receta y sus insumos. ¿Continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok == true) {
      await DbStock.borrarReceta(widget.recetaId);
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final producto = receta?['producto'] as String?;
    return Scaffold(
      appBar: AppBar(
        title: Text(receta?['nombre'] as String? ?? 'Receta'),
        actions: [
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: eliminarReceta),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: agregarInsumo,
        icon: const Icon(Icons.add),
        label: const Text('Insumo'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _Cifra('Costo tanda', pesos(costoTanda)),
                      _Cifra('Rinde', '$rinde u.'),
                      _Cifra('Costo unidad', pesos(costoUnidad)),
                    ],
                  ),
                  if (producto != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: items.isEmpty ? null : aplicarCosto,
                        icon: const Icon(Icons.sync),
                        label: Text('Aplicar costo a "$producto"'),
                      ),
                    ),
                  ] else
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Sin producto vinculado: el costo no se aplica a Ventas.',
                          style: TextStyle(fontSize: 12, color: Estanque.barro)),
                    ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 12, 4, 4),
            child: Text('Insumos de la tanda',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          if (items.isEmpty) const ListTile(title: Text('Todavía no agregaste insumos')),
          ...items.map((i) {
            final sub =
                ((i['cantidad'] as num) * (i['costo_unitario'] as num)).toDouble();
            return Card(
              child: ListTile(
                title: Text(i['nombre'] as String),
                subtitle: Text(
                    '${numTxt(i['cantidad'] as num)} ${i['unidad'] ?? ''} × ${pesos(i['costo_unitario'] as num)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(pesos(sub), style: const TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () async {
                        await DbStock.borrarItem(i['id'] as int);
                        cargar();
                      },
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _Cifra extends StatelessWidget {
  final String titulo, valor;
  const _Cifra(this.titulo, this.valor);

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(valor, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(titulo, style: const TextStyle(fontSize: 12)),
        ],
      );
}
