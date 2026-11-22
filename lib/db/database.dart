import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class Db {
  static Database? _db;

  static Future<Database> get abrir async {
    if (_db != null) return _db!;
    final ruta = join(await getDatabasesPath(), 'la_ranita.db');
    _db = await openDatabase(ruta,
        version: 3, onCreate: _crear, onUpgrade: _actualizar);
    return _db!;
  }

  static const _tablas = [
    'CREATE TABLE productos (id INTEGER PRIMARY KEY AUTOINCREMENT, nombre TEXT NOT NULL, codigo TEXT, costo REAL DEFAULT 0, precio REAL DEFAULT 0, precio_mayorista REAL DEFAULT 0, unidades_por_caja INTEGER DEFAULT 1, emoji TEXT)',
    "CREATE TABLE ventas (id INTEGER PRIMARY KEY AUTOINCREMENT, fecha TEXT NOT NULL, producto_id INTEGER NOT NULL, unidades INTEGER NOT NULL, total REAL NOT NULL, costo REAL NOT NULL, por_caja INTEGER DEFAULT 0, cliente_id INTEGER, medio_pago TEXT DEFAULT 'efectivo')",
    'CREATE TABLE insumos (id INTEGER PRIMARY KEY AUTOINCREMENT, nombre TEXT NOT NULL, unidad TEXT, costo_unitario REAL DEFAULT 0, codigo TEXT)',
    'CREATE TABLE recetas (id INTEGER PRIMARY KEY AUTOINCREMENT, producto_id INTEGER, nombre TEXT NOT NULL, rinde INTEGER DEFAULT 1)',
    'CREATE TABLE receta_items (id INTEGER PRIMARY KEY AUTOINCREMENT, receta_id INTEGER, insumo_id INTEGER, cantidad REAL)',
    'CREATE TABLE lotes (id INTEGER PRIMARY KEY AUTOINCREMENT, codigo TEXT, nombre TEXT, cantidad REAL, vencimiento TEXT, ingreso TEXT)',
    'CREATE TABLE empleados (id INTEGER PRIMARY KEY AUTOINCREMENT, nombre TEXT NOT NULL, valor_hora REAL DEFAULT 0)',
    'CREATE TABLE horas (id INTEGER PRIMARY KEY AUTOINCREMENT, empleado_id INTEGER, fecha TEXT, horas REAL)',
    'CREATE TABLE gastos (id INTEGER PRIMARY KEY AUTOINCREMENT, fecha TEXT, categoria TEXT, detalle TEXT, monto REAL)',
    'CREATE TABLE clientes (id INTEGER PRIMARY KEY AUTOINCREMENT, nombre TEXT NOT NULL, tipo TEXT, direccion TEXT, dia_visita TEXT)',
    'CREATE TABLE config (clave TEXT PRIMARY KEY, valor TEXT)',
  ];

  static Future<void> _crear(Database db, int version) async {
    for (final sql in _tablas) {
      await db.execute(sql);
    }
    // Datos de ejemplo: editalos desde Ventas (mantené apretado el producto)
    await db.insert('productos', {
      'nombre': 'Gelatina con gomitas',
      'costo': 1200,
      'precio': 2500,
      'precio_mayorista': 1700,
      'unidades_por_caja': 12,
      'emoji': '🍬',
    });
    await db.insert('productos', {
      'nombre': 'Flan con caramelo',
      'costo': 1500,
      'precio': 3000,
      'precio_mayorista': 2000,
      'unidades_por_caja': 8,
      'emoji': '🍮',
    });
    await db.insert('config', {'clave': 'meta_diaria', 'valor': '20000'});
  }

  // Migraciones: no se pierde ningún dato
  static Future<void> _actualizar(Database db, int viejo, int nuevo) async {
    if (viejo < 2) {
      await db.execute('ALTER TABLE ventas ADD COLUMN cliente_id INTEGER');
    }
    if (viejo < 3) {
      await db.execute('ALTER TABLE productos ADD COLUMN emoji TEXT');
      await db.execute(
          "ALTER TABLE ventas ADD COLUMN medio_pago TEXT DEFAULT 'efectivo'");
      await db.execute(
          "UPDATE productos SET emoji = '🍮' WHERE lower(nombre) LIKE '%flan%'");
      await db.execute(
          "UPDATE productos SET emoji = '🍬' WHERE lower(nombre) LIKE '%gelatina%'");
    }
  }

  // ---------- Config ----------
  static Future<String> getConfig(String clave, String porDefecto) async {
    final db = await abrir;
    final r = await db.query('config', where: 'clave = ?', whereArgs: [clave]);
    return r.isEmpty ? porDefecto : r.first['valor'] as String;
  }

  static Future<void> setConfig(String clave, String valor) async {
    final db = await abrir;
    await db.insert('config', {'clave': clave, 'valor': valor},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---------- Productos ----------
  static Future<List<Map<String, dynamic>>> productos() async {
    final db = await abrir;
    return db.query('productos', orderBy: 'nombre');
  }

  static Future<void> guardarProducto(Map<String, dynamic> datos, [int? id]) async {
    final db = await abrir;
    if (id == null) {
      await db.insert('productos', datos);
    } else {
      await db.update('productos', datos, where: 'id = ?', whereArgs: [id]);
    }
  }

  // ---------- Ventas ----------
  static Future<void> registrarVenta({
    required String fecha,
    required Map<String, dynamic> producto,
    required int unidades,
    required bool porCaja,
    int? clienteId,
    String medioPago = 'efectivo',
  }) async {
    final db = await abrir;
    final precio = porCaja
        ? (producto['precio_mayorista'] as num).toDouble()
        : (producto['precio'] as num).toDouble();
    final costo = (producto['costo'] as num).toDouble();
    await db.insert('ventas', {
      'fecha': fecha,
      'producto_id': producto['id'],
      'unidades': unidades,
      'total': precio * unidades,
      'costo': costo * unidades,
      'por_caja': porCaja ? 1 : 0,
      'cliente_id': clienteId,
      'medio_pago': medioPago,
    });
  }

  static Future<void> borrarVenta(int id) async {
    final db = await abrir;
    await db.delete('ventas', where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<Map<String, dynamic>>> ventasDelDia(String fecha) async {
    final db = await abrir;
    return db.rawQuery(
        'SELECT v.*, p.nombre, p.emoji FROM ventas v JOIN productos p ON p.id = v.producto_id WHERE v.fecha = ? ORDER BY v.id DESC',
        [fecha]);
  }

  static Future<Map<String, double>> resumenDia(String fecha) async {
    final db = await abrir;
    final r = await db.rawQuery(
        'SELECT COALESCE(SUM(total),0) AS t, COALESCE(SUM(costo),0) AS c, COALESCE(SUM(unidades),0) AS u FROM ventas WHERE fecha = ?',
        [fecha]);
    final f = r.first;
    return {
      'total': (f['t'] as num).toDouble(),
      'costo': (f['c'] as num).toDouble(),
      'unidades': (f['u'] as num).toDouble(),
    };
  }

  // Total cobrado por medio de pago: efectivo / transferencia / qr
  static Future<Map<String, double>> resumenPagos(String fecha) async {
    final db = await abrir;
    final r = await db.rawQuery(
        "SELECT COALESCE(medio_pago,'efectivo') AS m, SUM(total) AS t FROM ventas WHERE fecha = ? GROUP BY m",
        [fecha]);
    final out = <String, double>{'efectivo': 0, 'transferencia': 0, 'qr': 0};
    for (final x in r) {
      final k = x['m'] as String;
      out[k] = (out[k] ?? 0) + (x['t'] as num).toDouble();
    }
    return out;
  }
}
