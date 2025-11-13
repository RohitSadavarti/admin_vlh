import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/printer_device.dart';

class PrinterService with ChangeNotifier {
  BluetoothDevice? _bluetoothDevice;
  BluetoothCharacteristic? _writeCharacteristic;
  PrinterDevice? _connectedPrinter;
  bool _isConnecting = false;
  bool _isConnected = false;
  String? _errorMessage;

  // Getters
  PrinterDevice? get connectedPrinter => _connectedPrinter;
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String? get errorMessage => _errorMessage;

  PrinterService() {
    _loadSavedPrinter();
  }

  // Load previously paired printer from shared preferences
  Future<void> _loadSavedPrinter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final printerJson = prefs.getString('saved_printer');
      if (printerJson != null) {
        _connectedPrinter = PrinterDevice.fromJson(jsonDecode(printerJson));
        print('[v0] Loaded saved printer: ${_connectedPrinter?.name}');
        notifyListeners();
      }
    } catch (e) {
      print('[v0] Error loading saved printer: $e');
    }
  }

  // Get all available Bluetooth devices
  Future<List<PrinterDevice>> getAvailableDevices() async {
    try {
      _errorMessage = null;
      final List<PrinterDevice> devices = [];

      final adapterState = await FlutterBluePlus.adapterState.first;
      final bool isBluetoothOn = adapterState == BluetoothAdapterState.on;

      if (!isBluetoothOn) {
        _errorMessage = 'Bluetooth is turned off';
        notifyListeners();
        return devices;
      }

      // Get all connected devices from system
      final connectedDevices = await FlutterBluePlus.connectedDevices;

      for (var device in connectedDevices) {
        devices.add(PrinterDevice(
          id: device.remoteId.str,
          name:
              device.platformName.isNotEmpty ? device.platformName : 'Unknown',
          address: device.remoteId.str,
          pairedAt: DateTime.now(),
        ));
      }

      print('[v0] Found ${devices.length} available Bluetooth devices');
      return devices;
    } catch (e) {
      _errorMessage = 'Failed to get devices: $e';
      print('[v0] Error getting devices: $e');
      notifyListeners();
      return [];
    }
  }

  // Connect to a specific printer device
  Future<bool> connectToDevice(PrinterDevice device) async {
    try {
      _isConnecting = true;
      _errorMessage = null;
      notifyListeners();

      print('[v0] Connecting to printer: ${device.name}');

      _bluetoothDevice =
          BluetoothDevice(remoteId: DeviceIdentifier(device.address));

      await _bluetoothDevice!.connect(timeout: const Duration(seconds: 10));
      print('[v0] Connected to device, discovering services...');

      // Discover services and characteristics
      List<BluetoothService> services =
          await _bluetoothDevice!.discoverServices();

      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.write ||
              characteristic.properties.writeWithoutResponse) {
            _writeCharacteristic = characteristic;
            print('[v0] Found write characteristic: ${characteristic.uuid}');
            break;
          }
        }
        if (_writeCharacteristic != null) break;
      }

      if (_writeCharacteristic == null) {
        throw Exception('No write characteristic found on printer');
      }

      _isConnected = true;
      _isConnecting = false;

      // Save printer to local storage
      _connectedPrinter = device;
      await _savePrinterLocally(device);

      print('[v0] Successfully connected to ${device.name}');
      notifyListeners();
      return true;
    } catch (e) {
      _isConnecting = false;
      _isConnected = false;
      _bluetoothDevice = null;
      _writeCharacteristic = null;
      _errorMessage = 'Connection failed: $e';
      print('[v0] Connection error: $e');
      notifyListeners();
      return false;
    }
  }

  // Save printer to shared preferences
  Future<void> _savePrinterLocally(PrinterDevice printer) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_printer', jsonEncode(printer.toJson()));
      print('[v0] Saved printer: ${printer.name}');
    } catch (e) {
      print('[v0] Error saving printer: $e');
    }
  }

  // Send raw bytes to printer
  Future<void> _sendRawBytes(List<int> bytes) async {
    if (!_isConnected || _writeCharacteristic == null) {
      throw Exception('Not connected to printer');
    }
    await _writeCharacteristic!.write(bytes, withoutResponse: false);
    await Future.delayed(const Duration(
        milliseconds: 100)); // Small delay for printer processing
  }

  // ESC/POS Commands
  List<int> _initializePrinter() => [0x1B, 0x40]; // ESC @ - Initialize
  List<int> _centerAlign() => [0x1B, 0x61, 0x01]; // ESC a 1 - Center align
  List<int> _leftAlign() => [0x1B, 0x61, 0x00]; // ESC a 0 - Left align
  List<int> _setBold() => [0x1B, 0x45, 0x01]; // ESC E 1 - Bold on
  List<int> _unsetBold() => [0x1B, 0x45, 0x00]; // ESC E 0 - Bold off
  List<int> _setDoubleHeight() =>
      [0x1B, 0x21, 0x10]; // ESC ! 16 - Double height
  List<int> _setNormalHeight() => [0x1B, 0x21, 0x00]; // ESC ! 0 - Normal height
  List<int> _lineFeed() => [0x0A]; // LF - Line feed
  List<int> _paperCut() => [0x1D, 0x56, 0x01]; // GS V 1 - Partial cut

  // Print text with encoding
  Future<void> _printText(String text,
      {bool bold = false,
      bool centerAlign = false,
      bool doubleHeight = false,
      bool leftAlign = false}) async {
    try {
      // Set alignment
      if (centerAlign) {
        await _sendRawBytes(_centerAlign());
      } else if (leftAlign) {
        await _sendRawBytes(_leftAlign());
      }

      // Set formatting
      if (bold) {
        await _sendRawBytes(_setBold());
      }
      if (doubleHeight) {
        await _sendRawBytes(_setDoubleHeight());
      }

      // Send text
      await _sendRawBytes(utf8.encode(text));
      await _sendRawBytes(_lineFeed());

      // Reset formatting
      if (bold || doubleHeight) {
        await _sendRawBytes(_unsetBold());
        await _sendRawBytes(_setNormalHeight());
      }
    } catch (e) {
      print('[v0] Error printing text: $e');
      throw e;
    }
  }

  // Test print to verify connection
  Future<bool> testPrint() async {
    if (!_isConnected || _bluetoothDevice == null) {
      _errorMessage = 'Not connected to printer';
      notifyListeners();
      return false;
    }

    try {
      print('[v0] Sending test print...');

      await _sendRawBytes(_initializePrinter());
      await _printText('TEST PRINT', bold: true, centerAlign: true);
      await _sendRawBytes(_paperCut());

      print('[v0] Test print sent successfully');
      return true;
    } catch (e) {
      _errorMessage = 'Test print failed: $e';
      print('[v0] Test print error: $e');
      notifyListeners();
      return false;
    }
  }

  // Print invoice data to thermal printer (58mm format)
  Future<bool> printInvoice({
    required String storeName,
    required String customerName,
    required String mobileNumber,
    required String paymentMethod,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required String invoiceNumber,
    required String printDate,
  }) async {
    if (!_isConnected || _bluetoothDevice == null) {
      _errorMessage = 'Not connected to printer';
      notifyListeners();
      return false;
    }

    try {
      print('[v0] Printing invoice to thermal printer...');

      await _sendRawBytes(_initializePrinter());

      final dateFormat = printDate.isNotEmpty
          ? printDate
          : DateTime.now().toString().split(' ')[0];
      final timeFormat =
          DateTime.now().toString().split(' ')[1].substring(0, 5);

      await _printText('VANITA LUNCH HOME',
          bold: true, centerAlign: true, doubleHeight: true);
      await _printText('Authentic Home-Cooked Meals', centerAlign: true);
      await _sendRawBytes(_lineFeed());

      // Address and contact
      await _printText('Address: Shop 31, Grandeur', leftAlign: true);
      await _printText('C.H.S., plot 33/34, sector 20', leftAlign: true);
      await _printText('Kamothe, 410209', leftAlign: true);
      await _sendRawBytes(_lineFeed());
      await _printText('Tel: 9892955938 / 9768559898', leftAlign: true);

      // Separator line
      await _printText('================================', leftAlign: true);

      // TAX INVOICE header
      await _printText('TAX INVOICE', bold: true, centerAlign: true);
      await _printText('================================', leftAlign: true);
      await _sendRawBytes(_lineFeed());

      // Invoice details
      await _printText(
          'Bill No: ${invoiceNumber.padRight(20)}${dateFormat.padLeft(10)}',
          leftAlign: true);
      await _printText('Time: $timeFormat', leftAlign: true);
      await _printText('--------------------------------', leftAlign: true);
      await _sendRawBytes(_lineFeed());

      // Customer details
      await _printText('Customer: $customerName', leftAlign: true);
      await _printText('Mobile: $mobileNumber', leftAlign: true);
      await _printText('Payment: $paymentMethod', leftAlign: true);
      await _sendRawBytes(_lineFeed());
      await _printText('================================', leftAlign: true);
      await _sendRawBytes(_lineFeed());

      // Items section
      if (items.isNotEmpty) {
        for (var item in items) {
          final itemName = item['name'] as String;
          final qty = (item['quantity'] as int).toString();
          final price = (item['price'] as double).toStringAsFixed(2);
          final total = (item['total'] as double).toStringAsFixed(2);

          await _printText(itemName, leftAlign: true);
          await _printText('  Qty: $qty x ₹$price = ₹$total', leftAlign: true);
        }
        await _sendRawBytes(_lineFeed());
      }

      // Totals
      await _printText('================================', leftAlign: true);
      await _printText(
          'Subtotal:            ₹${totalAmount.toStringAsFixed(2)}',
          leftAlign: true);
      await _printText('================================', leftAlign: true);

      await _printText('TOTAL: ₹${totalAmount.toStringAsFixed(2)}',
          bold: true, centerAlign: true, doubleHeight: true);
      await _printText('================================', leftAlign: true);
      await _sendRawBytes(_lineFeed());
      await _sendRawBytes(_lineFeed());

      // Footer
      await _printText('THANK YOU!', bold: true, centerAlign: true);
      await _printText('Visit Again', centerAlign: true);
      await _sendRawBytes(_lineFeed());
      await _printText('Powered by VLH POS System', centerAlign: true);
      await _sendRawBytes(_lineFeed());
      await _sendRawBytes(_lineFeed());
      await _sendRawBytes(_paperCut());

      print('[v0] Invoice printed successfully');
      return true;
    } catch (e) {
      _errorMessage = 'Print failed: $e';
      print('[v0] Print error: $e');
      notifyListeners();
      return false;
    }
  }

  // Disconnect printer
  Future<void> disconnectPrinter() async {
    try {
      await _bluetoothDevice?.disconnect();
      _isConnected = false;
      _bluetoothDevice = null;
      _writeCharacteristic = null;
      _connectedPrinter = null;
      _errorMessage = null;
      print('[v0] Disconnected from printer');
      notifyListeners();
    } catch (e) {
      print('[v0] Error disconnecting: $e');
    }
  }

  // Clear saved printer
  Future<void> clearSavedPrinter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_printer');
      _connectedPrinter = null;
      print('[v0] Cleared saved printer');
      notifyListeners();
    } catch (e) {
      print('[v0] Error clearing saved printer: $e');
    }
  }

  @override
  void dispose() {
    disconnectPrinter();
    super.dispose();
  }
}
