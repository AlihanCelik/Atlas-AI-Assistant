#!/bin/bash
# Atlas Başlatma Scripti

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
echo "🚀 Atlas başlatılıyor... [$PROJECT_ROOT]"

# ─── Port 8000 Temizliği ──────────────────────────────────────
pkill -f uvicorn 2>/dev/null || true

# ─── Ollama Başlat ────────────────────────────────────────────
echo "🤖 Ollama kontrol ediliyor..."
if ! pgrep -x "ollama" > /dev/null; then
    echo "Ollama başlatılıyor..."
    ollama serve &
    sleep 2
fi

# Model var mı kontrol et
MODEL="qwen2.5:1.5b"
if ! ollama list | grep -q "$MODEL"; then
    echo "📥 $MODEL indiriliyor (bu biraz sürebilir)..."
    ollama pull $MODEL
fi

echo "✅ Ollama hazır."

# ─── Python Backend ───────────────────────────────────────────
BACKEND_DIR="$PROJECT_ROOT/backend"
cd "$BACKEND_DIR"

if [ ! -d "venv" ]; then
    echo "🐍 Python virtual environment oluşturuluyor..."
    /Library/Frameworks/Python.framework/Versions/3.12/bin/python3 -m venv venv
    source venv/bin/activate
    echo "📦 Bağımlılıklar yükleniyor..."
    pip install fastapi uvicorn requests ollama websockets python-multipart sounddevice numpy SpeechRecognition
else
    source venv/bin/activate
fi

echo "🔧 Atlas backend başlatılıyor (port 8000)..."
uvicorn main:app --host 0.0.0.0 --port 8000 &
BACKEND_PID=$!
echo "Backend PID: $BACKEND_PID"

sleep 2

# ─── Flutter Frontend ─────────────────────────────────────────
FRONTEND_DIR="$PROJECT_ROOT/frontend"
cd "$FRONTEND_DIR"

echo "📱 Flutter uygulaması başlatılıyor..."
flutter pub get
flutter run -d macos

# Temizlik
kill $BACKEND_PID 2>/dev/null
pkill -f uvicorn 2>/dev/null || true
echo "👋 Atlas kapatıldı."
