
class ShareDetails {
  final String? text;
  final String? url;
  final String? sourceApp;

  ShareDetails({this.text, this.url, this.sourceApp});

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'url': url,
      'sourceApp': sourceApp,
    };
  }

  factory ShareDetails.fromMap(Map<String, dynamic> map) {
    return ShareDetails(
      text: map['text'],
      url: map['url'],
      sourceApp: map['sourceApp'],
    );
  }
}
