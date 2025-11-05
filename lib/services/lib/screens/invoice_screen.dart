// lib/screens/invoice_screen.dart
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import your OrderDetails model
import '../models/order_details.dart';

class InvoiceScreen extends StatefulWidget {
  static const routeName = '/invoice';

  final OrderDetails orderDetails;

  const InvoiceScreen({
    super.key,
    required this.orderDetails,
  });

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  BluetoothDevice? _printerDevice;
  bool _isLoading = false;
  bool _connected = false;
  String? _savedPrinterAddress;

  late OrderDetails details;

  @override
  void initState() {
    super.initState();
    details = widget.orderDetails; // Initialize details from the widget
    _quickConnect();
  }

  // --- All Bluetooth Connection Logic ---
  // (No changes needed here, this is your working code)
  Future<void> _quickConnect() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final futures = await Future.wait([
        SharedPreferences.getInstance(),
        bluetooth.getBondedDevices(),
      ]);

      final prefs = futures[0] as SharedPreferences;
      final devices = futures[1] as List<BluetoothDevice>;

      _savedPrinterAddress = prefs.getString('printer_mac');

      if (devices.isEmpty) {
        _showError('No paired Bluetooth devices found');
        setState(() => _isLoading = false);
        return;
      }

      BluetoothDevice? targetDevice;

      if (_savedPrinterAddress != null) {
        try {
          targetDevice = devices.firstWhere(
            (d) => d.address == _savedPrinterAddress,
          );
          print("Found saved printer: ${targetDevice.name}");
        } catch (e) {
          print("Saved printer not in paired devices");
          await prefs.remove('printer_mac');
          _savedPrinterAddress = null;
        }
      }

      if (targetDevice == null) {
        final printerKeywords = [
          'rpp',
          'pos',
          'printer',
          'thermal',
          'sr588',
          'xprinter',
          'bluetooth printer'
        ];
        for (var keyword in printerKeywords) {
          try {
            targetDevice = devices.firstWhere(
              (d) => (d.name?.toLowerCase() ?? '').contains(keyword),
            );
            print("Auto-detected printer: ${targetDevice.name}");
            break;
          } catch (e) {
            continue;
          }
        }
      }

      if (targetDevice == null && devices.isNotEmpty) {
        targetDevice = devices.first;
        print("Using first paired device: ${targetDevice.name}");
      }

