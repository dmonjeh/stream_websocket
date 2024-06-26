import 'package:camera/camera.dart';
import 'package:detector_live_websocket/presentation/provider/camera_provider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GetBuilder<CameraProvider>(
        id: 'camera-screen',
        init: CameraProvider(),
        builder: (cameraProvider) => SafeArea(
          child: SizedBox(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  (cameraProvider.isCameraInitialized)
                    ? SizedBox(
                      height: 500,
                      child: Stack(
                        children: [
                          CameraPreview(cameraProvider.cameraController),
                                
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              height: 150,
                              width: 90,
                              color: Colors.black.withOpacity(0.5),
                              child: ListView.builder(
                                itemCount: cameraProvider.data.length,
                                itemBuilder: (context, index) => Text(
                                  cameraProvider.data[index],
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                  ),
                                )
                              ),
                            ),
                          ),
                                
                          Positioned(
                            bottom: 10,
                            left: 10,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Datos detectados: ${cameraProvider.data.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    : const Center(child: CircularProgressIndicator()),
              
                  TextButton(
                    onPressed: (!cameraProvider.isStreaming)
                     ? () async => await cameraProvider.initializeStreaming()
                     : () async => await cameraProvider.stopStreaming(),
                    child: (!cameraProvider.isStreaming)
                     ? const Text('Iniciar streaming')
                     : const Text('detener streaming'),
                  ),
              
                ],
              ),
            ),
          )
        )
      ),
    );
  }
}