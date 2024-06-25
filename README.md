# detector_live_websocket

Proyecto en Flutter(3.7.11) para el envío de fotogramas a un servidor WebSocket desarrollado en Python(3.12.4).

## Requisitos

- Python 3.12.4
- pip 3
- virtual env
- Flutter 3.7.11

## Preparar servidor

- Abrir carpeta server_websocket_python(en el proyecto) en una ventada nueva de Visual Studio Code.
- crear entorno virtual:
```
virtualenv env
```
- activar entorno virtual:
```
source env/bin/source
```
- Instalar requirements.txt:
```
pip3 install -r requirements.txt
```
- Correr servidor:
```
python3 server.py
```

## Preparar cliente

- en el archivo lib/config/constants/environment.dart, reemplazar por la ip y el puerto de acceso del servidor:
```
static const String webSocketIP = "ws://ip:puerto";

EJ: ws://111.222.333.44:8080
```

## Servidor Pruebas

- apuntar cliente a ip obtenida en ifconfig