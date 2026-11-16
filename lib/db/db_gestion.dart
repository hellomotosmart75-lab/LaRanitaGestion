import 'database.dart';

class DbGestion {
  static const categoriasFijas = ['Impuestos', 'Luz', 'Gas', 'Alquiler', 'Otro fijo'];
  static const categoriasVariables = ['Compras', 'Combustible', 'Otro variable'];
  static List<String> get categorias => [...categoriasFijas, ...categoriasVariables];
  static bool esFijo(String c) => categoriasFijas.contains(c);

  static String _dos(int n) => n.toString().padLeft(2, '0');
  static String fecha(DateTime d) => '${d.year}-${_dos(d.month)}-${_dos(d.day)}';
  static String mesDe(DateTime d) => '${d.year}-${_dos(d.month)}';

  static String nombreMes(DateTime d) {
    const m = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    return '${m[d.month - 1]} ${d.year}';
  }

  // ---------- Empleados ----------
  static Future<void> guardarEmpleado(Map<String, dynamic> datos, [int? id]) async {
    final db = await Db.abrir;
    if (id == null) {
      await db.insert('empleados', datos);
    } else {
      await db.update('empleados', datos, where: 'id = ?', whereArgs: [id]);
    }
  }

  static Future<void> borrarEmpleado(int id) async {
    final db = await Db.abrir;
    await db.delete('horas', where: 'empleado_id = ?', whereArgs: [id]);
    await db.delete('empleados', where: 'id = ?', whereArgs: [id]);
  }

  // Empleados con las horas del mes (mes = 'yyyy-MM')
  static Future<List<Map<String, dynamic>>> resumenEmpleados(String mes) async {
    final db = await Db.abrir;
    return db.rawQuery(
        'SELECT e.id, e.nombre, e.valor_hora, COALESCE(SUM(h.horas),0) AS horas '
        'FROM empleados e LEFT JOIN horas h ON h.empleado_id = e.id AND h.fecha LIKE ? '
        'GROUP BY e.id ORDER BY e.nombre',
        ['$mes-%']);
  }

  static Future<List<Map<String, dynamic>>> horasDelMes(int empleadoId, String mes) async {
    final db = await Db.abrir;
    return db.query('horas',
        where: 'empleado_id = ? AND fecha LIKE ?',
        whereArgs: [empleadoId, '$mes-%'],
        orderBy: 'fecha DESC, id DESC');
  }

  static Future<void> agregarHoras(int empleadoId, String fecha, double horas) async {
    final db = await Db.abrir;
    await db.insert('horas', {'empleado_id': empleadoId, 'fecha': fecha, 'horas': horas});
  }

  static Future<void> borrarHoras(int id) async {
    final db = await Db.abrir;
    await db.delete('horas', where: 'id = ?', whereArgs: [id]);
  }

  static Future<double> sueldosDelMes(String mes) async {
    final db = await Db.abrir;
    final r = await db.rawQuery(
        'SELECT COALESCE(SUM(h.horas * e.valor_hora),0) AS t '
        'FROM horas h JOIN empleados e ON e.id = h.empleado_id WHERE h.fecha LIKE ?',
        ['$mes-%']);
    return (r.first['t'] as num).toDouble();
  }

  // ---------- Gastos ----------
  static Future<List<Map<String, dynamic>>> gastosDelMes(String mes) async {
    final db = await Db.abrir;
    return db.query('gastos',
        where: 'fecha LIKE ?', whereArgs: ['$mes-%'], orderBy: 'fecha DESC, id DESC');
  }

  static Future<void> agregarGasto(
      String fecha, String categoria, String detalle, double monto) async {
    final db = await Db.abrir;
    await db.insert('gastos',
        {'fecha': fecha, 'categoria': categoria, 'detalle': detalle, 'monto': monto});
  }

  static Future<void> borrarGasto(int id) async {
    final db = await Db.abrir;
    await db.delete('gastos', where: 'id = ?', whereArgs: [id]);
  }

  static Future<Map<String, double>> totalesGastos(String mes) async {
    final g = await gastosDelMes(mes);
    double f = 0, v = 0;
    for (final x in g) {
      final m = (x['monto'] as num?)?.toDouble() ?? 0;
      if (esFijo((x['categoria'] ?? '') as String)) {
        f += m;
      } else {
        v += m;
      }
    }
    return {'fijos': f, 'variables': v};
  }

  // ---------- Mano de obra en el costo de lo vendido ----------
  // Sueldos del mes / unidades vendidas del mes
  static Future<double> manoDeObraPorUnidad() async {
    final db = await Db.abrir;
    final mes = mesDe(DateTime.now());
    final sueldos = await sueldosDelMes(mes);
    final r = await db.rawQuery(
        'SELECT COALESCE(SUM(unidades),0) AS u FROM ventas WHERE fecha LIKE ?',
        ['$mes-%']);
    final u = (r.first['u'] as num).toDouble();
    return u > 0 ? sueldos / u : 0;
  }

  // ---------- Meta diaria automática ----------
  static Future<Map<String, double>> metaAutomatica() async {
    final db = await Db.abrir;
    final ahora = DateTime.now();
    var mes = mesDe(ahora);
    var sueldos = await sueldosDelMes(mes);
    var fijos = (await totalesGastos(mes))['fijos']!;
    if (sueldos + fijos == 0) {
      // Mes recién empezado sin cargas: usa el mes anterior
      mes = mesDe(DateTime(ahora.year, ahora.month - 1, 1));
      sueldos = await sueldosDelMes(mes);
      fijos = (await totalesGastos(mes))['fijos']!;
    }

    final dias =
        (double.tryParse(await Db.getConfig('dias_venta_mes', '26')) ?? 26).clamp(1, 31).toDouble();

    // Margen: ventas de los últimos 30 días
    final desde = fecha(ahora.subtract(const Duration(days: 30)));
    final v = await db.rawQuery(
        'SELECT COALESCE(SUM(total),0) AS t, COALESCE(SUM(costo),0) AS c FROM ventas WHERE fecha >= ?',
        [desde]);
    final t = (v.first['t'] as num).toDouble();
    final c = (v.first['c'] as num).toDouble();
    double margen;
    if (t > 0) {
      margen = (t - c) / t;
    } else {
      final ps = await db.query('productos');
      double suma = 0;
      int n = 0;
      for (final p in ps) {
        final precio = (p['precio'] as num).toDouble();
        final costo = (p['costo'] as num).toDouble();
        if (precio > 0) {
          suma += (precio - costo) / precio;
          n++;
        }
      }
      margen = n > 0 ? suma / n : 0.5;
    }
    if (margen < 0.1) margen = 0.1;
    if (margen > 1) margen = 1;

    final costoDia = (sueldos + fijos) / dias;
    final meta = costoDia <= 0 ? 0.0 : (costoDia / margen / 100).ceil() * 100.0;
    return {
      'meta': meta,
      'costoDia': costoDia,
      'margen': margen,
      'sueldos': sueldos,
      'fijos': fijos,
      'dias': dias,
    };
  }
}
