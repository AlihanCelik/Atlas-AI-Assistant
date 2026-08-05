"""
Atlas - Yerel LLM Entegrasyonu
Ollama üzerinden yerel model yönetimi
"""

import ollama
import requests
from typing import Generator


# Kullanılacak model (ollama pull ile indirilmeli)
DEFAULT_MODEL = "llama3.2:3b"  # CPU'da makul hızda çalışır

SYSTEM_PROMPT = """Sen Atlas'sın, Alihan'ın kişisel yapay zeka asistanısın.
Türkçe konuşursun, samimi ve yardımseversin.
Kısa ve öz cevaplar verirsin, gerekmedikçe uzatmazsın.
Kullanıcına 'sen' diye hitap edersin."""


class AtlasModel:
    def __init__(self, model_name: str = DEFAULT_MODEL):
        self.model_name = model_name
        self.conversation_history = []

    def check_ollama(self) -> bool:
        """Ollama servisinin çalışıp çalışmadığını kontrol eder."""
        try:
            requests.get("http://localhost:11434", timeout=2)
            return True
        except Exception:
            return False

    def reset_conversation(self):
        """Konuşma geçmişini sıfırlar."""
        self.conversation_history = []

    def chat(self, user_message: str) -> str:
        """Tek seferlik yanıt döndürür."""
        self.conversation_history.append({
            "role": "user",
            "content": user_message
        })

        messages = [{"role": "system", "content": SYSTEM_PROMPT}] + self.conversation_history

        response = ollama.chat(
            model=self.model_name,
            messages=messages
        )

        assistant_message = response["message"]["content"]
        self.conversation_history.append({
            "role": "assistant",
            "content": assistant_message
        })

        return assistant_message

    def chat_stream(self, user_message: str) -> Generator[str, None, None]:
        """Streaming yanıt döndürür (token token gelir)."""
        self.conversation_history.append({
            "role": "user",
            "content": user_message
        })

        messages = [{"role": "system", "content": SYSTEM_PROMPT}] + self.conversation_history

        full_response = ""
        stream = ollama.chat(
            model=self.model_name,
            messages=messages,
            stream=True
        )

        for chunk in stream:
            token = chunk["message"]["content"]
            full_response += token
            yield token

        self.conversation_history.append({
            "role": "assistant",
            "content": full_response
        })

    def list_models(self) -> list:
        """Yüklü modelleri listeler."""
        try:
            models = ollama.list()
            return [m["name"] for m in models.get("models", [])]
        except Exception:
            return []


# Global instance
atlas_model = AtlasModel()
