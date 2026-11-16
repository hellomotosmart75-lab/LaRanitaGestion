import 'package:flutter/material.dart';
import '../db/database.dart';
import '../theme.dart';
import '../utils.dart';

class InicioPage extends StatefulWidget {
  const InicioPage({super.key});
  @override
  State<InicioPage> createState() => _InicioPageState();
}

class _InicioPageState extends State<InicioPage> {
  double ventas = 0, costo = 0, meta = 20000;
  int unidades = 0;

  @override
  void initState() {
    super.initState();
    cargar();
  }

  Future<void> cargar() async {
    final r = await Db.resumenDia(hoy());
    final m = await Db.getConfig('meta_diaria', '20000');
    if (!mounted) return;
    setState(() {
      ventas = r['total']!;
      costo = r['costo']!;
      unidades = r['unidades']!.round();
      meta = double.tryParse(m) ?? 20000;
    });
  }

  Future<void> editarMeta() async {
    final ctl = TextEditingController(text: meta.round().toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Meta diaria de ventas'),
        content: TextField(
          controller: ctl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: 'Monto que cubre tus costos del día', prefixText: '\$ '),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (ok == true) {
      await Db.setConfig('meta_diaria', ctl.text.trim());
      cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final double pct = meta > 0 ? ventas / meta : 0.0;
    final int nivel = pct >= 1 ? 2 : (pct >= 0.6 ? 1 : 0);
    final Color color =
        nivel == 2 ? Estanque.verdeRana : (nivel == 1 ? Estanque.amarillo : Estanque.rojo);
    final String msg = nivel == 2
        ? '¡Meta cubierta! Lo que vendas ahora es ganancia.'
        : (nivel == 1
            ? 'Vas bien: faltan ${pesos(meta - ventas)} para cubrir costos.'
            : 'Atención: faltan ${pesos(meta - ventas)} para la meta del día.');

    return RefreshIndicator(
      onRefresh: cargar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  _Semaforo(nivel: nivel),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Ventas de hoy'),
                        Text(pesos(ventas),
                            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: pct > 1 ? 1.0 : pct,
                          minHeight: 10,
                          color: color,
                          backgroundColor: Estanque.aguaClara,
                        ),
                        const SizedBox(height: 8),
                        Text(msg),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Expanded(child: _Dato('Unidades', '$unidades', Icons.cake)),
              Expanded(child: _Dato('Ganancia bruta', pesos(ventas - costo), Icons.savings)),
            ],
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.flag, color: Estanque.barro),
              title: const Text('Meta diaria'),
              subtitle: Text(pesos(meta)),
              trailing: const Icon(Icons.edit),
              onTap: editarMeta,
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'Hoy la meta es manual. En la etapa 3 se calcula sola con sueldos, luz, gas e impuestos.',
              style: TextStyle(fontSize: 12, color: Estanque.barro),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  final String titulo, valor;
  final IconData icono;
  const _Dato(this.titulo, this.valor, this.icono);

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icono, color: Estanque.agua),
              const SizedBox(height: 4),
              Text(valor, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(titulo, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      );
}

class _Semaforo extends StatelessWidget {
  final int nivel; // 0 rojo, 1 amarillo, 2 verde
  const _Semaforo({required this.nivel});

  Widget luz(Color c, bool activa) => Container(
        width: 26,
        height: 26,
        margin: const EdgeInsets.symmetric(vertical: 3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: activa ? c : c.withOpacity(0.2),
        ),
      );

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            luz(Estanque.rojo, nivel == 0),
            luz(Estanque.amarillo, nivel == 1),
            luz(Estanque.verdeRana, nivel == 2),
          ],
        ),
      );
}
