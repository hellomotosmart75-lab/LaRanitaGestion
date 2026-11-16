import 'package:flutter/material.dart';
import 'theme.dart';
import 'widgets/rana_logo.dart';
import 'pages/inicio_page.dart';
import 'pages/ventas_page.dart';
import 'pages/recetas_page.dart';
import 'pages/stock_page.dart';

void main() {
  runApp(const LaRanitaApp());
}

class LaRanitaApp extends StatelessWidget {
  const LaRanitaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'La Ranita Gestión',
        debugShowCheckedModeBanner: false,
        theme: temaEstanque(),
        home: const Principal(),
      );
}

class _Modulo {
  final String nombre;
  final IconData icono;
  final Widget Function() pagina;
  _Modulo(this.nombre, this.icono, this.pagina);
}

class Pronto extends StatelessWidget {
  final String titulo, etapa;
  const Pronto(this.titulo, this.etapa, {super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const RanaLogo(size: 160),
            const SizedBox(height: 12),
            Text(titulo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('Llega en la $etapa'),
          ],
        ),
      );
}

class Principal extends StatefulWidget {
  const Principal({super.key});
  @override
  State<Principal> createState() => _PrincipalState();
}

class _PrincipalState extends State<Principal> {
  int sel = 0;

  final List<_Modulo> modulos = [
    _Modulo('Inicio', Icons.home_rounded, () => const InicioPage()),
    _Modulo('Ventas', Icons.point_of_sale, () => const VentasPage()),
    _Modulo('Recetas e insumos', Icons.menu_book, () => const RecetasPage()),
    _Modulo('Stock y vencimientos', Icons.inventory_2, () => const StockPage()),
    _Modulo('Empleados', Icons.groups, () => const Pronto('Empleados', 'etapa 3')),
    _Modulo('Gastos e impuestos', Icons.receipt_long,
        () => const Pronto('Gastos e impuestos', 'etapa 3')),
    _Modulo('Rutas y clientes', Icons.local_shipping,
        () => const Pronto('Rutas y clientes', 'etapa 4')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(modulos[sel].nombre)),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Estanque.verdeProfundo, Estanque.agua],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: const [
                  RanaLogo(size: 90),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'La Ranita\nGestión',
                      style: TextStyle(
                          color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < modulos.length; i++)
              ListTile(
                leading: Icon(modulos[i].icono),
                title: Text(modulos[i].nombre),
                selected: i == sel,
                selectedColor: Estanque.verdeProfundo,
                selectedTileColor: Estanque.aguaClara,
                onTap: () {
                  setState(() => sel = i);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
      body: modulos[sel].pagina(),
    );
  }
}
