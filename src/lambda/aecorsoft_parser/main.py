import re
from typing import Any, Dict


def _failure(message: str, event: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "aecorsoft_status": "FAILED",
        "error_message": message,
        "ssm_status": event.get("ssm_status"),
        "response_code": event.get("response_code"),
    }


def handler(event: Dict[str, Any], _context: Any) -> Dict[str, Any]:
    ssm_status = event.get("ssm_status")
    response_code = event.get("response_code")
    standard_output = event.get("standard_output") or ""
    standard_error = event.get("standard_error") or ""
    bucket = event.get("bucket")
    base_path = (event.get("base_path") or "").strip("/")

    combined_log = "\n".join(part for part in [standard_output, standard_error] if part)

    if not bucket:
        return _failure("No se recibio bucket para validar salida Aecorsoft.", event)

    if ssm_status != "Success" or response_code not in (0, "0", None):
        return _failure("SSM no finalizo exitosamente la ejecucion del CLI Aecorsoft.", event)

    if not re.search(r"(?i)task\s+completed\.", combined_log):
        return _failure("No se encontro senal de exito 'Task completed.' en el log Aecorsoft.", event)

    if not re.search(r"(?i)upload:\s*done\.", combined_log):
        return _failure("No se encontro senal de exito 'Upload: done.' en el log Aecorsoft.", event)

    s3_matches = re.findall(r"(?i)S3 file\s+'([^']+)'", combined_log)
    if not s3_matches:
        return _failure("No se encontro ruta S3 generada por Aecorsoft en el log.", event)

    raw_s3_path = s3_matches[-1].strip()
    s3_uri_match = re.match(r"^s3://([^/]+)/(.+)$", raw_s3_path)
    if s3_uri_match:
        output_bucket = s3_uri_match.group(1)
        s3_key = s3_uri_match.group(2).lstrip("/")
    else:
        output_bucket = bucket
        s3_key = raw_s3_path.lstrip("/")

    codproceso_match = re.search(r"(?i)codproceso=([^/\\\s']+)", s3_key)
    if not codproceso_match:
        return _failure(f"No se encontro codproceso en la ruta S3: {s3_key}", event)

    codproceso = codproceso_match.group(1)
    prefix_match = re.match(r"(?i)^(.*codproceso=[^/]+/)", s3_key)
    if prefix_match:
        partition_prefix = prefix_match.group(1)
    elif base_path:
        partition_prefix = f"{base_path}/codproceso={codproceso}/"
    else:
        return _failure("No se pudo construir partition_prefix desde log ni base_path.", event)

    return {
        "aecorsoft_status": "SUCCESS",
        "ssm_status": ssm_status,
        "response_code": response_code,
        "codproceso": codproceso,
        "bucket": output_bucket,
        "s3_key": s3_key,
        "partition_prefix": partition_prefix,
        "partition_location": f"s3://{output_bucket}/{partition_prefix}",
    }
