// lib/screens/scanner_screen.dart

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:async'; // Nodig voor Timer

/// A screen that displays a camera feed to scan barcodes AND QR codes.
/// Includes controls for flashlight and camera switching,
/// and validation/extraction logic for different code types.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController ctrl = MobileScannerController(
      // --- Detecteer NU OOK QR Codes ---
      formats: const [BarcodeFormat.ean13, BarcodeFormat.qrCode],
      // Andere instellingen blijven optioneel
  );

  bool _isProcessingDetect = false;
  bool torch = false;
  CameraFacing cam = CameraFacing.back;
  Color _overlayBorderColor = Colors.white.withOpacity(0.6);
  Timer? _feedbackTimer;

  @override
  void dispose() {
    ctrl.dispose();
    _feedbackTimer?.cancel();
    super.dispose();
  }

  /// Handles barcode/QR detection events.
  /// Validates EAN-13 or extracts Product ID from Gamma QR Code URL.
  void _onDetect(BarcodeCapture capture) {
    if (_isProcessingDetect) return;

    final Barcode? barcode = capture.barcodes.firstOrNull;

    if (barcode != null && barcode.rawValue != null) {
      final String scannedValue = barcode.rawValue!;
      final BarcodeFormat scannedFormat = barcode.format; // Haal het formaat op
      print('[Scanner] Code gedetecteerd: $scannedValue (Formaat: $scannedFormat)');

      String? resultValue; // Waarde om terug te geven (EAN of Product URL/ID)
      bool isValid = false;

      // --- AANGEPASTE LOGICA VOOR TYPE ---
      if (scannedFormat == BarcodeFormat.ean13) {
        // Valideer EAN-13 (13 cijfers)
        final bool isValidEan13Format = RegExp(r'^[0-9]{13}$').hasMatch(scannedValue);
        if (isValidEan13Format) {
          resultValue = scannedValue; // Geldige EAN
          isValid = true;
        } else {
          print('[Scanner] Ongeldig EAN-13 formaat gedetecteerd: $scannedValue.');
        }
      } else if (scannedFormat == BarcodeFormat.qrCode) {
        // Probeer URL en Product ID te extraheren
        final Uri? uri = Uri.tryParse(scannedValue);
        // Check of het een geldige gamma.nl product URL is
        if (uri != null &&
            uri.host.endsWith('gamma.nl') &&
            uri.pathSegments.contains('assortiment') &&
            uri.pathSegments.contains('p') &&
            uri.pathSegments.last.isNotEmpty)
        {
           // We geven de *volledige* URL terug, de detail pagina kan hier direct mee werken
           // Of je kunt alleen de ID extraheren: final productId = uri.pathSegments.last;
           resultValue = scannedValue; // Geldige Gamma Product URL
           isValid = true;
           print('[Scanner] Geldige Gamma product URL gevonden: $resultValue');
        } else {
           print('[Scanner] QR code gedetecteerd, maar geen geldige Gamma product URL: $scannedValue');
           // Optioneel: Andere QR code logica hier (bv. toon inhoud)
        }
      } else {
         print('[Scanner] Niet-ondersteund formaat gescand: $scannedFormat');
      }
      // --- EINDE AANGEPASTE LOGICA ---


      if (isValid && resultValue != null) {
        // Geldige code gevonden!
        if (mounted) { setState(() { _isProcessingDetect = true; }); }
        print('[Scanner] Geldige code doorgegeven: $resultValue');
        Navigator.pop(context, resultValue); // Geef resultaat terug

      } else if (!isValid) {
        // Ongeldige scan (geen EAN13, geen Gamma URL, of ander formaat)
        _showInvalidScanFeedback(); // Toon rode rand
      }
    }
 }

 /// Shows visual feedback for an invalid scan.
 void _showInvalidScanFeedback() {
   _feedbackTimer?.cancel();
   if (mounted) {
     setState(() { _overlayBorderColor = Colors.red.withOpacity(0.8); });
     _feedbackTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) { setState(() { _overlayBorderColor = Colors.white.withOpacity(0.6); }); }
     });
     // Geen SnackBar meer nodig, rode rand is de feedback
     // ScaffoldMessenger.of(context).removeCurrentSnackBar();
     // ScaffoldMessenger.of(context).showSnackBar( ... );
   }
 }

  Future<void> _torch() async { try { await ctrl.toggleTorch(); if(mounted) setState(() { torch = !torch; }); } catch (e) { print("Torch Err: $e"); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Flits error: $e"))); } }
  Future<void> _cam() async { try { await ctrl.switchCamera(); if(mounted) setState(() { cam = (cam == CameraFacing.back) ? CameraFacing.front : CameraFacing.back; }); } catch (e) { print("Cam Err: $e"); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Camera error: $e"))); } }

  @override
  Widget build(BuildContext context) {
    final appBarForegroundColor = Theme.of(context).appBarTheme.foregroundColor ?? Colors.white;
    final iconButtonColor = appBarForegroundColor.withOpacity(0.8);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Code'), // Titel aangepast
        foregroundColor: appBarForegroundColor, iconTheme: IconThemeData(color: appBarForegroundColor), actionsIconTheme: IconThemeData(color: appBarForegroundColor),
        elevation: 1,
        actions: [
          IconButton(icon: Icon(torch ? Icons.flash_on : Icons.flash_off_outlined, color: torch ? Colors.yellowAccent[700] : iconButtonColor), iconSize: 28.0, onPressed: _torch, tooltip: 'Flits'),
          IconButton(icon: Icon(cam == CameraFacing.back ? Icons.flip_camera_ios_outlined : Icons.flip_camera_ios, color: iconButtonColor), iconSize: 28.0, onPressed: _cam, tooltip: 'Wissel'),
        ],
      ),
      body: Stack( alignment: Alignment.center, children: [
          MobileScanner(
            controller: ctrl,
            onDetect: _onDetect, // Gebruikt bijgewerkte onDetect
            errorBuilder: (ctx, err, ch) { String msg = 'Camera Fout.'; if (err.errorDetails?.message?.toLowerCase().contains('permission') ?? false || err.errorCode.name.contains('CAMERA')) { msg = 'Camera permissie? Check instellingen.'; } return Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Text(msg, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 16), textAlign: TextAlign.center), )); },
            placeholderBuilder: (ctx, ch) => const Center(child: CircularProgressIndicator()),
          ),
          // Overlay gebruikt nu state kleur
          Container(
            width: MediaQuery.of(context).size.width * 0.75,
            height: MediaQuery.of(context).size.height * 0.3,
            decoration: BoxDecoration(
              border: Border.all(color: _overlayBorderColor, width: 2.0), // Gebruikt state kleur
              borderRadius: BorderRadius.circular(12),
            ),
          )
        ]
      ),
    );
  }
} // <<< EINDE _ScannerScreenState