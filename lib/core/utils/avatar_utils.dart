String buildDefaultAvatarUrl(String seed) {
  final safeSeed = Uri.encodeComponent(seed.trim().isEmpty ? 'encore' : seed);

  return 'https://api.dicebear.com/9.x/identicon/svg'
      '?seed=$safeSeed'
      '&size=128'
      '&radius=50'
      '&backgroundColor=1f2937,111827,0f172a';
}