class OnboardingMediaItem {
  final String id;
  final String title;
  final String domain;
  final List<String> genres;
  final List<String> tags;
  final String imageUrl;
  final String source;
  final String description;
  final double apiRating;

  const OnboardingMediaItem({
    required this.id,
    required this.title,
    required this.domain,
    required this.genres,
    required this.tags,
    required this.imageUrl,
    required this.source,
    this.description = '',
    this.apiRating = 0,
  });
}