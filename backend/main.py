"""
Atlas Backend - FastAPI Server
Flutter frontend ile WebSocket + REST üzerinden iletişim kurar.
"""

import asyncio
import json
from contextlib import asynccontextmanager
from typing import Optional

from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from model import atlas_model
from wake_word import WakeWordDetector


# ─── WebSocket Bağlantı Yöneticisi ────────────────────────────────
class ConnectionManager:
    def __init__(self):
        self.active_connections: list[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)
        print(f"[WS] Bağlantı kuruldu. Toplam: {len(self.active_connections)}")

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)
        print(f"[WS] Bağlantı kesildi. Toplam: {len(self.active_connections)}")

    async def broadcast(self, data: dict):
        """Tüm bağlı istemcilere mesaj gönderir."""
        message = json.dumps(data, ensure_ascii=False)
        for connection in self.active_connections:
            try:
                await connection.send_text(message)
            except Exception:
                pass


manager = ConnectionManager()
wake_detector: Optional[WakeWordDetector] = None


# ─── Wake Word Callback ────────────────────────────────────────────
def on_wake_word():
    """Hey Atlas algılandığında tüm Flutter istemcilerine bildir."""
    asyncio.run_coroutine_threadsafe(
        manager.broadcast({"type": "wake_word", "message": "Hey Atlas algılandı!"}),
        asyncio.get_event_loop()
    )


# ─── Lifespan ─────────────────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    global wake_detector

    print("[Atlas] Backend başlatılıyor...")

    # Ollama kontrolü
    if atlas_model.check_ollama():
        print("[Atlas] ✅ Ollama çalışıyor.")
        models = atlas_model.list_models()
        print(f"[Atlas] Yüklü modeller: {models}")
    else:
        print("[Atlas] ⚠️  Ollama bulunamadı! `ollama serve` çalıştırın.")

    # Wake word dinleyiciyi başlat
    wake_detector = WakeWordDetector(
        callback=on_wake_word,
        use_simple_mode=True  # pvporcupine yoksa basit mod
    )
    wake_detector.start()

    yield

    # Kapatma
    if wake_detector:
        wake_detector.stop()
    print("[Atlas] Backend kapatıldı.")


# ─── FastAPI Uygulaması ────────────────────────────────────────────
app = FastAPI(
    title="Atlas AI Assistant",
    version="1.0.0",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Flutter local emulator için
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ─── REST Modelleri ───────────────────────────────────────────────
class ChatRequest(BaseModel):
    message: str
    stream: bool = False


class ChatResponse(BaseModel):
    response: str
    model: str


class StatusResponse(BaseModel):
    status: str
    ollama_running: bool
    models: list[str]
    current_model: str


# ─── REST Endpoints ───────────────────────────────────────────────
@app.get("/", tags=["Health"])
async def root():
    return {"message": "Atlas Backend çalışıyor 🚀"}


@app.get("/status", response_model=StatusResponse, tags=["Health"])
async def get_status():
    ollama_ok = atlas_model.check_ollama()
    return StatusResponse(
        status="ok" if ollama_ok else "ollama_offline",
        ollama_running=ollama_ok,
        models=atlas_model.list_models() if ollama_ok else [],
        current_model=atlas_model.model_name,
    )


@app.post("/chat", response_model=ChatResponse, tags=["Chat"])
async def chat(request: ChatRequest):
    """Tek seferlik chat endpoint'i."""
    if not atlas_model.check_ollama():
        raise HTTPException(status_code=503, detail="Ollama çalışmıyor. `ollama serve` çalıştırın.")

    try:
        response = atlas_model.chat(request.message)
        return ChatResponse(response=response, model=atlas_model.model_name)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/reset", tags=["Chat"])
async def reset_conversation():
    """Konuşma geçmişini sıfırlar."""
    atlas_model.reset_conversation()
    return {"message": "Konuşma sıfırlandı."}


@app.post("/model/{model_name}", tags=["Model"])
async def change_model(model_name: str):
    """Aktif modeli değiştirir."""
    atlas_model.model_name = model_name
    return {"message": f"Model değiştirildi: {model_name}"}


# ─── WebSocket Endpoint ───────────────────────────────────────────
@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """
    Flutter ile gerçek zamanlı iletişim.
    Streaming yanıtlar burada token token gönderilir.
    """
    await manager.connect(websocket)
    try:
        while True:
            data = await websocket.receive_text()
            payload = json.loads(data)

            msg_type = payload.get("type")

            if msg_type == "chat":
                user_message = payload.get("message", "")

                if not atlas_model.check_ollama():
                    await websocket.send_text(json.dumps({
                        "type": "error",
                        "message": "Ollama çalışmıyor!"
                    }))
                    continue

                # Streaming yanıt
                await websocket.send_text(json.dumps({"type": "stream_start"}))

                full_response = ""
                for token in atlas_model.chat_stream(user_message):
                    full_response += token
                    await websocket.send_text(json.dumps({
                        "type": "stream_token",
                        "token": token
                    }))

                await websocket.send_text(json.dumps({
                    "type": "stream_end",
                    "full_response": full_response
                }))

            elif msg_type == "reset":
                atlas_model.reset_conversation()
                await websocket.send_text(json.dumps({
                    "type": "reset_ok",
                    "message": "Konuşma sıfırlandı."
                }))

            elif msg_type == "ping":
                await websocket.send_text(json.dumps({"type": "pong"}))

    except WebSocketDisconnect:
        manager.disconnect(websocket)
    except Exception as e:
        print(f"[WS] Hata: {e}")
        manager.disconnect(websocket)


# ─── Çalıştırma ───────────────────────────────────────────────────
if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
