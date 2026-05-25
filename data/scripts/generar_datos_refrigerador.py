import random
import datetime
import csv
from datetime import timedelta

# Configuración general
N_REGISTROS = 25000
FECHA_INICIO = datetime.datetime(2025, 1, 1, 0, 0, 0)  # puedes cambiar la fecha base
INTERVALO_PROMEDIO_SEG = 4             # ~4 segundos entre lecturas en promedio
NOMBRE_ARCHIVO = "datos_refrigerador_25000_flag0.csv"

# Rangos realistas para refrigerador de carnicería
IN_TEMP_NORMAL = (1.8, 4.2)            # °C ideal para carnes frescas
IN_TEMP_ANOMALO = (4.3, 8.5)           # cuando hay problemas (usado con baja probabilidad)

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
    # Decidir estados principales
    door_open = random.random() < PROB_DOOR_OPEN
    power_on = random.random() >= PROB_POWER_OFF
    compressor_on = False

    if power_on:
        if door_open:
            compressor_on = True  # casi siempre enciende si puerta abierta
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

    # Pequeña probabilidad de anomalía térmica (para que tu ML tenga algo que aprender después)
    if random.random() < 0.08:
        in_temp += random.uniform(1.2, 4.5)

    out_temp = random.uniform(*OUT_TEMP)
    in_humid = random.uniform(*IN_HUMID_NORMAL) if not door_open else random.uniform(60, 88)
    out_humid = random.uniform(*OUT_HUMID)

    # Consumo eléctrico
    if not power_on:
        consumo = 0.0
    elif compressor_on:
        consumo = random.uniform(*CONSUMO_NORMAL_W)
        if random.random() < 0.07:  # anomalía de sobrecarga
            consumo = random.uniform(*CONSUMO_ANOMALO_W)
    else:
        consumo = random.uniform(*CONSUMO_BAJO_W)

    # Vibración
    vibracion = random.uniform(*VIBRACION_NORMAL)
    if compressor_on and random.random() < 0.09:
        vibracion = random.uniform(*VIBRACION_ALTA)

    # Formato de timestamp
    timestamp_str = tiempo_actual.strftime("%A %d.%m.%Y -- %H:%M:%S")

    # Estados como texto (manteniendo el estilo de tus ejemplos)
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

for i in range(N_REGISTROS):
    registro = generar_registro(tiempo)
    datos.append(registro)
    
    # Avanzar tiempo de forma variable (simulando lecturas irregulares)
    segundos_avance = random.gauss(INTERVALO_PROMEDIO_SEG, 1.8)
    segundos_avance = max(1, round(segundos_avance))
    tiempo += timedelta(seconds=segundos_avance)

    if (i + 1) % 5000 == 0:
        print(f"Generados {i+1} registros...")

# Guardar en CSV
columnas = ["inTemp", "InHumid", "outTemp", "outHumid", "DoorStatus", "PowerStatus",
            "ConsumoElectrico", "CompressorStatus", "Vibration", "Timestamp", "flag_mantenimiento"]

with open(NOMBRE_ARCHIVO, mode='w', newline='', encoding='utf-8') as f:
    writer = csv.DictWriter(f, fieldnames=columnas)
    writer.writeheader()
    for reg in datos:
        writer.writerow(reg)

print(f"\nArchivo generado: {NOMBRE_ARCHIVO}")
print(f"Total de registros: {len(datos)}")
print("Primeros 3 registros de ejemplo (flag siempre en 0):")
for reg in datos[:3]:
    print(reg)