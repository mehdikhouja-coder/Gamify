import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:image/image.dart' as img;
// ignore: depend_on_referenced_packages
import 'package:vector_math/vector_math_64.dart' as vec;

class CircularCropDialog extends StatefulWidget {
  final Uint8List imageBytes;
  const CircularCropDialog({super.key, required this.imageBytes});

  @override
  State<CircularCropDialog> createState() => _CircularCropDialogState();
}

class _CircularCropDialogState extends State<CircularCropDialog> {
  final TransformationController _transformationController = TransformationController();
  bool _isCropping = false;
  ui.Image? _image;
  double? _viewportSize;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final codec = await ui.instantiateImageCodec(widget.imageBytes);
    final frame = await codec.getNextFrame();
    if (mounted) {
      setState(() => _image = frame.image);
      // Set initial zoom to 2x
      _transformationController.value = Matrix4.identity()..scale(2.0, 2.0, 1.0);
      // Center the image? The InteractiveViewer handles centering if content is smaller.
      // But with 2x zoom, it zooms into top-left by default?
      // We might want to translate to center.
      // Let's leave it for now, user can pan.
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _image?.dispose();
    super.dispose();
  }

  Future<Uint8List?> _cropImage() async {
    if (_viewportSize == null) return null;
    
    // Decode the image
    final img.Image? image = img.decodeImage(widget.imageBytes);
    if (image == null) return null;

    final double viewportSize = _viewportSize!;
    
    // Calculate displayed image size (content size)
    double contentWidth = viewportSize;
    double contentHeight = viewportSize;
    final double imageAspect = image.width / image.height;
    
    // Logic matching BoxFit.contain
    if (imageAspect > 1) {
      contentHeight = viewportSize / imageAspect;
    } else {
      contentWidth = viewportSize * imageAspect;
    }
    
    // Calculate offsets due to centering
    double offsetX = (viewportSize - contentWidth) / 2;
    double offsetY = (viewportSize - contentHeight) / 2;

    // Transformation matrix
    final Matrix4 matrix = _transformationController.value;
    // Invert to map viewport -> child widget coordinates
    final Matrix4 inverse = Matrix4.inverted(matrix);

    // Viewport rect in child widget coordinates
    // Top-left (0,0)
    final vec.Vector3 tl = inverse.transform3(vec.Vector3(0, 0, 0));
    // Bottom-right (size, size)
    final vec.Vector3 br = inverse.transform3(vec.Vector3(viewportSize, viewportSize, 0));

    // Crop rect in child widget coordinates
    double widgetCropX = tl.x;
    double widgetCropY = tl.y;
    double widgetCropW = br.x - tl.x;
    double widgetCropH = br.y - tl.y;
    
    // Map to content coordinates (subtract offset)
    double contentCropX = widgetCropX - offsetX;
    double contentCropY = widgetCropY - offsetY;

    // Map to actual image pixels
    final double scaleX = image.width / contentWidth;
    final double scaleY = image.height / contentHeight;

    int imgX = (contentCropX * scaleX).round();
    int imgY = (contentCropY * scaleY).round();
    int imgW = (widgetCropW * scaleX).round();
    int imgH = (widgetCropH * scaleY).round();

    // Target size is 512x512
    final img.Image target = img.Image(width: 512, height: 512);
    // Fill with black (or transparent if supported by format, but we encode to PNG so transparent is fine)
    // Profile pics usually have a background color in UI, so transparent is best.
    img.fill(target, color: img.ColorRgb8(0, 0, 0)); // Black background for now

    // Intersection with image bounds
    int srcX = imgX;
    int srcY = imgY;
    int srcW = imgW;
    int srcH = imgH;

    int validX = srcX < 0 ? 0 : srcX;
    int validY = srcY < 0 ? 0 : srcY;
    int validR = (srcX + srcW) > image.width ? image.width : (srcX + srcW);
    int validB = (srcY + srcH) > image.height ? image.height : (srcY + srcH);
    
    int validW = validR - validX;
    int validH = validB - validY;
    
    if (validW <= 0 || validH <= 0) {
      return Uint8List.fromList(img.encodePng(target));
    }
    
    img.Image croppedValid = img.copyCrop(image, x: validX, y: validY, width: validW, height: validH);
    
    // Scale factor from "Crop Space" to "Target Space" is 512 / imgW.
    // Use double for precision
    double scaleToTarget = 512.0 / imgW;
    
    // Resize the valid part to target scale
    int targetValidW = (validW * scaleToTarget).round();
    int targetValidH = (validH * scaleToTarget).round();
    
    if (targetValidW <= 0 || targetValidH <= 0) return Uint8List.fromList(img.encodePng(target));

    img.Image resizedValid = img.copyResize(croppedValid, width: targetValidW, height: targetValidH);
    
    // Calculate position in target
    int offsetXInSrc = validX - srcX;
    int offsetYInSrc = validY - srcY;
    
    int targetX = (offsetXInSrc * scaleToTarget).round();
    int targetY = (offsetYInSrc * scaleToTarget).round();
    
    img.compositeImage(target, resizedValid, dstX: targetX, dstY: targetY);
    
    return Uint8List.fromList(img.encodePng(target));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          children: [
            AppBar(
              title: const Text('Crop Profile Picture'),
              automaticallyImplyLeading: false,
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
            Expanded(
              child: _image == null
                  ? const Center(child: CircularProgressIndicator())
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final size = constraints.maxWidth < constraints.maxHeight
                              ? constraints.maxWidth
                              : constraints.maxHeight;
                          // Capture viewport size for crop math
                          if (_viewportSize != size) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) setState(() => _viewportSize = size);
                            });
                          }
                          
                          return Center(
                            child: SizedBox(
                              width: size,
                              height: size,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  InteractiveViewer(
                                    transformationController: _transformationController,
                                    minScale: 0.5,
                                    maxScale: 4.0,
                                    child: Image.memory(
                                      widget.imageBytes,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  // Circular overlay - ignore pointer to allow zooming
                                  IgnorePointer(
                                    child: CustomPaint(
                                      painter: _CircleMaskPainter(
                                        color: Colors.black.withOpacity(0.6),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: _isCropping || _image == null
                    ? null
                    : () async {
                        setState(() => _isCropping = true);
                        try {
                          final croppedBytes = await _cropImage();
                          if (mounted && croppedBytes != null) {
                            Navigator.of(context).pop(croppedBytes);
                          }
                        } catch (e) {
                          if (mounted) {
                            setState(() => _isCropping = false);
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to crop: $e')),
                            );
                          }
                        }
                      },
                icon: _isCropping
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check),
                label: Text(_isCropping ? 'Cropping...' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleMaskPainter extends CustomPainter {
  final Color color;

  _CircleMaskPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    canvas.saveLayer(rect, Paint());
    canvas.drawRect(rect, Paint()..color = color);
    canvas.drawCircle(center, radius, Paint()..blendMode = BlendMode.clear);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CircleMaskPainter oldDelegate) => color != oldDelegate.color;
}
