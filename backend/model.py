"""
Atlas - Yerel LLM Entegrasyonu & Kalıcı Bellek
Ollama üzerinden gelişmiş model yönetimi
"""

import ollama
import requests
from typing import Generator
from memory import memory_db

DEFAULT_MODEL = "qwen2.5:1.5b"

BASE_SYSTEM_PROMPT = """Sen Atlas'sın; Alihan'ın son derece zeki, samimi, öğrenmeye açık ve sohbet etmeyi seven akıllı yapay zeka arkadaşısın.
Türkçe dilinde son derece açık, net, doğal, akıcı ve akılda kalıcı bir diksiyonla konuşursun.
Kullanıcınla derin ve samimi bir sohbet havasında iletişim kurarsın.
Geçmişte konuşulanları ve kullanıcı hakkında bildiklerini hatırlar ve konuşmalarında doğal bir şekilde kullanırsın.
Kullanıcı seninle konuştuğunda kısa kestirip atma, samimi ve detaylı sohbet et."""


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

    def get_active_model(self) -> str:
        models = self.list_models()
        # Tercih edilen gelişmiş modeller sıralaması
        preferred = ["qwen2.5:7b", "llama3.2:3b", "llama3:8b", "gemma2:9b", "qwen2.5:1.5b"]
        for p in preferred:
            for m in models:
                if p in m:
                    return m
        return self.model_name

    def reset_conversation(self):
        """Konuşma geçmişini sıfırlar."""
        self.conversation_history = []

    def list_models(self) -> list:
        """Yüklü modelleri listeler."""
        try:
            res = ollama.list()
            model_list = []
            models_attr = getattr(res, 'models', res if isinstance(res, list) else [])
            for m in models_attr:
                name = getattr(m, 'model', None) or getattr(m, 'name', None) or (m.get('name') if isinstance(m, dict) else str(m))
                if name:
                    model_list.append(name)
            return model_list
        except Exception as e:
            print(f"[Model] list_models hatası: {e}")
            return []

    def set_model(self, model_name: str):
        """Aktif modeli değiştirir."""
        self.model_name = model_name

    def chat_stream(self, prompt: str) -> Generator[str, None, None]:
        """Model ile canlı kelime kelime akışlı sohbet yanıtı üretir."""
        active_model = self.get_active_model()
        print(f"[Model] Akışlı sohbet başlatıldı, aktif model: {active_model}")

        # Dinamik Bellek Context Enjeksiyonu
        memory_context = memory_db.get_memory_context()
        full_system_prompt = f"{BASE_SYSTEM_PROMPT}\n\n[SİSTEM BELLEĞİ VE ÖĞRENİLENLER]:\n{memory_context}"

        messages = [
            {"role": "system", "content": full_system_prompt}
        ]

        # Son 12 konuşma turunu ekle
        messages.extend(self.conversation_history[-12:])
        messages.append({"role": "user", "content": prompt})

        full_response = ""
        try:
            response = ollama.chat(
                model=active_model,
                messages=messages,
                stream=True
            )

            for chunk in response:
                content = chunk.get("message", {}).get("content", "")
                if content:
                    full_response += content
                    yield content

            # Başarıyla tamamlandıysa geçmişe ve kalıcı belleğe kaydet
            self.conversation_history.append({"role": "user", "content": prompt})
            self.conversation_history.append({"role": "assistant", "content": full_response})

            memory_db.save_chat_turn("user", prompt)
            memory_db.save_chat_turn("atlas", full_response)

        except Exception as e:
            print(f"[Model] Chat hatası: {e}")
            yield f"Üzgünüm, yanıt üretirken bir sorun oluştu: {e}"


atlas_model = AtlasModel()
