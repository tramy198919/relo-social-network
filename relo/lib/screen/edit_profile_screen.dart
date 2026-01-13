import 'package:flutter/material.dart';
import 'package:relo/services/service_locator.dart';
import 'package:relo/services/user_service.dart';
import 'package:relo/utils/show_notification.dart';

class EditProfileScreen extends StatefulWidget {
  final String initialDisplayName;
  final String initialBio;
  final bool isPublicEmail;

  const EditProfileScreen({
    super.key,
    required this.initialDisplayName,
    required this.initialBio,
    required this.isPublicEmail,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final UserService _userService = ServiceLocator.userService;
  late final TextEditingController _displayNameController;
  late final TextEditingController _bioController;
  bool _isPublicEmail = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: widget.initialDisplayName,
    );
    _bioController = TextEditingController(text: widget.initialBio);
    _isPublicEmail = widget.isPublicEmail;
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _userService.updateProfile(
        displayName: _displayNameController.text.trim(),
        bio: _bioController.text.trim(),
        isPublicEmail: _isPublicEmail,
      );

      if (mounted) {
        await ShowNotification.showToast(
          context,
          'Cập nhật thông tin thành công',
        );
        Navigator.pop(context, true); // Return true on success
      }
    } catch (e) {
      if (mounted) {
        await ShowNotification.showToast(
          context,
          'Không thể cập nhật thông tin',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF7A2FC0),
        title: const Text(
          'Chỉnh sửa thông tin',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context, false),
        ),
        actions: [
          TextButton(
            onPressed: _updateProfile,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Lưu',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            TextField(
              controller: _displayNameController,
              maxLength: 50,
              decoration: InputDecoration(
                labelText: 'Tên hiển thị',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.person, color: Color(0xFF7A2FC0)),
                helperText: 'Tối đa 50 ký tự',
                counterText: '',
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _bioController,
              maxLines: 3,
              maxLength: 150,
              decoration: InputDecoration(
                labelText: 'Giới thiệu bản thân',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                helperText: 'Tối đa 150 ký tự',
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Quyền riêng tư',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF7A2FC0),
              ),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              title: const Text('Công khai Email'),
              subtitle: const Text('Cho phép người khác thấy email của bạn'),
              value: _isPublicEmail,
              activeColor: const Color(0xFF7A2FC0),
              onChanged: (bool value) {
                setState(() {
                  _isPublicEmail = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
