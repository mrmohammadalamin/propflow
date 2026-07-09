import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import 'visual_template_editor.dart';

class DocumentTemplatesScreen extends StatefulWidget {
  const DocumentTemplatesScreen({super.key});

  @override
  State<DocumentTemplatesScreen> createState() => _DocumentTemplatesScreenState();
}

class _DocumentTemplatesScreenState extends State<DocumentTemplatesScreen> {
  List<dynamic> _templates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchTemplates();
    });
  }

  Future<void> _fetchTemplates() async {
    setState(() => _isLoading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final templates = await api.fetchTemplates();
      setState(() {
        _templates = templates;
      });
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteTemplate(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Template'),
        content: const Text('Are you sure you want to delete this template?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final api = Provider.of<ApiService>(context, listen: false);
        await api.deleteTemplate(id);
        _fetchTemplates();
      } catch (e) {
        _showError(e.toString());
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Templates'),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _templates.isEmpty
              ? const Center(child: Text('No templates found. Create one!'))
              : ListView.builder(
                  itemCount: _templates.length,
                  itemBuilder: (context, index) {
                    final tpl = _templates[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: const Icon(Icons.description, color: Colors.indigo),
                        title: Text(tpl['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Type: ${tpl['document_type']} ${tpl['is_default'] ? '(Default)' : ''}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (tpl['is_default'])
                              const Icon(Icons.star, color: Colors.orange, size: 20),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () async {
                                await Navigator.push(context, MaterialPageRoute(builder: (_) => VisualTemplateEditor(template: tpl)));
                                _fetchTemplates();
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteTemplate(tpl['id']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const VisualTemplateEditor()));
          _fetchTemplates();
        },
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
