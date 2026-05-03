import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/onboarding_media_item.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/services/discover_api_service.dart';
import '../../items/screens/item_details_screen.dart';

const Color kShelfBg = Color(0xFF050507);
const Color kShelfAccent = Color(0xFFFF8B3D);

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
      barrierColor: Colors.black.withOpacity(0.76),
      builder: (_) => const _ConfirmDialog(
        title: 'Delete this shelf?',
        body: 'This removes the shelf and everything inside it.',
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
      barrierColor: Colors.black.withOpacity(0.76),
      builder: (_) => const _ConfirmDialog(
        title: 'Leave shelf?',
        body: 'You will lose access to editing this shelf.',
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
      backgroundColor: kShelfBg,
      floatingActionButton: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _shelfRef.snapshots(),
        builder: (context, snapshot) {
          final shelf = snapshot.data?.data();
          if (shelf == null || !_canEdit(shelf)) return const SizedBox.shrink();

          return FloatingActionButton(
            backgroundColor: kShelfAccent,
            foregroundColor: Colors.black,
            shape: const CircleBorder(),
            elevation: 12,
            onPressed: () => _openAddItemsDialog(shelf),
            child: const Icon(Icons.add_rounded, size: 32),
          );
        },
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _shelfRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorState(
              title: 'Could not load shelf',
              body: 'Check your Firestore shelf rules.',
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
          final collaboratorIds = ((shelf['collaboratorIds'] as List?) ?? [])
              .map((e) => e.toString())
              .toList();

          final itemCount = (shelf['itemsCount'] ?? 0) is num
              ? (shelf['itemsCount'] as num).toInt()
              : 0;

          final isOwner = _isOwner(shelf);
          final isCollaborator = _isCollaborator(shelf);
          final canEdit = _canEdit(shelf);
          final peopleCount = collaboratorIds.length + 1;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _ShelfTopBar(
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
                child: _ShelfHeader(
                  name: name,
                  description: description,
                  imageUrl: imageUrl,
                  itemCount: itemCount,
                  peopleCount: peopleCount,
                  role: isOwner
                      ? 'Owner'
                      : isCollaborator
                          ? 'Collaborator'
                          : 'Viewer',
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 110),
                  child: _ShelfItemsGrid(
                    itemsRef: _itemsRef,
                    canEdit: canEdit,
                    onRemove: _removeItem,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
class _ShelfTopBar extends StatelessWidget {
  final bool canEdit;
  final bool isOwner;
  final bool isCollaborator;
  final VoidCallback onBack;
  final VoidCallback? onEdit;
  final VoidCallback? onInvite;
  final VoidCallback? onDelete;
  final VoidCallback? onLeave;

  const _ShelfTopBar({
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
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
        child: Row(
          children: [
            _RoundIconButton(
              icon: Icons.arrow_back_rounded,
              onTap: onBack,
            ),
            const Spacer(),
            if (canEdit)
              _RoundIconButton(
                icon: Icons.edit_rounded,
                onTap: onEdit,
              ),
            if (isOwner) ...[
              const SizedBox(width: 10),
              _RoundIconButton(
                icon: Icons.person_add_alt_1_rounded,
                onTap: onInvite,
              ),
            ],
            if (isOwner || (isCollaborator && !isOwner)) ...[
              const SizedBox(width: 10),
              _RoundIconButton(
                icon: Icons.more_horiz_rounded,
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: const Color(0xFF101014),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                    ),
                    builder: (_) => _ShelfOptionsSheet(
                      isOwner: isOwner,
                      isCollaborator: isCollaborator && !isOwner,
                      onDelete: onDelete,
                      onLeave: onLeave,
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShelfHeader extends StatelessWidget {
  final String name;
  final String description;
  final String imageUrl;
  final int itemCount;
  final int peopleCount;
  final String role;

  const _ShelfHeader({
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.itemCount,
    required this.peopleCount,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;

          final cover = Container(
            width: compact ? 124 : 184,
            height: compact ? 162 : 242,
            decoration: BoxDecoration(
              color: const Color(0xFF15151A),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.38),
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
          );

          final details = Column(
            crossAxisAlignment:
                compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              Text(
                'curated shelf',
                style: GoogleFonts.inter(
                  color: kShelfAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                name,
                textAlign: compact ? TextAlign.center : TextAlign.start,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: compact ? 38 : 58,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2.4,
                  height: 0.92,
                ),
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 650),
                  child: Text(
                    description,
                    textAlign: compact ? TextAlign.center : TextAlign.start,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.58),
                      fontSize: 14,
                      height: 1.55,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Wrap(
                alignment: compact ? WrapAlignment.center : WrapAlignment.start,
                spacing: 10,
                runSpacing: 10,
                children: [
                  _ShelfMetric(
                    icon: Icons.auto_awesome_mosaic_rounded,
                    text: '$itemCount items',
                  ),
                  _ShelfMetric(
                    icon: Icons.people_alt_rounded,
                    text:
                        '$peopleCount ${peopleCount == 1 ? 'person' : 'people'}',
                  ),
                  _ShelfMetric(
                    icon: Icons.lock_open_rounded,
                    text: role,
                  ),
                ],
              ),
            ],
          );

          if (compact) {
            return Column(
              children: [
                cover,
                const SizedBox(height: 22),
                details,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              cover,
              const SizedBox(width: 28),
              Expanded(child: details),
            ],
          );
        },
      ),
    );
  }

  Widget _coverFallback() {
    return Container(
      color: const Color(0xFF15151A),
      child: Center(
        child: Icon(
          Icons.auto_awesome_mosaic_rounded,
          color: Colors.white.withOpacity(0.28),
          size: 44,
        ),
      ),
    );
  }
}

class _ShelfMetric extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ShelfMetric({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.62), size: 15),
          const SizedBox(width: 7),
          Text(
            text,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.70),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShelfOptionsSheet extends StatelessWidget {
  final bool isOwner;
  final bool isCollaborator;
  final VoidCallback? onDelete;
  final VoidCallback? onLeave;

  const _ShelfOptionsSheet({
    required this.isOwner,
    required this.isCollaborator,
    required this.onDelete,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 18),
            if (isOwner)
              _SheetAction(
                icon: Icons.delete_outline_rounded,
                title: 'Delete shelf',
                subtitle: 'Remove this shelf permanently',
                destructive: true,
                onTap: () {
                  Navigator.pop(context);
                  onDelete?.call();
                },
              ),
            if (isCollaborator)
              _SheetAction(
                icon: Icons.logout_rounded,
                title: 'Leave shelf',
                subtitle: 'Remove yourself from this shelf',
                destructive: true,
                onTap: () {
                  Navigator.pop(context);
                  onLeave?.call();
                },
              ),
          ],
        ),
      ),
    );
  }
}
class _ShelfItemsGrid extends StatelessWidget {
  final CollectionReference<Map<String, dynamic>> itemsRef;
  final bool canEdit;
  final Future<void> Function(String itemId) onRemove;

  const _ShelfItemsGrid({
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
            body: 'Tap + to search movies, shows, books, or games.',
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            final count = width >= 1200
                ? 6
                : width >= 950
                    ? 5
                    : width >= 720
                        ? 4
                        : width >= 500
                            ? 3
                            : 2;

            final itemWidth = (width - ((count - 1) * 16)) / count;
            final itemHeight = itemWidth / 0.68 + 88;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: count,
                crossAxisSpacing: 16,
                mainAxisSpacing: 26,
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

    final addedByName = (data['addedByName'] ?? 'Someone').toString();
    final addedByUsername = (data['addedByUsername'] ?? '').toString();
    final addedByAvatar = (data['addedByAvatar'] ?? '').toString();

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
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF101014),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.055)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: item.imageUrl.isNotEmpty
                          ? Image.network(
                              item.imageUrl,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.high,
                              errorBuilder: (_, __, ___) => _fallbackPoster(),
                            )
                          : _fallbackPoster(),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.02),
                              Colors.black.withOpacity(0.08),
                              Colors.black.withOpacity(0.45),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      bottom: 10,
                      child: _DomainChip(domain: item.domain),
                    ),
                    if (canEdit)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _PosterMenuButton(onRemove: onRemove),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 12.8,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 11,
                          backgroundColor: const Color(0xFF1B1B21),
                          backgroundImage: addedByAvatar.isNotEmpty
                              ? NetworkImage(addedByAvatar)
                              : null,
                          child: addedByAvatar.isEmpty
                              ? Text(
                                  addedByName.isNotEmpty
                                      ? addedByName[0].toUpperCase()
                                      : '?',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            addedByUsername.isNotEmpty
                                ? '@$addedByUsername'
                                : addedByName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.48),
                              fontSize: 10.8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

class _PosterMenuButton extends StatelessWidget {
  final VoidCallback onRemove;

  const _PosterMenuButton({
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.54),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: const Color(0xFF101014),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            builder: (_) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SheetAction(
                      icon: Icons.playlist_remove_rounded,
                      title: 'Remove from shelf',
                      subtitle: 'This only removes it from this shelf',
                      destructive: true,
                      onTap: () {
                        Navigator.pop(context);
                        onRemove();
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        child: const SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            Icons.more_horiz_rounded,
            color: Colors.white,
            size: 19,
          ),
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
  State<_AddShelfItemsDialog> createState() => _AddShelfItemsDialogState();
}

class _AddShelfItemsDialogState extends State<_AddShelfItemsDialog> {
  final DiscoverApiService _service = DiscoverApiService();
  final TextEditingController _searchController = TextEditingController();

  Timer? _debounce;
  List<OnboardingMediaItem> _results = [];

  bool _loading = false;
  String _error = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 450), () {
      _searchAll(value);
    });
  }

  Future<void> _searchAll(String query) async {
    final cleanQuery = query.trim();

    if (cleanQuery.isEmpty) {
      setState(() {
        _results = [];
        _error = '';
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final results = await _service.searchAll(cleanQuery);

      final seen = <String>{};
      final unique = <OnboardingMediaItem>[];

      for (final item in results) {
        final key = '${item.domain}_${item.id}';
        if (seen.contains(key)) continue;
        seen.add(key);
        unique.add(item);
      }

      if (!mounted) return;

      setState(() {
        _results = unique;
        _error = unique.isEmpty ? 'No results found.' : '';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _results = [];
        _error = 'Search failed. Check DiscoverApiService and API keys.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Map<String, String>> _currentUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return {
        'name': 'Someone',
        'username': '',
        'avatar': '',
      };
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = doc.data() ?? {};

    return {
      'name':
          (data['displayName'] ?? data['name'] ?? user.displayName ?? 'Someone')
              .toString(),
      'username': (data['username'] ?? '').toString(),
      'avatar':
          (data['photoUrl'] ?? data['avatarUrl'] ?? user.photoURL ?? '')
              .toString(),
    };
  }

  Future<void> _addItem(OnboardingMediaItem item) async {
    final itemId = item.id;

    if (itemId.isEmpty) return;
    if (widget.existingItemIds.contains(itemId)) return;

    setState(() => _loading = true);

    try {
      final userInfo = await _currentUserInfo();

      await widget.itemsRef.doc(itemId).set({
        'itemId': item.id,
        'title': item.title,
        'domain': item.domain,
        'imageUrl': item.imageUrl,
        'source': item.source,
        'description': item.description,
        'genres': item.genres,
        'tags': item.tags,
        'addedBy': widget.currentUid,
        'addedByName': userInfo['name'],
        'addedByUsername': userInfo['username'],
        'addedByAvatar': userInfo['avatar'],
        'addedAt': FieldValue.serverTimestamp(),
      });

      await widget.shelfRef.update({
        'itemIds': FieldValue.arrayUnion([itemId]),
        'itemsCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item added to shelf.')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add item: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: kShelfBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(32),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    'Add to shelf',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.9,
                    ),
                  ),
                  const Spacer(),
                  _DialogCloseButton(
                    onTap: _loading ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Search movies, shows, books, and games.',
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _SearchField(
                controller: _searchController,
                hint: 'Search anything...',
                onChanged: _onSearchChanged,
              ),
              const SizedBox(height: 18),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: kShelfAccent,
                        ),
                      )
                    : _error.isNotEmpty
                        ? _ShelfInfoBlock(
                            title: 'No results',
                            body: _error,
                          )
                        : _results.isEmpty
                            ? const _ShelfInfoBlock(
                                title: 'Start searching',
                                body: 'Try a movie, show, book, or game title.',
                              )
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                  final width = constraints.maxWidth;

                                  final count = width >= 760
                                      ? 5
                                      : width >= 560
                                          ? 4
                                          : width >= 390
                                              ? 3
                                              : 2;

                                  return GridView.builder(
                                    itemCount: _results.length,
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: count,
                                      crossAxisSpacing: 14,
                                      mainAxisSpacing: 18,
                                      childAspectRatio: 0.58,
                                    ),
                                    itemBuilder: (context, index) {
                                      final item = _results[index];
                                      final added = widget.existingItemIds
                                          .contains(item.id);

                                      return _AddItemResultCard(
                                        item: item,
                                        added: added,
                                        loading: _loading,
                                        onTap: added || _loading
                                            ? null
                                            : () => _addItem(item),
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

class _AddItemResultCard extends StatelessWidget {
  final OnboardingMediaItem item;
  final bool added;
  final bool loading;
  final VoidCallback? onTap;

  const _AddItemResultCard({
    required this.item,
    required this.added,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = _image(item.imageUrl);

    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor:
            added || loading ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: Opacity(
          opacity: added ? 0.48 : 1,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF111116),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.055)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.high,
                              errorBuilder: (_, __, ___) =>
                                  _fallback(item.domain),
                            )
                          : _fallback(item.domain),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.12),
                                Colors.black.withOpacity(0.50),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 9,
                        bottom: 9,
                        child: _DomainChip(domain: item.domain),
                      ),
                      Positioned(
                        top: 9,
                        right: 9,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: added
                                ? Colors.white.withOpacity(0.92)
                                : kShelfAccent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            added ? Icons.check_rounded : Icons.add_rounded,
                            color: Colors.black,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 9, 10, 11),
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 12.3,
                      fontWeight: FontWeight.w800,
                      height: 1.22,
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
        'searchName': name.trim().toLowerCase(),
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
      backgroundColor: kShelfBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 24, 26, 26),
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
                    _DialogCloseButton(
                      onTap: _saving ? null : () => Navigator.of(context).pop(),
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
                      backgroundColor: kShelfAccent,
                      disabledBackgroundColor: kShelfAccent.withOpacity(0.55),
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
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: 190,
        height: 245,
        decoration: BoxDecoration(
          color: const Color(0xFF15151A),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
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
                          errorBuilder: (_, __, ___) => _emptyPicker(),
                        )
                      : _emptyPicker(),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.20),
                      Colors.black.withOpacity(0.70),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Row(
                children: [
                  const Icon(
                    Icons.add_photo_alternate_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Change image',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
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

  Widget _emptyPicker() {
    return Container(
      color: const Color(0xFF15151A),
      child: Center(
        child: Icon(
          Icons.auto_awesome_mosaic_rounded,
          color: Colors.white.withOpacity(0.30),
          size: 42,
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
      backgroundColor: kShelfBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    'Invite people',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const Spacer(),
                  _DialogCloseButton(
                    onTap: _loading ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Collaborators can edit shelf details and add items.',
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _SearchField(
                controller: _searchController,
                hint: 'Search username...',
                onChanged: (value) {
                  setState(() => _query = value);
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
                        body: 'Make sure username is saved as lowercase.',
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: kShelfAccent,
                        ),
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
              radius: 23,
              backgroundColor: const Color(0xFF1A1A20),
              backgroundImage:
                  photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
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
                color: disabled ? Colors.white.withOpacity(0.08) : kShelfAccent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                trailingText,
                style: GoogleFonts.inter(
                  color:
                      disabled ? Colors.white.withOpacity(0.55) : Colors.black,
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
class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _RoundIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.07),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _DialogCloseButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _DialogCloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
    );
  }
}

class _DomainChip extends StatelessWidget {
  final String domain;

  const _DomainChip({required this.domain});

  @override
  Widget build(BuildContext context) {
    String label = 'Item';
    IconData icon = Icons.auto_awesome_mosaic_rounded;

    if (domain == 'movies') {
      label = 'Movie';
      icon = Icons.movie_rounded;
    } else if (domain == 'shows') {
      label = 'Show';
      icon = Icons.tv_rounded;
    } else if (domain == 'books') {
      label = 'Book';
      icon = Icons.menu_book_rounded;
    } else if (domain == 'games') {
      label = 'Game';
      icon = Icons.sports_esports_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.58),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool destructive;
  final VoidCallback? onTap;

  const _SheetAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? const Color(0xFFFF6F86) : Colors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.045),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.055)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.44),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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
      cursorColor: kShelfAccent,
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
        fillColor: const Color(0xFF141419),
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
          cursorColor: kShelfAccent,
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
            fillColor: const Color(0xFF141419),
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
                              : kShelfAccent,
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
            Icons.auto_awesome_mosaic_rounded,
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
      backgroundColor: kShelfBg,
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
                    color: kShelfAccent,
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

String _image(String url) {
  if (url.contains('image.tmdb.org/t/p/w500')) {
    return url.replaceAll('/w500/', '/original/');
  }

  if (url.contains('image.tmdb.org/t/p/w780')) {
    return url.replaceAll('/w780/', '/original/');
  }

  if (url.contains('http://')) {
    return url.replaceAll('http://', 'https://');
  }

  return url;
}

Widget _fallback(String domain) {
  IconData icon;

  switch (domain) {
    case 'movies':
      icon = Icons.local_movies_outlined;
      break;
    case 'shows':
      icon = Icons.tv_outlined;
      break;
    case 'books':
      icon = Icons.menu_book_outlined;
      break;
    case 'games':
      icon = Icons.sports_esports_outlined;
      break;
    default:
      icon = Icons.image_outlined;
  }

  return Container(
    color: Colors.white.withOpacity(0.07),
    child: Center(
      child: Icon(
        icon,
        color: Colors.white54,
        size: 30,
      ),
    ),
  );
}