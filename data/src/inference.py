"""
ColdTrack - Inferencia Final (Versión Minimal y Segura)
Compatible con el modelo final de 16 features
"""

import pandas as pd
import numpy as np
import joblib
from collections import deque
import warnings

warnings.filterwarnings('ignore')

class ColdTrackPredictor:
    def __init__(self):
        self.model = joblib.load("models/coldtrack_rf_model_final.pkl")
        self.feature_columns = joblib.load("models/feature_columns_final.pkl")
        self.threshold = joblib.load("models/decision_threshold.pkl")
        
        self.buffer = deque(maxlen=360)
        
        print(f"ColdTrack Predictor inicializado | Umbral: {self.threshold}")

    def predict(self, nueva_lectura: dict) -> dict:
        self.buffer.append(nueva_lectura)
        
        if len(self.buffer) < 10:
            return {
                "probabilidad": 0.0,
                "requiere_mantenimiento": False,
                "confianza": "Insuficiente datos",
                "buffer_size": len(self.buffer)
            }
        
        df = pd.DataFrame(self.buffer)
        df['Timestamp'] = pd.to_datetime(df['Timestamp'], format="%A %d.%m.%Y -- %H:%M:%S", errors='coerce')
        df = df.sort_values('Timestamp').reset_index(drop=True)
        
        n = len(df)
        
        # Solo creamos las columnas que el modelo final necesita
        df['temp_diff_setpoint'] = df['inTemp'] - 2.5
        df['hour'] = df['Timestamp'].dt.hour
        df['day_of_week'] = df['Timestamp'].dt.dayofweek
        df['is_weekend'] = df['day_of_week'].isin([5, 6]).astype(int)
        
        df['DoorOPEN_flag'] = (df['DoorStatus'] == 'DoorOPEN').astype(int)
        
        df['inTemp_ma_5min']   = df['inTemp'].rolling(window=min(60, n), min_periods=1).mean()
        df['inTemp_ma_15min']  = df['inTemp'].rolling(window=min(180, n), min_periods=1).mean()
        df['inTemp_ma_30min']  = df['inTemp'].rolling(window=min(360, n), min_periods=1).mean()
        
        df['Vibration_ma_5min'] = df['Vibration'].rolling(window=min(60, n), min_periods=1).mean()
        df['Vibration_ma_15min'] = df['Vibration'].rolling(window=min(180, n), min_periods=1).mean()
        
        df['ConsumoElectrico_ma_5min'] = df['ConsumoElectrico'].rolling(window=min(60, n), min_periods=1).mean()
        
        df['door_open_last_hour'] = df['DoorOPEN_flag'].rolling(window=min(720, n), min_periods=1).sum()
        
        # Tendencia segura
        def safe_slope(x):
            if len(x) < 2:
                return 0.0
            return np.polyfit(range(len(x)), x, 1)[0]
        
        if n >= 10:
            df['inTemp_trend_30min'] = df['inTemp'].rolling(window=min(360, n), min_periods=10).apply(safe_slope, raw=True)
        else:
            df['inTemp_trend_30min'] = 0.0
        
        # Selección exacta
        X_new = df.iloc[[-1]][self.feature_columns]
        
        proba = self.model.predict_proba(X_new)[0, 1]
        requiere = proba >= self.threshold
        
        confianza = "Alta" if proba > 0.85 else "Media" if proba > 0.65 else "Baja"
        
        return {
            "probabilidad": round(proba, 4),
            "requiere_mantenimiento": bool(requiere),
            "confianza": confianza,
            "buffer_size": len(self.buffer)
        }


# ====================== PRUEBA ======================
if __name__ == "__main__":
    predictor = ColdTrackPredictor()
    
    print("\n=== PRUEBA CON LECTURAS REALES ===\n")
    
    df_test = pd.read_csv("coldtrack_dataset_completo.csv").iloc[10000:10060]
    
    for i, row in df_test.iterrows():
        lectura = {
            "inTemp": float(row["inTemp"]),
            "InHumid": float(row["InHumid"]),
            "outTemp": float(row["outTemp"]),
            "outHumid": float(row["outHumid"]),
            "DoorStatus": str(row["DoorStatus"]),
            "PowerStatus": str(row["PowerStatus"]),
            "ConsumoElectrico": float(row["ConsumoElectrico"]),
            "CompressorStatus": str(row["CompressorStatus"]),
            "Vibration": float(row["Vibration"]),
            "Timestamp": str(row["Timestamp"])
        }
        
        resultado = predictor.predict(lectura)
        
        if i % 5 == 0 or resultado["requiere_mantenimiento"]:
            estado = "⚠️ MANTENIMIENTO" if resultado["requiere_mantenimiento"] else "✅ Normal"
            print(f"[{row['Timestamp']}] Prob: {resultado['probabilidad']:.4f} | {estado} | {resultado['confianza']}")

    print("\n✅ Prueba finalizada.")