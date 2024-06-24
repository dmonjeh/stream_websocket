import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as paqImg;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:path_provider/path_provider.dart';


class CameraProvider extends GetxController {

  late List<CameraDescription> cameras;
  late CameraController cameraController;
  bool isCameraInitialized = false;
  WebSocketChannel? channel;

  List<String> patentes = [];

  @override
  Future<void> onInit() async {
    super.onInit();
    
    await initializeCamera();
  }

  // Future<void> requestCameraPermission() async {
  //   var status = await Permission.camera.status;
  //   if (!status.isGranted) {
  //     status = await Permission.camera.request();
  //     if (!status.isGranted) {
  //       openAppSettings();
  //     }
  //   }
  // }

  Future<void> initializeCamera() async {

    // detecta las camaras del dispositivo
    cameras = await availableCameras();

    // configura el controlador con las configuraciones de la camara
    cameraController = CameraController(
      cameras[0],
      ResolutionPreset.medium,
      enableAudio: false,
    );


    // inicializa el controlador
    await cameraController.initialize().then((_) {
      isCameraInitialized = true;
      update(['camera-screen']);
    });

    // establece el flash desactivado
    await cameraController.setFlashMode(FlashMode.off);

  }

  Future<void> initializeStreaming() async {

    int contador = 0;

    await cameraController.startImageStream((image) async {
      contador++;
      // print(contador);
      if (contador%25 == 0) {

        final bytes = await convertCameraImageToFile(image);

        channel = WebSocketChannel.connect(Uri.parse('ws://192.168.100.18:8080'));

        channel!.sink.add(bytes);

        channel!.stream.listen((message) {
          print(message);
          patentes.add(message);
          update(['camera-screen']);
        });

      }
    });
  }

  Future<void> stopStreaming() async {
    print('DETENIENDO STREAMING');
    await Future.wait([
      cameraController.stopImageStream(),
      channel!.sink.close(),
    ]);
  }

  Future<Uint8List> convertCameraImageToFile(CameraImage image) async {

    final plane = image.planes[0];

    final paqImg.Image rgbImage = paqImg.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: plane.bytes.buffer,
      rowStride: plane.bytesPerRow,
      bytesOffset: 28,
      order: paqImg.ChannelOrder.bgra,
    );

    // final paqImg.Image rgbImage = convertCameraImageToImage(image);

    // Encode the image to JPEG
    final List<int> jpeg = paqImg.encodeJpg(rgbImage);

    // Get the temporary directory
    final Directory tempDir = await getTemporaryDirectory();

    // Create a temporary file
    final File tempFile = File('${tempDir.path}/temp.jpg');

    // Write the JPEG data to the file
    await tempFile.writeAsBytes(jpeg);

    // Read the file as bytes
    final Uint8List bytes = await tempFile.readAsBytes();

    // Delete the temporary file
    await tempFile.delete();

    return bytes;
  }

  paqImg.Image convertCameraImageToImage(CameraImage cImage) {
  
    final image = paqImg.Image(width: cImage.width, height: cImage.height);
  
    final frameSize = cImage.width * cImage.height;
    final chromaSize = frameSize ~/ 4;

    final yData = cImage.planes[0].bytes.sublist(0, frameSize);
    final uData = cImage.planes[1].bytes.sublist(frameSize, frameSize + chromaSize);
    final vData = cImage.planes[2].bytes.sublist(frameSize + chromaSize, frameSize + 2 * chromaSize);

    for (int j = 0; j < cImage.height; j++) {
      for (int i = 0; i < cImage.width; i++) {
        final yIndex = j * cImage.width + i;
        final uvIndex = (j ~/ 2) * (cImage.width ~/ 2) + (i ~/ 2);

        final y = yData[yIndex] & 0xff;
        final u = uData[uvIndex] & 0xff;
        final v = vData[uvIndex] & 0xff;

        final r = (y + 1.402 * (v - 128)).clamp(0, 255).toInt();
        final g = (y - 0.344136 * (u - 128) - 0.714136 * (v - 128)).clamp(0, 255).toInt();
        final blue = (y + 1.772 * (u - 128)).clamp(0, 255).toInt();

        image.setPixel(i, j, Color.fromARGB(0, r, g, blue) as paqImg.Color);
      }
    }

    return image;
  }


}