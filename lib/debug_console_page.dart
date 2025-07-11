import 'package:flutter/material.dart';

class DebugConsolePage extends StatefulWidget {
  @override
  _DebugConsolePageState createState() => _DebugConsolePageState();
}

class _DebugConsolePageState extends State<DebugConsolePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('调试控制台')),
      body: ListView.builder(
        itemCount: DebugConsoleLog.logs.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: SelectableText(
              DebugConsoleLog.logs[index],
              style: TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.delete),
        tooltip: '清空日志',
        onPressed: () {
          setState(() {
            DebugConsoleLog.clear();
          });
        },
      ),
    );
  }
}

class DebugConsoleLog {
  static final List<String> logs = [];
  static void log(String msg) {
    logs.add(msg);
    if (logs.length > 200) logs.removeAt(0);
  }

  static void clear() => logs.clear();
}
