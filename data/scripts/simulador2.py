import json
import random
import time
from datetime import datetime, timedelta

try:
    import firebase_admin
    from firebase_admin import credentials
    from firebase_admin import db
except ImportError:
    print("Error: firebase-admin no está instalado.")
    print("Ejecuta: pip install firebase-admin  (o pip3 en macOS)")
    exit(1)

# ────────────────────────────────────────────────
# CONFIGURACIÓN PRINCIPAL (ajusta aquí si necesitas)
# ────────────────────────────────────────────────
ARCHIVO_CREDENCIALES = "/Users/josea/Documents/pruebas-json/credentials/carnitrackmigajas-d689b-firebase-adminsdk-fbsvc-03b8d27c9b.json"
URL_DATABASE         = "https://carnitrackmigajas-d689b-default-rtdb.firebaseio.com/"

INTERVALO_ENVIO      = 60          # segundos (1 minuto, igual que tu CSV)
RUTA_FIREBASE        = "sensores/refrigerador/lecturas"   # push() creará hijos con ID único

# Rangos y probabilidades (copiados de tu generador CSV)
IN_TEMP_NORMAL       = (1.8, 4.2)
OUT_TEMP             = (18.0, 32.0)
IN_HUMID_NORMAL      = (45, 75)
OUT_HUMID            = (50, 90)
CONSUMO_NORMAL_W     = (90, 160)
CONSUMO_BAJO_W       = (20, 60)
CONSUMO_ANOMALO_W    = (170, 240)
VIBRACION_NORMAL     = (0.02, 0.45)
VIBRACION_ALTA       = (0.50, 1.2)

PROB_DOOR_OPEN       = 0.12
PROB_POWER_OFF       = 0.03
PROB_COMP_OFF_NORMAL = 0.45   # ~55% duty cycle cuando power on y puerta cerrada

def generar_registro():
    """Genera un registro idéntico en lógica y rangos al de tu CSV."""
    door_open = random.random() < PROB_DOOR_OPEN
    power_on  = random.random() >= PROB_POWER_OFF
    
    compressor_on = False
    if power_on:
        if door_open:
            compressor_on = True
        else:
            compressor_on = random.random() >= PROB_COMP_OFF_NORMAL

    # Temperatura interior
    if door_open:
        in_temp = random.uniform(3.5, 7.8)
    elif compressor_on:
        in_temp = random.uniform(*IN_TEMP_NORMAL)
    else:
        in_temp = random.uniform(3.0, 5.5)
    
    # Anomalía térmica ocasional (como en tu generador)
    if random.random() < 0.08:
        in_temp += random.uniform(1.2, 4.5)
        in_temp = min(in_temp, 12.0)

    # Otras variables
    out_temp   = random.uniform(*OUT_TEMP)
    in_humid   = random.uniform(*IN_HUMID_NORMAL) if not door_open else random.uniform(60, 88)
    out_humid  = random.uniform(*OUT_HUMID)

    # Consumo
    if not power_on:
        consumo = 0.0
    elif compressor_on:
        consumo = random.uniform(*CONSUMO_NORMAL_W)
        if random.random() < 0.07:
            consumo = random.uniform(*CONSUMO_ANOMALO_W)
    else:
        consumo = random.uniform(*CONSUMO_BAJO_W)

    # Vibración
    vibracion = random.uniform(*VIBRACION_NORMAL)
    if compressor_on and random.random() < 0.09:
        vibracion = random.uniform(*VIBRACION_ALTA)

    # Timestamp con formato exacto de tu CSV
    ahora = datetime.now()
    timestamp_str = ahora.strftime("%A %d.%m.%Y -- %H:%M:%S")

    # Estados como strings
    door_str   = "DoorOPEN"  if door_open   else "DoorCLOSED"
    power_str  = "PowerON"   if power_on    else "PowerOFF"
    comp_str   = "CompressorON" if compressor_on else "CompressorOFF"

    return {
        "inTemp":            round(in_temp, 2),
        "InHumid":           round(in_humid, 2),
        "outTemp":           round(out_temp, 2),
        "outHumid":          round(out_humid, 2),
        "DoorStatus":        door_str,
        "PowerStatus":       power_str,
        "ConsumoElectrico":  round(consumo, 2),
        "CompressorStatus":  comp_str,
        "Vibration":         round(vibracion, 2),
        "Timestamp":         timestamp_str,
        "flag_mantenimiento": 0   # puedes poner lógica futura aquí
    }

def enviar_a_firebase():
    try:
        cred = credentials.Certificate(ARCHIVO_CREDENCIALES)
        firebase_admin.initialize_app(cred, {'databaseURL': URL_DATABASE})
    except Exception as e:
        print("Error al inicializar Firebase:", e)
        exit(1)

    ref = db.reference(RUTA_FIREBASE)

    print("┌────────────────────────────────────────────────────────────┐")
    print("│  Simulador refrigerador → Firebase (formato CSV idéntico)  │")
    print(f"│  Enviando cada {INTERVALO_ENVIO} segundos a: {RUTA_FIREBASE} │")
    print("│  Ctrl+C para detener                                       │")
    print("└────────────────────────────────────────────────────────────┘\n")

    contador = 0
    while True:
        try:
            datos = generar_registro()
            ref.push(datos)   # ← cada lectura es un nodo nuevo con ID único

            contador += 1
            print(f"[{contador:04d}] Enviado → {datos['Timestamp']}")
            print(f"  inTemp: {datos['inTemp']:5.2f} °C   |  Door: {datos['DoorStatus']}")
            print(f"  Consumo: {datos['ConsumoElectrico']:6.2f} W  |  Compressor: {datos['CompressorStatus']}")
            print(f"  Vibration: {datos['Vibration']:5.2f}   |  flag_mantenimiento: {datos['flag_mantenimiento']}")
            print("-" * 70)

            time.sleep(INTERVALO_ENVIO)

        except KeyboardInterrupt:
            print("\nDetenido por usuario.")
            break
        except Exception as e:
            print("Error en envío:", e)
            time.sleep(10)

if __name__ == "__main__":
    enviar_a_firebase()
