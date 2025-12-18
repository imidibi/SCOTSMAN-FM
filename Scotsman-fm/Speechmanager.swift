//
//  Speechmanager.swift
//  SalesDiver
//
//  Created by Ian Miller on 4/13/25.
//
import Foundation
#if os(iOS)
import Speech
import AVFoundation
#endif
import Combine

class SpeechManager: NSObject, ObservableObject {
#if os(iOS)
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
#endif

    @Published var transcribedText: String = ""
    @Published var isRecording: Bool = false
    @Published var isTranscribingAvailable: Bool = false

    override init() {
        super.init()
#if os(iOS)
        requestAuthorization()
#endif
    }

    func requestAuthorization() {
#if os(iOS)
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                self.isTranscribingAvailable = (authStatus == .authorized)
            }
        }
#else
        self.isTranscribingAvailable = false
#endif
    }

    func startTranscribing() throws {
#if os(iOS)
        guard speechRecognizer?.isAvailable == true else {
            throw NSError(domain: "SpeechRecognizerUnavailable", code: 1, userInfo: nil)
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }

        let inputNode = audioEngine.inputNode
        recognitionRequest.shouldReportPartialResults = true

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                DispatchQueue.main.async {
                    self.transcribedText = result.bestTranscription.formattedString
                }
            }

            if error != nil || (result?.isFinal ?? false) {
                self.stopTranscribing()
            }
        }

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        DispatchQueue.main.async {
            self.isRecording = true
        }
#endif
    }

    func stopTranscribing() {
#if os(iOS)
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        DispatchQueue.main.async {
            self.isRecording = false
        }
#endif
    }
}
