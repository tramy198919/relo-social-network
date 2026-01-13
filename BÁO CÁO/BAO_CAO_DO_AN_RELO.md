# HƯỚNG DẪN: CÁCH CHUYỂN NỘI DUNG NÀY SANG WORD
1. Mở file này bằng một trình đọc văn bản (Notepad, VS Code, v.v.).
2. Sao chép (Ctrl + A, Ctrl + C) toàn bộ nội dung phía dưới.
3. Mở Microsoft Word, dán (Ctrl + V) vào.
4. Chỉnh sửa định dạng (Font, Căn lề) theo ý muốn.

---

# [TRANG BÌA]

**BỘ GIÁO DỤC VÀ ĐÀO TẠ**
**TRƯỜNG ĐẠI HỌC CÔNG NGHỆ TP. HCM**

---
(Chèn Logo HUTECH tại đây)
---

**BÁO CÁO ĐỒ ÁN MÔN HỌC**

# <RELO SOCIAL NETWORK - MẠNG XÃ HỘI RELO>

**Ngành:** CÔNG NGHỆ THÔNG TIN
**Môn học:** LẬP TRÌNH TRÊN THIẾT BỊ DI ĐỘNG

**Giảng viên hướng dẫn:** Nguyễn Mạnh Hùng

**Sinh viên thực hiện:**
1.  Trần Ngọc Huy       - 2380614831 - 23DTHA7
2.  Nguyễn Huỳnh Bình   - 2380600201 - 23DTHA7
3.  Nguyễn Minh Huy     - 2280601188 - 23DTHA7
4.  Nguyễn Thị Trà My    - 2280601981 - 23DTHB1

**TP. Hồ Chí Minh, 2025**

---

## 1. LỜI NÓI ĐẦU
Trong thời đại công nghệ số bùng nổ, nhu cầu kết nối và chia sẻ thông tin của con người ngày càng trở nên thiết yếu. Các thiết bị di động đã trở thành vật bất ly thân, mở ra cơ hội phát triển các nền tảng mạng xã hội tiện lợi và đa năng. Đồ án "RELO Social Network" là kết quả của quá trình nghiên cứu và thực hành môn học "Lập trình trên thiết bị di động", nhằm tạo ra một không gian kết nối hiện đại, mượt mà và bảo mật cho người dùng.

## 2. LÝ DO CHỌN ĐỀ TÀI
Mặc dù hiện nay có rất nhiều mạng xã hội lớn, nhưng việc tự xây dựng một hệ thống mạng xã hội từ đầu giúp nhóm sinh viên nắm vững quy trình phát triển phần mềm toàn diện:
- Từ việc thiết kế UI/UX trên thiết bị di động.
- Đến việc xây dựng hệ thống Backend xử lý dữ liệu thời gian thực.
- Tích hợp các tính năng giải trí (Game) để tăng tính tương tác.
- Giải quyết các bài toán về hiệu năng và trải nghiệm người dùng trên nền tảng di động.

## 3. MỤC TIÊU CỦA ĐỀ TÀI
- **Xây dựng ứng dụng di động**: Cho phép người dùng đăng ký, đăng nhập và quản lý thông tin cá nhân.
- **Tính năng tương tác cốt lõi**: Đăng tải bài viết, bình luận, và theo dõi bạn bè.
- **Hệ thống tin nhắn thời gian thực**: Cho phép nhắn tin và gọi điện giữa các người dùng.
- **Tích hợp khu vực giải trí (GAME HUB)**: Cung cấp các trò chơi như Relo Bird, Caro (chơi với máy và chơi qua mạng) để tăng thời gian giữ chân người dùng.
- **Đồng bộ hóa dữ liệu**: Đảm bảo trải nghiệm nhất quán giữa các thiết bị thông qua hệ thống API mạnh mẽ.

## 4. ĐỐI TƯỢNG VÀ PHẠM VI NGHIÊN CỨU
- **Đối tượng nghiên cứu**: Quy trình phát triển ứng dụng di động bằng Flutter (Frontend) và FastAPI (Backend), hệ thống cơ sở dữ liệu MongoDB và giao tiếp thời gian thực qua WebSockets.
- **Phạm vi nghiên cứu**: Ứng dụng chạy trên nền tảng Android (Android Studio), tập trung vào các tính năng mạng xã hội cơ bản và tích hợp các Mini Game.

## 5. CÔNG NGHỆ SỬ DỤNG
- **Frontend**: Flutter SDK, Dart language.
- **Backend**: FastAPI (Python), Beanie ODM.
- **Database**: MongoDB cloud.
- **Real-time**: WebSockets (cho Chat và Game multiplayer).
- **Storage**: Cloudinary/Local storage cho hình ảnh và tệp tin.

## 6. CÁC TÍNH NĂNG CHÍNH ĐÃ CÀI ĐẶT
- Quản lý tài khoản và hồ sơ người dùng.
- Bảng tin (Newsfeed) với khả năng đăng bài, tương tác.
- Trò chuyện (Chat) 1-1 và theo nhóm.
- Trung tâm trò chơi (Game Hub) với Relo Bird và Caro đa chế độ.
- Thông báo (Notification) thời gian thực.

## 7. KẾT LUẬN
Đồ án đã cơ bản hoàn thành các mục tiêu đề ra, tạo được một ứng dụng mạng xã hội có tính thẩm mỹ và chức năng ổn định. Qua đó, nhóm đã học hỏi được cách vận hành hệ thống client-server và xử lý các vấn đề kỹ thuật phức tạp trong lập trình di động.
