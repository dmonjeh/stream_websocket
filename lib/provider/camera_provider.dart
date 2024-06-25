import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:detector_live_websocket/config/service/isolateData_service.dart';
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
    Uint8List bytes;
    int frameRate = (Platform.isAndroid) ? 50 : 25;

    // bloquea el enfoque y la exposición de la cámara para ganar rendimiento
    await Future.wait([
      cameraController.setFocusMode(FocusMode.locked),
      cameraController.setExposureMode(ExposureMode.locked),
    ]);


    await cameraController.startImageStream((image) async {
      contador++;
      // print(contador);
      if (contador%frameRate == 0) {

        try {  

          if (channel != null) {
            channel = WebSocketChannel.connect(Uri.parse('ws://192.168.100.18:8080'));
          }
          
          if (Platform.isAndroid) {
            bytes = await convertCameraImageInIsolate(image);
          } else {
            bytes = await convertCameraImageToFile(image);
          }

          channel!.sink.add(bytes);
          // channel!.sink.add('hola');

          channel!.stream.listen((message) {
            print(message);
            patentes.add(message);
            update(['camera-screen']);
          });

        } catch (e) {
          print('Error: initializeStreaming(): $e');
        }

      }
    });
  }

  Future<void> stopStreaming() async {
    print('DETENIENDO STREAMING');

    await cameraController.stopImageStream();

    // Cierra el WebSocket solo si está abierto
    if (channel != null && channel!.closeCode == null) {
      await channel!.sink.close();
    }
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

  Future<Uint8List> convertCameraImageInIsolate(CameraImage cImage) async {
    // Crear un ReceivePort para recibir mensajes del Isolate
    final receivePort = ReceivePort();

    // Crear el Isolate
    await Isolate.spawn(
      convertYUV420toRGBIsolate,
      IsolateDataService(cImage, receivePort.sendPort),
    );

    // Esperar por el resultado
    final Uint8List result = await receivePort.first;
    return result;
  }

}