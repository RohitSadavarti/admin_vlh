// lib/models/analytics_data.dart

class AnalyticsData {
  final KeyMetrics keyMetrics;
  final ChartData mostOrderedItems;
  final ChartData paymentMethodDistribution;
  final ChartData orderStatusDistribution;
  final ChartData ordersByHour;
  final ChartData customerRevenueSplit;
  final DayWiseRevenue dayWiseRevenue;
  final DayWiseMenu dayWiseMenu;
  final List<TableOrder> tableData;

  AnalyticsData({
    required this.keyMetrics,
    required this.mostOrderedItems,
    required this.paymentMethodDistribution,
    required this.orderStatusDistribution,
    required this.ordersByHour,
    required this.customerRevenueSplit,
    required this.dayWiseRevenue,
    required this.dayWiseMenu,
    required this.tableData,
  });

  factory AnalyticsData.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return AnalyticsData(
        keyMetrics:
            KeyMetrics(totalRevenue: 0, totalOrders: 0, averageOrderValue: 0),
        mostOrderedItems: ChartData(labels: [], data: []),
        paymentMethodDistribution: ChartData(labels: [], data: []),
        orderStatusDistribution: ChartData(labels: [], data: []),
        ordersByHour: ChartData(labels: [], data: []),
        customerRevenueSplit: ChartData(labels: [], data: []),
        dayWiseRevenue:
            DayWiseRevenue(labels: [], revenueData: [], ordersData: []),
        dayWiseMenu: DayWiseMenu(labels: [], datasets: []),
        tableData: [],
      );
    }
    
    print('[v0] Full Analytics JSON: $json');
    print('[v0] mostOrderedItems: ${json['most_ordered_items']}');
    print('[v0] paymentMethodDist: ${json['payment_method_distribution']}');
    print('[v0] ordersByHour: ${json['orders_by_hour']}');
    print('[v0] dayWiseRevenue: ${json['day_wise_revenue']}');
    print('[v0] dayWiseMenu: ${json['day_wise_menu']}');
    
    return AnalyticsData(
      keyMetrics: KeyMetrics.fromJson(json['key_metrics']),
      mostOrderedItems: ChartData.fromJson(json['most_ordered_items']),
      paymentMethodDistribution:
          ChartData.fromJson(json['payment_method_distribution']),
      orderStatusDistribution:
          ChartData.fromJson(json['order_status_distribution']),
      ordersByHour: ChartData.fromJson(json['orders_by_hour']),
      customerRevenueSplit: ChartData.fromJson(json['customerRevenueSplit']),
      dayWiseRevenue: DayWiseRevenue.fromJson(json['day_wise_revenue']),
      dayWiseMenu: DayWiseMenu.fromJson(json['day_wise_menu']),
      tableData: json['table_data'] is List
          ? (json['table_data'] as List)
              .map((e) => TableOrder.fromJson(e))
              .toList()
          : [],
    );
  }
}

class KeyMetrics {
  final double totalRevenue;
  final int totalOrders;
  final double averageOrderValue;

  KeyMetrics({
    required this.totalRevenue,
    required this.totalOrders,
    required this.averageOrderValue,
  });

  factory KeyMetrics.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return KeyMetrics(
          totalRevenue: 0.0, totalOrders: 0, averageOrderValue: 0.0);
    }
    return KeyMetrics(
      totalRevenue: double.tryParse(json['total_revenue'].toString()) ?? 0.0,
      totalOrders: json['total_orders'] is int
          ? json['total_orders']
          : int.tryParse(json['total_orders'].toString()) ?? 0,
      averageOrderValue:
          double.tryParse(json['average_order_value'].toString()) ?? 0.0,
    );
  }
}

class ChartData {
  final List<String> labels;
  final List<double> data;

  ChartData({required this.labels, required this.data});

