import 'database.dart';

class DbClientes {
  static const dias = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
  ];
  static const tipos = ['Kiosco', 'Almacén', 'Otro'];

  static String diaDe(DateTime d) => dias[d.weekday - 1];

  static Future<List<Map<String, dynamic>>> clientes() async {
    final db = await Db.abrir;
    return db.query('clientes', orderBy: 'nombre');
  }

  static Future<void> guardarCliente(Map<String, dynamic> datos, [int? id]) async {
    final db = await Db.abrir;
    if (id == null) {
      await db.insert('clientes', datos);
    } else {
      await db.update('clientes', datos, where: 'id = ?', whereArgs: [id]);
    }
  }

  static Future<void> borrarCliente(int id) async {
    final db = await Db.abrir;
    await db.update('ventas', {'cliente_id': null},
        where: 'cliente_id = ?', whereArgs: [id]);
    await db.delete('clientes', where: 'id = ?', whereArgs: [id]);
  }

  // cliente_id -> total comprado en esa fecha
  static Future<Map<int, double>> comprasDeFecha(String fecha) async {
    final db = await Db.abrir;
    final r = await db.rawQuery(
        'SELECT cliente_id, SUM(total) AS t FROM ventas '
        'WHERE fecha = ? AND cliente_id IS NOT NULL GROUP BY cliente_id',
        [fecha]);
    return {
      for (final x in r) (x['cliente_id'] as int): (x['t'] as num).toDouble()
    };
  }

  static Future<List<Map<String, dynamic>>> ventasDeCliente(int id) async {
    final db = await Db.abrir;
    return db.rawQuery(
        'SELECT v.*, p.nombre FROM ventas v JOIN productos p ON p.id = v.producto_id '
        'WHERE v.cliente_id = ? ORDER BY v.fecha DESC, v.id DESC LIMIT 30',
        [id]);
  }
}
