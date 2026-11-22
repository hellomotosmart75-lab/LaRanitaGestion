import 'package:flutter/material.dart';
import '../db/database.dart';
import '../theme.dart';
import '../utils.dart';

const _medios = ['efectivo', 'transferencia', 'qr'];

String _emojiMedio(String m) =>
    m == 'efectivo' ? '💵' : (m == 'transferencia' ? '🏦' : '📱');

String _nombreMedio(String m) =>
    m == 'efectivo' ? 'Efectivo' : (m == 'transferencia' ? 'Transferencia' : 'QR');

const _emojis = ['🍮', '🍬', '🍓', '🍰', '🍧', '🍫', '🍪', '🧁', '🍨', '🍩', '🥛', '🐸'];

String emojiDe(Map<String, dynamic> p) {
  final e = (p['emoji'] ?? '') as String;
  if (e.isNotEmpty) return e;
  final n = ((p['nombre'] ?? '') as String).toLowerCase();
  if (n.contains('flan')) return '🍮';
  if (n.contains('gelatina')) return '🍬';
  return '🍰';
}

int _porCajaN(Map<String, dynamic> p) {
  final n = (p['unidades_por_caja'] as num?)?.toInt() ?? 1;
  return n < 1 ? 1 : n;
}

class VentasPage extends StatefulWidget {
  const VentasPage({super.key});
  @override
  State<VentasPage> createState() => _VentasPageState();
}

class _VentasPageState extends State<VentasPage> {
  List<Map<String, dynamic>> productos = [];
  final Map<int, int> carrito = {};
  bool porCaja = false;
  double totalHoy = 0;
  Map<String, double> pagos = {'efectivo': 0, 'transferencia': 0, 'qr': 0};

  @override
  void initState() {
    super.initState();
    cargar();
  }

  Future<void> cargar() async {
    final p = await Db.productos();
    final r = await Db.resumenDia(hoy());
    final pg = await Db.resumenPagos(hoy());
    if (!mounted) return;
    setState(() {
      productos = p;
      totalHoy = r['total']!;
      pagos = pg;
    });
  }

  Map<String, dynamic>? prod(int id) {
    for (final p in productos) {
      if (p['id'] == id) return p;
    }
    return null;
  }

  int unidadesPorClic(Map<String, dynamic> p) => porCaja ? _porCajaN(p) : 1;

  double precioClic(Map<String, dynamic> p) => porCaja
      ? (p['precio_mayorista'] as num).toDouble() * _porCajaN(p)
      : (p['precio'] as num).toDouble();

  double get total {
    double s = 0;
    carrito.forEach((id, cant) {
      final p = prod(id);
      if (p != null) s += cant * precioClic(p);
    });
    return s;
  }

  int get items => carrito.values.fold(0, (a, b) => a + b);

  void cambiar(int id, int d) {
    setState(() {
      final n = (carrito[id] ?? 0) + d;
      if (n <= 0) {
        carrito.remove(id);
      } else {
        carrito[id] = n;
      }
    });
  }

