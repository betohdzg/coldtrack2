import json
import random
import time
from datetime import datetime

try:
    import firebase_admin
    from firebase_admin import credentials
    from firebase_admin import db
except ImportError:
    print("Error: firebase-admin no está instalado.")
    print("Ejecuta:  pip install firebase-admin   (o pip3 install firebase-admin en macOS)")
    exit(1)


def generar_datos_simulados():
    """
    Genera datos simulados de los sensores en una carnicería.
    Todos los valores son aleatorios dentro de rangos realistas.
    """
    # Simulación simple de puerta: 15–25% de probabilidad de estar abierta en cada envío
    estado_puerta = 'abierto' if random.random() < 0.20 else 'cerrado'
    
    # Conteo acumulativo (en hardware real se mantendría en memoria o EEPROM)
    conteo_aperturas = random.randint(0, 60)  # simulación; en real sería persistente

    datos = {
        "timestamp": datetime.now().isoformat(),
        "temperatura_refrigerador_bhs200c": round(random.uniform(0.5, 5.8), 2),     # °C — algo de margen realista
        "temperatura_ambiental_cdvalles": round(random.uniform(22.0, 40), 2),     # °C — clima típico Cd. Valles
        "humedad_ambiental": round(random.uniform(45, 82), 1),                      # %  — zona húmeda
        "estado_puertas": estado_puerta,
        "conteo_aperturas_puertas": conteo_aperturas,
        "consumo_electrico_w": round(random.uniform(120, 480), 1)                   # W — consumo típico refrigerador comercial
    }
    return datos   # ← devolvemos diccionario directamente (mejor para Firebase)


def enviar_a_firebase():
    """
    Inicializa Firebase Admin SDK y envía datos cada 5 segundos.
    """
    # ────────────────────────────────────────────────
    # ¡¡¡ MODIFICA ESTAS DOS LÍNEAS CON TUS VALORES !!!
    # ────────────────────────────────────────────────
    ARCHIVO_CREDENCIALES = "/Users/josea/Documents/pruebas-json/credentials/carnitrackmigajas-d689b-firebase-adminsdk-fbsvc-03b8d27c9b.json"
    URL_DATABASE = "https://carnitrackmigajas-d689b-default-rtdb.firebaseio.com/"

    try:
        cred = credentials.Certificate(ARCHIVO_CREDENCIALES)
        firebase_admin.initialize_app(cred, {
            'databaseURL': URL_DATABASE
        })
    except Exception as e:
        print("Error al inicializar Firebase:")
        print(e)
        print("\nVerifica:")
        print("  • Ruta al archivo JSON de credenciales")
        print("  • URL de la base de datos (incluye https:// y termina en .com/)")
        print("  • Que el proyecto tenga Realtime Database creada")
        exit(1)

    # Ruta donde se guardarán los datos (puedes cambiarla)
    ref = db.reference('sensores/carniceria/refrigerador')

    print("┌──────────────────────────────────────────────────────┐")
    print("│  Simulador de sensores → Firebase Realtime Database  │")
    print("│  Enviando datos cada tantos segundos...                   │")
    print("│  Presiona Ctrl + C para detener                      │")
    print("└──────────────────────────────────────────────────────┘")
    print("Ruta en Firebase:", ref.path)
    print("")

    contador = 0
    while True:
        try:
            datos = generar_datos_simulados()
            # Usamos push() → crea un ID único automático por cada medición
            nuevo_registro = ref.push(datos)
            
            contador += 1
            print(f"[{contador:04d}] Enviado → {datos['timestamp']}")
            print(f"   Temp refri: {datos['temperatura_refrigerador_bhs200c']} °C")
            print(f"   Temp amb:   {datos['temperatura_ambiental_cdvalles']} °C")
            print(f"   Humedad:    {datos['humedad_ambiental']}%")
            print(f"   Puerta:     {datos['estado_puertas']} (conteo: {datos['conteo_aperturas_puertas']})")
            print(f"   Consumo:    {datos['consumo_electrico_w']} W")
            print("-" * 60)

            time.sleep(60)

        except KeyboardInterrupt:
            print("\nDetenido por el usuario. Saliendo...")
            break
        except Exception as e:
            print("Error durante el envío:", e)
            time.sleep(10)  # espera más antes de reintentar


if __name__ == "__main__":
    enviar_a_firebase()