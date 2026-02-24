class VocabImageHint {
  final bool imageHintEnabled;
  final String? imageHintReason;
  final String? imageUrl;

  VocabImageHint({
    required this.imageHintEnabled,
    this.imageHintReason,
    this.imageUrl,
  });

  factory VocabImageHint.fromJson(Map<String, dynamic> json) {
    return VocabImageHint(
      imageHintEnabled: json['image_hint_enabled'] == true,
      imageHintReason: json['image_hint_reason']?.toString(),
      imageUrl: json['image_url']?.toString(),
    );
  }
}
