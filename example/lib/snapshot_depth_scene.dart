import 'dart:developer';

import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:arkit_plugin_example/util/ar_helper.dart';
import 'package:flutter/material.dart';

import 'dart:math' as math;
import 'dart:async';

class SnapshotDepthScenePage extends StatefulWidget {
  @override
  _SnapshotDepthScenePageState createState() => _SnapshotDepthScenePageState();
}

class _SnapshotDepthScenePageState extends State<SnapshotDepthScenePage> {
  late ARKitController arkitController;

  @override
  void dispose() {
    arkitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
        title: const Text('Snapshot'),
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.camera_alt),
        onPressed: () async {
          try {
            final data = await arkitController.snapshotWithDepthData();
            if (data == null) return;
            log("$data");
            final image = data['image']! as MemoryImage;
            final depthData = (data..remove('image')).map<String, String>(
              (key, value) => MapEntry(key, value.toString()),
            );
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SnapshotPreview(
                  imageProvider: image,
                  depthData: depthData,
                ),
              ),
            );
          } catch (e) {
            print(e);
          }
        },
      ),
      body: Container(
        child: ARKitSceneView(
          configuration: ARKitConfiguration.depthTracking,
          onARKitViewCreated: onARKitViewCreated,
        ),
      ));

  void onARKitViewCreated(ARKitController arkitController) {
    this.arkitController = arkitController;
    this.arkitController.add(createSphere());
  }
}

class SnapshotPreview extends StatefulWidget {
  const SnapshotPreview({
    Key? key,
    required this.imageProvider,
    required this.depthData,
  }) : super(key: key);

  final ImageProvider imageProvider;
  final Map<String, String> depthData;

  @override
  State<SnapshotPreview> createState() => _SnapshotPreviewState();
}

