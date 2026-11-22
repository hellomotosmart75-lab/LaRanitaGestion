import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../db/database.dart';
import '../db/db_clientes.dart';
import '../theme.dart';
import '../utils.dart';

const _medios = ['efectivo', 'transferencia', 'qr'];

String _emojiMedio(String m) =>
    m == 'efectivo' ? '💵' : (m == 'transferencia' ? '🏦' : '📱');

String _nombreMedio(String m) =>
    m == 'efectivo' ? 'Efectivo' : (m == 'transferencia' ? 'Transferencia' : 'QR');

IconData _iconoTipo(String? t) =>
    t == 'Kiosco' ? Icons.storefront : (t == 'Almacén' ? Icons.shopping_basket : Icons.place);

class ClientesPage extends StatefulWidget {
  const ClientesPage({super.key});
  @override
  State<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends State<ClientesPage> {
  List<Map<String, dynamic>> clientes = [];
  Map<int, double> compras = {};
  bool soloHoy = true;
  final String diaHoy = DbClientes.diaDe(DateTime.now());

  @override
  void initState() {
    super.initState();
    cargar();
  }

  Future<void> cargar() async {
    final c = await DbClientes.clientes();
    final h = await DbClientes.comprasDeFecha(hoy());
    if (!mounted) return;
    setState(() {
      clientes = c;
      compras = h;
    });
  }

  Future<void> editar([Map<String, dynamic>? c]) async {
    final nombre = TextEditingController(text: c?['nombre'] as String? ?? '');
    final dir = TextEditingController(text: c?['direccion'] as String? ?? '');
    String tipo = DbClientes.tipos.contains(c?['tipo']) ? c!['tipo'] as String : 'Kiosco';
    String dia = DbClientes.dias.contains(c?['dia_visita']) ? c!['dia_visita'] as String : '';
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(c == null ? 'Nuevo cliente' : 'Editar cliente'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nombre,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Nombre')),
                DropdownButtonFormField<String>(
                  value: tipo,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: [
                    for (final t in DbClientes.tipos)
                      DropdownMenuItem(value: t, child: Text(t)),
                  ],
                  onChanged: (v) => setD(() => tipo = v ?? tipo),
                ),
                TextField(
                    controller: dir,
                    decoration: const InputDecoration(labelText: 'Dirección')),
                DropdownButtonFormField<String>(
                  value: dia,
                  decoration: const InputDecoration(labelText: 'Día de visita'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Sin día fijo')),
                    for (final d in DbClientes.dias)
                      DropdownMenuItem(value: d, child: Text(d)),
                  ],
                  onChanged: (v) => setD(() => dia = v ?? ''),
                ),
              ],
            ),
          ),
          actions: [
            if (c != null)
              TextButton(
                  onPressed: () => Navigator.pop(ctx, 'borrar'),
                  child: const Text('Borrar', style: TextStyle(color: Estanque.rojo))),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, 'ok'), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (res == 'ok') {
      if (nombre.text.trim().isEmpty) return;
      await DbClientes.guardarCliente({
        'nombre': nombre.text.trim(),
        'tipo': tipo,
        'direccion': dir.text.trim(),
        'dia_visita': dia,
      }, c?['id'] as int?);
      cargar();
    } else if (res == 'borrar') {
      final seguro = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¿Borrar cliente?'),
          content: const Text('Sus ventas quedan registradas, pero sin cliente.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sí, borrar')),
          ],
        ),
      );
      if (seguro == true) {
        await DbClientes.borrarCliente(c!['id'] as int);
        cargar();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibles =
        clientes.where((c) => !soloHoy || c['dia_visita'] == diaHoy).toList();
    visibles.sort((a, b) {
      final ca = compras.containsKey(a['id']) ? 1 : 0;
      final cb = compras.containsKey(b['id']) ? 1 : 0;
      if (ca != cb) return ca - cb;
      return (a['nombre'] as String).compareTo(b['nombre'] as String);
    });
    final visitados = visibles.where((c) => compras.containsKey(c['id'])).length;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => editar(),
        child: const Icon(Icons.add_business),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: true, label: Text('Hoy · $diaHoy')),
                const ButtonSegment(value: false, label: Text('Todos')),
              ],
              selected: {soloHoy},
              onSelectionChanged: (s) => setState(() => soloHoy = s.first),
            ),
          ),
          if (visibles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('Visitados: $visitados de ${visibles.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          Expanded(
            child: visibles.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        soloHoy
                            ? 'Hoy no te toca visitar a nadie.\nElegí "Todos" o asignale un día a tus clientes.'
                            : 'Tocá el botón para agregar tu primer cliente',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: visibles.length,
                    itemBuilder: (ctx, i) {
                      final c = visibles[i];
                      final compro = compras[c['id']];
                      final dir = (c['direccion'] ?? '') as String;
                      final dia = (c['dia_visita'] ?? '') as String;
                      return Card(
                        child: ListTile(
                          leading: compro != null
                              ? const Icon(Icons.check_circle, color: Estanque.verdeRana, size: 32)
                              : Icon(_iconoTipo(c['tipo'] as String?), color: Estanque.agua, size: 32),
                          title: Text(c['nombre'] as String),
                          subtitle: Text([
                            c['tipo'] ?? '',
                            if (dir.isNotEmpty) dir,
                            if (!soloHoy && dia.isNotEmpty) dia,
                          ].join(' · ')),
                          trailing: compro != null
                              ? Text(pesos(compro),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, color: Estanque.verdeProfundo))
                              : null,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => _ClienteDetalle(cliente: c)),
                            );
                            cargar();
                          },
                          onLongPress: () => editar(c),
                        ),
                      );
                    },
                  ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Tocá un cliente para venderle. Mantené apretado para editarlo.',
                style: TextStyle(fontSize: 12, color: Estanque.barro)),
          ),
        ],
      ),
    );
  }
}

