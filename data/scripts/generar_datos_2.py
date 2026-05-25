import random
import datetime
import csv

# Configuración general
N_REGISTROS = 25000
FECHA_INICIO = datetime.datetime(2025, 1, 1, 0, 0, 0)  # puedes cambiar la fecha base
INTERVALO_SEGUNDOS = 60                                 # exactamente 1 minuto entre lecturas
NOMBRE_ARCHIVO = "datos_refrigerador_25000_1porMinuto.csv"

# Rangos realistas para refrigerador de carnicería
IN_TEMP_NORMAL = (1.8, 4.2)            # °C ideal para carnes frescas
OUT_TEMP = (18.0, 32.0)                # ambiente carnicería
IN_HUMID_NORMAL = (45, 75)
OUT_HUMID = (50, 90)

CONSUMO_NORMAL_W = (90, 160)           # compresor encendido
CONSUMO_BAJO_W = (20, 60)              # ventiladores / standby
CONSUMO_ANOMALO_W = (170, 240)

VIBRACION_NORMAL = (0.02, 0.45)
VIBRACION_ALTA = (0.50, 1.2)

# Probabilidades de estados
PROB_DOOR_OPEN = 0.12                  # ~12% del tiempo la puerta está abierta
PROB_POWER_OFF = 0.03                  # cortes de energía raros
PROB_COMP_OFF_NORMAL = 0.45            # duty cycle aproximado ~55% encendido

def generar_registro(tiempo_actual):
    door_open = random.random() < PROB_DOOR_OPEN
    power_on = random.random() >= PROB_POWER_OFF
    compressor_on = False

    if power_on:
        if door_open:
            compressor_on = True
        else:
            compressor_on = random.random() >= PROB_COMP_OFF_NORMAL
    else:
        compressor_on = False

    # Temperaturas
    if door_open:
        in_temp = random.uniform(3.5, 7.8)
    elif compressor_on:
        in_temp = random.uniform(*IN_TEMP_NORMAL)
    else:
        in_temp = random.uniform(3.0, 5.5)

    # Pequeña probabilidad de anomalía térmica (para entrenamiento futuro de ML)
    if random.random() < 0.08:
        in_temp += random.uniform(1.2, 4.5)
        in_temp = min(in_temp, 12.0)  # límite realista

    out_temp = random.uniform(*OUT_TEMP)
    in_humid = random.uniform(*IN_HUMID_NORMAL) if not door_open else random.uniform(60, 88)
    out_humid = random.uniform(*OUT_HUMID)

    # Consumo eléctrico
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

    # Formato timestamp (igual al de tus ejemplos originales)
    timestamp_str = tiempo_actual.strftime("%A %d.%m.%Y -- %H:%M:%S")

    door_str = "DoorOPEN" if door_open else "DoorCLOSED"
    power_str = "PowerON" if power_on else "PowerOFF"
    comp_str = "CompressorON" if compressor_on else "CompressorOFF"

    return {
        "inTemp": round(in_temp, 2),
        "InHumid": round(in_humid, 2),
        "outTemp": round(out_temp, 2),
        "outHumid": round(out_humid, 2),
        "DoorStatus": door_str,
        "PowerStatus": power_str,
        "ConsumoElectrico": round(consumo, 2),
        "CompressorStatus": comp_str,
        "Vibration": round(vibracion, 2),
        "Timestamp": timestamp_str,
        "flag_mantenimiento": 0
    }


# Generar datos
datos = []
tiempo = FECHA_INICIO

print("Generando 25,000 registros (1 por minuto)...")

for i in range(N_REGISTROS):
    registro = generar_registro(tiempo)
    datos.append(registro)
    
    # Avance fijo: +1 minuto exacto
    tiempo += datetime.timedelta(seconds=INTERVALO_SEGUNDOS)

    if (i + 1) % 5000 == 0:
        print(f"→ {i+1} registros generados")

# Guardar en CSV
columnas = ["inTemp", "InHumid", "outTemp", "outHumid", "DoorStatus", "PowerStatus",
            "ConsumoElectrico", "CompressorStatus", "Vibration", "Timestamp", "flag_mantenimiento"]

with open(NOMBRE_ARCHIVO, mode='w', newline='', encoding='utf-8') as f:
    writer = csv.DictWriter(f, fieldnames=columnas)
    writer.writeheader()
    for reg in datos:
        writer.writerow(reg)

print(f"\nArchivo generado correctamente: {NOMBRE_ARCHIVO}")
print(f"Total de registros: {len(datos)}")
print(f"Duración simulada: desde {datos[0]['Timestamp']} hasta {datos[-1]['Timestamp']}")
print("Primeros 2 registros de ejemplo:")
for reg in datos[:2]:
    print(reg)
