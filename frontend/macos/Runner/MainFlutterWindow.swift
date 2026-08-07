import Cocoa
import FlutterMacOS
import AVFoundation
import Speech

class MainFlutterWindow: NSWindow, AVSpeechSynthesizerDelegate {

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

    avSynth.delegate = self

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

  // ─── AVSpeechSynthesizerDelegate Callbacks ─────────────────────────
  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
    DispatchQueue.main.async { [weak self] in
      self?.voiceChannel?.invokeMethod("onSpeakFinished", arguments: nil)
    }
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
    DispatchQueue.main.async { [weak self] in
      self?.voiceChannel?.invokeMethod("onSpeakFinished", arguments: nil)
    }
  }

  // ─── Safe Permission Request ─────────────────────────────────────
  private func requestPermissions(result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      let status = AVCaptureDevice.authorizationStatus(for: .audio)
      if status == .notDetermined {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
          print("[NativeSpeech] Audio permission request result: \(granted)")
        }
      }

      let speechStatus = SFSpeechRecognizer.authorizationStatus()
      if speechStatus == .notDetermined {
        SFSpeechRecognizer.requestAuthorization { authStatus in
          print("[NativeSpeech] Speech recognition auth status: \(authStatus.rawValue)")
        }
      }

      result("authorized")
    }
  }

  // ─── Thread-Safe & Clean CoreAudio Persistent-Engine macOS STT ────
  private var speechWorkItemIndex: Int = 0
  private var isListening = false

  private func ensureAudioEngineRunning() {
    if audioEngine == nil {
      let engine = AVAudioEngine()
      self.audioEngine = engine

      // 1. Prepare engine FIRST so inputNode resolves valid hardware format
      engine.prepare()

      let inputNode = engine.inputNode
      let format = inputNode.outputFormat(forBus: 0)
      print("[NativeSpeech] Input node format: \(format.sampleRate) Hz, \(format.channelCount) channels")

      inputNode.removeTap(onBus: 0)
      inputNode.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buf, _ in
        guard let self = self else { return }
        if self.isListening {
          self.recognitionRequest?.append(buf)

          // Real-time Audio RMS Sound Level Metering
          if let channelData = buf.floatChannelData?[0] {
            let frameCount = Int(buf.frameLength)
            if frameCount > 0 {
              var sum: Float = 0
              for i in 0..<frameCount {
                let sample = channelData[i]
                sum += sample * sample
              }
              let rms = sqrt(sum / Float(frameCount))
              let level = min(max(Double(rms * 30.0), 0.0), 1.0)

              DispatchQueue.main.async {
                self.voiceChannel?.invokeMethod("onSoundLevel", arguments: level)
              }
            }
          }
        }
      }

      do {
        try engine.start()
        print("[NativeSpeech] Persistent AudioEngine started successfully.")
      } catch {
        print("[NativeSpeech] AudioEngine start failed: \(error)")
      }
    } else if let engine = audioEngine, !engine.isRunning {
      try? engine.start()
    }
  }

  private func startListening(result: @escaping FlutterResult) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }

      self.lastPartialText = ""
      self.speechWorkItemIndex += 1
      let localWorkIndex = self.speechWorkItemIndex

      let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)
      if audioStatus != .authorized && audioStatus != .notDetermined {
        print("[NativeSpeech] Audio permission not granted (\(audioStatus.rawValue)).")
        result(false)
        return
      }

      // 1. Ensure Persistent Audio Engine is running
      self.ensureAudioEngineRunning()

      // 2. Clean up previous recognition request/task without destroying hardware mic engine
      self.recognitionRequest?.endAudio()
      self.recognitionTask?.cancel()
      self.recognitionTask = nil
      self.recognitionRequest = nil

      let supportedLocales = SFSpeechRecognizer.supportedLocales()
      let trLocale = supportedLocales.first(where: { $0.identifier.contains("tr") }) ?? Locale(identifier: "tr-TR")
      let rec = SFSpeechRecognizer(locale: trLocale) ?? SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer()
      guard let recognizer = rec else {
        print("[NativeSpeech] SFSpeechRecognizer unavailable.")
        self.voiceChannel?.invokeMethod("onError", arguments: "Speech recognizer unavailable")
        result(false)
        return
      }
      if !recognizer.isAvailable {
        print("[NativeSpeech] Warning: SFSpeechRecognizer.isAvailable is false. Proceeding with task creation.")
      }
      self.recognizer = recognizer

      let req = SFSpeechAudioBufferRecognitionRequest()
      req.shouldReportPartialResults = true
      req.requiresOnDeviceRecognition = false
      req.taskHint = .dictation
      self.recognitionRequest = req
      self.isListening = true

      // 3. Attach Recognition Task
      self.recognitionTask = recognizer.recognitionTask(with: req) { [weak self] res, err in
        guard let self = self else { return }

        if let res = res {
          let text = res.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
          if !text.isEmpty {
            self.lastPartialText = text
            print("[NativeSpeech] STT Partial: \(text)")

            DispatchQueue.main.async {
              self.voiceChannel?.invokeMethod("onResult", arguments: ["text": text, "final": false])

              // Silence Auto-Commit timer
              self.speechWorkItemIndex += 1
              let silenceIndex = self.speechWorkItemIndex

              DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                guard let self = self else { return }
                if self.isListening && self.speechWorkItemIndex == silenceIndex && !self.lastPartialText.isEmpty {
                  print("[NativeSpeech] Silence auto-commit: \(self.lastPartialText)")
                  let finalText = self.lastPartialText
                  self.isListening = false
                  self.voiceChannel?.invokeMethod("onResult", arguments: ["text": finalText, "final": true])
                }
              }
            }
          }

          if res.isFinal {
            DispatchQueue.main.async {
              let finalText = self.lastPartialText
              self.isListening = false
              self.voiceChannel?.invokeMethod("onResult", arguments: ["text": finalText, "final": true])
            }
          }
        }

        if let err = err {
          print("[NativeSpeech] STT Task ended: \(err.localizedDescription)")
          DispatchQueue.main.async {
            if self.isListening && self.speechWorkItemIndex == localWorkIndex {
              let text = self.lastPartialText
              self.isListening = false
              self.voiceChannel?.invokeMethod("onResult", arguments: ["text": text, "final": true])
            }
          }
        }
      }

      // Non-blocking method call response
      result(true)
    }
  }

  private func stopListeningNow() {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      self.isListening = false
      self.speechWorkItemIndex += 1

      self.recognitionRequest?.endAudio()
      self.recognitionTask?.finish()
      self.recognitionTask = nil
      self.recognitionRequest = nil

      // Send final status update to Flutter
      let finalText = self.lastPartialText
      self.voiceChannel?.invokeMethod("onResult", arguments: ["text": finalText, "final": true])
      self.voiceChannel?.invokeMethod("onSoundLevel", arguments: 0.0)
    }
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

      utterance.rate = 0.52
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
