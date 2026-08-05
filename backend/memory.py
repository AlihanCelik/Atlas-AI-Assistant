import os
import json
from typing import List, Dict, Any

MEMORY_FILE = os.path.join(os.path.dirname(__file__), "memory_db.json")

class LongTermMemory:
    """Yapay Zeka Kalıcı Bellek ve Öğrenme Sistemi"""

    def __init__(self):
        self.data: Dict[str, Any] = {
            "user_name": "Alihan",
            "user_preferences": {},
            "learned_facts": [],
            "conversation_history": []
        }
        self.load()

    def load(self):
        if os.path.exists(MEMORY_FILE):
            try:
                with open(MEMORY_FILE, "r", encoding="utf-8") as f:
                    self.data = json.load(f)
                    print(f"[Memory] Kalıcı bellek yüklendi. {len(self.data.get('learned_facts', []))} bilgi mevcut.")
            except Exception as e:
                print(f"[Memory] Yükleme hatası: {e}")

    def save(self):
        try:
            with open(MEMORY_FILE, "w", encoding="utf-8") as f:
                json.dump(self.data, f, ensure_ascii=False, indent=2)
        except Exception as e:
            print(f"[Memory] Kaydetme hatası: {e}")

    def add_fact(self, fact: str):
        """Kullanıcı hakkında yeni öğrenilen bir bilgiyi belleğe ekler"""
        if fact not in self.data["learned_facts"]:
            self.data["learned_facts"].append(fact)
            self.save()
            print(f"[Memory] 🧠 Yeni bilgi öğrenildi: '{fact}'")

    def get_memory_context(self) -> str:
        """Sistem komut istemine enjekte edilecek bellek özetini üretir"""
        facts = self.data.get("learned_facts", [])
        name = self.data.get("user_name", "Alihan")
        
        ctx = f"Kullanıcının Adı: {name}.\n"
        if facts:
            ctx += "Kullanıcı Hakkında Bildiklerin ve Öğrendiklerin:\n"
            for f in facts[-10:]: # Son 10 öğrenilen bilgi
                ctx += f"- {f}\n"
        return ctx

    def save_chat_turn(self, role: str, text: str):
        self.data["conversation_history"].append({"role": role, "text": text})
        # Son 100 mesajı tut
        if len(self.data["conversation_history"]) > 100:
            self.data["conversation_history"] = self.data["conversation_history"][-100:]
        self.save()

memory_db = LongTermMemory()
