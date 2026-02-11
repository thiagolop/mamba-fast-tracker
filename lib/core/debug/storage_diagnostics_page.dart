import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../storage/hive_boxes.dart';

class StorageDiagnosticsPage extends StatelessWidget {
  const StorageDiagnosticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final report = HiveBoxes.diagnosticsReport();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostics'),
        actions: [
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: report));
              if (kDebugMode) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Diagnostics copied')),
                );
              }
            },
            icon: const Icon(Icons.copy),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: SelectableText(
              report,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ),
    );
  }
}
