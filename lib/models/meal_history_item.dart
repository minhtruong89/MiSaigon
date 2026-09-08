/// Mục lịch sử suất ăn từ API /misaigon/mealHistory
class MealHistoryItem {
  final String thoiGian;
  final String tenQuan;
  final int soSuat;

  MealHistoryItem({
    required this.thoiGian,
    required this.tenQuan,
    required this.soSuat,
  });

  factory MealHistoryItem.fromJson(Map<String, dynamic> json) {
    return MealHistoryItem(
      thoiGian: json['thoi_gian']?.toString() ?? '',
      tenQuan: json['ten_quan']?.toString() ?? '',
      soSuat: (json['so_suat'] is num)
          ? (json['so_suat'] as num).toInt()
          : int.tryParse(json['so_suat']?.toString() ?? '1') ?? 1,
    );
  }
}
