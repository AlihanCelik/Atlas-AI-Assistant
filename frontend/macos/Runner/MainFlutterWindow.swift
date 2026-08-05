import Cocoa
import FlutterMacOS
import AVFoundation
import Speech

class MainFlutterWindow: NSWindow {

  private var recognizer: SFSpeechRecognizer?
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  private let audioEngine = AVAudioEngine()
  private var activeResult: FlutterResult?
  private var lastPartialText = ""
  private var voiceChannel: FlutterMethodChannel?
  private let synth = NSSpeechSynthesizer()

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Channel burada kur — messenger artık hazır
    let messenger = flutterViewController.engine.binaryMessenger
    voiceChannel = FlutterMethodChannel(
      name: "com.atlas.atlasApp/voice",
      binaryMessenger: messenger
    )

    voiceChannel?.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }
      switch call.method {
      case "requestPermissions":
        self.requestPermissions(result: result)
      case "startListening":
        self.startListening(result: result)
      case "stopListening":
        self.stopListeningNow()
        result(nil)
      case "speak":
        let text = call.arguments as? String ?? ""
        self.speakText(text)
        result(nil)
      case "stopSpeaking":
        self.synth.stopSpeaking()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }

  // ─── İzin İste ────────────────────────────────────────────────
  private func requestPermissions(result: @escaping FlutterResult) {
    let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    if micStatus == .authorized {
      result("authorized")
      return
    }

    if micStatus == .notDetermined {
      AVCaptureDevice.requestAccess(for: .audio) { granted in
        DispatchQueue.main.async {
          result(granted ? "authorized" : "mic_denied")
        }
      }
      return
    }

    result("mic_denied")
  }

  // ─── Dinlemeye Başla ──────────────────────────────────────────
  private func startListening(result: @escaping FlutterResult) {
    stopListeningNow()
    lastPartialText = ""

    let trLocale = Locale(identifier: "tr-TR")
    recognizer = SFSpeechRecognizer(locale: trLocale) ?? SFSpeechRecognizer()
    guard let rec = recognizer, rec.isAvailable else {
      result("")
      return
    }

    recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
    guard let req = recognitionRequest else { result(""); return }
    req.shouldReportPartialResults = true

    let inputNode = audioEngine.inputNode
    let format = inputNode.outputFormat(forBus: 0)
    guard format.sampleRate > 0 && format.channelCount > 0 else {
      result("")
      return
    }
    
    inputNode.removeTap(onBus: 0)
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buf, _ in
      req.append(buf)
    }

    audioEngine.prepare()
    do {
      try audioEngine.start()
    } catch {
      result("")
      return
    }

    activeResult = result

    recognitionTask = rec.recognitionTask(with: req) { [weak self] res, err in
      guard let self = self else { return }

      if let res = res {
        let text = res.bestTranscription.formattedString
        self.lastPartialText = text
        // Partial sonucu Flutter'a bildir
        self.voiceChannel?.invokeMethod("onResult", arguments: ["text": text, "final": false])

        if res.isFinal {
          DispatchQueue.main.async {
            self.stopListeningNow()
            self.activeResult?(text)
            self.activeResult = nil
          }
        }
      }

      if let _ = err {
        DispatchQueue.main.async {
          self.stopListeningNow()
          let text = self.lastPartialText
          self.activeResult?(text)
          self.activeResult = nil
        }
      }
    }
  }

  private func stopListeningNow() {
    audioEngine.stop()
    if audioEngine.inputNode.numberOfInputs > 0 {
      audioEngine.inputNode.removeTap(onBus: 0)
    }
    recognitionRequest?.endAudio()
    recognitionTask?.cancel()
    recognitionTask = nil
    recognitionRequest = nil
  }

  // ─── TTS ──────────────────────────────────────────────────────
  private func speakText(_ text: String) {
    synth.stopSpeaking()
    // Türkçe Yelda sesi varsa yeni bir synth oluştur
    let voices = NSSpeechSynthesizer.availableVoices
    let trVoice = voices.first {
      $0.rawValue.lowercased().contains("yelda") ||
      $0.rawValue.lowercased().contains("tr_") ||
      $0.rawValue.lowercased().contains("_tr")
    }
    let activeSynth: NSSpeechSynthesizer
    if let v = trVoice, let s = NSSpeechSynthesizer(voice: v) {
      activeSynth = s
    } else {
      activeSynth = synth
    }
    activeSynth.rate = 175
    activeSynth.startSpeaking(text)
  }
}
