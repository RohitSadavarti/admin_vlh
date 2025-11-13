// lib/screens/invoice_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/order_details.dart';
import '../services/printer_service.dart';

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
  late OrderDetails details;

  @override
  void initState() {
    super.initState();
    details = widget.orderDetails;
  }

  // --- Thermal Print Logic ---
  // (This is your working 58mm print logic)
  Future<void> _printInvoice() async {
    try {
      final printerService = Provider.of<PrinterService>(context, listen: false);

      if (!printerService.isConnected) {
        // Show dialog to connect printer
        if (!mounted) return;
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('No Printer Connected'),
            content: const Text('Please connect your thermal printer first.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/printer-setup');
                },
                child: const Text('Connect Printer'),
              ),
            ],
          ),
        );
        return;
      }

      // Show loading
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Printing to ${printerService.connectedPrinter?.name}...',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      );

      // Prepare print data
      List<Map<String, dynamic>> printItems = [];
      for (var cartItem in details.items) {
        printItems.add({
          'name': cartItem.item.name,
          'quantity': cartItem.quantity,
          'price': cartItem.item.price,
          'total': cartItem.item.price * cartItem.quantity,
        });
      }

      final success = await printerService.printInvoice(
        storeName: 'VANITA LUNCH HOME',
        customerName: details.customerName,
        mobileNumber: details.customerMobile,
        paymentMethod: details.paymentMethod,
        items: printItems,
        totalAmount: details.totalPrice,
        invoiceNumber: 'INV${DateTime.now().millisecondsSinceEpoch.toString().substring(0, 10)}',
        printDate: details.formattedDate,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice printed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print failed: ${printerService.errorMessage}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('[v0] Print error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- Share Invoice Placeholder ---
  // (This shows a message, as seen in your screenshot)
  Future<void> _shareInvoice(BuildContext context) async {
    // _showError('Share functionality not yet implemented.');
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
          Consumer<PrinterService>(
            builder: (context, printerService, _) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/printer-setup'),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.print,
                        color: printerService.isConnected ? Colors.green : Colors.white,
                        size: 24,
                      ),
                      if (printerService.isConnected)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
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

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber, width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade700, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thermal Printer',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Thermal printer functionality has been disabled. Use the Share Invoice feature instead.',
                          style: GoogleFonts.roboto(
                            fontSize: 12,
                            color: Colors.amber.shade700,
                          ),
                        ),
                      ],
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
                  child: Consumer<PrinterService>(
                    builder: (context, printerService, _) {
                      return Container(
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: printerService.isConnected
                                ? [Colors.green.shade600, Colors.green.shade400]
                                : [primaryColor, primaryColor.withOpacity(0.8)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: (printerService.isConnected ? Colors.green : primaryColor).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          icon: Icon(
                            printerService.isConnected ? Icons.print : Icons.print_disabled,
                            color: Colors.white,
                          ),
                          label: Text(
                            printerService.isConnected ? 'Print Invoice' : 'Setup Printer',
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
                          onPressed: printerService.isConnected
                              ? _printInvoice
                              : () => Navigator.pushNamed(context, '/printer-setup'),
                        ),
                      );
                    },
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
                      icon: Icon(Icons.home, color: primaryColor),
                      label: Text(
                        'Back to Menu',
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
                      onPressed: () {
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
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
                        '7666717724 / 9221022103',
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

  @override
  void dispose() {
    // Keep this empty so the connection persists
    super.dispose();
  }
}
