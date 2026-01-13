import 'author_info.dart';
import 'reaction.dart';

class Post {
  final String id;
  final String authorId;
  final AuthorInfo authorInfo;
  final String content;
  final List<String> mediaUrls;
  final List<Reaction> reactions;
  final Map<String, int> reactionCounts;
  final DateTime createdAt;
  final Post? sharedPost;
  final bool isLiked;

  Post({
    required this.id,
    required this.authorId,
    required this.authorInfo,
    required this.content,
    required this.mediaUrls,
    required this.reactions,
    required this.reactionCounts,
    required this.createdAt,
    this.sharedPost,
    this.isLiked = false,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    try {
      return Post(
        id: json['id'] ?? json['_id'] ?? '',
        authorId: json['authorId'] ?? '',
        authorInfo: json['authorInfo'] != null
            ? AuthorInfo.fromJson(json['authorInfo'])
            : AuthorInfo(displayName: 'Người dùng', avatarUrl: null),
        content: json['content'] ?? '',
        mediaUrls: (json['mediaUrls'] is List)
            ? List<String>.from(json['mediaUrls'])
            : [],
        reactions: (json['reactions'] is List)
            ? (json['reactions'] as List<dynamic>)
                  .map((r) {
                    try {
                      return Reaction.fromJson(r);
                    } catch (e) {
                      print('Error parsing reaction: $e');
                      return null;
                    }
                  })
                  .whereType<Reaction>()
                  .toList()
            : [],
        reactionCounts: (json['reactionCounts'] is Map)
            ? Map<String, int>.from(json['reactionCounts'])
            : {},
        createdAt: json['createdAt'] is String
            ? DateTime.parse(json['createdAt'])
            : DateTime.now(),
        sharedPost: json['sharedPost'] != null
            ? Post.fromJson(json['sharedPost'])
            : null,
        isLiked: json['isLiked'] ?? false,
      );
    } catch (e) {
      print('Error parsing Post: $e');
      print('Post JSON: $json');
      // Return a default post with minimal data
      return Post(
        id: json['id'] ?? json['_id'] ?? '',
        authorId: json['authorId'] ?? '',
        authorInfo: AuthorInfo(displayName: 'Người dùng', avatarUrl: null),
        content: json['content']?.toString() ?? '',
        mediaUrls: [],
        reactions: [],
        reactionCounts: {},
        createdAt: DateTime.now(),
        sharedPost: json['sharedPost'] != null
            ? Post.fromJson(json['sharedPost'])
            : null,
        isLiked: json['isLiked'] ?? false,
      );
    }
  }
}
