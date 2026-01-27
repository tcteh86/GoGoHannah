class RagDebugResult {
  final bool enabled;
  final String query;
  final String? childName;
  final List<String> results;
  final String? message;

  RagDebugResult({
    required this.enabled,
    required this.query,
    required this.childName,
    required this.results,
    required this.message,
  });

  factory RagDebugResult.fromJson(Map<String, dynamic> json) {
    final resultsValue = json['results'];
    return RagDebugResult(
      enabled: json['enabled'] == true,
      query: json['query']?.toString() ?? '',
      childName: json['child_name']?.toString(),
      results: resultsValue is List
          ? resultsValue.map((item) => item.toString()).toList()
          : const [],
      message: json['message']?.toString(),
    );
  }
}
