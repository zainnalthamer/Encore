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
  final String discoverySource;
  final String discoveryContext;

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
    this.discoverySource = 'unknown',
    this.discoveryContext = '',
  });

  OnboardingMediaItem copyWith({
  String? id,
  String? title,
  String? domain,
  List<String>? genres,
  List<String>? tags,
  String? imageUrl,
  String? source,
  String? description,
  double? apiRating,
  String? discoverySource,
  String? discoveryContext,
}) {
  return OnboardingMediaItem(
    id: id ?? this.id,
    title: title ?? this.title,
    domain: domain ?? this.domain,
    genres: genres ?? this.genres,
    tags: tags ?? this.tags,
    imageUrl: imageUrl ?? this.imageUrl,
    source: source ?? this.source,
    description: description ?? this.description,
    apiRating: apiRating ?? this.apiRating,
    discoverySource: discoverySource ?? this.discoverySource,
    discoveryContext: discoveryContext ?? this.discoveryContext,
  );
}
}