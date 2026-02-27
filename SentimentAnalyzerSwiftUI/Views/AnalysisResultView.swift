//
//  AnalysisResultView.swift
//  SentimentAnalyzerSwiftUI
//
//  Created by Малова Олеся on 23.01.2026.
//
import SwiftUI

struct AnalysisResultsView: View {
    @ObservedObject var viewModel: AnalysisViewModel
    var body: some View {
        VStack(spacing: 16) {
            if viewModel.isAnalyzing {
                ProgressView("Анализ текста...")
                    .padding()
            } else if let result = viewModel.result {
                SentimentCard(result: result)
                ConfidenceIndicator(confidence: result.confidence)
                Text("Детали анализа:")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(result.details.prefix(3), id: \.title) { detail in
                    AnalysisDetailRow(detail: detail)
                }
            } else if let error = viewModel.errorMessage {
                ErrorView(message: error)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.2), radius: 5)
    }
}

struct SentimentCard: View {
    let result: TextAnalysisResult
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Результат анализа")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        Text(result.sentiment.rawValue)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(result.sentiment.color)
                        Text(result.sentiment.emoji)
                            .font(.title2)
                    }
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Уверенность")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(result.confidence * 100))%")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
            }
            Text("Язык: \(result.language)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(result.sentiment.color.opacity(0.1))
        )
    }
}

struct ErrorView: View {
    let message: String
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.red)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.red.opacity(0.1))
        )
    }
}
