class AdminReport {
  final String period;
  final DateRange dateRange;
  final ReportSummary summary;
  final List<TopProduct> topProducts;
  final List<DailyBreakdown> dailyBreakdown;

  AdminReport({
    required this.period,
    required this.dateRange,
    required this.summary,
    required this.topProducts,
    required this.dailyBreakdown,
  });

  factory AdminReport.fromJson(Map<String, dynamic> json) {
    return AdminReport(
      period: json['period'] ?? '',
      dateRange: DateRange.fromJson(json['date_range'] ?? {}),
      summary: ReportSummary.fromJson(json['summary'] ?? {}),
      topProducts: (json['top_products'] as List<dynamic>?)
              ?.map((e) => TopProduct.fromJson(e))
              .toList() ??
          [],
      dailyBreakdown: (json['daily_breakdown'] as List<dynamic>?)
              ?.map((e) => DailyBreakdown.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class DateRange {
  final String start;
  final String end;

  DateRange({required this.start, required this.end});

  factory DateRange.fromJson(Map<String, dynamic> json) {
    return DateRange(
      start: json['start'] ?? '',
      end: json['end'] ?? '',
    );
  }
}

class ReportSummary {
  final int totalOrders;
  final double totalRevenue;
  final int completedOrders;
  final int pendingOrders;
  final int cancelledOrders;

  ReportSummary({
    required this.totalOrders,
    required this.totalRevenue,
    required this.completedOrders,
    required this.pendingOrders,
    required this.cancelledOrders,
  });

  factory ReportSummary.fromJson(Map<String, dynamic> json) {
    return ReportSummary(
      totalOrders: _parseInt(json['total_orders']),
      totalRevenue: _parseDouble(json['total_revenue']),
      completedOrders: _parseInt(json['completed_orders']),
      pendingOrders: _parseInt(json['pending_orders']),
      cancelledOrders: _parseInt(json['cancelled_orders']),
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

class TopProduct {
  final int productId;
  final String productName;
  final double totalQuantity;
  final double totalRevenue;

  TopProduct({
    required this.productId,
    required this.productName,
    required this.totalQuantity,
    required this.totalRevenue,
  });

  factory TopProduct.fromJson(Map<String, dynamic> json) {
    return TopProduct(
      productId: _parseInt(json['product_id']),
      productName: json['product_name'] ?? '',
      totalQuantity: _parseDouble(json['total_quantity']),
      totalRevenue: _parseDouble(json['total_revenue']),
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

class DailyBreakdown {
  final String date;
  final int totalOrders;
  final double totalRevenue;

  DailyBreakdown({
    required this.date,
    required this.totalOrders,
    required this.totalRevenue,
  });

  factory DailyBreakdown.fromJson(Map<String, dynamic> json) {
    return DailyBreakdown(
      date: json['date'] ?? '',
      totalOrders: _parseInt(json['total_orders']),
      totalRevenue: _parseDouble(json['total_revenue']),
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
