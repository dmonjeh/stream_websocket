// Importar las bibliotecas necesarias
import 'dart:isolate';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as paqImg;

// Definir la estructura de los datos a pasar al Isolate
class IsolateData {
  final CameraImage cImage;
  final SendPort sendPort;

  IsolateData(this.cImage, this.sendPort);
}

// Función de envoltura para ejecutar en el Isolate
void convertYUV420toRGBIsolate(IsolateData isolateData) {

  int width = isolateData.cImage.width;
  int height = isolateData.cImage.height;
  var imgRgb = Uint8List(width * height * 3);

  int uvRowStride = isolateData.cImage.planes[1].bytesPerRow;
  int uvPixelStride = isolateData.cImage.planes[1].bytesPerPixel ?? 1; // Asumir un valor por defecto si es null

  for (int y = 0; y < height; y++) {
    int yIndex = y * width;
    int uvRowStart = uvRowStride * (y ~/ 2);
    for (int x = 0; x < width; x++) {
      final int uvIndex = uvPixelStride * (x ~/ 2) + uvRowStart;
      final int index = yIndex + x;

      final yp = isolateData.cImage.planes[0].bytes[index];
      final up = isolateData.cImage.planes[1].bytes[uvIndex];
      final vp = isolateData.cImage.planes[2].bytes[uvIndex];

      // Convert YUV to RGB con optimizaciones matemáticas
      int r = (yp + vp * 1436 / 1024 - 179).round();
      int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91).round();
      int b = (yp + up * 1814 / 1024 - 227).round();

      // Uso de operaciones condicionales en lugar de clamp
      imgRgb[index * 3] = r < 0 ? 0 : (r > 255 ? 255 : r);
      imgRgb[index * 3 + 1] = g < 0 ? 0 : (g > 255 ? 255 : g);
      imgRgb[index * 3 + 2] = b < 0 ? 0 : (b > 255 ? 255 : b);
    }
  }

  // Crear una imagen vacía con la biblioteca 'image'
  paqImg.Image image = paqImg.Image.fromBytes(width: width, height: height, bytes: imgRgb.buffer);

  // Codificar la imagen a PNG
  Uint8List png = Uint8List.fromList(paqImg.encodePng(image));

  // Enviar el resultado de vuelta al hilo principal
  isolateData.sendPort.send(png);
}