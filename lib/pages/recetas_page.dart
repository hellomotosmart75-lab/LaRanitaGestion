import 'package:flutter/material.dart';
import '../db/database.dart';
import '../db/db_stock.dart';
import '../theme.dart';
import '../utils.dart';
import 'scanner_page.dart';
import 'receta_detalle_page.dart';

class RecetasPage extends StatelessWidget {
  const RecetasPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: Estanque.aguaClara,
            child: TabBar(
              tabs: [
                Tab(text: 'Recetas', icon: Icon(Icons.menu_book)),
                Tab(text: 'Insumos', icon: Icon(Icons.shopping_basket)),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(children: [_RecetasTab(), _InsumosTab()]),
          ),
        ],
      ),
    );
  }
}

// =================== RECETAS ===================
class _RecetasTab extends StatefulWidget {
  const _RecetasTab();
  @override
  State<_RecetasTab> createState() => _RecetasTabState();
}

class _RecetasTabState extends State<_RecetasTab> {
  List<Map<String, dynamic>> lista = [];

  @override
  void initState() {
    super.initState();
    cargar();
  }

  Future<void> cargar() async {
    final l = await DbStock.recetas();
    if (!mounted) return;
    setState(() => lista = l);
  }

  Future<void> nueva() async {
    final productos = await Db.productos();
    if (!mounted) return;
    final nombre = TextEditingController();
    final rinde = TextEditingController(text: '10');
    int? productoId;

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: const Text('Nueva receta'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: nombre,
                  decoration: const InputDecoration(labelText: 'Nombre de la receta'),
                ),
                TextField(
                  controller: rinde,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Unidades que salen por tanda'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int?>(
                  value: productoId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Producto que genera'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Sin vincular')),
                    ...productos.map((p) => DropdownMenuItem<int?>(
                        value: p['id'] as int, child: Text(p['nombre'] as String))),
                  ],
                  onChanged: (v) => setD(() => productoId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Crear')),
          ],
        ),
      ),
    );

    if (ok == true && nombre.text.trim().isNotEmpty) {
      final r = int.tryParse(rinde.text) ?? 1;
      await DbStock.guardarReceta({
        'nombre': nombre.text.trim(),
        'rinde': r < 1 ? 1 : r,
        'producto_id': productoId,
      });
      await cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: nueva,
        icon: const Icon(Icons.add),
        label: const Text('Receta'),
      ),
      body: lista.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Todavía no hay recetas.\nPrimero carga tus insumos y luego crea la receta.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              children: lista
                  .map((r) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.menu_book, color: Estanque.agua),
                          title: Text(r['nombre'] as String),
                          subtitle: Text(
                              'Rinde ${r['rinde']} unidades · ${r['producto'] ?? 'sin producto vinculado'}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      RecetaDetallePage(recetaId: r['id'] as int)),
                            );
                            cargar();
                          },
                        ),
                      ))
                  .toList(),
            ),
    );
  }
}

// =================== INSUMOS ===================
class _InsumosTab extends StatefulWidget {
  const _InsumosTab();
  @override
  State<_InsumosTab> createState() => _InsumosTabState();
}

class _InsumosTabState extends State<_InsumosTab> {
  List<Map<String, dynamic>> lista = [];

  @override
  void initState() {
    super.initState();
    cargar();
  }

  Future<void> cargar() async {
    final l = await DbStock.insumos();
    if (!mounted) return;
    setState(() => lista = l);
  }

  Future<void> dialogo([Map<String, dynamic>? i]) async {
    final nombre = TextEditingController(text: i?['nombre'] as String? ?? '');
    final unidad = TextEditingController(text: i?['unidad'] as String? ?? '');
    final costo = TextEditingController(
        text: i == null ? '' : numTxt(i['costo_unitario'] as num));
    final codigo = TextEditingController(text: i?['codigo'] as String? ?? '');

    final res = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(i == null ? 'Nuevo insumo' : 'Editar insumo'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nombre,
                decoration: const InputDecoration(labelText: 'Nombre (ej: Leche)'),
              ),
              TextField(
                controller: unidad,
                decoration: const InputDecoration(
                    labelText: 'Unidad', hintText: 'kg, litro, sobre, unidad'),
              ),
              TextField(
                controller: costo,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Costo por unidad', prefixText: '\$ '),
              ),
              TextField(
                controller: codigo,
                decoration: InputDecoration(
                  labelText: 'Código de barras (opcional)',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: () async {
                      final r = await escanear(c);
                      if (r != null) codigo.text = r;
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (i != null)
            TextButton(
              onPressed: () => Navigator.pop(c, 'borrar'),
              child: const Text('Eliminar', style: TextStyle(color: Estanque.rojo)),
            ),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, 'ok'), child: const Text('Guardar')),
        ],
      ),
    );

    if (res == 'borrar' && i != null) {
      await DbStock.borrarInsumo(i['id'] as int);
      await cargar();
    } else if (res == 'ok' && nombre.text.trim().isNotEmpty) {
      await DbStock.guardarInsumo({
        'nombre': nombre.text.trim(),
        'unidad': unidad.text.trim(),
        'costo_unitario': aNum(costo.text),
        'codigo': codigo.text.trim(),
      }, i?['id'] as int?);
      await cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => dialogo(),
        icon: const Icon(Icons.add),
        label: const Text('Insumo'),
      ),
      body: lista.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Todavía no hay insumos.\nCarga leche, huevos, azúcar, gomitas, vasos, etc.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              children: lista
                  .map((i) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.shopping_basket, color: Estanque.barro),
                          title: Text(i['nombre'] as String),
                          subtitle: Text(
                              '${pesos(i['costo_unitario'] as num)} por ${(i['unidad'] as String?)?.isNotEmpty == true ? i['unidad'] : 'unidad'}'),
                          trailing: const Icon(Icons.edit),
                          onTap: () => dialogo(i),
                        ),
                      ))
                  .toList(),
            ),
    );
  }
}
