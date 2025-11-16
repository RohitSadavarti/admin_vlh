import 'dart:async';

class OrderUpdateService {
  // Singleton setup
  static final OrderUpdateService _instance = OrderUpdateService._internal();
  factory OrderUpdateService() => _instance;
  OrderUpdateService._internal();

  // A "broadcast" stream controller can have many listeners
  final _streamController = StreamController<void>.broadcast();

  // This is what your screens will listen to
  Stream<void> get stream => _streamController.stream;

  // This is what the popup will call
  void notifyOrderUpdated() {
    _streamController.add(null);
  }

  void dispose() {
    _streamController.close();
  }
}
