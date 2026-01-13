import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:relo/models/post.dart';
import 'package:relo/screen/edit_post_screen.dart';
import 'package:relo/screen/media_fullscreen_viewer.dart';
import 'package:relo/services/post_service.dart';
import 'package:relo/services/service_locator.dart';
import 'package:relo/services/secure_storage_service.dart';
import 'package:relo/services/comment_service.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:relo/widgets/posts/auto_play_video_widget.dart';
import 'package:relo/utils/show_notification.dart';
import 'package:relo/widgets/posts/comments_bottom_sheet.dart';

class EnhancedPostCard extends StatefulWidget {
  final Post post;
  final VoidCallback? onPostDeleted;

  const EnhancedPostCard({super.key, required this.post, this.onPostDeleted});

  @override
  State<EnhancedPostCard> createState() => _EnhancedPostCardState();
}

class _EnhancedPostCardState extends State<EnhancedPostCard> {
  final PostService _postService = ServiceLocator.postService;
  final CommentService _commentService = ServiceLocator.commentService;
  final SecureStorageService _secureStorage = const SecureStorageService();
  late Post _currentPost;
  String? _currentUserId;
  int _commentCount = 0;
  final Map<String, Size> _imageSizeCache = {};

  @override
  void initState() {
    super.initState();
    _currentPost = widget.post;
    _loadCurrentUserId();
    _loadCommentCount();
  }

  Future<void> _loadCommentCount() async {
    try {
      final count = await _commentService.getCommentCount(_currentPost.id);
      if (mounted) {
        setState(() {
          _commentCount = count;
        });
      }
    } catch (e) {
      // Silent fail
    }
  }