      if (targetDevice != null) {
        await _connectWithTimeout(targetDevice);
      } else {
        _showError('No printer found in paired devices');
      }
    } catch (e) {
      print("Error in quick connect: $e");
      _showError('Failed to initialize: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _connectWithTimeout(BluetoothDevice device) async {
    try {
      try {
        await bluetooth.disconnect();
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (e) {
        // Ignore disconnect errors
      }

      await bluetooth.connect(device).timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );

      if (mounted) {
        setState(() {
          _connected = true;
          _printerDevice = device;
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('printer_mac', device.address!);
        _savedPrinterAddress = device.address;

        print("Connected to ${device.name}");
        _showSuccess('Connected to ${device.name}');
      }
    } catch (error) {
      print("Connection error: $error");
      if (mounted) {
        setState(() => _connected = false);
        _showError('Connection failed. Please retry.');
      }
    }
  }

  Future<void> _reconnect() async {
    setState(() => _isLoading = true);
    try {
      if (_printerDevice != null) {
        await _connectWithTimeout(_printerDevice!);
      } else {
        await _quickConnect();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showPrinterSelection() async {
    setState(() => _isLoading = true);
    try {
      final devices = await bluetooth.getBondedDevices();
      if (!mounted) return;
      if (devices.isEmpty) {
        _showError(
            'No paired devices. Please pair your printer in Bluetooth settings.');
        setState(() => _isLoading = false);
        return;
      }
      setState(() => _isLoading = false);

      final selected = await showDialog<BluetoothDevice>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Printer'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                return ListTile(
                  leading: const Icon(Icons.print),
                  title: Text(device.name ?? 'Unknown'),
                  subtitle: Text(device.address ?? ''),
                  onTap: () => Navigator.pop(context, device),
                );
              },
            ),
          ),
        ),
      );

      if (selected != null) {
        setState(() => _isLoading = true);
        await _connectWithTimeout(selected);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Error showing printer selection: $e");
      _showError('Failed to load devices');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _disconnect() async {
    try {
      await bluetooth.disconnect();
      if (mounted) {
        setState(() => _connected = false);
        _showSuccess('Disconnected');
      }
    } catch (e) {
      print("Error disconnecting: $e");
    }
  }

  // --- Thermal Print Logic ---
  // (This is your working 58mm print logic)
  Future<void> _printInvoice() async {
    bool? isConnected = await bluetooth.isConnected;
    if (isConnected != true || _printerDevice == null) {
      _showError('Printer not connected. Reconnecting...');
      await _reconnect();
      isConnected = await bluetooth.isConnected;
      if (isConnected != true) {
        return;
      }
    }

    try {
      bluetooth.printCustom("VANITA LUNCH HOME", 3, 1);
      bluetooth.printCustom("Authentic Home-Cooked Meals", 1, 1);
      bluetooth.printNewLine();
      bluetooth.printCustom("Address: Shop 31, Grandeur", 0, 1);
      bluetooth.printCustom("C.H.S., plot 33/34, sector 20", 0, 1);
      bluetooth.printCustom("Kamothe, 410209", 0, 1);
      bluetooth.printNewLine();
      bluetooth.printCustom("Tel: 9892955938 / 9768559898", 0, 1);
      bluetooth.printCustom("--------------------------------", 1, 1);
      bluetooth.printCustom("TAX INVOICE", 2, 1);
      bluetooth.printNewLine();

      bluetooth.printLeftRight("Bill No:", details.orderId, 1);

      String dateStr = details.formattedDate;
      String timeStr = "";
      if (details.formattedDate.contains(",")) {
        var parts = details.formattedDate.split(',');
        dateStr = parts[0].trim();
        timeStr = parts.length > 1 ? parts[1].trim() : "";
      }
      bluetooth.printLeftRight("Date:", dateStr, 1);
      bluetooth.printLeftRight("Time:", timeStr, 1);

      bluetooth.printCustom("--------------------------------", 1, 1);
      bluetooth.printLeftRight("Customer:", details.customerName, 1);
      bluetooth.printLeftRight("Mobile:", details.customerMobile, 1);
      bluetooth.printLeftRight("Payment:", details.paymentMethod, 1);
      bluetooth.printCustom("--------------------------------", 1, 1);

      double subtotal = 0;
      for (var cartItem in details.items) {
        final itemTotal = cartItem.item.price * cartItem.quantity;
        subtotal += itemTotal;
        String itemName = cartItem.item.name;
        String qty = cartItem.quantity.toString();
        String price = "₹${cartItem.item.price.toStringAsFixed(2)}";
        String total = "₹${itemTotal.toStringAsFixed(2)}";
        bluetooth.printCustom(itemName, 1, 0);
        String leftText = "$qty x $price";
        bluetooth.printLeftRight(leftText, total, 0);
      }

      bluetooth.printCustom("--------------------------------", 1, 1);
      bluetooth.printLeftRight(
          "Subtotal:", "₹${subtotal.toStringAsFixed(2)}", 1);
      bluetooth.printCustom("================================", 1, 1);
      bluetooth.printLeftRight("TOTAL:", details.formattedTotal, 2);
      bluetooth.printNewLine();
      bluetooth.printCustom("THANK YOU!", 2, 1);
      bluetooth.printCustom("Visit Again", 1, 1);
      bluetooth.printNewLine();
      bluetooth.printCustom("Powered by VLH POS System", 0, 1);
      bluetooth.printNewLine();
      bluetooth.printNewLine();
      bluetooth.paperCut();

      _showSuccess('Invoice sent to thermal printer');
    } catch (e) {
      print("Print error: $e");
      _showError('Print failed: ${e.toString()}');
    }
  }

  // --- Share Invoice Placeholder ---
  // (This shows a message, as seen in your screenshot)
  Future<void> _shareInvoice(BuildContext context) async {
    _showError('Share functionality not yet implemented.');
    // If you want to add PDF sharing later, you can use the
    // 'printing' and 'pdf' packages here.
  }

  // --- Snackbar Helpers ---
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    }
  }

  // ===================================================================
  // --- PROFESSIONAL UI/UX BUILD METHOD ---
  // Enhanced with modern design, typography, and visual hierarchy
  // ===================================================================
  @override
  Widget build(BuildContext context) {
    // Professional color scheme
    final Color primaryColor = const Color(0xFF1E3A8A); // Deep blue
    final Color secondaryColor = const Color(0xFF64748B); // Slate gray
    final Color accentColor = const Color(0xFFF59E0B); // Amber
    final Color backgroundColor =
        const Color(0xFFF8FAFC); // Light gray background
    final Color cardColor = Colors.white;
    final Color highlightColor = const Color(0xFFFEF3C7); // Light amber

    // Theme-aware colors
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final effectiveBackgroundColor =
        isDarkMode ? const Color(0xFF0F172A) : backgroundColor;
    final effectiveCardColor = isDarkMode ? const Color(0xFF1E293B) : cardColor;
    final effectiveTextColor = isDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: effectiveBackgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        title: Text(
          'Invoice',
          style: GoogleFonts.montserrat(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: _connected
                  ? Colors.green.withOpacity(0.2)
                  : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: Icon(
                _connected ? Icons.print : Icons.print_disabled,
                color: _connected ? Colors.green : Colors.red,
              ),
              tooltip: _connected
                  ? 'Print Thermal Invoice'
                  : 'Printer not connected',
              onPressed: (_isLoading || !_connected) ? null : _printInvoice,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Professional Header with Branding
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, primaryColor.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.receipt_long,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'VANITA LUNCH HOME',
                              style: GoogleFonts.montserrat(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Authentic Home-Cooked Meals',
                              style: GoogleFonts.roboto(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calendar_today,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          details.formattedDate,
                          style: GoogleFonts.roboto(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Customer Details Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: effectiveCardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person, color: primaryColor, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Customer Information',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: effectiveTextColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildProfessionalDetailRow(
                    Icons.person_outline,
                    'Name',
                    details.customerName,
                    primaryColor,
                    effectiveTextColor,
                  ),
                  const Divider(height: 24),
                  _buildProfessionalDetailRow(
                    Icons.phone,
                    'Mobile',
                    details.customerMobile,
                    primaryColor,
                    effectiveTextColor,
                  ),
                  const Divider(height: 24),
                  _buildProfessionalDetailRow(
                    Icons.payment,
                    'Payment Method',
                    details.paymentMethod,
                    primaryColor,
                    effectiveTextColor,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Order Items Section
            Container(
              decoration: BoxDecoration(
                color: effectiveCardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Icon(Icons.shopping_cart,
                            color: primaryColor, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Order Items',
                          style: GoogleFonts.montserrat(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: effectiveTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF334155)
                          : Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              'Item',
                              style: GoogleFonts.roboto(
                                fontWeight: FontWeight.w600,
                                color: effectiveTextColor,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              'Qty',
                              style: GoogleFonts.roboto(
                                fontWeight: FontWeight.w600,
                                color: effectiveTextColor,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              'Price',
                              style: GoogleFonts.roboto(
                                fontWeight: FontWeight.w600,
                                color: effectiveTextColor,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              'Total',
                              style: GoogleFonts.roboto(
                                fontWeight: FontWeight.w600,
                                color: effectiveTextColor,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  // Items with alternating background
                  ...details.items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final cartItem = entry.value;
                    final itemTotal = cartItem.item.price * cartItem.quantity;
                    final isEven = index % 2 == 0;

                    return Container(
                      color: isEven
                          ? Colors.transparent
                          : (isDarkMode
                              ? const Color(0xFF1E293B).withOpacity(0.3)
                              : Colors.grey[50]),
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              cartItem.item.name,
                              style: GoogleFonts.roboto(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: effectiveTextColor,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 8),
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${cartItem.quantity}',
                                style: GoogleFonts.roboto(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: accentColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              '₹${cartItem.item.price.toStringAsFixed(2)}',
                              style: GoogleFonts.roboto(
                                fontSize: 14,
                                color: effectiveTextColor,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              '₹${itemTotal.toStringAsFixed(2)}',
                              style: GoogleFonts.roboto(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Total Section with Gradient
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentColor, accentColor.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Grand Total',
                    style: GoogleFonts.montserrat(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    details.formattedTotal,
                    style: GoogleFonts.montserrat(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Printer Status Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: effectiveCardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.print, color: primaryColor, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Printer Status',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: effectiveTextColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildPrinterStatus(),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton.icon(
                      icon: const Icon(Icons.settings),
                      label: Text(
                        'Change Printer',
                        style: GoogleFonts.roboto(fontWeight: FontWeight.w500),
                      ),
                      onPressed: _isLoading ? null : _showPrinterSelection,
                      style: TextButton.styleFrom(
                        foregroundColor: primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryColor, primaryColor.withOpacity(0.8)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.home, color: Colors.white),
                      label: Text(
                        'Back to Menu',
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      border: Border.all(color: primaryColor, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.share, color: primaryColor),
                      label: Text(
                        'Share Invoice',
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => _shareInvoice(context),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Professional Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1E293B) : Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    'Thank you for choosing VANITA LUNCH HOME!',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: effectiveTextColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Visit us again for authentic home-cooked meals',
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      color: secondaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.phone, size: 16, color: secondaryColor),
                      const SizedBox(width: 4),
                      Text(
                        '9892955938 / 9768559898',
                        style: GoogleFonts.roboto(
                          fontSize: 12,
                          color: secondaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Powered by VLH POS System',
                    style: GoogleFonts.roboto(
                      fontSize: 10,
                      color: secondaryColor.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Professional Detail Row Helper ---
  Widget _buildProfessionalDetailRow(IconData icon, String label, String value,
      Color primaryColor, Color textColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: primaryColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.roboto(
                  fontSize: 12,
                  color: primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.roboto(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Bluetooth Status UI Widget ---
  Widget _buildPrinterStatus() {
    if (_isLoading) {
      return const Center(
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 8),
            Text('Connecting to printer...'),
          ],
        ),
      );
    }

    if (_connected && _printerDevice != null) {
      return Center(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Connected: ${_printerDevice!.name}',
                  style: const TextStyle(
                      color: Colors.green, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _disconnect,
              child: const Text('Disconnect'),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Text(
                'Printer not connected',
                style: const TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Reconnect'),
            onPressed: _reconnect,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Keep this empty so the connection persists
    super.dispose();
  }
}
