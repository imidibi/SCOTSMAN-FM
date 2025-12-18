//
//  HandwritingCaptureView.swift
//  SalesDiver
//
//  Created by Ian Miller on 5/19/25.
//

import SwiftUI
import PencilKit
import Vision

struct HandwritingCaptureView: View {
    var onSave: (String) -> Void
    @State private var canvasView = PKCanvasView()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geometry in
            VStack {
                CanvasView(canvasView: $canvasView)
                    .frame(height: geometry.size.height * 0.75)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(10)
                    .padding()

                Button("Save Notes") {
                    let image = canvasView.drawing.image(from: canvasView.bounds, scale: UIScreen.main.scale)
                    recognizeText(from: image)
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
            .navigationTitle("Handwritten Notes")
        }
    }

    private func recognizeText(from image: UIImage) {
        guard let cgImage = image.cgImage else { return }

        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { (request, error) in
            if let results = request.results as? [VNRecognizedTextObservation] {
                let recognizedStrings = results.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                let fullText = recognizedStrings.joined(separator: "\n")
                DispatchQueue.main.async {
                    onSave(fullText)
                    dismiss()
                }
            }
        }

        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = true

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try requestHandler.perform([request])
            } catch {
                
            }
        }
    }
}

struct CanvasView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = UIColor.secondarySystemBackground
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.drawing = canvasView.drawing
    }
}
