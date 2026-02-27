//
//  ExportManager.swift
//  SentimentAnalyzerSwiftUI
//
//  Created by Малова Олеся on 23.01.2026.
//

import Foundation
import SwiftUI
import PDFKit

class ExportManager {
    
    // MARK: - Export to Text File
    static func exportToText(_ result: TextAnalysisResult) -> String {
        var text = "=== РЕЗУЛЬТАТЫ АНАЛИЗА ТОНАЛЬНОСТИ ===\n\n"
        text += "Дата анализа: \(formatDate(result.timestamp))\n"
        text += "Язык: \(result.language)\n"
        text += "Тональность: \(result.sentiment.rawValue) \(result.sentiment.emoji)\n"
        text += "Уверенность: \(Int(result.confidence * 100))%\n"
        text += "Количество слов: \(result.wordCount)\n\n"
        
        text += "=== ДЕТАЛИ АНАЛИЗА ===\n"
        for detail in result.details {
            text += "\(detail.title): \(detail.value)\n"
        }
        
        text += "\n=== ИСХОДНЫЙ ТЕКСТ ===\n"
        text += result.text
        
        return text
    }
    
    // MARK: - Export to PDF
    static func exportToPDF(_ result: TextAnalysisResult) -> Data? {
        let pdfMetaData = [
            kCGPDFContextCreator: "SentimentAnalyzerSwiftUI",
            kCGPDFContextAuthor: "Sentiment Analyzer",
            kCGPDFContextTitle: "Результаты анализа тональности"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageWidth = 8.5 * 72.0
        let pageHeight = 11 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { context in
            context.beginPage()
            
            var yPosition: CGFloat = 72
            
            // Заголовок
            let title = "Результаты анализа тональности"
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .foregroundColor: UIColor.label
            ]
            let titleSize = title.size(withAttributes: titleAttributes)
            title.draw(at: CGPoint(x: (pageWidth - titleSize.width) / 2, y: yPosition), withAttributes: titleAttributes)
            yPosition += titleSize.height + 20
            
            // Основная информация
            let infoText = """
            Дата: \(formatDate(result.timestamp))
            Язык: \(result.language)
            Тональность: \(result.sentiment.rawValue) \(result.sentiment.emoji)
            Уверенность: \(Int(result.confidence * 100))%
            Слов: \(result.wordCount)
            """
            
            let infoAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.label
            ]
            
            let infoSize = infoText.size(withAttributes: infoAttributes)
            infoText.draw(at: CGPoint(x: 72, y: yPosition), withAttributes: infoAttributes)
            yPosition += infoSize.height + 30
            
            // Детали
            let detailsTitle = "Детали анализа:"
            let detailsTitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 16),
                .foregroundColor: UIColor.label
            ]
            detailsTitle.draw(at: CGPoint(x: 72, y: yPosition), withAttributes: detailsTitleAttributes)
            yPosition += 20
            
            for detail in result.details {
                let detailText = "• \(detail.title): \(detail.value)"
                let detailAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12),
                    .foregroundColor: UIColor.secondaryLabel
                ]
                let detailSize = detailText.size(withAttributes: detailAttributes)
                if yPosition + detailSize.height > pageHeight - 72 {
                    context.beginPage()
                    yPosition = 72
                }
                detailText.draw(at: CGPoint(x: 90, y: yPosition), withAttributes: detailAttributes)
                yPosition += detailSize.height + 5
            }
            
            yPosition += 20
            
            // Исходный текст
            let originalTitle = "Исходный текст:"
            originalTitle.draw(at: CGPoint(x: 72, y: yPosition), withAttributes: detailsTitleAttributes)
            yPosition += 20
            
            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.label
            ]
            
            let textRect = CGRect(x: 72, y: yPosition, width: pageWidth - 144, height: pageHeight - yPosition - 72)
            result.text.draw(in: textRect, withAttributes: textAttributes)
        }
        
        return data
    }
    
    // MARK: - Share Sheet
    static func shareText(_ text: String) {
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
    
    static func sharePDF(_ pdfData: Data) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("analysis_\(UUID().uuidString).pdf")
        
        do {
            try pdfData.write(to: tempURL)
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(activityVC, animated: true)
            }
        } catch {
            print("Ошибка сохранения PDF: \(error)")
        }
    }
    
    // MARK: - Helper
    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
}

