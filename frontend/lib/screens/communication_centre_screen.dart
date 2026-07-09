import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter_html/flutter_html.dart';

class CommunicationCentreScreen extends StatefulWidget {
  final int? initialPropertyId;
  const CommunicationCentreScreen({super.key, this.initialPropertyId});

  @override
  State<CommunicationCentreScreen> createState() => _CommunicationCentreScreenState();
}

class _CommunicationCentreScreenState extends State<CommunicationCentreScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _messages = [];
  bool _isLoading = false;
  Timer? _refreshTimer;

  final _toController = TextEditingController();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  
  List<dynamic> _propertiesList = [];
  int? _selectedPropertyId;
  Map<String, dynamic>? _selectedPropertyData;
  
  String _selectedRecipientType = 'Custom';
  bool _includeAttachment = false;
  String _attachmentSource = 'Local File';
  String? _localFilePath;
  String? _localFileName;
  Uint8List? _fileBytes;
  String _selectedSystemReport = 'Tenant Invoice';


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedPropertyId = widget.initialPropertyId;
    _loadProperties();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_selectedPropertyId != null && !_isLoading && mounted) {
        _loadCommunicationsSilently(_selectedPropertyId!);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    _toController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }
  
  Future<void> _loadProperties() async {
    setState(() => _isLoading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final props = await api.fetchProperties();
      setState(() {
        _propertiesList = props;
      });
      if (_selectedPropertyId != null) {
        try {
          _selectedPropertyData = _propertiesList.firstWhere((p) => p['id'] == _selectedPropertyId);
          _prefillFields();
        } catch (_) {}
        _loadCommunications(_selectedPropertyId!);
      }
    } catch (e) {
      print(e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _getPrefilledSubject() {
    if (_selectedPropertyData == null) return '';
    final address = _selectedPropertyData!['address_line_1'] ?? '';
    final address2 = _selectedPropertyData!['address_line_2'] ?? '';
    final city = _selectedPropertyData!['city'] ?? '';
    final ref = _selectedPropertyData!['reference_number'] ?? '';
    final postcode = _selectedPropertyData!['postcode'] ?? '';
    final roomNo = _selectedPropertyData!['room_no'] ?? '';
    final flatNo = _selectedPropertyData!['flat_no'] ?? '';
    
    List<String> parts = [];
    if (ref.isNotEmpty) parts.add('PR-$ref');
    if (flatNo.isNotEmpty) parts.add(flatNo);
    if (roomNo.isNotEmpty) parts.add(roomNo);
    if (address.isNotEmpty) parts.add(address);
    if (address2.isNotEmpty) parts.add(address2);
    if (city.isNotEmpty) parts.add(city);
    if (postcode.isNotEmpty) parts.add(postcode);
    
    return parts.join(', ');
  }

  void _prefillFields() {
    _subjectController.text = _getPrefilledSubject();
    _updateToField();
  }

  void _updateToField() {
    if (_selectedPropertyData == null) return;
    setState(() {
      if (_selectedRecipientType == 'Landlord') {
        final landlord = _selectedPropertyData!['landlord'];
        _toController.text = (landlord != null && landlord['email'] != null) ? landlord['email'] : '';
      } else if (_selectedRecipientType == 'Tenant') {
        final tenants = _selectedPropertyData!['tenants'] as List<dynamic>?;
        if (tenants != null && tenants.isNotEmpty) {
           _toController.text = tenants.first['email'] ?? '';
        } else {
           _toController.text = '';
        }
      }
    });
  }
  
  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.pickFiles(withData: true);
    if (result != null) {
      setState(() {
        _fileBytes = result.files.single.bytes;
        _localFilePath = result.files.single.path;
        _localFileName = result.files.single.name;
      });
    }
  }


  Future<void> _loadCommunications(int propertyId) async {
    setState(() => _isLoading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final msgs = propertyId == -1 
          ? await api.fetchUnassignedCommunications() 
          : await api.fetchPropertyCommunications(propertyId);
      setState(() {
        _messages = msgs;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load messages: $e')));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCommunicationsSilently(int propertyId) async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final msgs = propertyId == -1 
          ? await api.fetchUnassignedCommunications() 
          : await api.fetchPropertyCommunications(propertyId);
      if (mounted) {
        setState(() {
          _messages = msgs;
        });
      }
    } catch (e) {
      // ignore silently
    }
  }

  Future<void> _sendCommunication() async {
    if (_toController.text.isEmpty || _subjectController.text.isEmpty) return;
    if (_includeAttachment && _attachmentSource == 'System Report' && _selectedSystemReport == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a system report type.')));
      return;
    }

    
    setState(() => _isLoading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      
      final data = {
        'property_id': _selectedPropertyId,
        'tenant_id': _selectedPropertyData?['tenant_id'],
        'landlord_id': _selectedPropertyData?['landlord_id'],
        'type': 'email',
        'subject': _subjectController.text,
        'body_text': _bodyController.text,
        'recipient_address': _toController.text,
        'status': 'sent'
      };

      if (_includeAttachment) {
         await api.sendCommunicationWithAttachment(
           data: data,
           fileBytes: _attachmentSource == 'Local File' ? _fileBytes : null,
           fileName: _attachmentSource == 'Local File' ? _localFileName : null,
           localFilePath: _attachmentSource == 'Local File' ? _localFilePath : null,
           systemReportType: _attachmentSource == 'System Report' ? _selectedSystemReport : null,
         );
      } else {
         await api.sendCommunication(data);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message sent successfully!')));
        _toController.clear();
        _bodyController.clear();
        _prefillFields(); // Re-populate subject
        if (_selectedPropertyId != null) _loadCommunications(_selectedPropertyId!);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF202124),
          foregroundColor: Colors.white,
        ),
        cardColor: const Color(0xFF202124),
        dividerColor: const Color(0xFF303134),
        colorScheme: const ColorScheme.dark(
          primary: Colors.blueAccent,
          surface: Color(0xFF202124),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Property Communication Centre'),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.blueAccent,
            labelColor: Colors.blueAccent,
            unselectedLabelColor: Colors.white54,
            tabs: const [
              Tab(text: 'Compose'),
              Tab(text: 'Inbox (Received)'),
              Tab(text: 'Sent'),
            ],
          ),
        ),
        body: Row(
          children: [
            // Left Sidebar for Property Selection
            if (widget.initialPropertyId == null) ...[
              Container(
                width: 300,
                color: const Color(0xFF202124),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Select Property', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _propertiesList.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return ListTile(
                              selected: _selectedPropertyId == -1,
                              selectedTileColor: Colors.blueAccent.withOpacity(0.15),
                              leading: const Icon(Icons.inbox, color: Colors.white70),
                              title: const Text('Global Inbox', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                              subtitle: const Text('Unassigned emails', style: TextStyle(color: Colors.white54)),
                              onTap: () {
                                setState(() {
                                  _selectedPropertyId = -1;
                                  _selectedPropertyData = null;
                                });
                                _toController.clear();
                                _subjectController.clear();
                                _loadCommunications(-1);
                              },
                            );
                          }
                          final p = _propertiesList[index - 1];
                          final isSelected = p['id'] == _selectedPropertyId;
                          return ListTile(
                            selected: isSelected,
                            selectedTileColor: Colors.blueAccent.withOpacity(0.15),
                            leading: Icon(Icons.home, color: isSelected ? Colors.blueAccent : Colors.white70),
                            title: Text(p['address_line_1'] ?? 'Unknown', style: TextStyle(color: isSelected ? Colors.blueAccent : Colors.white)),
                            subtitle: Text(p['postcode'] ?? '', style: const TextStyle(color: Colors.white54)),
                            onTap: () {
                              setState(() {
                                _selectedPropertyId = p['id'];
                                _selectedPropertyData = p;
                              });
                              _prefillFields();
                              _loadCommunications(p['id']);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1, color: Color(0xFF303134)),
            ],
            // Main Content Area
            Expanded(
              child: Container(
                color: const Color(0xFF121212),
                child: _isLoading && _selectedPropertyId != null
                    ? const Center(child: CircularProgressIndicator())
                    : _selectedPropertyId == null
                        ? const Center(child: Text('Please select a property from the left panel to view communications.', style: TextStyle(color: Colors.white54)))
                        : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildComposeTab(),
                          _buildMessagesTab(direction: 'inbound'),
                          _buildMessagesTab(direction: 'outbound'),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposeTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('New Message', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (_selectedPropertyData != null) ...[
            const Text('Select Recipient:', style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: ['Custom', 'Landlord', 'Tenant'].map((type) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Radio<String>(
                      value: type,
                      groupValue: _selectedRecipientType,
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedRecipientType = val);
                          _updateToField();
                        }
                      },
                    ),
                    Text(type),
                    const SizedBox(width: 16),
                  ],
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _toController,
            decoration: const InputDecoration(labelText: 'To (Email Address)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _subjectController,
            decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          
          // Attachment Options
          Row(
            children: [
              Switch(
                value: _includeAttachment,
                onChanged: (val) => setState(() => _includeAttachment = val),
              ),
              const Text('Include Attachment', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          if (_includeAttachment) ...[
            Row(
              children: ['Local File', 'System Report'].map((type) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Radio<String>(
                      value: type,
                      groupValue: _attachmentSource,
                      onChanged: (val) {
                        if (val != null) setState(() => _attachmentSource = val);
                      },
                    ),
                    Text(type),
                    const SizedBox(width: 16),
                  ],
                );
              }).toList(),
            ),
            if (_attachmentSource == 'Local File')
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Choose File'),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Text(_localFileName ?? 'No file selected', style: const TextStyle(color: Colors.grey))),
                ],
              ),
            if (_attachmentSource == 'System Report')
              DropdownButtonFormField<String>(
                value: _selectedSystemReport,
                decoration: const InputDecoration(labelText: 'Select System Report', border: OutlineInputBorder()),
                items: ['Tenant Invoice', 'Landlord Invoice', 'Landlord Statement', 'Agent Statement'].map((rep) {
                  return DropdownMenuItem(value: rep, child: Text(rep));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedSystemReport = val);
                },
              ),
            const SizedBox(height: 16),
          ],
          
          Expanded(
            child: TextField(
              controller: _bodyController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(labelText: 'Message Body', border: OutlineInputBorder(), alignLabelWithHint: true),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _sendCommunication,
              icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
              label: const Text('Send Message'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesTab({required String direction}) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    
    final filtered = _messages.where((m) => m['direction'] == direction).toList();
    
    if (filtered.isEmpty) {
      return Center(child: Text('No $direction messages found for this view.', style: const TextStyle(color: Colors.white70)));
    }
    
    return Container(
      color: const Color(0xFF202124),
      child: ListView.separated(
        itemCount: filtered.length,
        separatorBuilder: (context, index) => const Divider(height: 1, thickness: 1, color: Color(0xFF303134)),
        itemBuilder: (context, index) {
          final msg = filtered[index];
          String dateStr = '';
          if (msg['sent_at'] != null) {
            final DateTime parsedDate = DateTime.parse(msg['sent_at']).toLocal();
            final now = DateTime.now();
            final isToday = parsedDate.year == now.year && parsedDate.month == now.month && parsedDate.day == now.day;
            dateStr = isToday ? DateFormat('h:mm a').format(parsedDate) : DateFormat('MMM dd').format(parsedDate);
          }
          
          final isRead = msg['is_read'] ?? true;
          final fontWeight = isRead ? FontWeight.normal : FontWeight.bold;
          final primaryTextColor = isRead ? Colors.white70 : Colors.white;
          
          String snippet = msg['body_text'] ?? '';
          snippet = snippet.replaceAll(RegExp(r'\n+'), ' ').trim();
          if (snippet.length > 80) snippet = '${snippet.substring(0, 80)}...';

          String senderName = direction == 'inbound' ? (msg['sender_address'] ?? 'Unknown') : (msg['recipient_address'] ?? 'Unknown');
          if (senderName.contains('@')) {
             senderName = senderName.split('@')[0];
          }

          return Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent, 
              unselectedWidgetColor: Colors.white54,
              colorScheme: const ColorScheme.dark(),
            ),
            child: ExpansionTile(
              backgroundColor: isRead ? const Color(0xFF202124) : const Color(0xFF303134),
              collapsedBackgroundColor: isRead ? const Color(0xFF202124) : const Color(0xFF303134),
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              onExpansionChanged: (expanded) {
                if (expanded && !isRead) {
                   final api = Provider.of<ApiService>(context, listen: false);
                   api.markCommunicationRead(msg['id']).then((_) {
                      if (mounted) {
                        setState(() { msg['is_read'] = true; });
                      }
                   });
                }
              },
              title: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2.0),
                    child: Icon(Icons.check_box_outline_blank, color: Colors.white54, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Padding(
                    padding: EdgeInsets.only(top: 2.0),
                    child: Icon(Icons.star_border, color: Colors.white54, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2, 
                    child: Text(
                      senderName, 
                      style: TextStyle(fontWeight: fontWeight, fontSize: 14, color: primaryTextColor), 
                      overflow: TextOverflow.ellipsis
                    )
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 6, 
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: TextStyle(color: primaryTextColor, fontSize: 14),
                            children: [
                              TextSpan(text: msg['subject'] ?? 'No Subject', style: TextStyle(fontWeight: fontWeight, color: primaryTextColor)),
                              const TextSpan(text: ' - ', style: TextStyle(color: Colors.white38)),
                              TextSpan(text: snippet, style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.normal)),
                            ]
                          )
                        ),
                        if (msg['attachments'] != null && (msg['attachments'] as List).isNotEmpty)
                           Padding(
                             padding: const EdgeInsets.only(top: 8.0),
                             child: Wrap(
                               spacing: 8,
                               children: (msg['attachments'] as List).map<Widget>((att) {
                                  return Container(
                                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                     decoration: BoxDecoration(
                                       border: Border.all(color: Colors.white24),
                                       borderRadius: BorderRadius.circular(16),
                                       color: Colors.transparent,
                                     ),
                                     child: Row(
                                       mainAxisSize: MainAxisSize.min,
                                       children: [
                                         const Icon(Icons.image, size: 14, color: Colors.redAccent),
                                         const SizedBox(width: 4),
                                         Flexible(child: Text(att['file_name'] ?? 'Attachment', style: const TextStyle(fontSize: 12, color: Colors.white70), overflow: TextOverflow.ellipsis, maxLines: 1))
                                       ]
                                     )
                                  );
                               }).toList()
                             )
                           )
                      ]
                    )
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 70,
                    child: Text(dateStr, textAlign: TextAlign.right, style: TextStyle(fontWeight: fontWeight, color: isRead ? Colors.white54 : Colors.white, fontSize: 12))
                  ),
                ],
              ),
              children: [
                Container(
                  color: const Color(0xFF202124),
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(backgroundColor: Colors.blueGrey.shade800, child: Text((msg['sender_address'] ?? '?')[0].toUpperCase(), style: const TextStyle(color: Colors.white))),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(msg['sender_address'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                  const Text('to me', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                          Text(dateStr, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (_selectedPropertyId == -1) ...[
                        Row(
                          children: [
                            const Text('Link to Property: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Theme(
                                data: Theme.of(context).copyWith(canvasColor: const Color(0xFF303134)),
                                child: DropdownButtonFormField<int>(
                                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24))),
                                  style: const TextStyle(color: Colors.white),
                                  items: _propertiesList.map<DropdownMenuItem<int>>((p) {
                                    return DropdownMenuItem<int>(value: p['id'], child: Text("${p['address_line_1']}, ${p['postcode']}"));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                       Provider.of<ApiService>(context, listen: false).linkCommunicationProperty(msg['id'], val).then((_) {
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Property linked successfully!')));
                                          _loadCommunications(-1);
                                       });
                                    }
                                  }
                                )
                              )
                            )
                          ]
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: Colors.white24),
                      ],
                      DefaultTextStyle(
                        style: const TextStyle(color: Colors.white70),
                        child: msg['body_html'] != null && msg['body_html'].isNotEmpty
                            ? Html(
                                data: msg['body_html'],
                                style: {
                                  "body": Style(color: Colors.white70),
                                  "a": Style(color: Colors.blueAccent),
                                },
                              )
                            : SelectableText(msg['body_text'] ?? 'Empty Message'),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              _toController.text = msg['sender_address'] ?? '';
                              String propSubj = _getPrefilledSubject();
                              String origSubj = msg['subject'] ?? '';
                              String newSubj = origSubj;
                              if (propSubj.isNotEmpty && !origSubj.contains(propSubj)) {
                                newSubj = '$propSubj | $origSubj';
                              }
                              _subjectController.text = newSubj.startsWith('Re:') ? newSubj : 'Re: $newSubj';
                              _bodyController.text = '\n\n--- Original Message ---\n${msg['body_text'] ?? ''}';
                              _tabController.animateTo(0);
                            },
                            icon: const Icon(Icons.reply, size: 16),
                            label: const Text('Reply'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white24),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () {
                              _toController.text = '';
                              String propSubj = _getPrefilledSubject();
                              String origSubj = msg['subject'] ?? '';
                              String newSubj = origSubj;
                              if (propSubj.isNotEmpty && !origSubj.contains(propSubj)) {
                                newSubj = '$propSubj | $origSubj';
                              }
                              _subjectController.text = newSubj.startsWith('Fwd:') ? newSubj : 'Fwd: $newSubj';
                              _bodyController.text = '\n\n--- Forwarded Message ---\nFrom: ${msg['sender_address']}\nDate: $dateStr\nSubject: ${msg['subject']}\n\n${msg['body_text'] ?? ''}';
                              _tabController.animateTo(0);
                            },
                            icon: const Icon(Icons.forward, size: 16),
                            label: const Text('Forward'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white24),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                            ),
                          ),
                        ],
                      )
                    ]
                  ),
                ),
              ],
            ),
          );
        },
      )
    );
  }
}
