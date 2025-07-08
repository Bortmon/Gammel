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
  );

  bool _isProcessingDetect = false;
  bool torch = false;
  CameraFacing cam = CameraFacing.back;
  Color _overlayBorderColor = Colors.white.withOpacity(0.6);
  Timer? _feedbackTimer;
  Timer? _scanDelayTimer;
  
 
  String? _lastScannedCode;
  int _sameCodeCount = 0;
  static const int _requiredStableScans = 3; 
  static const int _scanDelayMs = 100; 

  @override
  void dispose()
  {
    ctrl.dispose();
    _feedbackTimer?.cancel();
    _scanDelayTimer?.cancel();
    super.dispose();
  }
  
  void _onDetect(BarcodeCapture capture)
  {
    if (_isProcessingDetect) return;

    final Barcode? barcode = capture.barcodes.firstOrNull;

    if (barcode != null && barcode.rawValue != null)
    {
      final String scannedValue = barcode.rawValue!;
      final BarcodeFormat scannedFormat = barcode.format;
      
      if (_lastScannedCode == scannedValue)
      {
        _sameCodeCount++;
      }
      else
      {
        _lastScannedCode = scannedValue;
        _sameCodeCount = 1;
      }
      
      print('[Scanner] Code gedetecteerd: $scannedValue (Formaat: $scannedFormat, Count: $_sameCodeCount)');
      
  
      if (_sameCodeCount < _requiredStableScans)
      {
        return;
      }

      String? resultValue;
      bool isValid = false;

      if (scannedFormat == BarcodeFormat.ean13)
      {
        final bool isValidEan13Format = RegExp(r'^[0-9]{13}$').hasMatch(scannedValue);
        if (isValidEan13Format)
        {
        
          if (_validateEan13Checksum(scannedValue))
          {
            resultValue = scannedValue;
            isValid = true;
          }
          else
          {
            print('[Scanner] EAN-13 checksum ongeldig: $scannedValue');
          }
        }
        else
        {
          print('[Scanner] Ongeldig EAN-13 formaat gedetecteerd: $scannedValue.');
        }
      }
      else if (scannedFormat == BarcodeFormat.qrCode)
      {
        final Uri? uri = Uri.tryParse(scannedValue);
  
        if (uri != null &&
            uri.host.endsWith('gamma.nl') &&
            uri.pathSegments.contains('assortiment') &&
            uri.pathSegments.contains('p') &&
            uri.pathSegments.last.isNotEmpty)
        {
         
           resultValue = scannedValue;
           isValid = true;
           print('[Scanner] Geldige Gamma product URL gevonden: $resultValue');
        }
        else
        {
           print('[Scanner] QR code gedetecteerd, maar geen geldige Gamma product URL: $scannedValue');
           
        }
      }
      else
      {
         print('[Scanner] Niet-ondersteund formaat gescand: $scannedFormat');
      }

      if (isValid && resultValue != null)
      {
        if (mounted)
        {
          setState(() { _isProcessingDetect = true; });
        }
        
        
        _scanDelayTimer = Timer(Duration(milliseconds: _scanDelayMs), ()
        {
          if (mounted)
          {
            print('[Scanner] Geldige code doorgegeven: $resultValue');
            Navigator.pop(context, resultValue);
          }
        });
      }
      else if (!isValid)
      {
        _showInvalidScanFeedback(); 
        
        _resetScanState();
      }
    }
 }
 
 void _resetScanState()
 {
   _lastScannedCode = null;
   _sameCodeCount = 0;
 }

 bool _validateEan13Checksum(String ean13)
 {
   if (ean13.length != 13) return false;
   
   int sum = 0;
   for (int i = 0; i < 12; i++)
   {
     int digit = int.tryParse(ean13[i]) ?? 0;
     sum += (i % 2 == 0) ? digit : digit * 3;
   }
   
   int checkDigit = (10 - (sum % 10)) % 10;
   int providedCheckDigit = int.tryParse(ean13[12]) ?? -1;
   
   return checkDigit == providedCheckDigit;
 }
 
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
         
          Container(
            width: MediaQuery.of(context).size.width * 0.75,
            height: MediaQuery.of(context).size.height * 0.3,
            decoration: BoxDecoration(
              border: Border.all(color: _overlayBorderColor, width: 2.0),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
         
          if (_sameCodeCount > 0 && _sameCodeCount < _requiredStableScans)
            Positioned(
              bottom: 100,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Stabiliseren... ${_sameCodeCount}/$_requiredStableScans',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
        ]
      ),
    );
  }
}