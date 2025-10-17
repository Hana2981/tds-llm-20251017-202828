# app/notify.py
import httpx
import os
from dotenv import load_dotenv
import time

load_dotenv()

def notify_evaluation_server(evaluation_url: str, payload: dict) -> bool:
    """
    Send repository/task details back to the evaluation server.
    Retries up to 5 times with exponential backoff if there are errors.
    """
    headers = {"Content-Type": "application/json"}
    delay = 1  # start delay in seconds

    for attempt in range(5):
        try:
            response = httpx.post(evaluation_url, headers=headers, json=payload)
            if response.status_code == 200:
                print("✅ Evaluation server notified successfully.")
                return True
            else:
                print(f"⚠️ Attempt {attempt+1}: Server responded {response.status_code} - {response.text}")
        except Exception as e:
            print(f"❌ Attempt {attempt+1} failed: {e}")

        time.sleep(delay)
        delay *= 2  # exponential backoff

    print("❌ Failed to notify evaluation server after 5 retries.")
    return False