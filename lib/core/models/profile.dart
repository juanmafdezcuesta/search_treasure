class Profile {
  final String id;
  final String username;
  final String? avatarUrl;
  final String? originRegion;
  final int xp;
  final bool isAdmin;
  final num walletBalance;

  const Profile({
    required this.id,
    required this.username,
    required this.avatarUrl,
    required this.originRegion,
    required this.xp,
    required this.isAdmin,
    required this.walletBalance,
  });

  int get level => (xp ~/ 1000) + 1;
  int get xpInCurrentLevel => xp % 1000;
  int get xpForNextLevel => 1000;

  factory Profile.fromMap(Map<String, dynamic> m) {
    return Profile(
      id: m['id'] as String,
      username: (m['username'] as String?) ?? 'Jugador',
      avatarUrl: m['avatar_url'] as String?,
      originRegion: m['origin_region'] as String?,
      xp: (m['xp'] as num?)?.toInt() ?? 0,
      isAdmin: (m['is_admin'] as bool?) ?? false,
      walletBalance: (m['wallet_balance'] as num?) ?? 0,
    );
  }
}

