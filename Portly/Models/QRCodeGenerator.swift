//
//  QRCodeGenerator.swift
//  Portly
//

import AppKit
import CoreImage

/// Generates sharp, high-contrast QR code images for URLs and endpoints.
enum QRCodeGenerator {
    /// Generates a pixel-crisp QR code NSImage from the provided text string.
    static func generate(from string: String, size: CGFloat = 160) -> NSImage? {
        guard let data = string.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else {
            return nil
        }

        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }

        let extent = outputImage.extent
        guard extent.width > 0 else { return nil }
        let scale = size / extent.width
        let transformed = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let rep = NSCIImageRep(ciImage: transformed)
        let nsImage = NSImage(size: NSSize(width: size, height: size))
        nsImage.addRepresentation(rep)
        return nsImage
    }
}