  Future<void> cobrar() async {
    final t = total;
    if (t <= 0) return;
    final r = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CobroSheet(total: t),
    );
    if (r == null) return;
    final medio = r['medio'] as String;
    final pagado = (r['pagado'] as num).toDouble();
    for (final e in carrito.entries) {
      final p = prod(e.key);
      if (p == null) continue;
      await Db.registrarVenta(
        fecha: hoy(),
        producto: p,
        unidades: e.value * unidadesPorClic(p),
        porCaja: porCaja,
        medioPago: medio,
      );
    }
    final vuelto = medio == 'efectivo' && pagado > t ? pagado - t : 0.0;
    setState(() => carrito.clear());
    await cargar();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 4),
      content: Text(vuelto > 0
          ? 'Venta registrada · Vuelto ${pesos(vuelto)}'
          : 'Venta registrada ✔'),
    ));
  }

  Future<void> verVentasHoy() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _VentasHoySheet(),
    );
    cargar();
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
    String emoji = p == null ? '🍰' : emojiDe(p);

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
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: Text(p == null ? 'Nuevo producto' : 'Editar producto'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Dibujito'),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final e in _emojis)
                      GestureDetector(
                        onTap: () => setD(() => emoji = e),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: emoji == e ? Estanque.aguaClara : Colors.transparent,
                            border: Border.all(
                                color: emoji == e ? Estanque.agua : Colors.black12, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(e, style: const TextStyle(fontSize: 26)),
                        ),
                      ),
                  ],
                ),
                campo('Nombre', nombre, num: false),
                campo('Código de barras (opcional)', codigo, num: false),
                campo('Costo por unidad', costo),
                campo('Precio de venta', precio),
                campo('Precio mayorista (por unidad)', mayor),
                campo('Unidades por caja madre', caja),
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

    if (ok == true && nombre.text.trim().isNotEmpty) {
      await Db.guardarProducto({
        'nombre': nombre.text.trim(),
        'codigo': codigo.text.trim(),
        'costo': double.tryParse(costo.text) ?? 0,
        'precio': double.tryParse(precio.text) ?? 0,
        'precio_mayorista': double.tryParse(mayor.text) ?? 0,
        'unidades_por_caja': int.tryParse(caja.text) ?? 1,
        'emoji': emoji,
      }, p?['id'] as int?);
      await cargar();
    }
  }

  Widget tarjeta(Map<String, dynamic> p) {
    final id = p['id'] as int;
    final cant = carrito[id] ?? 0;
    final activo = cant > 0;
    return Card(
      margin: EdgeInsets.zero,
      color: activo ? Estanque.aguaClara : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: activo ? Estanque.agua : Colors.black12, width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => cambiar(id, 1),
        onLongPress: () => productoDialog(p),
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emojiDe(p), style: const TextStyle(fontSize: 54)),
                    const SizedBox(height: 4),
                    Text(p['nombre'] as String,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(pesos(precioClic(p)),
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Estanque.verdeProfundo)),
                    if (porCaja)
                      Text('caja de ${_porCajaN(p)}', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
            if (activo)
              Positioned(
                top: 6,
                right: 10,
                child: CircleAvatar(
                  radius: 15,
                  backgroundColor: Estanque.verdeProfundo,
                  child: Text('$cant',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            if (activo)
              Positioned(
                top: 0,
                left: 2,
                child: IconButton(
                  onPressed: () => cambiar(id, -1),
                  icon: const Icon(Icons.remove_circle, color: Estanque.rojo, size: 30),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget tarjetaNuevo() => Card(
        margin: EdgeInsets.zero,
        color: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Estanque.agua, width: 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => productoDialog(),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_circle_outline, size: 44, color: Estanque.agua),
                SizedBox(height: 4),
                Text('Nuevo producto', style: TextStyle(fontWeight: FontWeight.bold)),
                Padding(
                  padding: EdgeInsets.all(6),
                  child: Text('Mantené apretado un producto para editarlo',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: carrito.isEmpty
          ? null
          : Material(
              elevation: 12,
              color: Colors.white,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Vaciar',
                        onPressed: () => setState(() => carrito.clear()),
                        icon: const Icon(Icons.delete_outline),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('$items ${items == 1 ? 'ítem' : 'ítems'}',
                                style: const TextStyle(fontSize: 12)),
                            Text(pesos(total),
                                style: const TextStyle(
                                    fontSize: 26, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: cobrar,
                        icon: const Icon(Icons.payments),
                        label: const Text('Cobrar'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: verVentasHoy,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hoy · ${pesos(totalHoy)}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(
                            '💵 ${pesos(pagos['efectivo'] ?? 0)}   '
                            '🏦 ${pesos(pagos['transferencia'] ?? 0)}   '
                            '📱 ${pesos(pagos['qr'] ?? 0)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.list_alt, color: Estanque.agua),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Unidad'), icon: Icon(Icons.cake)),
                  ButtonSegment(
                      value: true, label: Text('Caja mayorista'), icon: Icon(Icons.inventory_2)),
                ],
                selected: {porCaja},
                onSelectionChanged: (s) => setState(() {
                  porCaja = s.first;
                  carrito.clear();
                }),
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.95,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: productos.length + 1,
              itemBuilder: (c, i) =>
                  i < productos.length ? tarjeta(productos[i]) : tarjetaNuevo(),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Hoja de cobro: medio de pago y vuelto ----------
class _CobroSheet extends StatefulWidget {
  final double total;
  const _CobroSheet({required this.total});
  @override
  State<_CobroSheet> createState() => _CobroSheetState();
}

class _CobroSheetState extends State<_CobroSheet> {
  String medio = 'efectivo';
  final ctl = TextEditingController();

  double get pagado =>
      double.tryParse(ctl.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final total = widget.total;
    final efectivo = medio == 'efectivo';
    final vuelto = pagado - total;
    final puede = !efectivo || pagado == 0 || pagado >= total;

    Widget cajaVuelto() {
      if (pagado == 0) {
        return const Text('Ingresá con cuánto pagan para ver el vuelto',
            textAlign: TextAlign.center);
      }
      if (vuelto < 0) {
        return Text('Faltan ${pesos(-vuelto)}',
            style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, color: Estanque.rojo));
      }
      if (vuelto == 0) {
        return const Text('Pago justo ✔',
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, color: Estanque.verdeProfundo));
      }
      return Column(
        children: [
          const Text('Vuelto a dar'),
          Text(pesos(vuelto),
              style: const TextStyle(
                  fontSize: 44, fontWeight: FontWeight.bold, color: Estanque.verdeProfundo)),
        ],
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Total a cobrar'),
            Text(pesos(total), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final m in _medios)
                  ChoiceChip(
                    label: Text('${_emojiMedio(m)} ${_nombreMedio(m)}'),
                    selected: medio == m,
                    onSelected: (_) => setState(() => medio = m),
                  ),
              ],
            ),
            if (efectivo) ...[
              const SizedBox(height: 12),
              TextField(
                controller: ctl,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 22),
                decoration: const InputDecoration(
                    labelText: 'Paga con', prefixText: '\$ ', border: OutlineInputBorder()),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    label: const Text('Justo'),
                    onPressed: () => setState(() => ctl.text = total.round().toString()),
                  ),
                  for (final b in [2000, 5000, 10000, 20000])
                    if (b >= total)
                      ActionChip(
                        label: Text(pesos(b)),
                        onPressed: () => setState(() => ctl.text = b.toString()),
                      ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Estanque.aguaClara.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(child: cajaVuelto()),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: puede
                    ? () => Navigator.pop(context, {
                          'medio': medio,
                          'pagado': efectivo && pagado > 0 ? pagado : total,
                        })
                    : null,
                icon: const Icon(Icons.check),
                label: const Text('Registrar venta'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Ventas de hoy (con opción de anular) ----------
class _VentasHoySheet extends StatefulWidget {
  const _VentasHoySheet();
  @override
  State<_VentasHoySheet> createState() => _VentasHoySheetState();
}

class _VentasHoySheetState extends State<_VentasHoySheet> {
  List<Map<String, dynamic>> ventas = [];

  @override
  void initState() {
    super.initState();
    cargar();
  }

  Future<void> cargar() async {
    final v = await Db.ventasDelDia(hoy());
    if (!mounted) return;
    setState(() => ventas = v);
  }

  Future<void> anular(Map<String, dynamic> v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Anular esta venta?'),
        content: Text('${v['nombre']} · ${v['unidades']} u · ${pesos(v['total'] as num)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sí, anular')),
        ],
      ),
    );
    if (ok == true) {
      await Db.borrarVenta(v['id'] as int);
      cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          const Text('Ventas de hoy',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Expanded(
            child: ventas.isEmpty
                ? const Center(child: Text('Todavía no hay ventas hoy'))
                : ListView.builder(
                    itemCount: ventas.length,
                    itemBuilder: (c, i) {
                      final v = ventas[i];
                      final medio = ((v['medio_pago'] ?? 'efectivo') as String);
                      return ListTile(
                        leading: Text(
                            emojiDe({'emoji': v['emoji'], 'nombre': v['nombre']}),
                            style: const TextStyle(fontSize: 28)),
                        title: Text('${v['nombre']} · ${v['unidades']} u'),
                        subtitle: Text(
                            '${_emojiMedio(medio)} ${_nombreMedio(medio)}${v['cliente_id'] != null ? ' · cliente' : ''}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(pesos(v['total'] as num),
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => anular(v),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
