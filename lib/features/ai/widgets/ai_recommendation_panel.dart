import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/ai_recommendation_service.dart';
import '../models/recommendation_item.dart';
import '../../../core/models/onboarding_media_item.dart';
import '../../../features/items/screens/item_details_screen.dart';
import '../../../core/services/media_lookup_service.dart';

class AiRecommendationPanel extends StatefulWidget {
  const AiRecommendationPanel({super.key});

  @override
  State<AiRecommendationPanel> createState() => _AiRecommendationPanelState();
}

class _AiRecommendationPanelState extends State<AiRecommendationPanel> {
  final TextEditingController _promptController = TextEditingController();
  final AiRecommendationService _service = AiRecommendationService();
  final MediaLookupService _mediaLookupService = MediaLookupService();

  String _selectedCategory = 'movie';
  bool _isLoading = false;
  bool _hideQuickPrompts = false;
  String? _error;
  List<RecommendationItem> _items = [];

  final List<String> _categories = ['movie', 'show', 'book', 'game'];

  Future<void> _submit() async {
    final prompt = _promptController.text.trim();

    if (prompt.isEmpty) {
      setState(() {
        _error = 'Write what you want first.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _items = [];
    });

    try {
      final items = await _service.getRecommendations(
        prompt: prompt,
        category: _selectedCategory,
      );

      if (!mounted) return;

      setState(() {
        _items = items;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Color _accentForCategory(String category) {
    switch (category) {
      case 'movie':
        return const Color(0xFFFF9E57);
      case 'show':
        return const Color(0xFF86AFFF);
      case 'book':
        return const Color(0xFFF0C46A);
      case 'game':
        return const Color(0xFF63D8AE);
      default:
        return const Color(0xFFFF9E57);
    }
  }

  IconData _iconForCategory(String category) {
    switch (category) {
      case 'movie':
        return Icons.local_movies_outlined;
      case 'show':
        return Icons.tv_outlined;
      case 'book':
        return Icons.menu_book_outlined;
      case 'game':
        return Icons.sports_esports_outlined;
      default:
        return Icons.tune_rounded;
    }
  }

  String _labelForCategory(String category) {
    switch (category) {
      case 'movie':
        return 'Movies';
      case 'show':
        return 'Shows';
      case 'book':
        return 'Books';
      case 'game':
        return 'Games';
      default:
        return category;
    }
  }

  List<String> get _quickPrompts {
    switch (_selectedCategory) {
      case 'movie':
        return const [
          'dark sci-fi with emotional depth',
          'psychological thriller with twists',
          'beautiful romance that feels melancholic',
        ];
      case 'show':
        return const [
          'slow-burn mystery series',
          'smart dystopian drama',
          'something like Dark or Severance',
        ];
      case 'book':
        return const [
          'literary novel that feels unsettling',
          'fantasy with politics',
          'beautiful emotional fiction',
        ];
      case 'game':
        return const [
          'story-driven game with choices',
          'dark atmospheric action game',
          'something like Life is Strange',
        ];
      default:
        return const [];
    }
  }

  String _domainFromRecommendation(RecommendationItem item) {
    final type = item.type.toLowerCase().trim();

    if (type.contains('movie')) return 'movies';
    if (type.contains('show') || type.contains('tv')) return 'shows';
    if (type.contains('book')) return 'books';
    if (type.contains('game')) return 'games';

    switch (_selectedCategory) {
      case 'movie':
        return 'movies';
      case 'show':
        return 'shows';
      case 'book':
        return 'books';
      case 'game':
        return 'games';
      default:
        return 'movies';
    }
  }

  OnboardingMediaItem _recommendationToMediaItem(RecommendationItem item) {
    final domain = _domainFromRecommendation(item);

    return OnboardingMediaItem(
      id: 'ai_${domain}_${item.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}',
      title: item.title,
      domain: domain,
      genres: const [],
      tags: const ['AI recommendation'],
      imageUrl: '',
      source: 'ai',
      description: item.reason,
      apiRating: item.matchScore > 0 ? item.matchScore / 20 : 0,
    );
  }

  Future<void> _openRecommendation(RecommendationItem item) async {
    final mediaItem = await _resolveRecommendationToMediaItem(item);

    if (!mounted) return;

    Navigator.of(context).pop();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ItemDetailsScreen(item: mediaItem),
      ),
    );
  }

  Future<OnboardingMediaItem> _resolveRecommendationToMediaItem(
    RecommendationItem item,
  ) async {
    final domain = _domainFromRecommendation(item);

    try {
      if (domain == 'movies') {
        return await _mediaLookupService.searchMovieByTitle(item.title);
      }

      if (domain == 'shows') {
        return await _mediaLookupService.searchShowByTitle(item.title);
      }

      if (domain == 'books') {
        return await _mediaLookupService.searchBookByTitle(item.title);
      }

      if (domain == 'games') {
        return await _mediaLookupService.searchGameByTitle(item.title);
      }
    } catch (_) {}

    return OnboardingMediaItem(
      id: 'ai_${domain}_${item.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}',
      title: item.title,
      domain: domain,
      genres: const [],
      tags: const ['AI recommendation'],
      imageUrl: '',
      source: 'ai',
      description: item.reason,
      apiRating: item.matchScore > 0 ? item.matchScore / 20 : 0,
    );
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentForCategory(_selectedCategory);

    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.centerRight,
        child: SafeArea(
          child: Container(
            width: 440,
            margin: const EdgeInsets.all(16),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: const Color(0xFF09090C).withOpacity(0.94),
              border: Border.all(
                color: Colors.white.withOpacity(0.05),
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -50,
                  right: -40,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withOpacity(0.10),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      color: Colors.black.withOpacity(0.12),
                    ),
                  ),
                ),
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 14, 10),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: Colors.white.withOpacity(0.08),
                            ),
                            child: const Icon(
                              Icons.grid_view_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Encore AI',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Find something that fits',
                                  style: GoogleFonts.inter(
                                    color: Colors.white.withOpacity(0.55),
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),
                                  Text(
                                    'Choose a category, then describe the mood, themes, pacing, or similar titles you have in mind.',
                                    style: GoogleFonts.inter(
                                      color: Colors.white.withOpacity(0.62),
                                      fontSize: 14,
                                      height: 1.55,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: _categories.map((category) {
                                      final selected =
                                          category == _selectedCategory;

                                      return InkWell(
                                        onTap: () {
                                          setState(() {
                                            _selectedCategory = category;
                                            _error = null;
                                            _hideQuickPrompts = false;
                                          });
                                        },
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 160),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            color: selected
                                                ? Colors.white.withOpacity(0.10)
                                                : Colors.white.withOpacity(0.04),
                                            border: Border.all(
                                              color: selected
                                                  ? _accentForCategory(category)
                                                      .withOpacity(0.45)
                                                  : Colors.white
                                                      .withOpacity(0.06),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                _iconForCategory(category),
                                                size: 16,
                                                color: selected
                                                    ? _accentForCategory(
                                                        category,
                                                      )
                                                    : Colors.white70,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                _labelForCategory(category),
                                                style: GoogleFonts.inter(
                                                  color: selected
                                                      ? Colors.white
                                                      : Colors.white70,
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: TextField(
                                controller: _promptController,
                                minLines: 4,
                                maxLines: 6,
                                cursorColor: Colors.white,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w500,
                                  height: 1.55,
                                ),
                                decoration: InputDecoration(
                                  hintText:
                                      'Example: I want a dark emotional sci-fi movie with beautiful visuals and a lonely atmosphere.',
                                  hintStyle: GoogleFonts.inter(
                                    color: Colors.white38,
                                    fontSize: 14,
                                    height: 1.55,
                                  ),
                                  filled: true,
                                  fillColor: Colors.black.withOpacity(0.16),
                                  contentPadding: const EdgeInsets.all(18),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.05),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: BorderSide(
                                      color: accent.withOpacity(0.55),
                                      width: 1.1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (!_hideQuickPrompts) ...[
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: _quickPrompts.map((prompt) {
                                  return InkWell(
                                    onTap: () {
                                      setState(() {
                                        _promptController.text = prompt;
                                        _error = null;
                                        _hideQuickPrompts = true;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(999),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.045),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        prompt,
                                        style: GoogleFonts.inter(
                                          color: Colors.white70,
                                          fontSize: 12.8,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  elevation: 0,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (_isLoading)
                                      const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Colors.black,
                                        ),
                                      )
                                    else
                                      const Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 18,
                                      ),
                                    const SizedBox(width: 10),
                                    Text(
                                      _isLoading
                                          ? 'Loading...'
                                          : 'Get recommendations',
                                      style: GoogleFonts.inter(
                                        color: Colors.black,
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 14),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF4D67)
                                      .withOpacity(0.10),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(top: 1),
                                      child: Icon(
                                        Icons.error_outline_rounded,
                                        color: Color(0xFFFF8A9B),
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _error!,
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFFFFC3CC),
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w500,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            if (_items.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 28,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.035),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 58,
                                      height: 58,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(18),
                                        color: Colors.white.withOpacity(0.06),
                                      ),
                                      child: const Icon(
                                        Icons.explore_outlined,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      'No recommendations yet',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Results will appear here after you search.',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        color: Colors.white.withOpacity(0.60),
                                        fontSize: 13.5,
                                        height: 1.55,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _items.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final item = _items[index];
                                  final itemAccent = _accentForCategory(
                                    item.type.toLowerCase(),
                                  );

                                  return GestureDetector(
                                    onTap: () => _openRecommendation(item),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.045),
                                        borderRadius: BorderRadius.circular(22),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.06),
                                        ),
                                      ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                color:
                                                    itemAccent.withOpacity(0.14),
                                              ),
                                              child: Icon(
                                                _iconForCategory(
                                                  item.type.toLowerCase(),
                                                ),
                                                color: itemAccent,
                                                size: 18,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                item.title,
                                                style: GoogleFonts.inter(
                                                  color: Colors.white,
                                                  fontSize: 15.5,
                                                  fontWeight: FontWeight.w700,
                                                  height: 1.2,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 11,
                                                vertical: 7,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                '${item.matchScore}%',
                                                style: GoogleFonts.inter(
                                                  color: Colors.black,
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 7,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(0.05),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            _labelForCategory(
                                              item.type.toLowerCase(),
                                            ),
                                            style: GoogleFonts.inter(
                                              color: Colors.white70,
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          item.reason,
                                          style: GoogleFonts.inter(
                                            color:
                                                Colors.white.withOpacity(0.78),
                                            fontSize: 14,
                                            height: 1.6,
                                          ),
                                        ),
                                      ],
                                    ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}