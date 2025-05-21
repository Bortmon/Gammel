import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class ProductGalleryDialogContent extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const ProductGalleryDialogContent({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  @override
  State<ProductGalleryDialogContent> createState() => _ProductGalleryDialogContentState();
}

class _ProductGalleryDialogContentState extends State<ProductGalleryDialogContent> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme clr = Theme.of(context).colorScheme;

    if (widget.imageUrls.isEmpty) {
      return const Center(child: Text("Geen afbeeldingen beschikbaar"));
    }

    return Material( 
      type: MaterialType.transparency,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PhotoViewGallery.builder(
            pageController: _pageController,
            itemCount: widget.imageUrls.length,
            builder: (context, index) {
              return PhotoViewGalleryPageOptions(
                imageProvider: NetworkImage(widget.imageUrls[index]),
                initialScale: PhotoViewComputedScale.contained,
                minScale: PhotoViewComputedScale.contained * 0.8,
                maxScale: PhotoViewComputedScale.covered * 2.5,
                heroAttributes: PhotoViewHeroAttributes(tag: widget.imageUrls[index] + index.toString()),
              );
            },
            scrollPhysics: const BouncingScrollPhysics(),
            backgroundDecoration: const BoxDecoration(color: Colors.transparent),
            onPageChanged: onPageChanged,
            loadingBuilder: (context, event) => Center(
              child: SizedBox(
                width: 30.0,
                height: 30.0,
                child: CircularProgressIndicator(
                  value: event == null || event.expectedTotalBytes == null
                      ? null
                      : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
                  color: clr.primary,
                ),
              ),
            ),
          ),

          Positioned(
            top: 10,
            right: 10,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withAlpha((0.5 * 255).round()),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Sluiten',
              ),
            ),
          ),

          if (widget.imageUrls.length > 1)
            Positioned(
              left: 10,
              child: Container(
                 decoration: BoxDecoration(
                  color: Colors.black.withAlpha((0.4 * 255).round()),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 24),
                  onPressed: _currentIndex > 0
                      ? () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      : null, 
                  tooltip: 'Vorige',
                ),
              ),
            ),

          if (widget.imageUrls.length > 1)
            Positioned(
              right: 10,
              child: Container(
                 decoration: BoxDecoration(
                  color: Colors.black.withAlpha((0.4 * 255).round()),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 24),
                  onPressed: _currentIndex < widget.imageUrls.length - 1
                      ? () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      : null, 
                  tooltip: 'Volgende',
                ),
              ),
            ),

          if (widget.imageUrls.length > 1)
            Positioned(
              bottom: 20.0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha((0.6 * 255).round()),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${_currentIndex + 1} / ${widget.imageUrls.length}",
                  style: const TextStyle(color: Colors.white, fontSize: 14, decoration: TextDecoration.none),
                ),
              ),
            ),
        ],
      ),
    );
  }
}