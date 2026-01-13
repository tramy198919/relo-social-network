import 'package:flutter/material.dart';
import 'package:relo/models/post.dart';
import 'package:relo/services/service_locator.dart';
import 'package:relo/widgets/posts/post_card.dart';

class PostDetailsScreen extends StatefulWidget {
  final String postId;

  const PostDetailsScreen({super.key, required this.postId});

  @override
  State<PostDetailsScreen> createState() => _PostDetailsScreenState();
}

class _PostDetailsScreenState extends State<PostDetailsScreen> {
  late Future<Post> _postFuture;

  @override
  void initState() {
    super.initState();
    _loadPost();
  }

  void _loadPost() {
    setState(() {
      _postFuture = ServiceLocator.postService.getPost(widget.postId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bài viết'),
        centerTitle: true,
      ),
      body: FutureBuilder<Post>(
        future: _postFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Không thể tải bài viết',
                    style: TextStyle(color: Colors.grey[700], fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _loadPost,
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('Bài viết không tồn tại'));
          }

          final post = snapshot.data!;
          return SingleChildScrollView(
            child: PostCard(post: post),
          );
        },
      ),
    );
  }
}
