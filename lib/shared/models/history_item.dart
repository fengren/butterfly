
import 'dart:convert';

import 'package:butterfly/shared/models/history_type.dart';
import 'package:butterfly/shared/models/share_details.dart';

class HistoryItem {
  final int? id;
  final HistoryType type;
  final DateTime creationDate;
  final String content; // For recording: file path. For share: the main text/content.
  final ShareDetails? shareDetails; // Nullable, only for share type

  HistoryItem({
    this.id,
    required this.type,
    required this.creationDate,
    required this.content,
    this.shareDetails,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.index, // Store enum as integer
      'creationDate': creationDate.toIso8601String(),
      'content': content,
      'shareDetails': shareDetails != null ? jsonEncode(shareDetails!.toMap()) : null,
    };
  }

  factory HistoryItem.fromMap(Map<String, dynamic> map) {
    return HistoryItem(
      id: map['id'],
      type: HistoryType.values[map['type']],
      creationDate: DateTime.parse(map['creationDate']),
      content: map['content'],
      shareDetails: map['shareDetails'] != null
          ? ShareDetails.fromMap(jsonDecode(map['shareDetails']))
          : null,
    );
  }
}