class _ClienteDetalle extends StatefulWidget {
  final Map<String, dynamic> cliente;
  const _ClienteDetalle({required this.cliente});
  @override
  State<_ClienteDetalle> createState() => _ClienteDetalleState();
}

class _ClienteDetalleState extends State<_ClienteDetalle> {
  List<Map<String, dynamic>> ventas = [];

  int get id => widget.cliente['id'] as int;

  @override
  void initState() {
    super.initState();
    cargar();
  }

  Future<void> cargar() async {
    final v = await DbClientes.ventasDeCliente(id);
    if (!mounted) return;
    setState(() => ventas = v);
  }

  Future<void> vender() async {
    final prods = await Db.productos();
    if (prods.isEmpty || !mounted) return;
    int pid = prods.first['id'] as int;
    bool porCaja = true;
    String medio = 'efectivo';
    final ctl = TextEditingController(text: '1');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final prod = prods.firstWhere((p) => p['id'] == pid);
          final cant = int.tryParse(ctl.text) ?? 0;
          final porCajaN = (prod['unidades_por_caja'] as num?)?.toInt() ?? 1;
          final unidades = porCaja ? cant * porCajaN : cant;
          final precio = (porCaja ? prod['precio_mayorista'] : prod['precio']) as num;
          return AlertDialog(
            title: Text('Vender a ${widget.cliente['nombre']}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<int>(
                    value: pid,
                    decoration: const InputDecoration(labelText: 'Producto'),
                    items: [
                      for (final p in prods)
                        DropdownMenuItem(value: p['id'] as int, child: Text(p['nombre'] as String)),
                    ],
                    onChanged: (v) => setD(() => pid = v ?? pid),
                  ),
                  TextField(
                    controller: ctl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: porCaja ? 'Cajas (de $porCajaN)' : 'Unidades'),
                    onChanged: (_) => setD(() {}),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Por caja (mayorista)'),
                    value: porCaja,
                    onChanged: (v) => setD(() => porCaja = v),
                  ),
                  const Text('Forma de pago'),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final m in _medios)
                        ChoiceChip(
                          label: Text('${_emojiMedio(m)} ${_nombreMedio(m)}'),
                          selected: medio == m,
                          onSelected: (_) => setD(() => medio = m),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('$unidades unidades · ${pesos(precio * unidades)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Vender')),
            ],
          );
        },
      ),
    );
    if (ok != true) return;
    final cant = int.tryParse(ctl.text) ?? 0;
    if (cant <= 0) return;
    final prod = prods.firstWhere((p) => p['id'] == pid);
    final porCajaN = (prod['unidades_por_caja'] as num?)?.toInt() ?? 1;
    final unidades = porCaja ? cant * porCajaN : cant;
    await Db.registrarVenta(
        fecha: hoy(),
        producto: prod,
        unidades: unidades,
        porCaja: porCaja,
        clienteId: id,
        medioPago: medio);
    await cargar();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Venta registrada: $unidades unidades · ${_nombreMedio(medio)}')));
  }

  Future<void> comoLlegar() async {
    final dir = (widget.cliente['direccion'] ?? '') as String;
    if (dir.isEmpty) return;
    final uri = Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': dir});
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.cliente;
    final dir = (c['direccion'] ?? '') as String;
    return Scaffold(
      appBar: AppBar(title: Text(c['nombre'] as String)),
      body: Column(
        children: [
          Card(
            child: ListTile(
              leading: Icon(_iconoTipo(c['tipo'] as String?), color: Estanque.agua),
              title: Text(dir.isEmpty ? 'Sin dirección' : dir),
              subtitle: Text([
                c['tipo'] ?? '',
                if ((c['dia_visita'] ?? '') != '') 'Visita: ${c['dia_visita']}',
              ].join(' · ')),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: vender,
                    icon: const Icon(Icons.point_of_sale),
                    label: const Text('Vender'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: dir.isEmpty ? null : comoLlegar,
                    icon: const Icon(Icons.directions),
                    label: const Text('Cómo llegar'),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Últimas compras', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          Expanded(
            child: ventas.isEmpty
                ? const Center(child: Text('Todavía no le vendiste'))
                : ListView.builder(
                    itemCount: ventas.length,
                    itemBuilder: (ctx, i) {
                      final v = ventas[i];
                      final medio = (v['medio_pago'] ?? 'efectivo') as String;
                      return ListTile(
                        leading: const Icon(Icons.receipt, color: Estanque.agua),
                        title: Text('${v['nombre']} · ${v['unidades']} u'),
                        subtitle: Text('${v['fecha']} · ${_emojiMedio(medio)} ${_nombreMedio(medio)}'),
                        trailing: Text(pesos(v['total'] as num),
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
