# Atlas - Kişisel AI Asistan

Flutter ön yüz + Python (FastAPI) backend + Yerel LLM (Ollama)

## Hızlı Başlangıç

### 1. Ollama Kur
```bash
# macOS
brew install ollama

# veya: https://ollama.com
```

### 2. Modeli İndir
```bash
ollama pull llama3.2:3b   # ~2GB, CPU'da iyi çalışır
# Daha hafif:
ollama pull qwen2:1.5b    # ~1GB
```

### 3. Backend Başlat
```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python main.py
```

### 4. Flutter Uygulamasını Çalıştır
```bash
cd frontend
flutter pub get
flutter run
```

### Ya da tek komutla:
```bash
./start.sh
```

---

## Model Eğitimi (CPU)

```bash
cd backend
source venv/bin/activate

# Örnek veri oluştur
python trainer.py --create-sample

# Eğit (TinyLlama önerilir, CPU'da makul süre)
python trainer.py \
  --model TinyLlama/TinyLlama-1.1B-Chat-v1.0 \
  --data training_data.json \
  --epochs 3
```

`training_data.json` dosyasına kendi konuşmalarını ekleyerek Atlas'ı kişiselleştirebilirsin.

---

## Proje Yapısı

```
atlas/
├── backend/
│   ├── main.py           # FastAPI server (REST + WebSocket)
│   ├── model.py          # Ollama LLM entegrasyonu
│   ├── wake_word.py      # "Hey Atlas" ses algılama
│   ├── trainer.py        # CPU fine-tuning (LoRA)
│   ├── training_data.json
│   └── requirements.txt
├── frontend/
│   └── lib/
│       ├── main.dart
│       ├── services/
│       │   └── atlas_service.dart   # WS + REST
│       ├── screens/
│       │   └── chat_screen.dart
│       └── widgets/
│           ├── message_bubble.dart
│           └── wake_word_overlay.dart
└── start.sh
```

## API Endpoints

| Endpoint | Metod | Açıklama |
|----------|-------|----------|
| `/` | GET | Health check |
| `/status` | GET | Ollama & model durumu |
| `/chat` | POST | Tek seferlik chat |
| `/reset` | POST | Konuşma geçmişini sıfırla |
| `/model/{name}` | POST | Model değiştir |
| `/ws` | WS | Streaming chat |
# Atlas-AI-Assistant
