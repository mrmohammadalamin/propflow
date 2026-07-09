import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';

class VisualTemplateEditor extends StatefulWidget {
  final Map<String, dynamic>? template;
  
  const VisualTemplateEditor({super.key, this.template});

  @override
  State<VisualTemplateEditor> createState() => _VisualTemplateEditorState();
}

class VisualElement {
  String id;
  String text;
  double x;
  double y;
  double fontSize;
  
  VisualElement({required this.id, required this.text, required this.x, required this.y, this.fontSize = 12});
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'x': x,
    'y': y,
    'fontSize': fontSize,
  };
  
  factory VisualElement.fromJson(Map<String, dynamic> json) {
    return VisualElement(
      id: json['id'],
      text: json['text'],
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 12.0,
    );
  }
}

class _VisualTemplateEditorState extends State<VisualTemplateEditor> {
  final _nameController = TextEditingController();
  String _documentType = 'landlord_invoice_single';
  bool _isDefault = false;
  String _paperSize = 'A4';
  
  String? _backgroundFileUrl;
  String? _previewFileUrl;
  List<VisualElement> _elements = [];
  String? _selectedElementId;
  
  bool _isSaving = false;
  final GlobalKey _canvasKey = GlobalKey();
  final TransformationController _transformationController = TransformationController();

  final List<String> _documentTypes = [
    'landlord_invoice_single',
    'landlord_invoice_multi',
    'tenant_invoice',
    'agency_summary',
    'agency_property_statement'
  ];
  
