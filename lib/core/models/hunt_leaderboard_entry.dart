class HuntLeaderboardEntry {
  final String   userId;
  final String   username;
  final String?  avatarUrl;
  final int      finishRank;
  final int      pointsEarned;
  final DateTime validatedAt;

  const HuntLeaderboardEntry({
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.finishRank,
    required this.pointsEarned,
    required this.validatedAt,
  });

  factory HuntLeaderboardEntry.fromMap(Map<String, dynamic> m) =>
      HuntLeaderboardEntry(
        userId:       m['user_id']       as String,
        username:     (m['username']     as String?) ?? 'Aventurero',
        avatarUrl:    m['avatar_url']    as String?,
        finishRank:   (m['finish_rank']  as num).toInt(),
        pointsEarned: (m['points_earned'] as num).toInt(),
        validatedAt:  DateTime.parse(m['validated_at'] as String),
      );
}
