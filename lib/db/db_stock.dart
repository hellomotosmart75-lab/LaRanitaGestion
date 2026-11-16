import 'database.dart';

double aNum(String s) => double.tryParse(s.trim().replaceAll(',', '.')) ?? 0;

String numTxt(num v) => v == v.roundToDouble() ? v.round().toString() : v.toString();

class DbStock {
  // ---------- Insumos ----------
  static Future<List<Map<String, dynamic>>> insumos() async {
    final db = await Db.abrir;
    return db.query('insumos', orderBy: 'nombre');
  }

  static Future<void> guardarInsumo(Map<String, dynamic> datos, [int? id]) async {
    final db = await Db.abrir;
    if (id == null) {
      await db.insert('insumos', datos);
    } else {
      await db.update('insumos', datos, where: 'id = ?', whereArgs: [id]);
    }
  }

  static Future<void> borrarInsumo(int id) async {
    final db = await Db.abrir;
    await db.delete('receta_items', where: 'insumo_id = ?', whereArgs: [id]);
    await db.delete('insumos', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Recetas ----------
  static const _sqlReceta =
      'SELECT r.id, r.nombre, r.rinde, r.producto_id, p.nombre AS producto '
      'FROM recetas r LEFT JOIN productos p ON p.id = r.producto_id';

  static Future<List<Map<String, dynamic>>> recetas() async {
    final db = await Db.abrir;
    return db.rawQuery('$_sqlReceta ORDER BY r.nombre');
  }

  static Future<Map<String, dynamic>?> receta(int id) async {
    final db = await Db.abrir;
    final r = await db.rawQuery('$_sqlReceta WHERE r.id = ?', [id]);
    return r.isEmpty ? null : r.first;
  }

  static Future<void> guardarReceta(Map<String, dynamic> datos, [int? id]) async {
    final db = await Db.abrir;
    if (id == null) {
      await db.insert('recetas', datos);
    } else {
      await db.update('recetas', datos, where: 'id = ?', whereArgs: [id]);
    }
  }

  static Future<void> borrarReceta(int id) async {
    final db = await Db.abrir;
    await db.delete('receta_items', where: 'receta_id = ?', whereArgs: [id]);
    await db.delete('recetas', where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<Map<String, dynamic>>> items(int recetaId) async {
    final db = await Db.abrir;
    return db.rawQuery(
        'SELECT ri.id, ri.cantidad, i.nombre, i.unidad, i.costo_unitario '
        'FROM receta_items ri JOIN insumos i ON i.id = ri.insumo_id '
        'WHERE ri.receta_id = ? ORDER BY i.nombre',
        [recetaId]);
  }

  static Future<void> agregarItem(int recetaId, int insumoId, double cantidad) async {
    final db = await Db.abrir;
    await db.insert('receta_items',
        {'receta_id': recetaId, 'insumo_id': insumoId, 'cantidad': cantidad});
  }

  static Future<void> borrarItem(int id) async {
    final db = await Db.abrir;
    await db.delete('receta_items', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> aplicarCosto(int productoId, double costo) async {
    final db = await Db.abrir;
    await db.update('productos', {'costo': costo},
        where: 'id = ?', whereArgs: [productoId]);
  }

  // ---------- Lotes (stock) ----------
  static Future<List<Map<String, dynamic>>> lotes() async {
    final db = await Db.abrir;
    return db.query('lotes', where: 'cantidad > 0', orderBy: 'vencimiento ASC');
  }

  static Future<void> agregarLote(Map<String, dynamic> datos) async {
    final db = await Db.abrir;
    await db.insert('lotes', datos);
  }

  static Future<void> actualizarCantidad(int id, double cantidad) async {
    final db = await Db.abrir;
    await db.update('lotes', {'cantidad': cantidad}, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> borrarLote(int id) async {
    final db = await Db.abrir;
    await db.delete('lotes', where: 'id = ?', whereArgs: [id]);
  }

  // Busca un nombre por código de barras en productos e insumos
  static Future<String?> nombrePorCodigo(String codigo) async {
    final db = await Db.abrir;
    final p = await db.query('productos', where: 'codigo = ?', whereArgs: [codigo]);
    if (p.isNotEmpty) return p.first['nombre'] as String;
    final i = await db.query('insumos', where: 'codigo = ?', whereArgs: [codigo]);
    if (i.isNotEmpty) return i.first['nombre'] as String;
    final l = await db.query('lotes', where: 'codigo = ?', whereArgs: [codigo], limit: 1);
    if (l.isNotEmpty) return l.first['nombre'] as String;
    return null;
  }
}
