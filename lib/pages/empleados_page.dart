import 'package:flutter/material.dart';
import '../db/db_gestion.dart';
import '../db/db_stock.dart';
import '../theme.dart';
import '../utils.dart';

class EmpleadosPage extends StatefulWidget {
  const EmpleadosPage({super.key});
  @override
  State<EmpleadosPage> createState() => _EmpleadosPageState();
}

class _EmpleadosPageState extends State<EmpleadosPage> {
  DateTime mes = DateTime(DateTime.now().year, DateTime.now().month, 1);
  List<Map<String, dynamic>> lista = [];

  @override
  void initState() {
    super.initState();
    cargar();
  }

  Future<void> cargar() async {
    final r = await DbGestion.resumenEmpleados(DbGestion.mesDe(mes));
    if (!mounted) return;
    setState(() => lista = r);
  }

  void cambiarMes(int d) {
    setState(() => mes = DateTime(mes.year, mes.month + d, 1));
    cargar();
  }

  double pago(Map<String, dynamic> e) =>
      (e['horas'] as num).toDouble() * (e['valor_hora'] as num).toDouble();

  Future<void> editar([Map<String, dynamic>? e]) async {
    final nombre = TextEditingController(text: e == null ? '' : e['nombre'] as String);
    final valor = TextEditingController(
        text: e == null ? '' : numTxt((e['valor_hora'] as num).toDouble()));
    final res = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(e == null ? 'Nuevo empleado' : 'Editar empleado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nombre,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre')),
            TextField(
                controller: valor,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: 'Valor por hora', prefixText: '\$ ')),
          ],
        ),
        actions: [
          if (e != null)
            TextButton(
                onPressed: () => Navigator.pop(c, 'borrar'),
                child: const Text('Borrar', style: TextStyle(color: Estanque.rojo))),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, 'ok'), child: const Text('Guardar')),
        ],
      ),
    );
    if (res == 'ok') {
      if (nombre.text.trim().isEmpty) return;
      await DbGestion.guardarEmpleado(
          {'nombre': nombre.text.trim(), 'valor_hora': aNum(valor.text)},
          e?['id'] as int?);
      cargar();
    } else if (res == 'borrar') {
      final seguro = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('¿Borrar empleado?'),
          content: const Text('Se borran también todas sus horas cargadas.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sí, borrar')),
          ],
        ),
      );
      if (seguro == true) {
        await DbGestion.borrarEmpleado(e!['id'] as int);
        cargar();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = lista.fold<double>(0, (s, e) => s + pago(e));
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => editar(),
        child: const Icon(Icons.person_add),
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(onPressed: () => cambiarMes(-1), icon: const Icon(Icons.chevron_left)),
              Text(DbGestion.nombreMes(mes),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              IconButton(onPressed: () => cambiarMes(1), icon: const Icon(Icons.chevron_right)),
            ],
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.payments, color: Estanque.agua),
              title: const Text('Total a pagar en el mes'),
              trailing: Text(pesos(total),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          ),
          Expanded(
            child: lista.isEmpty
                ? const Center(child: Text('Tocá el botón para agregar un empleado'))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: lista.length,
                    itemBuilder: (c, i) {
                      final e = lista[i];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Estanque.aguaClara,
                            child: Text((e['nombre'] as String)[0].toUpperCase()),
                          ),
                          title: Text(e['nombre'] as String),
                          subtitle: Text(
                              '${numTxt((e['horas'] as num).toDouble())} h × ${pesos(e['valor_hora'] as num)}/h'),
                          trailing: Text(pesos(pago(e)),
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => _EmpleadoDetalle(emp: e, mes: mes)),
                            );
                            cargar();
                          },
                          onLongPress: () => editar(e),
                        ),
                      );
                    },
                  ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Tocá un empleado para cargar horas. Mantené apretado para editarlo.',
                style: TextStyle(fontSize: 12, color: Estanque.barro)),
          ),
        ],
      ),
    );
  }
}

class _EmpleadoDetalle extends StatefulWidget {
  final Map<String, dynamic> emp;
  final DateTime mes;
  const _EmpleadoDetalle({required this.emp, required this.mes});
  @override
  State<_EmpleadoDetalle> createState() => _EmpleadoDetalleState();
}

class _EmpleadoDetalleState extends State<_EmpleadoDetalle> {
  List<Map<String, dynamic>> horas = [];

  int get id => widget.emp['id'] as int;
  double get valorHora => (widget.emp['valor_hora'] as num).toDouble();

  @override
  void initState() {
    super.initState();
    cargar();
  }

  Future<void> cargar() async {
    final r = await DbGestion.horasDelMes(id, DbGestion.mesDe(widget.mes));
    if (!mounted) return;
    setState(() => horas = r);
  }

  Future<void> agregar() async {
    final ahora = DateTime.now();
    final esMesActual = ahora.year == widget.mes.year && ahora.month == widget.mes.month;
    DateTime fecha = esMesActual ? ahora : widget.mes;
    final ctl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: const Text('Cargar horas'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Horas trabajadas'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text(DbGestion.fecha(fecha)),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: c,
                    initialDate: fecha,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) setD(() => fecha = d);
                },
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
    if (ok == true && aNum(ctl.text) > 0) {
      await DbGestion.agregarHoras(id, DbGestion.fecha(fecha), aNum(ctl.text));
      cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = horas.fold<double>(0, (s, h) => s + (h['horas'] as num).toDouble());
    return Scaffold(
      appBar: AppBar(title: Text(widget.emp['nombre'] as String)),
      floatingActionButton: FloatingActionButton(
        onPressed: agregar,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Card(
            child: ListTile(
              title: Text('${DbGestion.nombreMes(widget.mes)}: ${numTxt(total)} h'),
              subtitle: Text('${pesos(valorHora)} por hora'),
              trailing: Text(pesos(total * valorHora),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          ),
          Expanded(
            child: horas.isEmpty
                ? const Center(child: Text('Sin horas este mes'))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: horas.length,
                    itemBuilder: (c, i) {
                      final h = horas[i];
                      return ListTile(
                        leading: const Icon(Icons.schedule, color: Estanque.agua),
                        title: Text('${numTxt((h['horas'] as num).toDouble())} horas'),
                        subtitle: Text(h['fecha'] as String),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await DbGestion.borrarHoras(h['id'] as int);
                            cargar();
                          },
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
