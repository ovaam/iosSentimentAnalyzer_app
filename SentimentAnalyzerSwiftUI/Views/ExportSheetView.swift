//
//  ExportSheetView.swift
//  SentimentAnalyzerSwiftUI
//
//  Created by Малова Олеся on 23.01.2026.
//

import SwiftUI

struct ExportSheetView: View {
    let result: TextAnalysisResult?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let result = result {
                    Text("Выберите формат экспорта")
                        .font(.headline)
                        .padding()
                    
                    Button(action: {
                        exportToText(result)
                    }) {
                        HStack {
                            Image(systemName: "doc.text")
                            Text("Экспорт в текстовый файл")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    Button(action: {
                        exportToPDF(result)
                    }) {
                        HStack {
                            Image(systemName: "doc.fill")
                            Text("Экспорт в PDF")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                } else {
                    Text("Нет результатов для экспорта")
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Экспорт")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func exportToText(_ result: TextAnalysisResult) {
        let text = ExportManager.exportToText(result)
        ExportManager.shareText(text)
    }
    
    private func exportToPDF(_ result: TextAnalysisResult) {
        if let pdfData = ExportManager.exportToPDF(result) {
            ExportManager.sharePDF(pdfData)
        }
    }
}

