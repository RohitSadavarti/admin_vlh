import 'dart:convert';

class PrinterDevice {
  final String id;
  final String name;
  final String address;
  final DateTime pairedAt;

  PrinterDevice({
    required this.id,
    required this.name,
    required this.address,
    required this.pairedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'pairedAt': pairedAt.toIso8601String(),
    };
  }

  factory PrinterDevice.fromJson(Map<String, dynamic> json) {
    return PrinterDevice(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      pairedAt: DateTime.parse(json['pairedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  @override
  String toString() => 'PrinterDevice(id: $id, name: $name, address: $address)';
}
