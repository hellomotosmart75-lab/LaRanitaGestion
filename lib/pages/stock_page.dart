import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/db_stock.dart';
import '../theme.dart';
import '../utils.dart';
import 'scanner_page.dart';

int _diasRestantes(String venc) {
  final f = DateTime.parse(venc);
  final h = DateTime.now();
  return DateTime(f.year, f.month, f.day)
      .difference(DateTime(h.year, h.month, h.day))
      .inDays;
}

Color _colorDias(int d) =>
    d < 0 ? Estanque.rojo : (d <= 3 ? Estanque.amarillo : Estanque.verdeRana);

String _textoDias(int d) {
  if (d < 0) return 'VENCIDO hace ${-d} día${d == -1 ? '' : 's'}';
  if (d == 0) return 'Vence HOY';
  return 'Quedan $d día${d == 1 ? '' : 's'}';
}

class StockPage extends StatefulWidget {
  const StockPage({super.key});
  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  List<Map<String, dynamic>> lotes = [];

  @override
  void initState() {
    super.initState();
    cargar();
  }

  Future<void> cargar() async {
    final l = await DbStock.lotes();
    if (!mounted) return;
    setState(() => lotes = l);
  }

  Future<void> ingresar() async {
    final codigo = TextEditingController();
    final nombre = TextEditingController();
    final cant = TextEditingController(text: '1');
    DateTime? venc;

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: const Text('Ingresar al stock'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: codigo,
                  decoration: InputDecoration(
                    labelText: 'Código de barras',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: () async {
                        final r = await escanear(c);
                        if (r != null) {
                          codigo.text = r;
                          final n = await DbStock.nombrePorCodigo(r);
                          if (n != null && nombre.text.isEmpty) nombre.text = n;
                          setD(() {});
                        }
                      },
                    ),
                  ),
                ),
                TextField(
                  controller: nombre,
                  decoration: const InputDecoration(labelText: 'Nombre del producto'),
                ),
                TextField(
                  controller: cant,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Cantidad'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event),
                    label: Text(venc == null
                        ? 'Elegir vencimiento'
                        : DateFormat('dd/MM/yyyy').format(venc!)),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: c,
                        initialDate: DateTime.now().add(const Duration(days: 7)),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) setD(() => venc = d);
                    },
                  ),
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

    if (ok != true) return;
    var nom = nombre.text.trim();
    if (nom.isEmpty && codigo.text.trim().isNotEmpty) {
      nom = await DbStock.nombrePorCodigo(codigo.text.trim()) ?? '';
    }
    final cantidad = aNum(cant.text);
    if (nom.isEmpty || cantidad <= 0 || venc == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Faltan datos: nombre, cantidad y vencimiento')));
      return;
    }
    await DbStock.agregarLote({
      'codigo': codigo.text.trim(),
      'nombre': nom,
      'cantidad': cantidad,
      'vencimiento': DateFormat('yyyy-MM-dd').format(venc!),
      'ingreso': hoy(),
    });
    await cargar();
  }

  Future<void> editar(Map<String, dynamic> l) async {
    final cant = TextEditingController(text: numTxt(l['cantidad'] as num));
    final res = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l['nombre'] as String),
        content: TextField(
          controller: cant,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Cantidad que queda'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, 'borrar'),
            child: const Text('Dar de baja', style: TextStyle(color: Estanque.rojo)),
          ),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, 'ok'), child: const Text('Guardar')),
        ],
      ),
    );
    if (res == 'borrar') {
      await DbStock.borrarLote(l['id'] as int);
    } else if (res == 'ok') {
      await DbStock.actualizarCantidad(l['id'] as int, aNum(cant.text));
    }
    await cargar();
  }

  @override
  Widget build(BuildContext context) {
    int vencidos = 0, porVencer = 0, ok = 0;
    for (final l in lotes) {
      final d = _diasRestantes(l['vencimiento'] as String);
      if (d < 0) {
        vencidos++;
      } else if (d <= 3) {
        porVencer++;
      } else {
        ok++;
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: ingresar,
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Ingresar'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          Row(
            children: [
              Expanded(child: _Chip('Vencidos', vencidos, Estanque.rojo)),
              Expanded(child: _Chip('Por vencer', porVencer, Estanque.amarillo)),
              Expanded(child: _Chip('En fecha', ok, Estanque.verdeRana)),
            ],
          ),
          const SizedBox(height: 8),
          if (lotes.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No hay lotes en stock.\nToca "Ingresar" y escanea el código de barras.',
                textAlign: TextAlign.center,
              ),
            ),
          ...lotes.map((l) {
            final d = _diasRestantes(l['vencimiento'] as String);
            final fecha = DateFormat('dd/MM/yyyy')
                .format(DateTime.parse(l['vencimiento'] as String));
            return Card(
              child: ListTile(
                leading: CircleAvatar(backgroundColor: _colorDias(d), radius: 12),
                title: Text(l['nombre'] as String),
                subtitle: Text('Vence $fecha · ${_textoDias(d)}'),
                trailing: Text('x ${numTxt(l['cantidad'] as num)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                onTap: () => editar(l),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String titulo;
  final int cantidad;
  final Color color;
  const _Chip(this.titulo, this.cantidad, this.color);

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              CircleAvatar(
                backgroundColor: color,
                radius: 16,
                child: Text('$cantidad',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 4),
              Text(titulo, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      );
}
