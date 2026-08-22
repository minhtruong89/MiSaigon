# MiCharity - Kiosk App (Chương trình từ thiện Mì Sài Gòn 0đ)

Ứng dụng Kiosk tự động hoàn toàn dành cho chương trình từ thiện **Mì Sài Gòn 0đ**, chạy trên **Android** và **iOS** ở chế độ **Portrait**.

---

## 1. Luồng hoạt động (Workflow)

```text
┌───────────────────────────────────────┐
│                STANDBY                │
│                                       │
│        Chương trình từ thiện          │
│            Mì Sài Gòn 0đ              │
│                                       │
│    Vui lòng đưa Thẻ thành viên        │
│         vào trước màn hình            │
│                                       │
│         ┌───────────────────┐         │
│         │   CAMERA PREVIEW  │         │
│         │   (Camera trước)  │         │
│         │                   │         │
│         │  [Đưa thẻ vào đây]│         │
│         └───────────────────┘         │
└───────────────────┬───────────────────┘
                    │ Quét QR hợp lệ
                    │ (Scheme: https, Host: dtri2206.github.io)
                    ▼
          ┌───────────────────┐
          │  BÍP lớn 1 lần    │
          └─────────┬─────────┘
                    ▼
┌───────────────────────────────────────┐
│                WORKING                │
│                                       │
│      WebView toàn màn hình            │
│      URL: https://dtri2206.github.io/ │
│                                       │
│                           [✕ Đóng]    │
└───────────────────┬───────────────────┘
                    │ Nhấn [✕] hoặc Android Back
                    ▼
┌───────────────────────────────────────┐
│                FINISH                 │
│                                       │
│              Cảm ơn bạn               │
│                                       │
│            (Đếm lùi 3 giây)           │
└───────────────────┬───────────────────┘
                    │ Sau 3 giây
                    ▼
┌───────────────────────────────────────┐
│                STANDBY                │
│    Reset state & sẵn sàng quét tiếp   │
└───────────────────────────────────────┘
```

---

## 2. Yêu cầu môi trường

- **Flutter SDK**: >= 3.19.0 (Khuyến nghị Flutter 3.22 trở lên)
- **Dart SDK**: ^3.3.0
- **Android**: Android 5.0+ (minSdkVersion 21)
- **iOS**: iOS 12.0+

---

## 3. Cài đặt và Chạy ứng dụng

### 3.1. Cài đặt dependencies
```bash
flutter pub get
```

### 3.2. Chạy ứng dụng trên thiết bị Android
```bash
flutter run -d android
```

### 3.3. Chạy ứng dụng trên thiết bị / giả lập iOS
```bash
cd ios && pod install && cd ..
flutter run -d ios
```

---

## 4. Cấu hình quyền và Nền tảng

### 4.1. Android (`android/app/src/main/AndroidManifest.xml`)
- **Camera Permission**: `android.permission.CAMERA`
- **Internet Permission**: `android.permission.INTERNET`
- **Wakelock Permission**: `android.permission.WAKE_LOCK` (giữ màn hình kiosk luôn sáng)
- **Portrait Lock**: `android:screenOrientation="portrait"`
- **Native Code**: 100% Java (`MainActivity.java`), không sử dụng Kotlin hay lambda.

### 4.2. iOS (`ios/Runner/Info.plist`)
- **Camera Permission**: `NSCameraUsageDescription`: *"MiCharity cần sử dụng camera để quét Thẻ thành viên QR."*
- **Portrait Lock**: `UISupportedInterfaceOrientations` được cấu hình chỉ cho phép `UIInterfaceOrientationPortrait`.

### 4.3. Âm thanh (Audio Beep)
- Asset âm thanh bíp tần số cao: `assets/audio/qr_success.wav` được khai báo trong `pubspec.yaml`.
- Có cơ chế fallback qua `SystemSoundType.alert` nếu phần cứng gặp sự cố.

---

## 5. Kiểm thử (Testing)

### 5.1. Chạy phân tích mã nguồn (Lint check)
```bash
flutter analyze
```

### 5.2. Chạy toàn bộ Unit Tests & State Machine Tests
```bash
flutter test
```

Bao gồm:
- **`test/qr_validation_test.dart`**: Kiểm tra nghiêm ngặt whitelist URL (`https://dtri2206.github.io/...`) và chặn mọi URL giả mạo/scheme nguy hiểm.
- **`test/app_controller_test.dart`**: Kiểm tra bộ máy trạng thái STANDBY → WORKING → FINISH → STANDBY, chống duplicate frame quét liên tiếp, và quản lý timer 3 giây.
- **`test/widget_test.dart`**: Smoke test hiển thị giao diện Kiosk ban đầu.

---

## 6. Đóng gói ứng dụng (Build Release)

### 6.1. Build APK (Android)
```bash
flutter build apk --release
```
Tập tin APK xuất xưởng sẽ nằm tại: `build/app/outputs/flutter-apk/app-release.apk`.

### 6.2. Build App Bundle (Google Play Kiosk / MDM)
```bash
flutter build appbundle --release
```

### 6.3. Build iOS (IPA)
```bash
flutter build ipa --release
```

---

## 7. Cấu trúc thư mục

```text
micharity/
├── android/                           # Cấu hình Android thuần Java (không Kotlin)
├── ios/                               # Cấu hình iOS (Camera & Portrait lock)
├── assets/
│   └── audio/
│       └── qr_success.wav             # File âm thanh BÍP chất lượng cao
├── lib/
│   ├── main.dart                      # Khởi tạo portrait & wakelock
│   ├── app.dart                       # Root MaterialApp & ListenableBuilder state switch
│   ├── models/
│   │   └── app_mode.dart              # Enum AppMode: standby, working, finish
│   ├── controllers/
│   │   └── app_controller.dart        # Kiosk state manager & duplicate debounce
│   ├── services/
│   │   ├── qr_service.dart            # Whitelist URL validation (Uri parser)
│   │   └── sound_service.dart         # AudioPlayer service & system fallback
│   ├── screens/
│   │   ├── standby_screen.dart        # Màn hình chờ quét QR kèm Camera preview
│   │   ├── working_screen.dart        # Màn hình in-app WebView kèm PopScope & Close button
│   │   └── finish_screen.dart         # Màn hình "Cảm ơn bạn" đếm lùi 3s
│   └── widgets/
│       ├── camera_preview_widget.dart # MobileScanner tích hợp camera trước & fallback
│       └── qr_scan_overlay.dart       # Khung ngắm định vị thẻ thành viên
└── test/
    ├── qr_validation_test.dart        # Unit test bảo mật URL
    ├── app_controller_test.dart       # Unit test State machine & chống quét lặp
    └── widget_test.dart               # Smoke test widget
```
