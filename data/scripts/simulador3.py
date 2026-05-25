import random
import datetime
import csv
import os

# ================== CONFIGURACIÓN ==================
DIAS = 18
FECHA_INICIO = datetime.datetime(2025, 1, 1, 0, 0, 0)
INTERVALO_SEGUNDOS = 5                    # 5 o 10 segundos
CARPETA_SALIDA = "datos_coldtrack_diarios"
os.makedirs(CARPETA_SALIDA, exist_ok=True)

PROB_ANOMALIA = 0.08                      # Probabilidad de registro anómalo (para entrenar)
# ===================================================

def generar_registro(tiempo_actual, es_anomalia=False):
    # Estados probabilísticos base
    door_open = random.random() < 0.12
    power_on = random.random() >= 0.03
    
    if power_on:
        if door_open:
            compressor_on = True
        else:
            compressor_on = random.random() >= 0.45
    else:
        compressor_on = False

    # ====================== ANOMALÍA ======================
    if es_anomalia:
        in_temp     = random.uniform(6.5, 12.0)      # Temperatura crítica
        in_humid    = random.uniform(75, 92)         # Humedad alta
        out_temp    = random.uniform(25, 35)
        out_humid   = random.uniform(60, 95)
        vibration   = random.uniform(0.8, 1.6)
        consumo     = random.uniform(180, 255)
        flag        = 1

    # ====================== NORMAL ======================
    else:
        if door_open:
            in_temp = random.uniform(3.5, 7.8)
        elif compressor_on:
            in_temp = random.uniform(1.8, 4.2)
        else:
            in_temp = random.uniform(3.0, 5.5)

        # Pequeña anomalía térmica ocasional
        if random.random() < 0.08:
            in_temp += random.uniform(1.2, 4.0)
            in_temp = min(in_temp, 11.0)

        in_humid  = random.uniform(45, 75) if not door_open else random.uniform(60, 88)
        out_temp  = random.uniform(18.0, 32.0)
        out_humid = random.uniform(50, 90)

        if not power_on:
            consumo = 0.0
        elif compressor_on:
            consumo = random.uniform(90, 160)
            if random.random() < 0.07:
                consumo = random.uniform(170, 240)
        else:
            consumo = random.uniform(20, 60)

        vibration = random.uniform(0.02, 0.45)
        if compressor_on and random.random() < 0.09:
            vibration = random.uniform(0.50, 1.3)
        
        flag = 0

    # Timestamp
    timestamp_str = tiempo_actual.strftime("%A %d.%m.%Y -- %H:%M:%S")

    door_str = "DoorOPEN" if door_open else "DoorCLOSED"
    power_str = "PowerON" if power_on else "PowerOFF"
    comp_str = "CompressorON" if compressor_on else "CompressorOFF"

    # Return correcto (todas las variables siempre definidas)
    return {
        "inTemp": round(in_temp, 2),
        "InHumid": round(in_humid, 2),
        "outTemp": round(out_temp, 2),
        "outHumid": round(out_humid, 2),
        "DoorStatus": door_str,
        "PowerStatus": power_str,
        "ConsumoElectrico": round(consumo, 2),
        "CompressorStatus": comp_str,
        "Vibration": round(vibration, 2),
        "Timestamp": timestamp_str,
        "flag_mantenimiento": flag
    }

# ================== GENERACIÓN DE 18 ARCHIVOS ==================
for d in range(DIAS):
    fecha = FECHA_INICIO + datetime.timedelta(days=d)
    nombre_archivo = f"{CARPETA_SALIDA}/datos_refrigerador_{fecha.strftime('%Y-%m-%d')}.csv"
    
    datos_dia = []
    tiempo = fecha
    registros_dia = 86400 // INTERVALO_SEGUNDOS   # 17280 para 5 segundos

    print(f"Generando día {d+1:2d}/18 → {nombre_archivo} ({registros_dia:,} registros)")

    for i in range(registros_dia):
        es_anomalia = random.random() < PROB_ANOMALIA
        registro = generar_registro(tiempo, es_anomalia)
        datos_dia.append(registro)
        tiempo += datetime.timedelta(seconds=INTERVALO_SEGUNDOS)

    # Escribir el CSV del día
    columnas = ["inTemp", "InHumid", "outTemp", "outHumid", "DoorStatus",
                "PowerStatus", "ConsumoElectrico", "CompressorStatus",
                "Vibration", "Timestamp", "flag_mantenimiento"]

    with open(nombre_archivo, mode='w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=columnas)
        writer.writeheader()
        writer.writerows(datos_dia)

print("\n✅ ¡Generación completada correctamente!")
print(f"Se crearon {DIAS} archivos en la carpeta: {CARPETA_SALIDA}")