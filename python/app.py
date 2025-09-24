import os
import json
import time
from typing import Dict, List, Tuple

import boto3
import cv2
import mediapipe as mp

# Configurações
KINESIS_STREAM_NAME = os.getenv("KINESIS_STREAM_NAME", "hand-gestures-stream")
AWS_REGION = os.getenv("AWS_DEFAULT_REGION", os.getenv("AWS_REGION", "us-east-1"))
MIN_SEND_INTERVAL_SEC = float(os.getenv("MIN_SEND_INTERVAL_SEC", "0.2"))  # limita envio para reduzir custo
IMAGE_FLIPPED = True  # usamos espelhamento para exibir como espelho

# Inicializações do MediaPipe e OpenCV
mp_hands = mp.solutions.hands
mp_drawing = mp.solutions.drawing_utils
mp_styles = mp.solutions.drawing_styles

# Cliente Kinesis
kinesis = boto3.client("kinesis", region_name=AWS_REGION)


def count_fingers(landmarks: List[Tuple[float, float]], handedness_label: str) -> int:
    """Conta dedos levantados usando landmarks normalizados (x,y) e rótulo de mão.

    Regras:
    - Polegar: compara x do tip (4) com IP (3) conforme mão (Right/Left).
    - Indicador, Médio, Anelar, Mínimo: tip (8, 12, 16, 20) acima (menor y) do PIP (6, 10, 14, 18).
    """
    if not landmarks or len(landmarks) < 21:
        return 0

    # Indices MediaPipe
    THUMB_TIP, THUMB_IP = 4, 3
    FINGERS_TIPS = [8, 12, 16, 20]
    FINGERS_PIPS = [6, 10, 14, 18]

    fingers_up = 0

    # Polegar
    thumb_tip_x = landmarks[THUMB_TIP][0]
    thumb_ip_x = landmarks[THUMB_IP][0]
    if handedness_label == "Right":
        if thumb_tip_x > thumb_ip_x:
            fingers_up += 1
    else:  # Left
        if thumb_tip_x < thumb_ip_x:
            fingers_up += 1

    # Demais dedos
    for tip_idx, pip_idx in zip(FINGERS_TIPS, FINGERS_PIPS):
        tip_y = landmarks[tip_idx][1]
        pip_y = landmarks[pip_idx][1]
        if tip_y < pip_y:
            fingers_up += 1

    return fingers_up


def send_to_kinesis(stream_name: str, payload: Dict) -> None:
    data = json.dumps(payload)
    kinesis.put_record(StreamName=stream_name, Data=data.encode("utf-8"), PartitionKey="hand")


def main() -> None:
    last_sent_time = 0.0

    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        raise RuntimeError("Não foi possível abrir a câmera.")

    with mp_hands.Hands(
        model_complexity=0,
        max_num_hands=2,
        min_detection_confidence=0.5,
        min_tracking_confidence=0.5,
    ) as hands:
        while True:
            success, image = cap.read()
            if not success:
                print("Falha ao capturar frame da câmera.")
                break

            # Mantemos o processamento com imagem espelhada para UX
            image = cv2.flip(image, 1)  # espelho
            image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
            results = hands.process(image_rgb)

            total_fingers = 0

            if results.multi_hand_landmarks and results.multi_handedness:
                for hand_landmarks, handedness in zip(
                    results.multi_hand_landmarks, results.multi_handedness
                ):
                    raw_label = handedness.classification[0].label  # "Left" ou "Right"

                    # Como aplicamos flip horizontal ANTES do process, o label fica invertido.
                    # Ajuste: invertendo label para refletir a mão real.
                    if IMAGE_FLIPPED:
                        handedness_label = "Left" if raw_label == "Right" else "Right"
                    else:
                        handedness_label = raw_label

                    coords = [(lm.x, lm.y) for lm in hand_landmarks.landmark]
                    total_fingers += count_fingers(coords, handedness_label)

                    # Desenho
                    mp_drawing.draw_landmarks(
                        image,
                        hand_landmarks,
                        mp_hands.HAND_CONNECTIONS,
                        mp_styles.get_default_hand_landmarks_style(),
                        mp_styles.get_default_hand_connections_style(),
                    )

            # Overlay no frame
            cv2.rectangle(image, (0, 0), (300, 60), (0, 0, 0), -1)
            cv2.putText(
                image,
                f"Dedos: {total_fingers}",
                (10, 40),
                cv2.FONT_HERSHEY_SIMPLEX,
                1.2,
                (0, 255, 0),
                2,
                cv2.LINE_AA,
            )

            # Enviar para Kinesis com rate limit
            now = time.time()
            if now - last_sent_time >= MIN_SEND_INTERVAL_SEC:
                try:
                    send_to_kinesis(KINESIS_STREAM_NAME, {"dedos": total_fingers})
                    last_sent_time = now
                except Exception as e:
                    # Loga no console, mas mantém aplicação rodando
                    print(f"Erro ao enviar para Kinesis: {e}")

            cv2.imshow("Detecção de Dedos (q para sair)", image)
            key = cv2.waitKey(1) & 0xFF
            if key == ord("q"):
                break

    cap.release()
    cv2.destroyAllWindows()


if __name__ == "__main__":
    main()
