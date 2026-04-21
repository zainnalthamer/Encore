class RecommendationItem {
  final String title;
  final String type;
  final String reason;
  final int matchScore;

  RecommendationItem({
    required this.title,
    required this.type,
    required this.reason,
    required this.matchScore,
  });

  factory RecommendationItem.fromJson(Map<String, dynamic> json) {
    return RecommendationItem(
      title: json['title']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      matchScore: json['matchScore'] is int
          ? json['matchScore']
          : int.tryParse(json['matchScore']?.toString() ?? '0') ?? 0,
    );
  }
}