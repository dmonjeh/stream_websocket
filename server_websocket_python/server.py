import asyncio
import websockets
import os

cont = 0

async def handler(websocket, path):
    try:
        data = await websocket.recv()
        
        print('llego la data')

        global cont
        cont += 1

        # Obtén la ruta del escritorio
        desktop_path = os.path.join(os.path.expanduser("~"), "Desktop/fotos")

        # Define la ruta del archivo
        file_path = os.path.join(desktop_path, "SF-"+str(cont)+".jpg")

        # Guarda la cadena de bytes como una imagen
        with open(file_path, 'wb') as f:
            f.write(data)

        print('se guardo')

        # Hacer una pausa de 1.5 segundos emulando un proceso de reconocimiento de fotos
        # retorna una lista de datos obtenidos de la imagen
        await asyncio.sleep(1.5)
        dataImg = ['AABB11', 'CCDD22', 'FFGG33']
        
        # Enviar los datos obtenidos al cliente
        for data in dataImg:
            await websocket.send(data)  

    except websockets.ConnectionClosed:
        print("Connection closed by the client")


start_server = websockets.serve(handler, '0.0.0.0', 8080, max_size=10**8 )

asyncio.get_event_loop().run_until_complete(start_server)
print("Server started")
asyncio.get_event_loop().run_forever()
