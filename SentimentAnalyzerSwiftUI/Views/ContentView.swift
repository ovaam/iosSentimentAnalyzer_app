//
//  ContentView.swift
//  SentimentAnalyzerSwiftUI
//
//  Created by Малова Олеся on 23.01.2026.
//

import SwiftUI
import NaturalLanguage

struct ContentView: View {
    @StateObject private var viewModel = AnalysisViewModel()
    @State private var inputText = "Я очень доволен этим продуктом! Работает отлично."
    @State private var showingDetails = false
    @State private var showingExportSheet = false
    @State private var showingImageExtractor = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    RealTimeAnalysisView(text: $inputText, viewModel: viewModel)
                    
                    // Импорт текста из изображения
                    ImageTextExtractorView(extractedText: $inputText)
                        .padding(.horizontal)
                    
                    // Поле ввода текста
                    TextEditorView(text: $inputText)
                    
                    // Кнопка анализа
                    AnalysisButton(viewModel: viewModel, text: inputText)
                    
                    // Результаты анализа
                    AnalysisResultsView(viewModel: viewModel)
                    
                    // Графики статистики
                    if let result = viewModel.result {
                        StatisticsChartView(result: result)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.result != nil)
                    }
                    
                    // Тестовые примеры
                    TestCasesView(viewModel: viewModel, inputText: $inputText)
                    
                    // Кнопка автотестирования
                    Button("Запустить автотесты") {
                        runTests()
                    }
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    
                    // Кнопка экспорта
                    if viewModel.result != nil {
                        Button(action: { showingExportSheet = true }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Экспорт результатов")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    
                    // Детали анализа
                    AnalysisDetailsView(viewModel: viewModel, isExpanded: $showingDetails)
                }
                .padding()
            }
            .navigationTitle("Анализатор тональности")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingDetails.toggle() }) {
                        Image(systemName: showingDetails ? "info.circle.fill" : "info.circle")
                    }
                }
            }
            .sheet(isPresented: $showingExportSheet) {
                ExportSheetView(result: viewModel.result)
            }
        }
        .preferredColorScheme(nil) // Автоматическая тема (следует системной)
    }
    
    // MARK: - Testing
    
    private func runTests() {
        let testTexts = [
            "Это отличный день! Я счастлив.",
            "Все ужасно, ничего не работает.",
            "Сегодня обычный день, ничего особенного.",
            "Ты дурак, иди отсюда!"
        ]
        for (index, text) in testTexts.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 2) {
                inputText = text
                viewModel.analyzeText(text)
            }
        }
    }
}

struct TextEditorView: View {
    @Binding var text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Введите текст для анализа:")
                .font(.headline)
            TextEditor(text: $text)
                .frame(height: 150)
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            HStack {
                Text("Символов: \(text.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Очистить") {
                    text = ""
                }
                .font(.caption)
                .disabled(text.isEmpty)
            }
        }
    }
}

struct AnalysisButton: View {
    @ObservedObject var viewModel: AnalysisViewModel
    let text: String
    var body: some View {
        Button(action: {
            viewModel.analyzeText(text)
        }) {
            HStack {
                Image(systemName: "text.magnifyingglass")
                Text("Анализировать тональность")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .disabled(text.isEmpty)
        .opacity(text.isEmpty ? 0.6 : 1)
    }
}

struct RealTimeAnalysisView: View {
    @Binding var text: String
    @ObservedObject var viewModel: AnalysisViewModel
    @State private var realTimeResult: Sentiment? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Анализ в реальном времени:")
                .font(.caption)
                .foregroundColor(.secondary)
            if let sentiment = realTimeResult, text.count > 10 {
                HStack {
                    Text(sentiment.emoji)
                    Text(sentiment.rawValue)
                        .fontWeight(.medium)
                        .foregroundColor(sentiment.color)
                }
                .transition(.opacity)
            }
        }
        .onChange(of: text) { newValue in
            // Запускаем анализ с задержкой
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                performQuickAnalysis(newValue)
            }
        }
    }
    private func performQuickAnalysis(_
                                      text: String) {
        guard text.count > 10 else {
            realTimeResult = nil
            return
        }
        let positiveWords = ["хорошо"
                             ,
                             "отлично"
                             ,
                             "супер"
                             ,
                             "нравится"
                             ,
                             "доволен"]
        let negativeWords = ["плохо"
                             ,
                             "ужасно"
                             ,
                             "кошмар"
                             ,
                             "ненавижу"
                             ,
                             "сломался"]
        var score = 0
        let words = text.lowercased().split(separator: " ")
        for word in words {
            if positiveWords.contains(String(word)) { score += 1 }
            if negativeWords.contains(String(word)) { score -= 1 }
        }
        if score > 0 {
            realTimeResult = .positive
        } else if score < 0 {
            realTimeResult = .negative
        } else {
            realTimeResult = .neutral
        }
    }
}
