import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:detector_live_websocket/config/constants/environment.dart';
import 'package:detector_live_websocket/config/service/isolateData_service.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as paqImg;
import 'package:web_socket_channel/web_socket_channel.dart';


class CameraProvider extends GetxController {

  late List<CameraDescription> cameras;
  late CameraController cameraController;
  bool isCameraInitialized = false;
  WebSocketChannel? channel;
  List<String> data = [];
  bool isStreaming = false;

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

    int contFrame = 0;
    Uint8List bytes;

    // Establecer la tasa de fotogramas según la plataforma
    int frameRate = (Platform.isAndroid) ? 42 : 25;
    
    // Establecer la conexión con el servidor WebSocket
    
    channel = WebSocketChannel.connect(Uri.parse(Environment.webSocketIP));
    
    // Establecer el estado de streaming a verdadero
    isStreaming = true;
    update(['camera-screen']);

    // Iniciar el streaming de la cámara
    await cameraController.startImageStream((image) async {
      contFrame++;
      // print(contFrame);
      if (contFrame%frameRate == 0) {

        try {  

          // Reconectar el WebSocket si está cerrado
          if (channel!.closeCode == null) {
            channel = WebSocketChannel.connect(Uri.parse(Environment.webSocketIP));
          }
          
          // Convertir la imagen de la cámara a bytes
          if (Platform.isAndroid) {
            bytes = await convertCameraImageANDROID(image);
          } else {
            bytes = await convertCameraImageIOS(image);
          }

          // Enviar los bytes de la imagen al servidor WebSocket
          channel!.sink.add(bytes);

          // Escuchar los mensajes del servidor WebSocket
          channel!.stream.listen((message) {
            print(message);
            // guardar los mensajes en una lista
            data.add(message);
            update(['camera-screen']);
          });

        } catch (e) {
          print('Error: initializeStreaming(): $e');
        }

      }
    });
  }

  Future<void> stopStreaming() async {

    isStreaming = false;
    update(['camera-screen']);

    print('DETENIENDO STREAMING');

    await cameraController.stopImageStream();

    // Cierra el WebSocket solo si está abierto
    if (channel != null && channel!.closeCode == null) {
      await channel!.sink.close();
    }
  }

  Future<Uint8List> convertCameraImageIOS(CameraImage image) async {

    final plane = image.planes[0];

    final paqImg.Image rgbImage = paqImg.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: plane.bytes.buffer,
      rowStride: plane.bytesPerRow,
      bytesOffset: 28,
      order: paqImg.ChannelOrder.bgra,
    );

    // Encode the image to JPEG with optional quality parameter
    // Ajusta la calidad según sea necesario para equilibrar calidad y rendimiento
    final List<int> jpeg = paqImg.encodeJpg(rgbImage, quality: 85);

    // Retorna directamente los bytes JPEG sin usar un archivo temporal
    return Uint8List.fromList(jpeg);
  }

  Future<Uint8List> convertCameraImageANDROID(CameraImage cImage) async {
    // Crear un ReceivePort para recibir mensajes del Isolate
    final receivePort = ReceivePort();

    // Crear el Isolate
    await Isolate.spawn(
      convertYUV420toRGB,
      IsolateDataService(cImage, receivePort.sendPort),
    );

    // Esperar por el resultado
    final Uint8List result = await receivePort.first;
    return result;
  }

}