/// Các trạng thái chính trong quy trình Kiosk của MiCharity
enum AppMode {
  /// Màn hình Splash kiểm tra cấu hình quán và cập nhật
  splash,

  /// Màn hình chờ nhận thẻ RFID / NFC
  standby,

  /// Màn hình hiển thị WebView trang web thành viên
  working,

  /// Màn hình Cảm ơn hiển thị trong 3 giây sau khi đóng WebView
  finish,

  /// Màn hình thành viên (App gốc gọi API /misaigon/memberInfo)
  member,
}
