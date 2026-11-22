import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../db/database.dart';
import '../informe.dart';
import '../theme.dart';

class InformePage extends StatefulWidget {
  const InformePage({super.key});
  @override
  State<InformePage> createState() => _InformePageState();
}

class _InformePageState extends State<InformePage> {
  DateTime dia = DateTime.now();
  String texto = 'Armando informe...';
  final mailCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    iniciar();
  }

  Future<void> iniciar() async {
    mailCtl.text = await Db.getConfig('mail_informe', '');
    await cargar();
  }

  Future<void> cargar() async {
    final t = await armarInforme(dia);
    if (!mounted) return;
    setState(() => texto = t);
  }

  void cambiarDia(int d) {
    setState(() => dia = dia.add(Duration(days: d)));
    cargar();
  }

  String get _fechaTxt =>
      '${dia.year}-${dia.month.toString().padLeft(2, '0')}-${dia.day.toString().padLeft(2, '0')}';

  void _aviso(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> enviar() async {
    final mail = mailCtl.text.trim();
    if (mail.isEmpty || !mail.contains('@')) {
      _aviso('Escribí tu mail primero');
      return;
    }
    await Db.setConfig('mail_informe', mail);
    final asunto = 'La Ranita - Informe $_fechaTxt';
    final uri = Uri(
      scheme: 'mailto',
      path: mail,
      query: 'subject=${Uri.encodeComponent(asunto)}&body=${Uri.encodeComponent(texto)}',
    );
    try {
      final ok = await launchUrl(uri);
      if (!ok) _aviso('No pude abrir el mail. Usá "Copiar".');
    } catch (_) {
      _aviso('No pude abrir el mail. Usá "Copiar".');
    }
  }

  Future<void> copiar() async {
    await Clipboard.setData(ClipboardData(text: texto));
    _aviso('Informe copiado');
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: cargar,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(onPressed: () => cambiarDia(-1), icon: const Icon(Icons.chevron_left)),
              Text(_fechaTxt, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              IconButton(onPressed: () => cambiarDia(1), icon: const Icon(Icons.chevron_right)),
            ],
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(texto, style: const TextStyle(height: 1.4)),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: mailCtl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Tu mail',
              prefixIcon: Icon(Icons.mail_outline),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: enviar,
                  icon: const Icon(Icons.send),
                  label: const Text('Enviar por mail'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: copiar,
                  icon: const Icon(Icons.copy),
                  label: const Text('Copiar'),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'Se abre tu app de mail con el informe listo: solo tocás Enviar.',
              style: TextStyle(fontSize: 12, color: Estanque.barro),
            ),
          ),
        ],
      ),
    );
  }
}
