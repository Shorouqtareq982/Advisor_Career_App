import json
import os
import time
from pathlib import Path

import requests

API_BASE_URL = os.getenv("API_BASE_URL", "http://localhost:8000/api/v1")
AUTH_TOKEN = os.getenv("AUTH_TOKEN", "")
ROLE_NAME = os.getenv("ROLE_NAME", "Software Engineer")
VIDEO_PATH = os.getenv(
    "VIDEO_PATH",
    str(
        Path(__file__).resolve().parents[2]
        / "features"
        / "mock_interview"
        / "ml_model"
        / "test-videos"
        / "13kjwEtSyXc.003.mp4"
    ),
)


def _auth_headers() -> dict:
    if not AUTH_TOKEN:
        raise RuntimeError("AUTH_TOKEN is not set")
    return {"Authorization": f"Bearer {AUTH_TOKEN}"}


def _start_session() -> dict:
    payload = {"role_name": ROLE_NAME}
    response = requests.post(
        f"{API_BASE_URL}/mock-interview/sessions/start/behavioral",
        headers={**_auth_headers(), "Content-Type": "application/json"},
        data=json.dumps(payload),
        timeout=60,
    )
    response.raise_for_status()
    data = response.json()

    if not data.get("session_id"):
        raise AssertionError("session_id missing")
    if not data.get("questions"):
        raise AssertionError("questions missing")
    if not data.get("sas_token"):
        raise AssertionError("sas_token missing")
    if not data.get("blob_url"):
        raise AssertionError("blob_url missing")
    if not data.get("sas_expires_at"):
        raise AssertionError("sas_expires_at missing")

    return data


def _stream_audio(question_id: str) -> None:
    response = requests.get(
        f"{API_BASE_URL}/mock-interview/questions/{question_id}/audio-stream",
        headers=_auth_headers(),
        timeout=120,
    )
    response.raise_for_status()
    if response.headers.get("content-type") != "audio/mpeg":
        raise AssertionError("Expected audio/mpeg response")
    if not response.content:
        raise AssertionError("Audio response is empty")

    output_path = Path(__file__).parent / "question_audio.mp3"
    output_path.write_bytes(response.content)


def _upload_video(blob_url: str, sas_token: str) -> None:
    video_path = Path(VIDEO_PATH)
    if not video_path.exists():
        raise FileNotFoundError(f"Video file not found: {video_path}")

    if "?" in blob_url:
        upload_url = blob_url
    else:
        upload_url = f"{blob_url}?{sas_token}"

    with video_path.open("rb") as handle:
        response = requests.put(
            upload_url,
            headers={
                "x-ms-blob-type": "BlockBlob",
                "Content-Type": "video/mp4",
            },
            data=handle,
            timeout=300,
        )
    if response.status_code not in (201, 202):
        raise AssertionError(f"Video upload failed: {response.status_code} {response.text}")


def _notify_upload(session_id: str, blob_url: str) -> None:
    payload = {"session_id": session_id, "blob_url": blob_url}
    response = requests.post(
        f"{API_BASE_URL}/mock-interview/behavioural/notify-upload",
        headers={**_auth_headers(), "Content-Type": "application/json"},
        data=json.dumps(payload),
        timeout=60,
    )
    response.raise_for_status()
    data = response.json()
    if data.get("status") != "processing":
        raise AssertionError("Expected status=processing")


def _poll_behavioral_report(session_id: str, timeout_seconds: int = 120) -> dict:
    deadline = time.time() + timeout_seconds
    while time.time() < deadline:
        response = requests.get(
            f"{API_BASE_URL}/mock-interview/analysis/{session_id}/behavioral-report",
            headers=_auth_headers(),
            timeout=30,
        )
        if response.status_code == 404:
            time.sleep(5)
            continue
        response.raise_for_status()
        data = response.json()
        if not data.get("behavioral_report"):
            time.sleep(5)
            continue
        if not data.get("analysis_metrics"):
            raise AssertionError("analysis_metrics is empty")
        return data

    raise TimeoutError("Timed out waiting for behavioral report")


def _poll_technical_report(session_id: str, timeout_seconds: int = 120) -> dict:
    deadline = time.time() + timeout_seconds
    while time.time() < deadline:
        response = requests.get(
            f"{API_BASE_URL}/mock-interview/analysis/{session_id}/technical-report",
            headers=_auth_headers(),
            timeout=30,
        )
        if response.status_code == 404:
            time.sleep(5)
            continue
        response.raise_for_status()
        data = response.json()
        if not data.get("technical_report"):
            time.sleep(5)
            continue
        return data

    raise TimeoutError("Timed out waiting for technical report")


def run_flow() -> None:
    session_data = _start_session()
    question_id = session_data["questions"][0]["question_id"]
    _stream_audio(question_id)
    _upload_video(session_data["blob_url"], session_data["sas_token"])
    _notify_upload(session_data["session_id"], session_data["blob_url"])
    behavioral_report = _poll_behavioral_report(session_data["session_id"])
    technical_report = _poll_technical_report(session_data["session_id"])

    print("Flow completed successfully")
    print("Behavioral report")
    print(json.dumps(behavioral_report, indent=2))
    print("Technical report")
    print(json.dumps(technical_report, indent=2))


if __name__ == "__main__":
    run_flow()
