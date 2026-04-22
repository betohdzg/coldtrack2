# test_prediction_from_csv.py
# Prototipo: Simula datos desde CSV y prueba el modelo en tiempo real

import pandas as pd
import joblib
import time
from src.inference import ColdTrackPredictor

print("=== COLDTRACK - PRUEBA DE INFERENCIA CON CSV (Prototipo) ===\n")

# Cargar el predictor (ya incluye modelo, columnas y umbral)
predictor = ColdTrackPredictor()

# Cargar el dataset completo
df = pd.read_csv("coldtrack_dataset_completo.csv")

print(f"Dataset cargado: {len(df):,} registros")
print("Iniciando simulación de flujo del hardware cada 5 segundos...\n")

# Simular envío de datos fila por fila
for i in range(len(df)):
    row = df.iloc[i]
    
    lectura = {
        "inTemp": row["inTemp"],
        "InHumid": row["InHumid"],
        "outTemp": row["outTemp"],
        "outHumid": row["outHumid"],
        "DoorStatus": row["DoorStatus"],
        "PowerStatus": row["PowerStatus"],
        "ConsumoElectrico": row["ConsumoElectrico"],
        "CompressorStatus": row["CompressorStatus"],
        "Vibration": row["Vibration"],
        "Timestamp": row["Timestamp"]
    }
    
    # Usar la función completa con feature engineering
    resultado = predictor.predict(lectura)
    
    estado = "⚠️ MANTENIMIENTO" if resultado["requiere_mantenimiento"] else "✅ Normal"
    
    if i % 30 == 0 or resultado["requiere_mantenimiento"]:   # Mostrar cada 30 lecturas o cuando detecte mantenimiento
        print(f"[{row['Timestamp']}]  Prob: {resultado['probabilidad']:.4f}  |  {estado}  |  Confianza: {resultado['confianza']}")

    # Simular tiempo real (5 segundos entre lecturas)
    time.sleep(0.05)   # 0.05 para que no sea tan lento en prueba

print("\n✅ Prueba de prototipo finalizada.")