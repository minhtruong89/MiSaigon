/// Kết quả phản hồi từ API /misaigon/checkin (Xác nhận suất ăn)
class CheckinResult {
  final bool isSuccess;
  final String? maKh;
  final String? hoTen;
  final String? tenQuan;
  final int? soSuat;
  final int? suatConLai;
  final String? code;
  final String? message;

  CheckinResult({
    required this.isSuccess,
    this.maKh,
    this.hoTen,
    this.tenQuan,
    this.soSuat,
    this.suatConLai,
    this.code,
    this.message,
  });

  factory CheckinResult.fromJson(Map<String, dynamic> json) {
    final isSuccess = json['result'] == 'success';
    return CheckinResult(
      isSuccess: isSuccess,
      maKh: json['ma_kh']?.toString(),
      hoTen: json['ho_ten']?.toString(),
      tenQuan: json['ten_quan']?.toString(),
      soSuat: (json['so_suat'] is num)
          ? (json['so_suat'] as num).toInt()
          : int.tryParse(json['so_suat']?.toString() ?? '1'),
      suatConLai: (json['suat_con_lai'] is num)
          ? (json['suat_con_lai'] as num).toInt()
          : int.tryParse(json['suat_con_lai']?.toString() ?? '0'),
      code: json['code']?.toString(),
      message: json['message']?.toString(),
    );
  }
}
