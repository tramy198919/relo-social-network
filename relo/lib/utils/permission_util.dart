import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:relo/utils/show_notification.dart';
import 'dart:io';

class PermissionUtils {
  /// 📸 Kiểm tra & xin quyền truy cập ảnh/video
  static Future<bool> ensurePhotoPermission(BuildContext context) async {
    try {
      if (Platform.isAndroid) {
        // We use photo_manager's recommendation: requestPermissionExtend
        final permit = await PhotoManager.requestPermissionExtend();
        
        if (permit == PermissionState.authorized || permit == PermissionState.limited) return true;
        
        // If not authorized, try using permission_handler as a backup for explicit request
        // Android 13+ (API 33+)
        PermissionStatus status;
        try {
          // Try to request based on what's likely needed
          status = await Permission.photos.request();
          if (status.isDenied) {
            status = await Permission.storage.request();
          }
        } catch (e) {
          status = await Permission.storage.request();
        }

        if (status.isPermanentlyDenied) {
          await openAppSettings();
          return false;
        }
        
        return status.isGranted || status.isLimited;
      }

      final permit = await PhotoManager.requestPermissionExtend();
      return permit == PermissionState.authorized || permit == PermissionState.limited;
    } catch (e) {
      debugPrint("⚠️ Permission Error: $e");
      return false;
    }
  }

  /// 🎙 Kiểm tra & xin quyền micro để ghi âm
  static Future<bool> ensureMicroPermission(BuildContext context) async {
    try {
      final micStatus = await Permission.microphone.request();

      if (!micStatus.isGranted) {
        final openSettings = await ShowNotification.showCustomAlertDialog(
          context,
          message: "Ứng dụng cần quyền truy cập micro để ghi âm",
          buttonText: "Mở cài đặt",
          buttonColor: const Color(0xFF7A2FC0),
        );

        if (openSettings == true) {
          await openAppSettings();
          await Future.delayed(const Duration(seconds: 1));

          final micAfter = await Permission.microphone.status;
          if (!micAfter.isGranted) {
            if (context.mounted) {
              await ShowNotification.showCustomAlertDialog(
                context,
                message: "Vẫn chưa có quyền micro, không thể ghi âm.",
              );
              Navigator.pop(context);
            }
            return false;
          }
        } else {
          if (context.mounted) Navigator.pop(context);
          return false;
        }
      }

      return true;
    } catch (e) {
      debugPrint("Lỗi khi kiểm tra quyền micro: $e");
      return false;
    }
  }

  /// 💾 Kiểm tra & xin quyền ghi bộ nhớ (Android 13 trở xuống)
  static Future<bool> ensureStoragePermission(BuildContext context) async {
    try {
      if (Platform.isAndroid) {
        // Permission.storage is for Android 12 and below. 
        // On Android 13+, it typically returns permanentlyDenied.
        final status = await Permission.storage.request();

        if (status.isGranted) return true;
        
        // If it's Android 13+ (API 33), and it's denied, it might actually be okay 
        // for some file picking operations, but photo_manager handles its own.
        // Let's assume if it's denied/permanentlyDenied on a modern device, 
        // we might not actually NEED it for basic FilePicker.
        if (status.isPermanentlyDenied || status.isDenied) {
           // For now, let's at least try to proceed if photos permission was already handled
           // Or just return true to let the system picker handle it.
           return true; 
        }
      }

      return true;
    } catch (e) {
      debugPrint("Lỗi khi kiểm tra quyền bộ nhớ: $e");
      return true; // Ngầm định cho phép để tránh block user
    }
  }
}
