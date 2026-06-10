import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class InvitationsScreen extends StatefulWidget {
  const InvitationsScreen({super.key});

  @override
  State<InvitationsScreen> createState() => _InvitationsScreenState();
}

class _InvitationsScreenState extends State<InvitationsScreen> {
  static const String _baseUrl = 'https://api.vohk.cl/app/intercom';
  static const String _residentEmployeeNo = '1';
  List<dynamic> _invitations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInvitations();
  }

  Future<void> _loadInvitations() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse(
          '$_baseUrl/invitations?residentEmployeeNo=$_residentEmployeeNo',
        ),
      );
      if (res.statusCode == 200) {
        setState(() => _invitations = jsonDecode(res.body));
      }
    } catch (e) {
      _showSnack('Error cargando invitaciones');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _createInvitation(DateTime begin, DateTime end) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/invitations'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'residentEmployeeNo': _residentEmployeeNo,
          'beginTime': begin.toIso8601String().substring(0, 19),
          'endTime': end.toIso8601String().substring(0, 19),
        }),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final url = data['url'];
        await _loadInvitations();
        if (mounted) _showCopyDialog(url);
      }
    } catch (e) {
      _showSnack('Error creando invitación');
    }
  }

  Future<void> _deleteInvitation(String id) async {
    try {
      final res = await http.delete(Uri.parse('$_baseUrl/invitations/$id'));
      if (res.statusCode == 200) {
        await _loadInvitations();
        _showSnack('Invitación eliminada');
      }
    } catch (e) {
      _showSnack('Error eliminando invitación');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showCopyDialog(String url) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Invitación creada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Comparte este enlace con tu visita:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                url,
                style: const TextStyle(fontSize: 13, color: Colors.white),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              Navigator.pop(context);
              _showSnack('Enlace copiado');
            },
            child: const Text('Copiar enlace'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog() {
    final now = DateTime.now();
    DateTime begin = DateTime(now.year, now.month, now.day, 8, 0);
    DateTime end = DateTime(now.year, now.month, now.day, 22, 0);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Nueva invitación'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Begin time
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Desde',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                subtitle: Text(
                  '${begin.day}/${begin.month}/${begin.year}  ${begin.hour.toString().padLeft(2, '0')}:${begin.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: const Icon(
                  Icons.edit_calendar,
                  color: Colors.white54,
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: ctx,
                    initialDate: begin,
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 365)),
                  );
                  if (date != null)
                    setLocal(
                      () => begin = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        begin.hour,
                        begin.minute,
                      ),
                    );
                },
              ),
              // End time
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Hasta',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                subtitle: Text(
                  '${end.day}/${end.month}/${end.year}  ${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: const Icon(
                  Icons.edit_calendar,
                  color: Colors.white54,
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: ctx,
                    initialDate: end,
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 365)),
                  );
                  if (date != null)
                    setLocal(
                      () => end = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        end.hour,
                        end.minute,
                      ),
                    );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _createInvitation(begin, end);
              },
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(String id, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Eliminar invitación'),
        content: Text('¿Eliminar la invitación de $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _deleteInvitation(id);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'registered':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'registered':
        return 'Registrada';
      case 'pending':
        return 'Pendiente';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invitaciones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInvitations,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('Nueva invitación'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _invitations.isEmpty
          ? const Center(
              child: Text(
                'No tienes invitaciones',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _invitations.length,
              itemBuilder: (context, index) {
                final inv = _invitations[index];
                final status = inv['status'] ?? 'pending';
                final visitorName = inv['visitor']?['name'] ?? 'Sin registrar';
                final beginTime = _formatDate(inv['beginTime']);
                final endTime = _formatDate(inv['endTime']);
                final dynamicCode = inv['dynamicCode'];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: _statusColor(status).withOpacity(0.2),
                      child: Icon(
                        status == 'registered'
                            ? Icons.person
                            : Icons.hourglass_empty,
                        color: _statusColor(status),
                      ),
                    ),
                    title: Text(
                      visitorName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          '$beginTime → $endTime',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor(status).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                _statusLabel(status),
                                style: TextStyle(
                                  color: _statusColor(status),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            if (dynamicCode != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                'PIN: $dynamicCode',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _confirmDelete(inv['id'], visitorName),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
