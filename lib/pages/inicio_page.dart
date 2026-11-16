import 'package:flutter/material.dart';
import '../db/database.dart';
import '../db/db_gestion.dart';
import '../db/db_stock.dart';
import '../theme.dart';
import '../utils.dart';

class InicioPage extends StatefulWidget {
  const InicioPage({super.key});
  @override
  State<InicioPage> createState() => _InicioPageState();
}

class _InicioPageState extends State<InicioPage> {
  double ventas = 0, costo = 0, metaManual = 20000, moUnidad = 0;
  double meta = 20000, costoDia = 0, margen = 0;
  bool auto = true, autoActiva = false;
  int unidades = 0;

  @override
  void initState() {
    super.initState();
    cargar();
  }

  Future<void> cargar() async {
    final r = await Db.resumenDia(hoy());
    final m = await Db.getConfig('meta_diaria', '20000');
    final a = await Db.getConfig('meta_auto', '1');
    final info = await DbGestion.metaAutomatica();
    final mo = await DbGestion.manoDeObraPorUnidad();
    if (!mounted) return;
    setState(() {
      ventas = r['total']!;
      costo = r['costo']!;
      unidades = r['unidades']!.round();
      metaManual = double.tryParse(m) ?? 20000;
      auto = a == '1';
      autoActiva = auto && info['meta']! > 0;
      meta = autoActiva ? info['meta']! : metaManual;
      costoDia = info['costoDia']!;
      margen = info['margen']!;
      moUnidad = mo;
    });
  }

  Future<void> editarMeta() async {
    bool autoTmp = auto;
    final ctl = TextEditingController(text: metaManual.round().toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: const Text('Meta diaria de ventas'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Calcular sola'),
                subtitle: const Text('Con sueldos y gastos fijos'),
                value: autoTmp,
                onChanged: (v) => setD(() => autoTmp = v),
              ),
              TextField(
                controller: ctl,
                enabled: !autoTmp,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Meta manual', prefixText: '\$ '),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (ok == true) {
      await Db.setConfig('meta_auto', autoTmp ? '1' : '0');
      await Db.setConfig('meta_diaria', numTxt(aNum(ctl.text)));
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

    final double manoObra = unidades * moUnidad;
    final double neta = ventas - costo - manoObra;

    final String detalleMeta = autoActiva
        ? 'Automática · costos fijos y sueldos ${pesos(costoDia)}/día ÷ margen ${(margen * 100).round()}%'
        : (auto
            ? 'Manual (cargá horas y gastos fijos para que se calcule sola)'
            : 'Manual');

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
          Row(
            children: [
              Expanded(child: _Dato('Mano de obra (est.)', pesos(manoObra), Icons.groups)),
              Expanded(child: _Dato('Ganancia neta', pesos(neta), Icons.account_balance_wallet)),
            ],
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.flag, color: Estanque.barro),
              title: Text('Meta diaria: ${pesos(meta)}'),
              subtitle: Text(detalleMeta),
              trailing: const Icon(Icons.edit),
              onTap: editarMeta,
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'La mano de obra por unidad = sueldos del mes ÷ unidades vendidas del mes.',
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
