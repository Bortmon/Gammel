// lib/screens/scanner_screen.dart

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:async'; 


class ScannerScreen extends StatefulWidget
{
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
{
  final MobileScannerController ctrl = MobileScannerController(
      formats: const [BarcodeFormat.ean13, BarcodeFormat.qrCode],
      // Andere optionele instellingen zoals resolutie, etc. kunnen hier
  );

  bool _isProcessingDetect = false;
  bool torch = false;
  CameraFacing cam = CameraFacing.back;
  Color _overlayBorderColor = Colors.white.withOpacity(0.6);
  Timer? _feedbackTimer;

  @override
  void dispose()
  {
    ctrl.dispose();
    _feedbackTimer?.cancel();
    super.dispose();
  }

  /// Handles barcode/QR detection events.
  /// Validates EAN-13 or extracts Product URL from Gamma QR Code.
  void _onDetect(BarcodeCapture capture)
  {
    if (_isProcessingDetect) return;

    final Barcode? barcode = capture.barcodes.firstOrNull;

    if (barcode != null && barcode.rawValue != null)
    {
      final String scannedValue = barcode.rawValue!;
      final BarcodeFormat scannedFormat = barcode.format;
      print('[Scanner] Code gedetecteerd: $scannedValue (Formaat: $scannedFormat)');

      String? resultValue;
      bool isValid = false;

      if (scannedFormat == BarcodeFormat.ean13)
      {
        final bool isValidEan13Format = RegExp(r'^[0-9]{13}$').hasMatch(scannedValue);
        if (isValidEan13Format)
        {
          resultValue = scannedValue;
          isValid = true;
        }
        else
        {
          print('[Scanner] Ongeldig EAN-13 formaat gedetecteerd: $scannedValue.');
        }
      }
      else if (scannedFormat == BarcodeFormat.qrCode)
      {
        final Uri? uri = Uri.tryParse(scannedValue);
        // Check of het een geldige gamma.nl product URL is
        if (uri != null &&
            uri.host.endsWith('gamma.nl') &&
            uri.pathSegments.contains('assortiment') &&
            uri.pathSegments.contains('p') &&
            uri.pathSegments.last.isNotEmpty)
        {
           // Geef de volledige URL terug
           resultValue = scannedValue;
           isValid = true;
           print('[Scanner] Geldige Gamma product URL gevonden: $resultValue');
        }
        else
        {
           print('[Scanner] QR code gedetecteerd, maar geen geldige Gamma product URL: $scannedValue');
           // Optioneel: Andere QR code logica hier
        }
      }
      else
      {
         print('[Scanner] Niet-ondersteund formaat gescand: $scannedFormat');
      }

      if (isValid && resultValue != null)
      {
        // Geldige code gevonden
        if (mounted)
        {
          setState(() { _isProcessingDetect = true; });
        }
        print('[Scanner] Geldige code doorgegeven: $resultValue');
        Navigator.pop(context, resultValue); // Geef resultaat terug
      }
      else if (!isValid)
      {
        // Ongeldige scan
        _showInvalidScanFeedback(); // Toon rode rand
      }
    }
 }

 /// Shows visual feedback (red border) for an invalid scan.
 void _showInvalidScanFeedback()
 {
   _feedbackTimer?.cancel();
   if (mounted)
   {
     setState(() { _overlayBorderColor = Colors.red.withOpacity(0.8); });
     _feedbackTimer = Timer(const Duration(milliseconds: 500), ()
     {
        if (mounted)
        {
          setState(() { _overlayBorderColor = Colors.white.withOpacity(0.6); });
        }
     });
   }
 }

  // Toggles the flashlight.
  Future<void> _torch() async
  {
    try
    {
      await ctrl.toggleTorch();
      if(mounted)
      {
        setState(() { torch = !torch; });
      }
    }
    catch (e)
    {
      print("Torch Error: $e");
      if (mounted)
      {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Flits error: $e")));
      }
    }
  }

  // Switches between front and back camera.
  Future<void> _cam() async
  {
    try
    {
      await ctrl.switchCamera();
      if(mounted)
      {
        setState(() { cam = (cam == CameraFacing.back) ? CameraFacing.front : CameraFacing.back; });
      }
    }
    catch (e)
    {
      print("Camera Switch Error: $e");
      if (mounted)
      {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Camera wisselen error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final appBarForegroundColor = Theme.of(context).appBarTheme.foregroundColor ?? Colors.white;
    final iconButtonColor = appBarForegroundColor.withOpacity(0.8);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Code'),
        foregroundColor: appBarForegroundColor,
        iconTheme: IconThemeData(color: appBarForegroundColor),
        actionsIconTheme: IconThemeData(color: appBarForegroundColor),
        elevation: 1,
        actions:
        [
          IconButton(
            icon: Icon(torch ? Icons.flash_on : Icons.flash_off_outlined, color: torch ? Colors.yellowAccent[700] : iconButtonColor),
            iconSize: 28.0,
            onPressed: _torch,
            tooltip: 'Flits aan/uit'
          ),
          IconButton(
            icon: Icon(cam == CameraFacing.back ? Icons.flip_camera_ios_outlined : Icons.flip_camera_ios, color: iconButtonColor),
            iconSize: 28.0,
            onPressed: _cam,
            tooltip: 'Wissel camera'
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children:
        [
          MobileScanner(
            controller: ctrl,
            onDetect: _onDetect,
            errorBuilder: (ctx, err, ch)
            {
              String msg = 'Camera Fout.';
              // Geef specifiekere melding bij permissie fouten
              if (err.errorDetails?.message?.toLowerCase().contains('permission') ?? false || err.errorCode.name.contains('CAMERA'))
              {
                msg = 'Camera permissie geweigerd. Controleer de app instellingen.';
              }
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(msg, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 16), textAlign: TextAlign.center),
                )
              );
            },
            placeholderBuilder: (ctx, ch) => const Center(child: CircularProgressIndicator()),
          ),
          // Overlay met dynamische randkleur voor feedback
          Container(
            width: MediaQuery.of(context).size.width * 0.75,
            height: MediaQuery.of(context).size.height * 0.3,
            decoration: BoxDecoration(
              border: Border.all(color: _overlayBorderColor, width: 2.0),
              borderRadius: BorderRadius.circular(12),
            ),
          )
        ]
      ),
    );
  }
}