  @override
  void didUpdateWidget(EnhancedPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post.id != oldWidget.post.id) {
      setState(() {
        _currentPost = widget.post;
      });
    }
  }

  Future<void> _loadCurrentUserId() async {
    _currentUserId = await _secureStorage.getUserId();
    if (mounted) {
      setState(() {});
    }
  }

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return DateFormat('dd/MM/yyyy HH:mm').format(time);
  }

  Future<void> _handleReaction(String reactionType) async {
    try {
      final updatedPost = await _postService.reactToPost(
        postId: _currentPost.id,
        reactionType: reactionType,
      );

      if (mounted) {
        setState(() {
          _currentPost = updatedPost;
        });
      }
    } catch (e) {
      if (mounted) {
        await ShowNotification.showToast(context, 'Lỗi: $e');
      }
    }
  }

  void _showPostOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(LucideIcons.edit, color: Colors.black87),
              title: const Text(
                'Chỉnh sửa bài đăng',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _editPost();
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(LucideIcons.trash2, color: Colors.red),
              title: const Text(
                'Xóa bài đăng',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmDeletePost();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editPost() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditPostScreen(post: _currentPost),
      ),
    );

    // If edit was successful, refresh the post
    if (result == true && mounted) {
      widget.onPostDeleted?.call(); // Reuse callback to refresh feed
    }
  }

  void _confirmDeletePost() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa bài đăng'),
        content: const Text('Bạn có chắc chắn muốn xóa bài đăng này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePost();
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePost() async {
    try {
      await _postService.deletePost(_currentPost.id);
      if (mounted) {
        await ShowNotification.showToast(context, 'Đã xóa bài đăng');
        // Notify parent to refresh feed
        widget.onPostDeleted?.call();
      }
    } catch (e) {
      if (mounted) {
        await ShowNotification.showToast(context, 'Lỗi xóa bài đăng: $e');
      }
    }
  }

  Future<void> _sharePost() async {
    try {
      final contentController = TextEditingController();
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Chia sẻ bài viết'),
          content: TextField(
            controller: contentController,
            decoration: const InputDecoration(
              hintText: 'Bạn đang nghĩ gì về bài viết này?',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Chia sẻ'),
            ),
          ],
        ),
      );

      if (result == true) {
        await _postService.sharePost(
          _currentPost.id,
          content: contentController.text,
        );
        if (mounted) {
          await ShowNotification.showToast(context, 'Đã chia sẻ bài viết');
          widget.onPostDeleted?.call(); // Refresh feed
        }
      }
    } catch (e) {
      if (mounted) {
        await ShowNotification.showToast(context, 'Lỗi chia sẻ: $e');
      }
    }
  }

  bool _isVideo(String url) {
    final ext = url.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'mkv', 'm4v'].contains(ext);
  }

  Widget _buildMediaItem(String url, {int? index}) {
    final isVideo = _isVideo(url);

    Widget mediaWidget;
    if (isVideo) {
      // Video: dùng tỉ lệ mặc định 16:9 theo chiều rộng màn hình
      final screenWidth = MediaQuery.of(context).size.width;
      final videoHeight = screenWidth * 9 / 16;
      mediaWidget = SizedBox(
        height: videoHeight,
        width: double.infinity,
        child: AutoPlayVideoWidget(
          videoUrl: url,
          height: videoHeight,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MediaFullScreenViewer(
                  mediaUrls: _currentPost.mediaUrls,
                  initialIndex: index ?? 0,
                ),
              ),
            );
          },
        ),
      );
    } else {
      mediaWidget = LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = MediaQuery.of(context).size.width;
          return FutureBuilder<Size>(
            future: _getImageSize(url),
            builder: (context, snapshot) {
              final hasSize = snapshot.hasData && snapshot.data!.width > 0;
              final aspectRatio = hasSize
                  ? snapshot.data!.width / snapshot.data!.height
                  : 16 / 9; // fallback
              final height = hasSize
                  ? screenWidth / aspectRatio
                  : screenWidth * 9 / 16;

              return SizedBox(
                width: double.infinity,
                height: height,
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MediaFullScreenViewer(
                          mediaUrls: _currentPost.mediaUrls,
                          initialIndex: index ?? 0,
                        ),
                      ),
                    );
                  },
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    placeholder: (context, url) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) => const Center(
                      child: Icon(
                        LucideIcons.imageOff,
                        color: Colors.grey,
                        size: 50,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    }

    return mediaWidget;
  }

  Future<Size> _getImageSize(String url) async {
    if (_imageSizeCache.containsKey(url)) {
      return _imageSizeCache[url]!;
    }

    final completer = Completer<Size>();
    final Image image = Image.network(url);
    image.image
        .resolve(const ImageConfiguration())
        .addListener(
          ImageStreamListener(
            (ImageInfo info, bool _) {
              final mySize = Size(
                info.image.width.toDouble(),
                info.image.height.toDouble(),
              );
              _imageSizeCache[url] = mySize;
              completer.complete(mySize);
            },
            onError: (error, stackTrace) {
              completer.complete(const Size(16, 9));
            },
          ),
        );
    return completer.future;
  }

  void _showReactionPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              children: [
                const Icon(
                  LucideIcons.smile,
                  size: 18,
                  color: Color(0xFF7A2FC0),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Chọn cảm xúc',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildReactionPickerButton('👍', 'like'),
                _buildReactionPickerButton('❤️', 'love'),
                _buildReactionPickerButton('😂', 'haha'),
                _buildReactionPickerButton('😮', 'wow'),
                _buildReactionPickerButton('😢', 'sad'),
                _buildReactionPickerButton('😡', 'angry'),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildReactionPickerButton(String emoji, String type) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        _handleReaction(type);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[200]!, width: 1),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 24)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==== Header: Avatar + Tên + Thời gian ====
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage:
                        _currentPost.authorInfo.avatarUrl != null &&
                            _currentPost.authorInfo.avatarUrl!.isNotEmpty
                        ? CachedNetworkImageProvider(
                            _currentPost.authorInfo.avatarUrl!,
                          )
                        : null,
                    child:
                        _currentPost.authorInfo.avatarUrl == null ||
                            _currentPost.authorInfo.avatarUrl!.isEmpty
                        ? Text(
                            _currentPost.authorInfo.displayName[0]
                                .toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentPost.authorInfo.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          _formatTimeAgo(_currentPost.createdAt),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Only show 3-dot menu if current user is the post author
                  if (_currentUserId != null &&
                      _currentUserId == _currentPost.authorId)
                    IconButton(
                      icon: const Icon(
                        LucideIcons.moreVertical,
                        size: 20,
                        color: Colors.grey,
                      ),
                      onPressed: _showPostOptions,
                    ),
                ],
              ),
            ),

            // ==== Nội dung bài viết ====
            if (_currentPost.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Text(
                  _currentPost.content,
                  style: const TextStyle(fontSize: 15, height: 1.4),
                ),
              ),

            const SizedBox(height: 8),

            // ==== Bài viết được chia sẻ ====
            if (_currentPost.sharedPost != null) _buildSharedPost(_currentPost.sharedPost!),

            // ==== Media (ảnh/video) ====
            if (_currentPost.mediaUrls.isNotEmpty)
              (_currentPost.mediaUrls.length == 1)
                  ? _buildMediaItem(_currentPost.mediaUrls[0], index: 0)
                  : PageView.builder(
                      itemCount: _currentPost.mediaUrls.length,
                      itemBuilder: (context, index) {
                        return _buildMediaItem(
                          _currentPost.mediaUrls[index],
                          index: index,
                        );
                      },
                    ),

            const SizedBox(height: 8),

            const Divider(height: 1),

            // ==== Reaction and Comment buttons ====
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8,
              ),
              child: Column(
                children: [
                  // Zalo-like: reaction count + react button on same row
                  Row(
                    children: [
                      if (_currentPost.reactionCounts.isNotEmpty) ...[
                        _buildReactionIcons(),
                        const SizedBox(width: 4),
                        Text(
                          _getTotalReactions().toString(),
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                          ),
                        ),
                      ],
                      const Spacer(),
                      _buildReactionButton(),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Action buttons row
                  Row(
                    children: [
                      _buildCommentButton(),
                      const Spacer(),
                      _buildShareButton(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReactionButton() {
    final currentReaction = _getCurrentUserReaction();
    final hasReacted = currentReaction != null;
    final emoji = hasReacted ? _getEmojiForReaction(currentReaction) : null;

    return TextButton.icon(
      onPressed: _showReactionPicker,
      icon: hasReacted
          ? Text(emoji!, style: const TextStyle(fontSize: 20))
          : const Icon(LucideIcons.heart, size: 20),
      label: Text(
        hasReacted ? _getReactionLabel(currentReaction) : 'Thích',
        style: TextStyle(
          fontWeight: hasReacted ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      style: TextButton.styleFrom(
        foregroundColor: hasReacted
            ? const Color(0xFF7A2FC0)
            : Colors.grey[700],
        backgroundColor: hasReacted
            ? const Color(0xFF7A2FC0).withOpacity(0.1)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  String _getReactionLabel(String type) {
    switch (type) {
      case 'like':
        return 'Thích';
      case 'love':
        return 'Yêu thích';
      case 'haha':
        return 'Haha';
      case 'wow':
        return 'Wow';
      case 'sad':
        return 'Buồn';
      case 'angry':
        return 'Phẫn nộ';
      default:
        return 'Thích';
    }
  }

  Widget _buildReactionIcons() {
    final reactions = _currentPost.reactionCounts.keys.take(3).toList();
    return Row(
      children: reactions.map((type) {
        final emoji = _getEmojiForReaction(type);
        return Container(
          margin: const EdgeInsets.only(right: 2),
          child: Text(emoji, style: const TextStyle(fontSize: 16)),
        );
      }).toList(),
    );
  }

  String _getEmojiForReaction(String type) {
    switch (type) {
      case 'like':
        return '👍';
      case 'love':
        return '❤️';
      case 'haha':
        return '😂';
      case 'wow':
        return '😮';
      case 'sad':
        return '😢';
      case 'angry':
        return '😡';
      default:
        return '👍';
    }
  }

  int _getTotalReactions() {
    return _currentPost.reactionCounts.values.fold(
      0,
      (sum, count) => sum + count,
    );
  }

  /// Lấy reaction type của user hiện tại (nếu có)
  String? _getCurrentUserReaction() {
    if (_currentUserId == null) {
      return null;
    }

    try {
      final userReaction = _currentPost.reactions.firstWhere(
        (r) => r.userId == _currentUserId,
      );
      return userReaction.type;
    } catch (e) {
      return null;
    }
  }

  Widget _buildCommentButton() {
    return TextButton.icon(
      onPressed: _showCommentsDialog,
      icon: const Icon(LucideIcons.messageCircle, size: 20),
      label: Text(
        _commentCount > 0 ? _commentCount.toString() : 'Bình luận',
        style: const TextStyle(fontWeight: FontWeight.normal),
      ),
      style: TextButton.styleFrom(
        foregroundColor: Colors.grey[700],
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildShareButton() {
    return TextButton.icon(
      onPressed: _sharePost,
      icon: const Icon(LucideIcons.share2, size: 20),
      label: const Text('Chia sẻ', style: TextStyle(fontWeight: FontWeight.normal)),
      style: TextButton.styleFrom(
        foregroundColor: Colors.grey[700],
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildSharedPost(Post sharedPost) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey[50],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundImage:
                      sharedPost.authorInfo.avatarUrl != null &&
                              sharedPost.authorInfo.avatarUrl!.isNotEmpty
                          ? CachedNetworkImageProvider(
                              sharedPost.authorInfo.avatarUrl!,
                            )
                          : null,
                  child: sharedPost.authorInfo.avatarUrl == null ||
                          sharedPost.authorInfo.avatarUrl!.isEmpty
                      ? Text(
                          sharedPost.authorInfo.displayName[0].toUpperCase(),
                          style: const TextStyle(fontSize: 8),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Text(
                  sharedPost.authorInfo.displayName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const Spacer(),
                Text(
                  _formatTimeAgo(sharedPost.createdAt),
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                ),
              ],
            ),
          ),
          if (sharedPost.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4),
              child: Text(
                sharedPost.content,
                style: const TextStyle(fontSize: 13),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (sharedPost.mediaUrls.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: sharedPost.mediaUrls[0],
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => const Icon(LucideIcons.image),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showCommentsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsBottomSheet(
        postId: _currentPost.id,
        postAuthorId: _currentPost.authorId,
        currentUserId: _currentUserId ?? '',
        onCommentAdded: () {
          _loadCommentCount();
          widget.onPostDeleted?.call();
        },
      ),
    );
  }
}
