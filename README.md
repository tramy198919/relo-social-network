# Relo Social Network

Dự án mạng xã hội Relo bao gồm 2 thành phần chính:

## 1. Mobile App (`relo/`)
- Ứng dụng Flutter (Android/iOS).
- Để chạy app:
  ```bash
  cd relo
  flutter pub get
  flutter run
  ```
- **Android Studio**: Open thư mục `relo/`.

## 2. Backend (`backend/`)
- API Server (FastAPI + MongoDB).
- Để chạy server:
  ```bash
  cd backend
  uvicorn main:app --reload --host 0.0.0.0 --port 5173
  ```

## Yêu cầu
- Flutter SDK 3.8+
- Python 3.9+
- MongoDB Atlas (đã cấu hình)
