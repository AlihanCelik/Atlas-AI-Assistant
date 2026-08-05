import Cocoa
import FlutterMacOS
import AVFoundation
import Speech

class MainFlutterWindow: NSWindow {

  private var recognizer: SFSpeechRecognizer?
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  private var audioEngine: AVAudioEngine?
  private var activeResult: FlutterResult?
  private var lastPartialText = ""
  private var voiceChannel: FlutterMethodChannel?
  private let avSynth = AVSpeechSynthesizer()
  private var silenceTimer: Timer?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

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
        self.stopSpeakingNow()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }

  // ─── Safe Permission Request ─────────────────────────────────────
  private func requestPermissions(result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      let status = AVCaptureDevice.authorizationStatus(for: .audio)
      if status == .notDetermined {
        AVCaptureDevice.requestAccess(for: .audio) { _ in
          DispatchQueue.main.async {
            result("authorized")
          }
        }
      } else {
        result("authorized")
      }
    }
  }

  // ─── Thread-Safe & Clean CoreAudio Fresh-Engine macOS STT ─────────
  private func startListening(result: @escaping FlutterResult) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      self.stopListeningNow()
      self.lastPartialText = ""

      let engine = AVAudioEngine()
      self.audioEngine = engine

      guard let rec = SFSpeechRecognizer(locale: Locale(identifier: "tr-TR")) ?? SFSpeechRecognizer() else {
        print("[NativeSpeech] SFSpeechRecognizer unavailable.")
        result("")
        return
      }
      self.recognizer = rec

      let req = SFSpeechAudioBufferRecognitionRequest()
      req.shouldReportPartialResults = true
      self.recognitionRequest = req

      let inputNode = engine.inputNode
      inputNode.removeTap(onBus: 0)

      inputNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak req] buf, _ in
        req?.append(buf)
      }

      engine.prepare()
      do {
        try engine.start()
        print("[NativeSpeech] AudioEngine started successfully.")
      } catch {
        print("[NativeSpeech] AudioEngine start failed: \(error)")
        result("")
        return
      }

      self.activeResult = result

      self.recognitionTask = rec.recognitionTask(with: req) { [weak self] res, err in
        guard let self = self else { return }

        if let res = res {
          let text = res.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
          if !text.isEmpty {
            self.lastPartialText = text
            print("[NativeSpeech] STT Partial: \(text)")
            
            DispatchQueue.main.async {
              self.voiceChannel?.invokeMethod("onResult", arguments: ["text": text, "final": false])

              // 1.2s Silence Auto-Commit Timer
              self.silenceTimer?.invalidate()
              self.silenceTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: false) { [weak self] _ in
                DispatchQueue.main.async {
                  guard let self = self else { return }
                  print("[NativeSpeech] Silence timeout - auto committing: \(self.lastPartialText)")
                  let finalText = self.lastPartialText
                  self.stopListeningNow()
                  if let act = self.activeResult {
                    act(finalText)
                    self.activeResult = nil
                  }
                }
              }
            }
          }

          if res.isFinal {
            DispatchQueue.main.async {
              self.silenceTimer?.invalidate()
              let finalText = self.lastPartialText
              self.stopListeningNow()
              if let act = self.activeResult {
                act(finalText)
                self.activeResult = nil
              }
            }
          }
        }

        if let _ = err {
          DispatchQueue.main.async {
            self.silenceTimer?.invalidate()
            let text = self.lastPartialText
            print("[NativeSpeech] STT Ended with text: \(text)")
            self.stopListeningNow()
            if let act = self.activeResult {
              act(text)
              self.activeResult = nil
            }
          }
        }
      }
    }
  }

  private func stopListeningNow() {
    silenceTimer?.invalidate()
    silenceTimer = nil

    if let engine = audioEngine {
      if engine.isRunning {
        engine.stop()
      }
      if engine.inputNode.numberOfInputs > 0 {
        engine.inputNode.removeTap(onBus: 0)
      }
      engine.reset()
    }
    audioEngine = nil

    recognitionRequest?.endAudio()
    recognitionTask?.cancel()
    recognitionTask = nil
    recognitionRequest = nil
  }

  // ─── Modern High-Quality Speech Synthesizer ─────────────────────
  private func speakText(_ text: String) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      if self.avSynth.isSpeaking {
        self.avSynth.stopSpeaking(at: .immediate)
      }

      let utterance = AVSpeechUtterance(string: text)
      
      let trVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.contains("tr") }
      if let bestVoice = trVoices.first {
        utterance.voice = bestVoice
      } else {
        utterance.voice = AVSpeechSynthesisVoice(language: "tr-TR")
      }

      utterance.rate = 0.51
      utterance.pitchMultiplier = 1.02
      utterance.volume = 1.0

      self.avSynth.speak(utterance)
    }
  }

  private func stopSpeakingNow() {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      if self.avSynth.isSpeaking {
        self.avSynth.stopSpeaking(at: .immediate)
      }
    }
  }
}
