"""
Atlas - Wake Word Detection
"Hey Atlas" sesini algılar ve callback tetikler.

Seçenek 1: pvporcupine (önerilen, hassas)
Seçenek 2: Basit keyword spotting (offline, ücretsiz)
"""

import threading
import numpy as np
import sounddevice as sd
import queue
import re

# Porcupine API key yoksa basit keyword mod kullanılır
PORCUPINE_API_KEY = ""  # https://console.picovoice.ai/ adresinden ücretsiz alınır


class WakeWordDetector:
    def __init__(self, callback, use_simple_mode: bool = True):
        """
        callback: Wake word algılandığında çağrılır
        use_simple_mode: True → basit ses seviyesi + keyword
                         False → pvporcupine (API key gerekir)
        """
        self.callback = callback
        self.use_simple_mode = use_simple_mode
        self.is_running = False
        self.thread = None
        self.audio_queue = queue.Queue()

    # ─── Basit Mod (pvporcupine olmadan) ──────────────────────────
    def _simple_audio_callback(self, indata, frames, time, status):
        """Ses verisini kuyruğa ekler."""
        if status:
            print(f"[WakeWord] Ses hatası: {status}")
        self.audio_queue.put(indata.copy())

    def _simple_listen_loop(self):
        """
        Basit mod: Ses kaydeder → speech_recognition ile metne çevirir
        → 'atlas' kelimesi geçiyor mu bakar.
        """
        try:
            import speech_recognition as sr
        except ImportError:
            print("[WakeWord] speech_recognition kurulu değil: pip install SpeechRecognition")
            return

        recognizer = sr.Recognizer()
        mic = sr.Microphone()

        print("[WakeWord] Dinleniyor... 'Hey Atlas' deyin.")

        with mic as source:
            recognizer.adjust_for_ambient_noise(source, duration=1)

        while self.is_running:
            try:
                with mic as source:
                    audio = recognizer.listen(source, timeout=5, phrase_time_limit=4)

                try:
                    text = recognizer.recognize_google(audio, language="tr-TR").lower()
                    print(f"[WakeWord] Duyulan: {text}")

                    if "atlas" in text:
                        print("[WakeWord] 🎯 Hey Atlas algılandı!")
                        self.callback()

                except sr.UnknownValueError:
                    pass  # Anlaşılmayan ses, devam et
                except sr.RequestError as e:
                    print(f"[WakeWord] API hatası: {e}")

            except Exception as e:
                if self.is_running:
                    print(f"[WakeWord] Hata: {e}")

    # ─── Porcupine Mod ────────────────────────────────────────────
    def _porcupine_listen_loop(self):
        """pvporcupine ile hassas wake word detection."""
        try:
            import pvporcupine
            import struct

            porcupine = pvporcupine.create(
                access_key=PORCUPINE_API_KEY,
                keywords=["hey siri"],  # özel keyword için model eğitmek gerekir
                sensitivities=[0.7]
            )

            CHUNK = porcupine.frame_length
            RATE = porcupine.sample_rate

            print("[WakeWord] Porcupine dinleniyor...")

            with sd.InputStream(
                samplerate=RATE,
                channels=1,
                dtype="int16",
                blocksize=CHUNK,
                callback=self._simple_audio_callback
            ):
                while self.is_running:
                    audio_data = self.audio_queue.get()
                    pcm = struct.unpack_from("h" * CHUNK, audio_data.tobytes()[:CHUNK * 2])
                    result = porcupine.process(pcm)
                    if result >= 0:
                        print("[WakeWord] 🎯 Hey Atlas algılandı!")
                        self.callback()

            porcupine.delete()

        except Exception as e:
            print(f"[WakeWord] Porcupine hatası: {e}")
            print("[WakeWord] Basit moda geçiliyor...")
            self._simple_listen_loop()

    # ─── Public API ───────────────────────────────────────────────
    def start(self):
        """Wake word dinlemeyi başlatır (arka planda)."""
        if self.is_running:
            return

        self.is_running = True

        if self.use_simple_mode:
            target = self._simple_listen_loop
        else:
            target = self._porcupine_listen_loop

        self.thread = threading.Thread(target=target, daemon=True)
        self.thread.start()
        print("[WakeWord] Başlatıldı.")

    def stop(self):
        """Wake word dinlemeyi durdurur."""
        self.is_running = False
        if self.thread:
            self.thread.join(timeout=2)
        print("[WakeWord] Durduruldu.")
