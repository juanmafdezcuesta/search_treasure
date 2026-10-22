class Hunt {
  final String id;
  final String title;
  final String? description;
  final String difficulty;
  final String? rewardInfo;
  final String? region;
  final String status;
  final double avgRating;
  final int ratingCount;
  final bool isSpecial;

  const Hunt({
    required this.id,
    required this.title,
    required this.description,
    required this.difficulty,
    required this.rewardInfo,
    required this.region,
    required this.status,
    required this.avgRating,
    required this.ratingCount,
    this.isSpecial = false,
  });

  factory Hunt.fromMap(Map<String, dynamic> m) {
    return Hunt(
      id: m['id'] as String,
      title: (m['title'] as String?) ?? 'Tesoro',
      description: m['description'] as String?,
      difficulty: (m['difficulty'] as String?) ?? 'medium',
      rewardInfo: m['reward_info'] as String?,
      region: m['region'] as String?,
      status: (m['status'] as String?) ?? 'active',
      avgRating: (m['avg_rating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: (m['rating_count'] as num?)?.toInt() ?? 0,
      isSpecial: (m['is_special'] as bool?) ?? false,
    );
  }
}