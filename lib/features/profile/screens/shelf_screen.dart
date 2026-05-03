import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../core/models/onboarding_media_item.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../items/screens/item_details_screen.dart';

const String _tmdbApiKey = 'PUT_YOUR_TMDB_KEY_HERE';
const String _rawgApiKey = 'PUT_YOUR_RAWG_KEY_HERE';

class ShelfScreen extends StatefulWidget {
  final String ownerId;
  final String shelfId;

  const ShelfScreen({
    super.key,
    required this.ownerId,
    required this.shelfId,
  });

  @override
  State<ShelfScreen> createState() => _ShelfScreenState();
}

class _ShelfScreenState extends State<ShelfScreen> {
  final CloudinaryService _cloudinaryService = CloudinaryService();

  DocumentReference<Map<String, dynamic>> get _shelfRef {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(widget.ownerId)
        .collection('shelves')
        .doc(widget.shelfId);
  }

  CollectionReference<Map<String, dynamic>> get _itemsRef {
    return _shelfRef.collection('items');
  }

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  bool _isOwner(Map<String, dynamic> shelf) {
    return _currentUid.isNotEmpty && shelf['ownerId'] == _currentUid;
  }

  bool _isCollaborator(Map<String, dynamic> shelf) {
    final ids = ((shelf['collaboratorIds'] as List?) ?? [])
        .map((e) => e.toString())
        .toList();

    return ids.contains(_currentUid);
  }

  bool _canEdit(Map<String, dynamic> shelf) {
    return _isOwner(shelf) || _isCollaborator(shelf);
  }

