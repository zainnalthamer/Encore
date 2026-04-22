class HomeMediaItem {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final String imageUrl;
  final String type;
  final String source;
  final double score;
  final bool isPlaceholder;

  const HomeMediaItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.imageUrl,
    required this.type,
    required this.source,
    required this.score,
    this.isPlaceholder = false,
  });
}

class HomeFeedBundle {
  final List<HomeMediaItem> popular;
  final List<HomeMediaItem> discover;
  final String becauseYouLikedTitle;
  final List<HomeMediaItem> becauseYouLiked;
  final List<HomeMediaItem> newFromFriends;

  const HomeFeedBundle({
    required this.popular,
    required this.discover,
    required this.becauseYouLikedTitle,
    required this.becauseYouLiked,
    required this.newFromFriends,
  });
}