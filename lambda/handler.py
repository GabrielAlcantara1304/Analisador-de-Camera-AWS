import base64
import json
import logging
from typing import Any, Dict, List

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """Processa eventos do Kinesis e registra quantidade de dedos.

    Cada registro vem base64-encoded em event['Records'][i]['kinesis']['data'].
    """
    processed = 0

    for record in event.get("Records", []):
        data_b64 = record.get("kinesis", {}).get("data")
        if not data_b64:
            continue
        try:
            payload_raw = base64.b64decode(data_b64)
            payload = json.loads(payload_raw)
            dedos = payload.get("dedos")
            logger.info("Você levantou %s dedos", dedos)
            processed += 1
        except Exception as exc:
            logger.exception("Falha ao processar registro: %s", exc)

    return {"status": "ok", "processed": processed}