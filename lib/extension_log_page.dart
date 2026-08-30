import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preference_app_group/shared_preference_app_group.dart';

class ExtensionLogPage extends StatefulWidget {
  const ExtensionLogPage({super.key});

  @override
  State<ExtensionLogPage> createState() => _ExtensionLogPageState();
}

class _ExtensionLogPageState extends State<ExtensionLogPage> {
  List<String> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final logsString = await SharedPreferenceAppGroup.getString('extension_logs');
      if (logsString != null && logsString.isNotEmpty) {
        final List<dynamic> parsed = jsonDecode(logsString);
        setState(() {
          _logs = parsed.map((e) => e.toString()).toList();
        });
      } else {
        setState(() {
          _logs = [];
        });
      }
    } catch (e) {
      debugPrint('Error loading logs: $e');
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('分享扩展日志'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await SharedPreferenceAppGroup.remove('extension_logs');
              _loadLogs();
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const Center(child: Text('暂无日志', style: TextStyle(color: Colors.white54)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        _logs[index],
                        style: const TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 12,
                          color: Colors.greenAccent,
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
