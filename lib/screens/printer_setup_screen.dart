import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/printer_device.dart';
import '../services/printer_service.dart';

class PrinterSetupScreen extends StatefulWidget {
  const PrinterSetupScreen({super.key});

  @override
  State<PrinterSetupScreen> createState() => _PrinterSetupScreenState();
}

class _PrinterSetupScreenState extends State<PrinterSetupScreen> {
  late PrinterService _printerService;
  List<PrinterDevice> _availableDevices = [];
  PrinterDevice? _selectedDevice;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _printerService = Provider.of<PrinterService>(context, listen: false);
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() => _isLoading = true);

    _availableDevices = await _printerService.getAvailableDevices();

    setState(() => _isLoading = false);
  }

  Future<void> _connectDevice(PrinterDevice device) async {
    setState(() => _isLoading = true);

    final success = await _printerService.connectToDevice(device);

    if (!mounted) return;

    if (success) {
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connected to printer successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() => _selectedDevice = device);

      // Navigate back after success
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) Navigator.pop(context);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: ${_printerService.errorMessage}'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF1E3A8A);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: Text(
          'Connect Thermal Printer',
          style:
              GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pairing 58mm Thermal Printer',
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Make sure your thermal printer is turned ON, paired with your device via Bluetooth, and within range. Once selected, it will be remembered for future prints.',
                  style: GoogleFonts.roboto(
                      fontSize: 14, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Connected printer status
          Consumer<PrinterService>(
            builder: (context, printerService, _) {
              if (printerService.connectedPrinter != null) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle,
                          color: Colors.green.shade600, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Printer Connected',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade700,
                              ),
                            ),
                            Text(
                              printerService.connectedPrinter!.name,
                              style: GoogleFonts.roboto(
                                fontSize: 14,
                                color: Colors.green.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          const SizedBox(height: 24),

          // Device list
          Text(
            'Available Printers',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _availableDevices.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.bluetooth_disabled,
                              color: Colors.amber.shade600, size: 32),
                          const SizedBox(height: 12),
                          Text(
                            'No paired devices found',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w600,
                              color: Colors.amber.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Pair your printer in Bluetooth settings first',
                            style: GoogleFonts.roboto(
                              fontSize: 12,
                              color: Colors.amber.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _availableDevices.length,
                      itemBuilder: (context, index) {
                        final device = _availableDevices[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading:
                                const Icon(Icons.print, color: Colors.blue),
                            title: Text(device.name),
                            subtitle: Text(device.address),
                            trailing: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Icon(
                                    Icons.arrow_forward,
                                    color: primaryColor,
                                  ),
                            onTap: _isLoading
                                ? null
                                : () => _connectDevice(device),
                          ),
                        );
                      },
                    ),
          const SizedBox(height: 24),

          // Refresh button
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh Device List'),
            onPressed: _isLoading ? null : _loadDevices,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
