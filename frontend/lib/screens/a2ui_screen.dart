import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/api_service.dart';

class A2UIScreen extends StatefulWidget {
  const A2UIScreen({super.key});

  @override
  State<A2UIScreen> createState() => _A2UIScreenState();
}

class _A2UIScreenState extends State<A2UIScreen> {
  final TextEditingController _commandController = TextEditingController();
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _agentResponse = 'Hello! I am your AI assistant. You can speak commands or upload invoices.';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => print('onStatus: $val'),
        onError: (val) => print('onError: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _commandController.text = val.recognizedWords;
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      _sendCommand();
    }
  }

  Future<void> _sendCommand() async {
    if (_commandController.text.isEmpty) return;
    
    setState(() {
      _isLoading = true;
      _agentResponse = 'Processing command...';
    });

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final result = await api.sendVoiceCommand(_commandController.text);
      
      setState(() {
        _agentResponse = 'Intent Detected: ${result['parsed_action']['intent']}\nDetails: ${result['parsed_action']['entities']}\n\nAction Taken: ${result['action_taken']}';
      });
      _commandController.clear();
    } catch (e) {
      setState(() {
        _agentResponse = 'Error communicating with Agent: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _uploadInvoice() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _isLoading = true;
        _agentResponse = 'Analyzing invoice with Gemini Vision...';
      });

      try {
        final api = Provider.of<ApiService>(context, listen: false);
        final response = await api.sendInvoiceImage(
          bytes,
          image.name,
        );
        
        setState(() {
          _agentResponse = 'Extracted Data:\n${response['extracted_data']}';
        });
      } catch (e) {
        setState(() {
          _agentResponse = 'Error analyzing image: $e';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _uploadBankStatement() async {
    const XTypeGroup csvTypeGroup = XTypeGroup(
      label: 'CSV',
      extensions: <String>['csv'],
    );
    final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[csvTypeGroup]);

    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() {
        _isLoading = true;
        _agentResponse = 'Reconciling bank statement with Gemini...';
      });

      try {
        final api = Provider.of<ApiService>(context, listen: false);
        final response = await api.sendBankStatementCsv(
          bytes,
          file.name,
        );
        
        setState(() {
          _agentResponse = 'Reconciliation Report:\n\n${response['reconciliation_report']}';
        });
      } catch (e) {
        setState(() {
          _agentResponse = 'Error analyzing bank statement: $e';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agentic Command Center'),
        backgroundColor: Colors.purple.shade900,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _agentResponse,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                ),
              ),
            ),
            if (_isLoading) const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commandController,
                    decoration: const InputDecoration(
                      hintText: 'Type or speak a command...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendCommand(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.purple),
                  onPressed: _sendCommand,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              alignment: WrapAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _listen,
                  icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                  label: Text(_isListening ? 'Listening...' : 'Voice'),
                ),
                ElevatedButton.icon(
                  onPressed: _uploadInvoice,
                  icon: const Icon(Icons.document_scanner),
                  label: const Text('Scan Invoice'),
                ),
                ElevatedButton.icon(
                  onPressed: _uploadBankStatement,
                  icon: const Icon(Icons.account_balance),
                  label: const Text('Auto-Allocate CSV'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
