import 'package:flutter/material.dart';
import '../db/db_gestion.dart';
import '../db/db_stock.dart';
import '../theme.dart';
import '../utils.dart';

class GastosPage extends StatefulWidget {
  const GastosPage({super.key});
  @override
  State<GastosPage> createState() => _GastosPageState();
}

class _GastosPageState extends State<GastosPage> {
  DateTime mes = DateTime(DateTime.now().year, DateTime.now().month, 1);
  List<Map<String, dynamic>> lista = [];
  double fijos = 0, variables = 0;

  @override
  void initState() {
    super.initState();
    cargar();
  }

  Future<void> cargar() async {
    final m = DbGestion.mesDe(mes);
    final g = await DbGestion.gastosDelMes(m);
    final t = await DbGestion.totalesGastos(m);
    if (!mounted) return;
    setState(() {
      lista = g;
      fijos = t['fijos']!;
      variables = t['variables']!;
    });
  }

  void cambiarMes(int d) {
    setState(() => mes = DateTime(mes.year, mes.month + d, 1));
    cargar();
  }

  Future<void> agregar() async {
    final ahora = DateTime.now();
    final esMesActual = ahora.year == mes.year && ahora.month == mes.month;
    DateTime fecha = esMesActual ? ahora : mes;
    String cat = DbGestion.categorias.first;
    final detalle = TextEditingController();
    final monto = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: const Text('Nuevo gasto'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: cat,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: [
                    for (final k in DbGestion.categorias)
                      DropdownMenuItem(
                        value: k,
                        child: Text(DbGestion.esFijo(k) ? '$k (fijo)' : '$k (variable)'),
                      ),
                  ],
                  onChanged: (v) => setD(() => cat = v ?? cat),
                ),
                TextField(
                    controller: detalle,
                    decoration: const InputDecoration(labelText: 'Detalle (opcional)')),
                TextField(
                  controller: monto,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Monto', prefixText: '\$ '),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(DbGestion.fecha(fecha)),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: c,
                      initialDate: fecha,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setD(() => fecha = d);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (ok == true && aNum(monto.text) > 0) {
      await DbGestion.agregarGasto(
          DbGestion.fecha(fecha), cat, detalle.text.trim(), aNum(monto.text));
      cargar();
    }
  }

  Future<void> borrar(Map<String, dynamic> g) async {
    final seguro = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Borrar gasto?'),
        content: Text('${g['categoria']} · ${pesos(g['monto'] as num)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sí, borrar')),
        ],
      ),
    );
    if (seguro == true) {
      await DbGestion.borrarGasto(g['id'] as int);
      cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: agregar,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(onPressed: () => cambiarMes(-1), icon: const Icon(Icons.chevron_left)),
              Text(DbGestion.nombreMes(mes),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              IconButton(onPressed: () => cambiarMes(1), icon: const Icon(Icons.chevron_right)),
            ],
          ),
          Row(
            children: [
              Expanded(child: _Total('Fijos', fijos, Icons.lock_clock)),
              Expanded(child: _Total('Variables', variables, Icons.shopping_cart)),
            ],
          ),
          Expanded(
            child: lista.isEmpty
                ? const Center(child: Text('Sin gastos este mes'))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: lista.length,
                    itemBuilder: (c, i) {
                      final g = lista[i];
                      final cat = (g['categoria'] ?? '') as String;
                      final det = (g['detalle'] ?? '') as String;
                      return ListTile(
                        leading: Icon(
                          DbGestion.esFijo(cat) ? Icons.lock_clock : Icons.shopping_cart,
                          color: DbGestion.esFijo(cat) ? Estanque.barro : Estanque.agua,
                        ),
                        title: Text(det.isEmpty ? cat : '$cat · $det'),
                        subtitle: Text(
                            '${g['fecha']} · ${DbGestion.esFijo(cat) ? 'fijo' : 'variable'}'),
                        trailing: Text(pesos(g['monto'] as num),
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        onLongPress: () => borrar(g),
                      );
                    },
                  ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
                'Mantené apretado un gasto para borrarlo. Solo los fijos cuentan para la meta diaria.',
                style: TextStyle(fontSize: 12, color: Estanque.barro)),
          ),
        ],
      ),
    );
  }
}

class _Total extends StatelessWidget {
  final String titulo;
  final double valor;
  final IconData icono;
  const _Total(this.titulo, this.valor, this.icono);

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Icon(icono, color: Estanque.agua),
              const SizedBox(height: 4),
              Text(pesos(valor),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(titulo, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      );
}
