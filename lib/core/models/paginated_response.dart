class PaginatedResponse<T> {
  final int currentPage;
  final List<T> data;
  final String? firstPageUrl;
  final int? from;
  final int lastPage;
  final String? lastPageUrl;
  final String? nextPageUrl;
  final String? path;
  final int perPage;
  final String? prevPageUrl;
  final int? to;
  final int total;

  PaginatedResponse({
    required this.currentPage,
    required this.data,
    this.firstPageUrl,
    this.from,
    required this.lastPage,
    this.lastPageUrl,
    this.nextPageUrl,
    this.path,
    required this.perPage,
    this.prevPageUrl,
    this.to,
    required this.total,
  });

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    // Fungsi pembantu untuk konversi int yang aman
    int toInt(dynamic value, int defaultValue) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      return int.tryParse(value.toString()) ?? defaultValue;
    }

    return PaginatedResponse<T>(
      // Gunakan fungsi pembantu agar tidak crash jika null
      currentPage: toInt(json['current_page'], 1),

      // Pastikan data adalah list, jika null beri list kosong []
      data: (json['data'] as List?)?.map((item) {
            try {
              return fromJsonT(item is Map<String, dynamic>
                  ? item
                  : Map<String, dynamic>.from(item as Map));
            } catch (e) {
              print('🔍 DEBUG: Error parsing item: $e');
              rethrow;
            }
          }).toList() ??
          [],

      // Gunakan toString() lebih aman daripada 'as String?'
      firstPageUrl: json['first_page_url']?.toString(),
      from: json['from'] != null ? toInt(json['from'], 0) : null,

      lastPage: toInt(json['last_page'], 1),
      lastPageUrl: json['last_page_url']?.toString(),
      nextPageUrl: json['next_page_url']?.toString(),
      path: json['path']?.toString(),

      perPage: toInt(json['per_page'], 15),
      prevPageUrl: json['prev_page_url']?.toString(),
      to: json['to'] != null ? toInt(json['to'], 0) : null,

      total: toInt(json['total'], 0),
    );
  }

  bool get hasNextPage => nextPageUrl != null;
  bool get hasPrevPage => prevPageUrl != null;
  bool get isFirstPage => currentPage == 1;
  bool get isLastPage => currentPage == lastPage;
}
