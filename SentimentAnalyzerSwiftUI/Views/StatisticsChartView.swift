//
//  StatisticsChartView.swift
//  SentimentAnalyzerSwiftUI
//
//  Created by Малова Олеся on 23.01.2026.
//

import SwiftUI
// Charts framework доступен только в iOS 16+
// Для совместимости используем простые графики
#if canImport(Charts)
import Charts
#endif

struct StatisticsChartView: View {
    let result: TextAnalysisResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Статистика анализа")
                .font(.headline)
            
            // График частей речи
            if let posChartData = partsOfSpeechData {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Части речи")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Простой график-бар для совместимости
                    VStack(spacing: 8) {
                        ForEach(posChartData, id: \.name) { item in
                            HStack {
                                Text(item.name)
                                    .font(.caption)
                                    .frame(width: 100, alignment: .leading)
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(height: 20)
                                        Rectangle()
                                            .fill(Color.blue)
                                            .frame(width: geometry.size.width * CGFloat(min(1.0, Double(item.value) / 10.0)), height: 20)
                                    }
                                }
                                .frame(height: 20)
                                Text("\(item.value)")
                                    .font(.caption)
                                    .frame(width: 30)
                            }
                        }
                    }
                    .frame(height: CGFloat(posChartData.count * 30))
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }
            
            // График эмоций (если есть)
            if let emotionsData = emotionsChartData {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Эмоции")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Простая круговая диаграмма
                    VStack(spacing: 12) {
                        ForEach(emotionsData, id: \.name) { item in
                            HStack {
                                Circle()
                                    .fill(colorForEmotion(item.name))
                                    .frame(width: 12, height: 12)
                                Text(item.name)
                                    .font(.caption)
                                Spacer()
                                Text("\(Int(item.value * 100))%")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .frame(height: CGFloat(emotionsData.count * 30))
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }
        }
    }
    
    private var partsOfSpeechData: [(name: String, value: Int)]? {
        let posDetails = result.details.filter { $0.title.contains("Часть речи") }
        guard !posDetails.isEmpty else { return nil }
        
        return posDetails.compactMap { detail in
            let name = detail.title.replacingOccurrences(of: "Часть речи: ", with: "")
            if let value = Int(detail.value) {
                return (name: name, value: value)
            }
            return nil
        }
    }
    
    private var emotionsChartData: [(name: String, value: Double)]? {
        let emotionsDetail = result.details.first { $0.title == "Эмоции" }
        guard let detail = emotionsDetail else { return nil }
        
        // Парсим строку типа "Радость: 45%, Грусть: 30%, Злость: 25%"
        let components = detail.value.components(separatedBy: ", ")
        return components.compactMap { component in
            let parts = component.components(separatedBy: ": ")
            guard parts.count == 2,
                  let name = parts.first,
                  let percentString = parts.last?.replacingOccurrences(of: "%", with: ""),
                  let percent = Double(percentString) else {
                return nil
            }
            return (name: name, value: percent / 100.0)
        }
    }
    
    private func colorForEmotion(_ emotion: String) -> Color {
        switch emotion.lowercased() {
        case "радость":
            return .yellow
        case "грусть":
            return .blue
        case "злость":
            return .red
        default:
            return .gray
        }
    }
}