class _SnapshotPreviewState extends State<SnapshotPreview> {
  Offset? _tapPosition;
  String? _depthValue;
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _loadImageSize();
  }

  Future<void> _loadImageSize() async {
    final ImageStream stream = widget.imageProvider.resolve(ImageConfiguration());
    final Completer<Size> completer = Completer<Size>();
    
    stream.addListener(ImageStreamListener((ImageInfo info, bool _) {
      completer.complete(Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      ));
    }));

    final Size size = await completer.future;
    setState(() {
      log("${size.height}x ${size.width}");
      _imageSize = size;
    });
  }

  Color _getHeatMapColor(double value) {
    // Normalize value between 0 and 1
    value = value.clamp(0.0, 1.0);
    
    if (value < 0.25) {
      return Color.lerp(Colors.blue, Colors.green, value * 4)!;
    } else if (value < 0.5) {
      return Color.lerp(Colors.green, Colors.yellow, (value - 0.25) * 4)!;
    } else if (value < 0.75) {
      return Color.lerp(Colors.yellow, Colors.orange, (value - 0.5) * 4)!;
    } else {
      return Color.lerp(Colors.orange, Colors.red, (value - 0.75) * 4)!;
    }
  }

  void _handleTapDown(TapDownDetails details, Size size, List<double> depthValues, int width, int height) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(details.globalPosition);
    log("tapped Image");
    // Account for rotation
    final adjustedX = localPosition.dy;
    final adjustedY = size.width - localPosition.dx;
    
    // Convert to depth map coordinates
    final depthX = (adjustedX * width / size.height).floor();
    final depthY = (adjustedY * height / size.width).floor();
      log("Tap position ${details.globalPosition.dx}, ${details.globalPosition..dy}");
      log("$depthY , $depthX, $width, $height");
    
    // if (depthX >= 0 && depthX < width && depthY >= 0 && depthY < height) {
      final index = depthY * width + depthX;
      if (index < depthValues.length) {
        setState(() {
          _tapPosition = details.globalPosition;
          _depthValue = depthValues[index].toStringAsFixed(3);
        });
      }
    // }
  }

  Widget _buildHeatMap() {
    final depthMapString = widget.depthData['depthMap']!;
    final depthWidth = int.parse(widget.depthData['depthWidth']!);
    final depthHeight = int.parse(widget.depthData['depthHeight']!);
    
    final depthValues = depthMapString
        .substring(1, depthMapString.length - 1)
        .split(',')
        .map((s) => double.tryParse(s.trim()) ?? 0.0)
        .toList();

    final minDepth = depthValues.reduce(math.min);
    final maxDepth = depthValues.reduce(math.max);
    final range = maxDepth - minDepth;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final availableHeight = constraints.maxHeight;
        
        // Calculate the size maintaining aspect ratio
        final aspectRatio = _imageSize != null 
            ? _imageSize!.width / _imageSize!.height
            : depthWidth / depthHeight;
            
        final width = availableWidth;
        final height = availableWidth / aspectRatio;

        if (height > availableHeight) {
          return FittedBox(
            fit: BoxFit.contain,
            child: GestureDetector(
              onTapDown: (details) => _handleTapDown(
                details,
                Size(width, height),
                depthValues,
                depthWidth,
                depthHeight,
              ),
              child: CustomPaint(
                size: Size(width, height),
                painter: HeatMapPainter(
                  depthValues: depthValues,
                  width: depthWidth,
                  height: depthHeight,
                  minDepth: minDepth,
                  range: range,
                  getColor: _getHeatMapColor,
                ),
              ),
            ),
          );
        }

        return GestureDetector(
          onTapDown: (details) => _handleTapDown(
            details,
            Size(width, height),
            depthValues,
            depthWidth,
            depthHeight,
          ),
          child: CustomPaint(
            size: Size(width, height),
            painter: HeatMapPainter(
              depthValues: depthValues,
              width: depthWidth,
              height: depthHeight,
              minDepth: minDepth,
              range: range,
              getColor: _getHeatMapColor,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Depth Map Preview'),
        actions: [
          IconButton(
            icon: Icon(Icons.info),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DepthDataPreview(
                  depthData: widget.depthData,
                ),
              ),
            ),
          )
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
                      child: Transform.rotate(
                        angle: 90 * math.pi / 180,
                        child: Image(image: widget.imageProvider),
                      ),
                    ),
          Center(
            child: Transform.rotate(
              angle: 90 * math.pi / 180,
              child: _buildHeatMap(),
            ),
          ),
          if (_tapPosition != null && _depthValue != null)
            Positioned(
              left: _tapPosition!.dx,
              top: _tapPosition!.dy,
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Depth: $_depthValue meters',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class HeatMapPainter extends CustomPainter {
  final List<double> depthValues;
  final int width;
  final int height;
  final double minDepth;
  final double range;
  final Color Function(double) getColor;

  HeatMapPainter({
    required this.depthValues,
    required this.width,
    required this.height,
    required this.minDepth,
    required this.range,
    required this.getColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final pixelWidth = size.width / width;
    final pixelHeight = size.height / height;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final index = y * width + x;
        if (index >= depthValues.length) continue;

        final normalizedValue = (depthValues[index] - minDepth) / range;
        paint.color = getColor(normalizedValue);

        canvas.drawRect(
          Rect.fromLTWH(
            x * pixelWidth,
            y * pixelHeight,
            pixelWidth,
            pixelHeight,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DepthDataPreview extends StatelessWidget {
  const DepthDataPreview({
    Key? key,
    required this.depthData,
  }) : super(key: key);

  final Map<String, String> depthData;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Depth Data Preview'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: Text('Depth Width'),
            subtitle: Text(depthData['depthWidth']!),
          ),
          ListTile(
            title: Text('Depth Height'),
            subtitle: Text(depthData['depthHeight']!),
          ),
          ListTile(
            title: Text('Intrinsics'),
            subtitle: Text(depthData['intrinsics']!),
          ),
          ListTile(
            title: Text('Depth Map'),
            subtitle: Text(depthData['depthMap']!),
          ),
        ],
      ),
    );
  }
}