  factory ChartData.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return ChartData(labels: [], data: []);
    }
    
    List<String> labels = [];
    List<double> data = [];
    
    // Try different key patterns for labels
    if (json['labels'] != null && json['labels'] is List) {
      labels = List<String>.from(json['labels'].map((e) => e.toString()));
    } else if (json['x_labels'] != null && json['x_labels'] is List) {
      labels = List<String>.from(json['x_labels'].map((e) => e.toString()));
    }
    
    // Try different key patterns for data
    if (json['data'] != null && json['data'] is List) {
      data = List<num>.from(json['data']).map((n) => n.toDouble()).toList();
    } else if (json['values'] != null && json['values'] is List) {
      data = List<num>.from(json['values']).map((n) => n.toDouble()).toList();
    } else if (json['counts'] != null && json['counts'] is List) {
      data = List<num>.from(json['counts']).map((n) => n.toDouble()).toList();
    }
    
    print('[v0] ChartData parsed - labels: ${labels.length}, data: ${data.length}');
    
    return ChartData(labels: labels, data: data);
  }
}

class DayWiseRevenue {
  final List<String> labels;
  final List<double> revenueData;
  final List<double> ordersData;

  DayWiseRevenue({
    required this.labels,
    required this.revenueData,
    required this.ordersData,
  });

  factory DayWiseRevenue.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return DayWiseRevenue(labels: [], revenueData: [], ordersData: []);
    }
    
    List<String> labels = [];
    List<double> revenueData = [];
    List<double> ordersData = [];
    
    if (json['labels'] != null && json['labels'] is List) {
      labels = List<String>.from(json['labels'].map((e) => e.toString()));
    }
    
    if (json['revenue_data'] != null && json['revenue_data'] is List) {
      revenueData = List<num>.from(json['revenue_data'])
          .map((n) => n.toDouble())
          .toList();
    } else if (json['revenue'] != null && json['revenue'] is List) {
      revenueData = List<num>.from(json['revenue'])
          .map((n) => n.toDouble())
          .toList();
    }
    
    if (json['orders_data'] != null && json['orders_data'] is List) {
      ordersData = List<num>.from(json['orders_data'])
          .map((n) => n.toDouble())
          .toList();
    } else if (json['orders'] != null && json['orders'] is List) {
      ordersData = List<num>.from(json['orders'])
          .map((n) => n.toDouble())
          .toList();
    }
    
    print('[v0] DayWiseRevenue parsed - labels: ${labels.length}, revenue: ${revenueData.length}, orders: ${ordersData.length}');
    
    return DayWiseRevenue(labels: labels, revenueData: revenueData, ordersData: ordersData);
  }
}

class DayWiseMenu {
  final List<String> labels;
  final List<MenuDataset> datasets;

  DayWiseMenu({required this.labels, required this.datasets});

  factory DayWiseMenu.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return DayWiseMenu(labels: [], datasets: []);
    }
    
    List<String> labels = [];
    List<MenuDataset> datasets = [];
    
    if (json['labels'] != null && json['labels'] is List) {
      labels = List<String>.from(json['labels'].map((e) => e.toString()));
    }
    
    if (json['datasets'] is List) {
      datasets = (json['datasets'] as List)
          .map((e) => MenuDataset.fromJson(e))
          .toList();
    }
    
    print('[v0] DayWiseMenu parsed - labels: ${labels.length}, datasets: ${datasets.length}');
    
    return DayWiseMenu(labels: labels, datasets: datasets);
  }
}

class MenuDataset {
  final String label;
  final List<double> data;
  final String backgroundColor;

  MenuDataset({
    required this.label,
    required this.data,
    required this.backgroundColor,
  });

  factory MenuDataset.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return MenuDataset(label: '', data: [], backgroundColor: '');
    }
    return MenuDataset(
      label: json['label']?.toString() ?? '',
      data: json['data'] is List
          ? List<num>.from(json['data']).map((n) => n.toDouble()).toList()
          : [],
      backgroundColor: json['backgroundColor']?.toString() ?? '',
    );
  }
}

class TableOrder {
  final String createdAt;
  final String orderId;
  final String itemsText;
  final double totalPrice;
  final String paymentMethod;
  final String orderStatus;

  TableOrder({
    required this.createdAt,
    required this.orderId,
    required this.itemsText,
    required this.totalPrice,
    required this.paymentMethod,
    required this.orderStatus,
  });

  factory TableOrder.fromJson(Map<String, dynamic> json) {
    return TableOrder(
      createdAt: json['created_at']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      itemsText: json['items_text']?.toString() ?? '',
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method']?.toString() ?? '',
      orderStatus: json['order_status']?.toString() ?? '',
    );
  }
}