  final List<String> _placeholders = [
    '{{ agency_info.name }}',
    '{{ agency_info.address }}',
    '{{ property.name }}',
    '{{ landlord.name }}',
    '{{ tenant.name }}',
    '{{ financials.rent_collected }}',
    '{{ financials.management_fee_amount }}',
    '{{ financials.net_amount_payable }}',
    '{{ date_from }}',
    '{{ date_to }}',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.template != null) {
      _nameController.text = widget.template!['name'] ?? '';
      _documentType = widget.template!['document_type'] ?? 'landlord_invoice_single';
      _isDefault = widget.template!['is_default'] ?? false;
      _paperSize = widget.template!['paper_size'] ?? 'A4';
      _backgroundFileUrl = widget.template!['background_file_url'];
      _previewFileUrl = widget.template!['preview_file_url'] ?? _backgroundFileUrl;
      
      if (widget.template!['visual_config'] != null) {
        try {
          final List<dynamic> configList = json.decode(widget.template!['visual_config']);
          _elements = configList.map((e) => VisualElement.fromJson(e)).toList();
        } catch (e) {
          debugPrint('Error parsing visual_config: $e');
        }
      }
    }
  }

  Future<void> _uploadBackground() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom, 
      allowedExtensions: ['pdf', 'png', 'jpg', 'doc', 'docx'],
      withData: true,
    );
    if (result == null) return;
    
    if (result.files.single.bytes == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Could not read file data. Try a different browser or file.')));
      return;
    }
    
    if (!mounted) return;
    final api = Provider.of<ApiService>(context, listen: false);
    try {
        final request = http.MultipartRequest('POST', Uri.parse('${api.baseUrl}/api/templates/upload-background'));
        request.headers['Authorization'] = 'Bearer ${api.token}';
        request.files.add(http.MultipartFile.fromBytes(
          'file', 
          result.files.single.bytes!,
          filename: result.files.single.name,
        ));
        
        final response = await request.send();
        final responseData = await response.stream.bytesToString();
        if (response.statusCode == 200) {
          final jsonResponse = json.decode(responseData);
          if (mounted) {
            setState(() {
              _backgroundFileUrl = jsonResponse['url'];
              _previewFileUrl = jsonResponse['preview_url'] ?? jsonResponse['url'];
            });
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Background uploaded!')));
          }
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $responseData')));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
  }

  Future<void> _saveTemplate() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name is required')));
      return;
    }
    
    setState(() => _isSaving = true);
    final api = Provider.of<ApiService>(context, listen: false);
    
    final payload = {
      'name': _nameController.text,
      'document_type': _documentType,
      'is_default': _isDefault,
      'paper_size': _paperSize,
      'template_type': 'visual',
      'background_file_url': _backgroundFileUrl,
      'preview_file_url': _previewFileUrl,
      'visual_config': json.encode(_elements.map((e) => e.toJson()).toList())
    };

    try {
      http.Response response;
      if (widget.template == null) {
        response = await http.post(
          Uri.parse('${api.baseUrl}/api/templates'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${api.token}'},
          body: json.encode(payload),
        );
      } else {
        response = await http.put(
          Uri.parse('${api.baseUrl}/api/templates/${widget.template!['id']}'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${api.token}'},
          body: json.encode(payload),
        );
      }

      if (mounted) {
        if (response.statusCode == 200) {
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving template: ${response.body}')));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Network error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addPlaceholderAt(String text, Offset localOffset) {
    setState(() {
      _elements.add(VisualElement(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        x: localOffset.dx,
        y: localOffset.dy,
        fontSize: 16,
      ));
    });
  }

  Future<void> _editElementText(VisualElement el) async {
    final TextEditingController controller = TextEditingController(text: el.text);
    final newText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Text'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
        ],
      ),
    );
    
    if (newText != null && newText.isNotEmpty) {
      setState(() {
        el.text = newText;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.template == null ? 'Create Visual Template' : 'Edit Visual Template'),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
        actions: [
          if (_isSaving) const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(color: Colors.white))),
          if (!_isSaving) IconButton(icon: const Icon(Icons.save), onPressed: _saveTemplate),
        ],
      ),
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 320,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(2, 0),
                )
              ]
            ),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      const Text('Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Template Name', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _documentType,
                        decoration: const InputDecoration(labelText: 'Document Type', border: OutlineInputBorder()),
                        items: _documentTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (v) => setState(() => _documentType = v!),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        title: const Text('Set as Default'),
                        value: _isDefault,
                        onChanged: (v) => setState(() => _isDefault = v),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const Divider(height: 32),
                      const Text('Background Template', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 8),
                      if (_backgroundFileUrl != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text('Uploaded: ', style: const TextStyle(color: Colors.green, fontSize: 12)),
                        ),
                      ElevatedButton.icon(
                        onPressed: _uploadBackground,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Upload PDF/Image Background'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade50, foregroundColor: Colors.indigo),
                      ),
                      const Divider(height: 32),
                      const Text('Variables (Drag to Paper)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _elements.add(VisualElement(
                              id: DateTime.now().millisecondsSinceEpoch.toString(),
                              text: 'Custom Text...',
                              x: 50,
                              y: 50,
                              fontSize: 16,
                            ));
                          });
                        },
                        icon: const Icon(Icons.text_fields),
                        label: const Text('Add Custom Text Block'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black87),
                      ),
                      const SizedBox(height: 16),
                      const Text('Drag a variable below and drop it onto the paper canvas.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 16),
                      ..._placeholders.map((p) => Draggable<String>(
                        data: p,
                        feedback: Material(
                          color: Colors.transparent,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.indigo,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4)]
                            ),
                            child: Text(p, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.5,
                          child: _buildPlaceholderTile(p),
                        ),
                        child: _buildPlaceholderTile(p),
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Canvas Area
          Expanded(
            child: Container(
              // Professional Desk Background Pattern
              decoration: const BoxDecoration(
                color: Color(0xFFE5E7EB),
                image: DecorationImage(
                  image: NetworkImage('data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAAXNSR0IArs4c6QAAACVJREFUKFNjZCASMDKgAnv37v3/n5OTk4GqFkKTY9M0FqFk6m4EAD4pBxTIfs+4AAAAAElFTkSuQmCC'),
                  repeat: ImageRepeat.repeat,
                  opacity: 0.3,
                ),
              ),
              alignment: Alignment.center,
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: () {
                      // Deselect on tap outside
                      setState(() {
                        _selectedElementId = null;
                      });
                    },
                    child: InteractiveViewer(
                      transformationController: _transformationController,
                      boundaryMargin: const EdgeInsets.all(500),
                      minScale: 0.1,
                      maxScale: 5.0,
                      constrained: false, // allows panning freely
                      child: DragTarget<String>(
                        onAcceptWithDetails: (details) {
                          final RenderBox renderBox = _canvasKey.currentContext!.findRenderObject() as RenderBox;
                          final localOffset = renderBox.globalToLocal(details.offset);
                          _addPlaceholderAt(details.data, localOffset);
                        },
                        builder: (context, candidateData, rejectedData) {
                          return Padding(
                            padding: const EdgeInsets.all(100.0), // Give room to pan around the paper
                            child: Container(
                              key: _canvasKey,
                              width: _paperSize == 'A4' ? 794 : 816, // A4 width in pixels at 96dpi approx
                              height: _paperSize == 'A4' ? 1123 : 1056,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: candidateData.isNotEmpty ? 0.3 : 0.15), blurRadius: 15, offset: const Offset(0, 8)),
                                ],
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  // Background Preview
                                  if (_previewFileUrl != null)
                                    Positioned.fill(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(2),
                                        child: Image.network(
                                          _previewFileUrl!, 
                                          fit: BoxFit.fill,
                                          errorBuilder: (ctx, err, stack) => const Center(
                                            child: Text('Failed to load preview. Please upload again.', style: TextStyle(color: Colors.red)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  
                                  if (_previewFileUrl == null && _backgroundFileUrl != null)
                                    const Center(
                                      child: Opacity(
                                        opacity: 0.5,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.warning, size: 64, color: Colors.orange),
                                            SizedBox(height: 16),
                                            Text('No visual preview available for this template.', style: TextStyle(fontSize: 20)),
                                            Text('Please upload a new PDF or Image to generate a preview.', style: TextStyle(fontSize: 16)),
                                          ],
                                        ),
                                      ),
                                    ),

                                  // Render visual elements
                                  ..._elements.map((el) {
                                    final isSelected = el.id == _selectedElementId;
                                    return Positioned(
                                      left: el.x,
                                      top: el.y,
                                      child: _buildElementWidget(el, isSelected),
                                    );
                                  }),
                                  // Toolbar Layer
                                  if (_selectedElementId != null)
                                    ...() {
                                      try {
                                        final el = _elements.firstWhere((e) => e.id == _selectedElementId);
                                        return [
                                          Positioned(
                                            left: el.x,
                                            top: el.y - 45,
                                            child: _buildElementToolbar(el),
                                          ),
                                          Positioned(
                                            left: el.x - 12,
                                            top: el.y - 12,
                                            child: _buildResizeHandle(el),
                                          )
                                        ];
                                      } catch (e) {
                                        return <Widget>[];
                                      }
                                    }(),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  
                  // Zoom Toolbar
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.zoom_in),
                            tooltip: 'Zoom In',
                            onPressed: () {
                              _transformationController.value *= Matrix4.diagonal3Values(1.2, 1.2, 1);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.zoom_out),
                            tooltip: 'Zoom Out',
                            onPressed: () {
                              _transformationController.value *= Matrix4.diagonal3Values(0.8, 0.8, 1);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.restart_alt),
                            tooltip: 'Reset Zoom',
                            onPressed: () {
                              _transformationController.value = Matrix4.identity();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderTile(String p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8)
      ),
      child: ListTile(
        title: Text(p, style: const TextStyle(fontSize: 14, color: Colors.indigo, fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.drag_indicator, color: Colors.grey),
        dense: true,
      ),
    );
  }

  Widget _buildElementWidget(VisualElement el, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedElementId = el.id;
        });
      },
      onPanUpdate: (details) {
        setState(() {
          el.x += details.delta.dx;
          el.y += details.delta.dy;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.blueAccent : Colors.transparent, 
            width: 1.5, 
            style: isSelected ? BorderStyle.solid : BorderStyle.none
          ),
          color: isSelected ? Colors.blueAccent.withValues(alpha: 0.1) : Colors.transparent,
        ),
        child: Text(el.text, style: TextStyle(fontSize: el.fontSize, color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildElementToolbar(VisualElement el) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      color: Colors.grey.shade900,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 18),
            onPressed: () => _editElementText(el),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
          Container(width: 1, height: 24, color: Colors.grey.shade700),
          IconButton(
            icon: const Icon(Icons.remove, color: Colors.white, size: 18),
            onPressed: () => setState(() => el.fontSize = (el.fontSize - 1).clamp(8.0, 100.0)),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
          Text('${el.fontSize.round()}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white, size: 18),
            onPressed: () => setState(() => el.fontSize = (el.fontSize + 1).clamp(8.0, 100.0)),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
          Container(width: 1, height: 24, color: Colors.grey.shade700),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
            onPressed: () {
              setState(() {
                if (_selectedElementId == el.id) _selectedElementId = null;
                _elements.remove(el);
              });
            },
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildResizeHandle(VisualElement el) {
    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          final dragAmount = (details.delta.dx + details.delta.dy) / 2;
          el.fontSize = (el.fontSize + dragAmount).clamp(8.0, 100.0);
        });
      },
      child: Container(
        width: 24,
        height: 24,
        alignment: Alignment.topLeft,
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.blueAccent, width: 2),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
