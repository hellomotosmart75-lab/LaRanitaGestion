import 'db/database.dart';
import 'db/db_clientes.dart';
import 'db/db_gestion.dart';
import 'db/db_stock.dart';
import 'utils.dart';

Future<String> armarInforme(DateTime dia) async {
  final db = await Db.abrir;
  final fecha = DbGestion.fecha(dia);

  final r = await Db.resumenDia(fecha);
  final ventas = r['total']!;
  final costo = r['costo']!;
  final unidades = r['unidades']!.round();

  final porProd = await db.rawQuery(
      'SELECT p.nombre, SUM(v.unidades) AS u, SUM(v.total) AS t FROM ventas v '
      'JOIN productos p ON p.id = v.producto_id WHERE v.fecha = ? '
      'GROUP BY p.id ORDER BY t DESC',
      [fecha]);
  final porCli = await db.rawQuery(
      'SELECT c.nombre, SUM(v.total) AS t FROM ventas v '
      'JOIN clientes c ON c.id = v.cliente_id WHERE v.fecha = ? '
      'GROUP BY c.id ORDER BY t DESC',
      [fecha]);

  // Mano de obra estimada y ganancia neta
  final moUnidad = await DbGestion.manoDeObraPorUnidad();
  final manoObra = unidades * moUnidad;
  final neta = ventas - costo - manoObra;

  // Meta
  final auto = (await Db.getConfig('meta_auto', '1')) == '1';
  final info = await DbGestion.metaAutomatica();
  final meta = auto && info['meta']! > 0
      ? info['meta']!
      : (double.tryParse(await Db.getConfig('meta_diaria', '20000')) ?? 20000);
  final pct = meta > 0 ? ventas / meta : 0.0;
  final String estadoMeta = pct >= 1
      ? '🟢 Meta cubierta (+${pesos(ventas - meta)})'
      : (pct >= 0.6
          ? '🟡 Faltaron ${pesos(meta - ventas)}'
          : '🔴 Faltaron ${pesos(meta - ventas)}');

  // Clientes
  final compras = await DbClientes.comprasDeFecha(fecha);
  final clientes = await DbClientes.clientes();
  final diaNombre = DbClientes.diaDe(dia);
  final pendientes = clientes
      .where((c) => c['dia_visita'] == diaNombre && !compras.containsKey(c['id']))
      .map((c) => c['nombre'] as String)
      .toList();

  // Gastos del día
  final gastos = await db.query('gastos', where: 'fecha = ?', whereArgs: [fecha]);

  // Lotes vencidos o por vencer (3 días)
  final limite = DbGestion.fecha(dia.add(const Duration(days: 3)));
  final lotes = await db.query('lotes',
      where: 'cantidad > 0 AND vencimiento <= ?',
      whereArgs: [limite],
      orderBy: 'vencimiento');

  final b = StringBuffer();
  b.writeln('🐸 La Ranita · Informe del $fecha');
  b.writeln();
  b.writeln('VENTAS');
  b.writeln('Total: ${pesos(ventas)} ($unidades unidades)');
  for (final p in porProd) {
    b.writeln('• ${p['nombre']}: ${(p['u'] as num).round()} u · ${pesos(p['t'] as num)}');
  }
  b.writeln();
  b.writeln('RESULTADO');
  b.writeln('Ganancia bruta: ${pesos(ventas - costo)}');
  b.writeln('Mano de obra (est.): ${pesos(manoObra)}');
  b.writeln('Ganancia neta: ${pesos(neta)}');
  b.writeln();
  b.writeln('META DEL DÍA: ${pesos(meta)}');
  b.writeln(estadoMeta);

  if (porCli.isNotEmpty || pendientes.isNotEmpty) {
    b.writeln();
    b.writeln('CLIENTES');
    for (final c in porCli) {
      b.writeln('• ${c['nombre']}: ${pesos(c['t'] as num)}');
    }
    if (pendientes.isNotEmpty) {
      b.writeln('Sin visitar (les tocaba $diaNombre): ${pendientes.join(', ')}');
    }
  }

  if (gastos.isNotEmpty) {
    b.writeln();
    b.writeln('GASTOS DEL DÍA');
    for (final g in gastos) {
      final det = (g['detalle'] ?? '') as String;
      b.writeln(
          '• ${g['categoria']}${det.isEmpty ? '' : ' ($det)'}: ${pesos(g['monto'] as num)}');
    }
  }

  if (lotes.isNotEmpty) {
    b.writeln();
    b.writeln('⚠️ VENCIDOS O POR VENCER');
    for (final l in lotes) {
      final venc = l['vencimiento'] as String;
      final estado = venc.compareTo(fecha) < 0 ? 'VENCIDO' : 'vence';
      b.writeln(
          '• ${l['nombre']} (${numTxt((l['cantidad'] as num).toDouble())}): $estado $venc');
    }
  }

  return b.toString();
}
