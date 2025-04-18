// lib/screens/scanner_screen.dart

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController ctrl = MobileScannerController();
  bool busy = false;
  bool torch = false;
  CameraFacing cam = CameraFacing.back;

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture cap) {
    if (busy) return;
    final bc = cap.barcodes.firstOrNull;
    if (bc != null && bc.rawValue != null) {
      final c = bc.rawValue!;
      print('[Scan] Code: $c');
      setState(() { busy = true; });
      Navigator.pop(context, c);
    }
  }

  Future<void> _torch() async {
    try {
      await ctrl.toggleTorch();
      setState(() { torch = !torch; });
    } catch (e) {
      print("Torch Err: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Flits error: $e")));
    }
  }

  Future<void> _cam() async {
    try {
      await ctrl.switchCamera();
      setState(() { cam = (cam == CameraFacing.back) ? CameraFacing.front : CameraFacing.back; });
    } catch (e) {
      print("Cam Err: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Camera error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final c = dark ? Colors.white70 : Colors.white70;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        elevation: 1,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: Icon(torch ? Icons.flash_on : Icons.flash_off, color: torch ? Colors.yellowAccent[700] : c), iconSize: 28.0, onPressed: _torch, tooltip: 'Flits'),
          IconButton(icon: Icon(cam == CameraFacing.back ? Icons.flip_camera_ios_outlined : Icons.flip_camera_ios, color: c), iconSize: 28.0, onPressed: _cam, tooltip: 'Wissel'),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: ctrl,
            onDetect: _onDetect,
            errorBuilder: (ctx, err, ch) {
              String msg = 'Camera Fout.';
              if (err.toString().toLowerCase().contains('permission') || err.toString().contains('CAMERA_ERROR')) {
                msg = 'Camera permissie? Check instellingen.';
              }
              return Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Text(msg, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 16), textAlign: TextAlign.center), ));
            },
            placeholderBuilder: (ctx, ch) => const Center(child: CircularProgressIndicator()),
          ),
          Container(
            width: MediaQuery.of(context).size.width * 0.75,
            height: MediaQuery.of(context).size.height * 0.3,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withAlpha((255 * 0.6).round()), width: 1.5),
              borderRadius: BorderRadius.circular(12),
            ),
          )
        ],
      ),
    );
  }
}