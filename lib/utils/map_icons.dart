import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Rasterise une IconData Material en BitmapDescriptor, orientée selon
/// [rotationDegrees]. Utilisé pour le marqueur "véhicule" du chauffeur sur
/// la carte de suivi, orienté selon le champ `heading` de Firebase.
Future<BitmapDescriptor> createRotatedMarkerIcon({
  required IconData iconData,
  required Color color,
  double rotationDegrees = 0,
  double size = 72,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  final textPainter = TextPainter(textDirection: TextDirection.ltr);
  textPainter.text = TextSpan(
    text: String.fromCharCode(iconData.codePoint),
    style: TextStyle(
      fontSize: size,
      fontFamily: iconData.fontFamily,
      package: iconData.fontPackage,
      color: color,
    ),
  );
  textPainter.layout();

  canvas.save();
  canvas.translate(size / 2, size / 2);
  canvas.rotate(rotationDegrees * (3.1415926535897932 / 180));
  canvas.translate(-size / 2, -size / 2);
  textPainter.paint(canvas, Offset.zero);
  canvas.restore();

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.toInt(), size.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  final Uint8List bytes = byteData!.buffer.asUint8List();
  return BitmapDescriptor.bytes(bytes);
}