  Future<void> _deleteShelf() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (_) => const _ConfirmDialog(
        title: 'Delete shelf?',
        body: 'This will permanently remove the shelf and all items inside it.',
        confirmText: 'Delete',
        destructive: true,
      ),
    );

    if (confirm != true) return;

    final items = await _itemsRef.get();
    final batch = FirebaseFirestore.instance.batch();

    for (final doc in items.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(_shelfRef);
    await batch.commit();

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _leaveShelf() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (_) => const _ConfirmDialog(
        title: 'Leave shelf?',
        body: 'You will no longer be able to add or remove items from this shelf.',
        confirmText: 'Leave',
        destructive: true,
      ),
    );

    if (confirm != true) return;

    await _shelfRef.update({
      'collaboratorIds': FieldValue.arrayRemove([_currentUid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _removeItem(String itemId) async {
    await _itemsRef.doc(itemId).delete();

    await _shelfRef.update({
      'itemIds': FieldValue.arrayRemove([itemId]),
      'itemsCount': FieldValue.increment(-1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _openEditShelfDialog(Map<String, dynamic> shelf) async {
    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.78),
      builder: (_) => _EditShelfDialog(
        shelfRef: _shelfRef,
        cloudinaryService: _cloudinaryService,
        currentName: (shelf['name'] ?? '').toString(),
        currentDescription: (shelf['description'] ?? '').toString(),
        currentImageUrl: (shelf['imageUrl'] ?? '').toString(),
      ),
    );
  }

  Future<void> _openInviteDialog(Map<String, dynamic> shelf) async {
    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.78),
      builder: (_) => _InviteCollaboratorDialog(
        shelfRef: _shelfRef,
        existingCollaboratorIds: ((shelf['collaboratorIds'] as List?) ?? [])
            .map((e) => e.toString())
            .toList(),
        ownerId: (shelf['ownerId'] ?? '').toString(),
      ),
    );
  }

  Future<void> _openAddItemsDialog(Map<String, dynamic> shelf) async {
    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.78),
      builder: (_) => _AddShelfItemsDialog(
        shelfRef: _shelfRef,
        itemsRef: _itemsRef,
        currentUid: _currentUid,
        existingItemIds: ((shelf['itemIds'] as List?) ?? [])
            .map((e) => e.toString())
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050507),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _shelfRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorState(
              title: 'Could not load shelf',
              body: 'Check Firestore rules or shelf data.',
              onBack: () => Navigator.of(context).pop(),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          final shelf = snapshot.data?.data();

          if (shelf == null) {
            return _ErrorState(
              title: 'Shelf not found',
              body: 'It may have been deleted.',
              onBack: () => Navigator.of(context).pop(),
            );
          }

          final name = (shelf['name'] ?? 'Untitled shelf').toString();
          final description = (shelf['description'] ?? '').toString().trim();
          final imageUrl = (shelf['imageUrl'] ?? '').toString().trim();
          final ownerId = (shelf['ownerId'] ?? widget.ownerId).toString();
          final collaboratorIds = ((shelf['collaboratorIds'] as List?) ?? [])
              .map((e) => e.toString())
              .toList();

          final isOwner = _isOwner(shelf);
          final isCollaborator = _isCollaborator(shelf);
          final canEdit = _canEdit(shelf);

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _ShelfHeader(
                      name: name,
                      description: description,
                      imageUrl: imageUrl,
                      ownerId: ownerId,
                      collaboratorIds: collaboratorIds,
                      canEdit: canEdit,
                      isOwner: isOwner,
                      isCollaborator: isCollaborator,
                      onBack: () => Navigator.of(context).pop(),
                      onEdit: canEdit ? () => _openEditShelfDialog(shelf) : null,
                      onInvite: isOwner ? () => _openInviteDialog(shelf) : null,
                      onDelete: isOwner ? _deleteShelf : null,
                      onLeave: isCollaborator && !isOwner ? _leaveShelf : null,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 8, 22, 120),
                      child: _ShelfItemsSection(
                        itemsRef: _itemsRef,
                        canEdit: canEdit,
                        onRemove: _removeItem,
                      ),
                    ),
                  ),
                ],
              ),
              if (canEdit)
                Positioned(
                  right: 22,
                  bottom: 22,
                  child: FloatingActionButton(
                    backgroundColor: const Color(0xFFFF8B3D),
                    foregroundColor: Colors.black,
                    elevation: 12,
                    shape: const CircleBorder(),
                    onPressed: () => _openAddItemsDialog(shelf),
                    child: const Icon(Icons.add_rounded, size: 31),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
class _ShelfHeader extends StatelessWidget {
  final String name;
  final String description;
  final String imageUrl;
  final String ownerId;
  final List<String> collaboratorIds;
  final bool canEdit;
  final bool isOwner;
  final bool isCollaborator;
  final VoidCallback onBack;
  final VoidCallback? onEdit;
  final VoidCallback? onInvite;
  final VoidCallback? onDelete;
  final VoidCallback? onLeave;

  const _ShelfHeader({
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.ownerId,
    required this.collaboratorIds,
    required this.canEdit,
    required this.isOwner,
    required this.isCollaborator,
    required this.onBack,
    this.onEdit,
    this.onInvite,
    this.onDelete,
    this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    final peopleCount = 1 + collaboratorIds.length;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
        child: Column(
          children: [
            Row(
              children: [
                _CircleIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: onBack,
                ),
                const Spacer(),
                if (canEdit)
                  _CircleIconButton(
                    icon: Icons.edit_rounded,
                    onTap: onEdit,
                  ),
                if (isOwner) ...[
                  const SizedBox(width: 10),
                  _CircleIconButton(
                    icon: Icons.person_add_alt_1_rounded,
                    onTap: onInvite,
                  ),
                  const SizedBox(width: 10),
                  _CircleIconButton(
                    icon: Icons.delete_outline_rounded,
                    onTap: onDelete,
                    destructive: true,
                  ),
                ],
                if (isCollaborator && !isOwner) ...[
                  const SizedBox(width: 10),
                  _CircleIconButton(
                    icon: Icons.logout_rounded,
                    onTap: onLeave,
                    destructive: true,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 30),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 136,
                    height: 136,
                    decoration: BoxDecoration(
                      color: const Color(0xFF17171C),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.28),
                          blurRadius: 30,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.high,
                            errorBuilder: (_, __, ___) => _coverFallback(),
                          )
                        : _coverFallback(),
                  ),
                  const SizedBox(width: 22),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SHELF',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFFF8B3D),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.4,
                            height: 0.98,
                          ),
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 11),
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.58),
                              fontSize: 13.5,
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 15),
                        Wrap(
                          spacing: 9,
                          runSpacing: 8,
                          children: [
                            _SoftPill(
                              icon: isOwner
                                  ? Icons.workspace_premium_rounded
                                  : isCollaborator
                                      ? Icons.group_rounded
                                      : Icons.visibility_rounded,
                              text: isOwner
                                  ? 'Owner'
                                  : isCollaborator
                                      ? 'Collaborator'
                                      : 'Viewing',
                            ),
                            _SoftPill(
                              icon: Icons.people_alt_rounded,
                              text: '$peopleCount ${peopleCount == 1 ? 'person' : 'people'}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverFallback() {
    return Container(
      color: const Color(0xFF18181D),
      child: Icon(
        Icons.grid_view_rounded,
        color: Colors.white.withOpacity(0.28),
        size: 42,
      ),
    );
  }
}

class _ShelfItemsSection extends StatelessWidget {
  final CollectionReference<Map<String, dynamic>> itemsRef;
  final bool canEdit;
  final Future<void> Function(String itemId) onRemove;

  const _ShelfItemsSection({
    required this.itemsRef,
    required this.canEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: itemsRef.orderBy('addedAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _ShelfInfoBlock(
            title: 'Could not load items',
            body: 'Check shelf item rules.',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const _ShelfInfoBlock(
            title: 'No items yet',
            body: 'Tap + to search and add movies, shows, books, or games.',
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            final count = width >= 1200
                ? 7
                : width >= 980
                    ? 6
                    : width >= 760
                        ? 5
                        : width >= 540
                            ? 4
                            : 3;

            final itemWidth = (width - ((count - 1) * 14)) / count;
            final itemHeight = itemWidth / 0.68 + 56;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: count,
                crossAxisSpacing: 14,
                mainAxisSpacing: 24,
                childAspectRatio: itemWidth / itemHeight,
              ),
              itemBuilder: (context, index) {
                final data = docs[index].data();
                final itemId = (data['itemId'] ?? docs[index].id).toString();

                return _ShelfItemCard(
                  data: data,
                  canEdit: canEdit,
                  onRemove: () => onRemove(itemId),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ShelfItemCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool canEdit;
  final VoidCallback onRemove;

  const _ShelfItemCard({
    required this.data,
    required this.canEdit,
    required this.onRemove,
  });

  OnboardingMediaItem _toItem() {
    return OnboardingMediaItem(
      id: (data['itemId'] ?? '').toString(),
      title: (data['title'] ?? 'Untitled').toString(),
      domain: (data['domain'] ?? '').toString(),
      genres: ((data['genres'] as List?) ?? []).map((e) => e.toString()).toList(),
      tags: ((data['tags'] as List?) ?? []).map((e) => e.toString()).toList(),
      imageUrl: (data['imageUrl'] ?? '').toString(),
      source: (data['source'] ?? 'shelf').toString(),
      description: (data['description'] ?? '').toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = _toItem();

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ItemDetailsScreen(item: item),
          ),
        );
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(17),
                      child: item.imageUrl.isNotEmpty
                          ? Image.network(
                              item.imageUrl,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.high,
                              errorBuilder: (_, __, ___) => _fallbackPoster(),
                            )
                          : _fallbackPoster(),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(17),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.08),
                            Colors.black.withOpacity(0.35),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (canEdit)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _SmallCircleButton(
                        icon: Icons.remove_rounded,
                        onTap: onRemove,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 12.6,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _domainLabel(item.domain),
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.42),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _domainLabel(String domain) {
    switch (domain) {
      case 'movies':
        return 'Movie';
      case 'shows':
        return 'Show';
      case 'books':
        return 'Book';
      case 'games':
        return 'Game';
      default:
        return 'Item';
    }
  }

  Widget _fallbackPoster() {
    return Container(
      color: const Color(0xFF18181D),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          color: Colors.white.withOpacity(0.24),
        ),
      ),
    );
  }
}
class _AddShelfItemsDialog extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> shelfRef;
  final CollectionReference<Map<String, dynamic>> itemsRef;
  final String currentUid;
  final List<String> existingItemIds;

  const _AddShelfItemsDialog({
    required this.shelfRef,
    required this.itemsRef,
    required this.currentUid,
    required this.existingItemIds,
  });

  @override
  State<_AddShelfItemsDialog> createState() =>
      _AddShelfItemsDialogState();
}

class _AddShelfItemsDialogState extends State<_AddShelfItemsDialog> {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _results = [];
  bool _loading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchAll(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }

    setState(() => _loading = true);

    try {
      final futures = await Future.wait([
        _searchTMDB(query),
        _searchRAWG(query),
        _searchBooks(query),
      ]);

      final combined = [
        ...futures[0],
        ...futures[1],
        ...futures[2],
      ];

      setState(() => _results = combined);
    } catch (_) {
      setState(() => _results = []);
    }

    setState(() => _loading = false);
  }

  Future<List<Map<String, dynamic>>> _searchTMDB(String query) async {
    final res = await http.get(Uri.parse(
        'https://api.themoviedb.org/3/search/multi?api_key=$_tmdbApiKey&query=$query'));

    final data = jsonDecode(res.body);

    return (data['results'] as List)
        .where((e) => e['media_type'] != 'person')
        .map<Map<String, dynamic>>((e) {
      final isMovie = e['media_type'] == 'movie';
      final isTv = e['media_type'] == 'tv';

      return {
        'itemId': 'tmdb_${e['id']}',
        'title': e['title'] ?? e['name'],
        'domain': isMovie ? 'movies' : 'shows',
        'imageUrl':
            'https://image.tmdb.org/t/p/w500${e['poster_path']}',
        'source': 'tmdb',
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _searchRAWG(String query) async {
    final res = await http.get(Uri.parse(
        'https://api.rawg.io/api/games?key=$_rawgApiKey&search=$query'));

    final data = jsonDecode(res.body);

    return (data['results'] as List).map<Map<String, dynamic>>((e) {
      return {
        'itemId': 'rawg_${e['id']}',
        'title': e['name'],
        'domain': 'games',
        'imageUrl': e['background_image'],
        'source': 'rawg',
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _searchBooks(String query) async {
    final res = await http.get(Uri.parse(
        'https://www.googleapis.com/books/v1/volumes?q=$query'));

    final data = jsonDecode(res.body);

    return (data['items'] as List).map<Map<String, dynamic>>((e) {
      final info = e['volumeInfo'];

      return {
        'itemId': 'book_${e['id']}',
        'title': info['title'],
        'domain': 'books',
        'imageUrl': info['imageLinks']?['thumbnail'] ?? '',
        'source': 'books',
      };
    }).toList();
  }

  Future<void> _addItem(Map<String, dynamic> data) async {
    final itemId = data['itemId'];

    if (widget.existingItemIds.contains(itemId)) return;

    await widget.itemsRef.doc(itemId).set({
      ...data,
      'addedBy': widget.currentUid,
      'addedAt': FieldValue.serverTimestamp(),
    });

    await widget.shelfRef.update({
      'itemIds': FieldValue.arrayUnion([itemId]),
      'itemsCount': FieldValue.increment(1),
    });

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0E0E11),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  'Add items',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: _searchAll,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search anything...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                filled: true,
                fillColor: const Color(0xFF1A1A20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 420,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? const Center(
                          child: Text(
                            'Search movies, shows, books, games...',
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : GridView.builder(
                          itemCount: _results.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.65,
                          ),
                          itemBuilder: (context, index) {
                            final item = _results[index];

                            final added = widget.existingItemIds
                                .contains(item['itemId']);

                            return GestureDetector(
                              onTap: added ? null : () => _addItem(item),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        item['imageUrl'] ?? '',
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            Container(
                                          color: Colors.grey[900],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    item['title'] ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
class _EditShelfDialog extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> shelfRef;
  final CloudinaryService cloudinaryService;
  final String currentName;
  final String currentDescription;
  final String currentImageUrl;

  const _EditShelfDialog({
    required this.shelfRef,
    required this.cloudinaryService,
    required this.currentName,
    required this.currentDescription,
    required this.currentImageUrl,
  });

  @override
  State<_EditShelfDialog> createState() => _EditShelfDialogState();
}

class _EditShelfDialogState extends State<_EditShelfDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  final ImagePicker _picker = ImagePicker();

  XFile? _newImage;
  Uint8List? _newImageBytes;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _descriptionController =
        TextEditingController(text: widget.currentDescription);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
    );

    if (picked == null) return;

    final bytes = await picked.readAsBytes();

    if (!mounted) return;

    setState(() {
      _newImage = picked;
      _newImageBytes = bytes;
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shelf name is required.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      String imageUrl = widget.currentImageUrl;

      if (_newImage != null) {
        imageUrl = await widget.cloudinaryService.uploadShelfImage(_newImage!);
      }

      await widget.shelfRef.update({
        'name': name,
        'description': description,
        'imageUrl': imageUrl,
        'imageSource': imageUrl.isEmpty ? 'empty' : 'cloudinary',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shelf updated.')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update shelf: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 680;

    return Dialog(
      backgroundColor: const Color(0xFF101014),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 26),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Edit shelf',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.9,
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: _saving ? null : () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                compact
                    ? Column(
                        children: [
                          Center(child: _EditCoverPicker(onPick: _pickImage)),
                          const SizedBox(height: 22),
                          _ShelfTextField(
                            controller: _nameController,
                            label: 'Name',
                            hint: 'comfort rotation',
                          ),
                          const SizedBox(height: 14),
                          _ShelfTextField(
                            controller: _descriptionController,
                            label: 'Description',
                            hint: 'The safe picks I always come back to',
                            maxLines: 4,
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _EditCoverPicker(onPick: _pickImage),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              children: [
                                _ShelfTextField(
                                  controller: _nameController,
                                  label: 'Name',
                                  hint: 'comfort rotation',
                                ),
                                const SizedBox(height: 14),
                                _ShelfTextField(
                                  controller: _descriptionController,
                                  label: 'Description',
                                  hint: 'The safe picks I always come back to',
                                  maxLines: 4,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8B3D),
                      disabledBackgroundColor:
                          const Color(0xFFFF8B3D).withOpacity(0.55),
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 2.2,
                            ),
                          )
                        : Text(
                            'Save changes',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _EditCoverPicker({required VoidCallback onPick}) {
    return InkWell(
      onTap: _saving ? null : onPick,
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        width: 190,
        height: 190,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: _newImageBytes != null
              ? Image.memory(
                  _newImageBytes!,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                )
              : widget.currentImageUrl.isNotEmpty
                  ? Image.network(
                      widget.currentImageUrl,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                    )
                  : Container(
                      color: const Color(0xFF1B1B21),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_rounded,
                            color: Colors.white.withOpacity(0.72),
                            size: 34,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Shelf image',
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.72),
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }
}
class _InviteCollaboratorDialog extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> shelfRef;
  final List<String> existingCollaboratorIds;
  final String ownerId;

  const _InviteCollaboratorDialog({
    required this.shelfRef,
    required this.existingCollaboratorIds,
    required this.ownerId,
  });

  @override
  State<_InviteCollaboratorDialog> createState() =>
      _InviteCollaboratorDialogState();
}

class _InviteCollaboratorDialogState extends State<_InviteCollaboratorDialog> {
  final TextEditingController _searchController = TextEditingController();

  String _query = '';
  bool _loading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _inviteUser(String uid) async {
    if (uid == widget.ownerId) return;

    setState(() => _loading = true);

    try {
      await widget.shelfRef.update({
        'collaboratorIds': FieldValue.arrayUnion([uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Collaborator invited.')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not invite user: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Query<Map<String, dynamic>> _usersQuery() {
    final q = _query.trim().toLowerCase();

    if (q.isEmpty) {
      return FirebaseFirestore.instance.collection('users').limit(12);
    }

    return FirebaseFirestore.instance
        .collection('users')
        .orderBy('username')
        .startAt([q])
        .endAt(['$q\uf8ff'])
        .limit(20);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF101014),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    'Invite collaborator',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.7,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: _loading ? null : () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SearchField(
                controller: _searchController,
                hint: 'Search by username',
                onChanged: (value) {
                  setState(() {
                    _query = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _usersQuery().snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const _ShelfInfoBlock(
                        title: 'Could not search users',
                        body: 'Make sure usernames are saved consistently.',
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];

                    if (docs.isEmpty) {
                      return const _ShelfInfoBlock(
                        title: 'No users found',
                        body: 'Try another username.',
                      );
                    }

                    return ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => Divider(
                        color: Colors.white.withOpacity(0.06),
                        height: 1,
                      ),
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data();
                        final uid = doc.id;

                        final name =
                            (data['displayName'] ?? data['name'] ?? 'User')
                                .toString();
                        final username =
                            (data['username'] ?? '').toString().trim();
                        final photo =
                            (data['photoUrl'] ?? data['avatarUrl'] ?? '')
                                .toString()
                                .trim();

                        final already =
                            widget.existingCollaboratorIds.contains(uid);
                        final isOwner = uid == widget.ownerId;

                        return _UserInviteTile(
                          name: name,
                          username: username,
                          photoUrl: photo,
                          disabled: already || isOwner || _loading,
                          trailingText: isOwner
                              ? 'Owner'
                              : already
                                  ? 'Added'
                                  : 'Invite',
                          onTap: already || isOwner || _loading
                              ? null
                              : () => _inviteUser(uid),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserInviteTile extends StatelessWidget {
  final String name;
  final String username;
  final String photoUrl;
  final bool disabled;
  final String trailingText;
  final VoidCallback? onTap;

  const _UserInviteTile({
    required this.name,
    required this.username,
    required this.photoUrl,
    required this.disabled,
    required this.trailingText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFF1A1A20),
              backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
              child: photoUrl.isEmpty
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (username.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      '@$username',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                color: disabled
                    ? Colors.white.withOpacity(0.08)
                    : const Color(0xFFFF8B3D),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                trailingText,
                style: GoogleFonts.inter(
                  color: disabled ? Colors.white.withOpacity(0.55) : Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _SoftPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SoftPill({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white.withOpacity(0.62)),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.68),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      cursorColor: const Color(0xFFFF8B3D),
      style: GoogleFonts.inter(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
          color: Colors.white.withOpacity(0.34),
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: Colors.white.withOpacity(0.45),
        ),
        filled: true,
        fillColor: const Color(0xFF1A1A20),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.20)),
        ),
      ),
    );
  }
}

class _ShelfTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;

  const _ShelfTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.65),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          cursorColor: const Color(0xFFFF8B3D),
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.30),
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
            filled: true,
            fillColor: const Color(0xFF1A1A20),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.20)),
            ),
          ),
        ),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool destructive;

  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.075),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.075)),
          ),
          child: Icon(
            icon,
            color: destructive ? const Color(0xFFFF8EA1) : Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _SmallCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _SmallCircleButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.62),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String body;
  final String confirmText;
  final bool destructive;

  const _ConfirmDialog({
    required this.title,
    required this.body,
    required this.confirmText,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF101014),
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                body,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.58),
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(false),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(true),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: destructive
                              ? const Color(0xFFFF4D6D)
                              : const Color(0xFFFF8B3D),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          confirmText,
                          style: GoogleFonts.inter(
                            color: Colors.black,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShelfInfoBlock extends StatelessWidget {
  final String title;
  final String body;

  const _ShelfInfoBlock({
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 52, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.035),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.grid_view_rounded,
            color: Colors.white.withOpacity(0.28),
            size: 42,
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.55),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String title;
  final String body;
  final VoidCallback onBack;

  const _ErrorState({
    required this.title,
    required this.body,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050507),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                body,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.58),
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF8B3D),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Go back',
                    style: GoogleFonts.inter(
                      color: Colors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}