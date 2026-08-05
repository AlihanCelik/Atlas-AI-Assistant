#!/bin/bash
# Atlas Başlatma Scripti

echo "🚀 Atlas başlatılıyor..."

# ─── Ollama Başlat ────────────────────────────────────────────
echo "🤖 Ollama kontrol ediliyor..."
if ! pgrep -x "ollama" > /dev/null; then
    echo "Ollama başlatılıyor..."
    ollama serve &
    sleep 2
fi

# Model var mı kontrol et
MODEL="llama3.2:3b"
if ! ollama list | grep -q "$MODEL"; then
    echo "📥 $MODEL indiriliyor (bu biraz sürebilir)..."
    ollama pull $MODEL
fi

echo "✅ Ollama hazır."

# ─── Python Virtual Env ───────────────────────────────────────
BACKEND_DIR="$(dirname "$0")/backend"
cd "$BACKEND_DIR"

if [ ! -d "venv" ]; then
    echo "🐍 Python virtual environment oluşturuluyor..."
    python3 -m venv venv
    source venv/bin/activate
    echo "📦 Bağımlılıklar yükleniyor..."
    pip install -r requirements.txt
else
    source venv/bin/activate
fi

# ─── Backend Başlat ───────────────────────────────────────────
echo "🔧 Atlas backend başlatılıyor (port 8000)..."
uvicorn main:app --host 0.0.0.0 --port 8000 &
BACKEND_PID=$!
echo "Backend PID: $BACKEND_PID"

sleep 2

# ─── Flutter ──────────────────────────────────────────────────
FRONTEND_DIR="$(dirname "$0")/frontend"
cd "$FRONTEND_DIR"

echo "📱 Flutter uygulaması başlatılıyor..."
flutter pub get
flutter run

# Temizlik
kill $BACKEND_PID 2>/dev/null
echo "👋 Atlas kapatıldı."
