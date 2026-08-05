import os
import time
import urllib.parse
import threading
import subprocess
from datetime import datetime

class SystemController:
    """Gelişmiş macOS İşletim Sistemi ve Web Otomasyonu Kontrolcüsü"""

    def __init__(self):
        self.is_scrolling = False
        self.scroll_direction = "down"
        self.scroll_thread = None

    def open_app(self, app_query: str) -> str:
        """Uygulama veya klasör açar"""
        query = app_query.lower().strip()
        
        # Klasör tanımları
        folders = {
            "indirilenler": os.path.expanduser("~/Downloads"),
            "indirmeler": os.path.expanduser("~/Downloads"),
            "masaüstü": os.path.expanduser("~/Desktop"),
            "belgeler": os.path.expanduser("~/Documents"),
            "dokümanlar": os.path.expanduser("~/Documents"),
            "resimler": os.path.expanduser("~/Pictures"),
        }

        for k, v in folders.items():
            if k in query:
                subprocess.run(["open", v])
                return f"📁 {k.capitalize()} klasörü açıldı."

        # Uygulama eşleştirmeleri
        mapping = {
            "chrome": "Google Chrome",
            "google chrome": "Google Chrome",
            "safari": "Safari",
            "finder": "Finder",
            "terminal": "Terminal",
            "kod": "Visual Studio Code",
            "code": "Visual Studio Code",
            "vscode": "Visual Studio Code",
            "spotify": "Spotify",
            "hesap makinesi": "Calculator",
            "takvim": "Calendar",
            "notlar": "Notes",
        }

        app_name = mapping.get(query, app_query.title())

        try:
            print(f"[SystemControl] Uygulama açılıyor: {app_name}")
            subprocess.run(["open", "-a", app_name], check=True)
            return f"🚀 {app_name} uygulaması açıldı."
        except Exception:
            try:
                subprocess.run(["open", "-a", query], check=True)
                return f"🚀 {query} açıldı."
            except Exception as e:
                print(f"[SystemControl] Hata: {e}")
                return f"⚠️ {app_name} uygulaması bilgisayarda bulunamadı."

    def web_search(self, service: str, query: str) -> str:
        """Google, YouTube veya Wikipedia üzerinde sesli arama yapar"""
        encoded_query = urllib.parse.quote(query)
        
        if service == "youtube":
            url = f"https://www.youtube.com/results?search_query={encoded_query}"
            subprocess.run(["open", url])
            return f"🎬 YouTube'da '{query}' için arama açıldı."
        elif service == "wikipedia":
            url = f"https://tr.wikipedia.org/wiki/Special:Search?search={encoded_query}"
            subprocess.run(["open", url])
            return f"📚 Wikipedia'da '{query}' bilgisi açıldı."
        else: # Google
            url = f"https://www.google.com/search?q={encoded_query}"
            subprocess.run(["open", url])
            return f"🔍 Google'da '{query}' araması yapıldı."

    def adjust_volume(self, action: str) -> str:
        """Mac ses seviyesini ayarlar"""
        try:
            if action == "up":
                cmd = 'set volume output volume ((output volume of (get volume settings)) + 20)'
                subprocess.run(["osascript", "-e", cmd])
                return "🔊 Bilgisayarın sesi arttırıldı."
            elif action == "down":
                cmd = 'set volume output volume ((output volume of (get volume settings)) - 20)'
                subprocess.run(["osascript", "-e", cmd])
                return "🔉 Bilgisayarın sesi kısıldı."
            elif action == "mute":
                cmd = 'set volume output volume 0'
                subprocess.run(["osascript", "-e", cmd])
                return "🔇 Ses kapatıldı."
            elif action == "unmute":
                cmd = 'set volume output volume 50'
                subprocess.run(["osascript", "-e", cmd])
                return "🔊 Ses 50% seviyesine getirildi."
        except Exception as e:
            return f"Ses ayarlanamadı: {e}"
        return "Ses seviyesi değiştirildi."

    def media_control(self, action: str) -> str:
        """Medya oynatma kontrolleri"""
        try:
            if action == "playpause":
                cmd = 'tell application "System Events" to key code 16'
                subprocess.run(["osascript", "-e", cmd], stderr=subprocess.DEVNULL)
                return "⏯️ Medya oynatıldı/durduruldu."
            elif action == "next":
                cmd = 'tell application "System Events" to key code 19'
                subprocess.run(["osascript", "-e", cmd], stderr=subprocess.DEVNULL)
                return "⏭️ Sonraki parçaya geçildi."
        except Exception:
            pass
        return "Medya kontrol edildi."

    def start_scrolling(self, direction: str = "down") -> str:
        """Sayfa kaydırmayı başlatır"""
        self.scroll_direction = direction
        self.is_scrolling = True
        
        if self.scroll_thread is None or not self.scroll_thread.is_alive():
            self.scroll_thread = threading.Thread(target=self._scroll_loop, daemon=True)
            self.scroll_thread.start()
            
        dir_text = "aşağı" if direction == "down" else "yukarı"
        return f"📜 Sayfa {dir_text} kaydırılıyor."

    def stop_scrolling(self) -> str:
        """Kaydırma işlemini durdurur"""
        self.is_scrolling = False
        return "🛑 Kaydırma durduruldu."

    def _scroll_loop(self):
        while self.is_scrolling:
            try:
                key_code = "125" if self.scroll_direction == "down" else "126"
                cmd = f'tell application "System Events" to key code {key_code}'
                subprocess.run(["osascript", "-e", cmd], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            except Exception:
                pass
            time.sleep(0.35)

    def get_time_date(self) -> str:
        now = datetime.now()
        months = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"]
        days = ["Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi", "Pazar"]
        
        time_str = now.strftime("%H:%M")
        date_str = f"{now.day} {months[now.month - 1]} {now.year} {days[now.weekday()]}"
        return f"Saat şu an {time_str}. Bugün {date_str}."

    def process_command(self, text: str):
        """Gelen Türkçe metnin sistem komutu olup olmadığını denetler"""
        t = text.lower().strip()

        # 1. Saat ve Tarih
        if t in ["saat kaç", "saati söyle", "bugün tarih ne", "tarih kaç", "bugün günlerden ne"]:
            return True, self.get_time_date()

        # 2. Durdurma Komutları
        if t in ["dur", "durdur", "dur artık", "tamam dur", "durabilirsin", "kaydırmayı durdur"]:
            return True, self.stop_scrolling()

        # 3. Kaydırma Komutları
        if "aşağı kaydır" in t or "aşağıya kaydır" in t or "aşağı in" in t or "sayfayı aşağı" in t:
            return True, self.start_scrolling("down")

        if "yukarı kaydır" in t or "yukarıya kaydır" in t or "yukarı çık" in t or "sayfayı yukarı" in t:
            return True, self.start_scrolling("up")

        # 4. Ses Kontrolü
        if "sesi arttır" in t or "sesi yükselt" in t or "sesi aç" in t:
            return True, self.adjust_volume("up")
        if "sesi kıs" in t or "sesi azalt" in t:
            return True, self.adjust_volume("down")
        if "sesi kapat" in t or "sessize al" in t or "mute" in t:
            return True, self.adjust_volume("mute")

        # 5. Medya Kontrolü
        if "müziği durdur" in t or "müziği başlat" in t or "oynat durdur" in t:
            return True, self.media_control("playpause")
        if "sonraki şarkı" in t or "diğer müzik" in t or "şarkıyı değiştir" in t:
            return True, self.media_control("next")

        # 6. Web Aramaları
        if "youtube'da" in t or "youtube da" in t or "youtube'dan" in t:
            clean = t.replace("youtube'da", "").replace("youtube da", "").replace("youtube'dan", "").replace("ara", "").replace("bul", "").strip()
            if clean:
                return True, self.web_search("youtube", clean)

        if "google'da" in t or "google da" in t or "google'dan" in t:
            clean = t.replace("google'da", "").replace("google da", "").replace("google'dan", "").replace("ara", "").replace("bul", "").strip()
            if clean:
                return True, self.web_search("google", clean)

        if "wikipedia'da" in t or "wikipedia da" in t or "vikipedi'de" in t:
            clean = t.replace("wikipedia'da", "").replace("wikipedia da", "").replace("vikipedi'de", "").replace("ara", "").replace("nedir", "").strip()
            if clean:
                return True, self.web_search("wikipedia", clean)

        # 7. Uygulama veya Klasör Açma
        if "aç" in t:
            words = t.split()
            if "aç" in words:
                idx = words.index("aç")
                app_part = " ".join(words[:idx]).replace("'u", "").replace("'ü", "").replace("'ı", "").replace("'i", "").replace("’u", "").replace("’ü", "").strip()
                if app_part:
                    return True, self.open_app(app_part)

        return False, None
