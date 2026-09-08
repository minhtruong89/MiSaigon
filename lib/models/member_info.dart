/// Thông tin thành viên nhận từ API /misaigon/memberInfo
class MemberInfo {
  final String maKh;
  final String hoTen;
  final String? soDienThoai;
  final int suatDuocCap;
  final int suatConLai;
  final String? qrLink;

  MemberInfo({
    required this.maKh,
    required this.hoTen,
    this.soDienThoai,
    required this.suatDuocCap,
    required this.suatConLai,
    this.qrLink,
  });

  factory MemberInfo.fromJson(Map<String, dynamic> json) {
    return MemberInfo(
      maKh: json['ma_kh']?.toString() ?? '',
      hoTen: json['ho_ten']?.toString() ?? '',
      soDienThoai: json['so_dien_thoai']?.toString(),
      suatDuocCap: (json['suat_duoc_cap'] is num)
          ? (json['suat_duoc_cap'] as num).toInt()
          : int.tryParse(json['suat_duoc_cap']?.toString() ?? '0') ?? 0,
      suatConLai: (json['suat_con_lai'] is num)
          ? (json['suat_con_lai'] as num).toInt()
          : int.tryParse(json['suat_con_lai']?.toString() ?? '0') ?? 0,
      qrLink: json['qr_link']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ma_kh': maKh,
      'ho_ten': hoTen,
      'so_dien_thoai': soDienThoai,
      'suat_duoc_cap': suatDuocCap,
      'suat_con_lai': suatConLai,
      'qr_link': qrLink,
    };
  }
}
