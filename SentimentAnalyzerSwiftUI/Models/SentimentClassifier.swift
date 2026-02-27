//
//  SentimentClassifier.swift
//  SentimentAnalyzerSwiftUI
//
//  Created by Малова Олеся on 23.01.2026.
//

import Foundation
import NaturalLanguage
import CoreML

/// Кастомный классификатор тональности текста
/// Использует NLModel для анализа тональности с возможностью работы с обученными моделями
class SentimentClassifier {
    
    // MARK: - Properties
    
    /// ML модель для анализа тональности
    private var nlModel: NLModel?
    
    /// Словари для обучения/работы модели
    private let positiveWords: Set<String> = [
        "хорошо", "отлично", "супер", "нравится", "доволен", "люблю",
        "прекрасно", "замечательно", "восхитительно", "отличный", "великолепно",
        "рад", "счастлив", "удовлетворен", "восхищен", "впечатлен", "рекомендую",
        "качественный", "надежный", "профессиональный", "лучший", "идеальный"
    ]
    
    private let negativeWords: Set<String> = [
        "плохо", "ужасно", "кошмар", "ненавижу", "сломался", "ужасный",
        "плохой", "недоволен", "разочарован", "ужас", "проблема",
        "некачественный", "обман", "мусор", "отстой", "гадость", "отвратительно",
        "не работает", "брак", "дефект", "неисправность", "поломка"
    ]
    
    // MARK: - Initialization
    
    public init() {
        // Пытаемся загрузить обученную модель из бандла
        if let modelURL = Bundle.main.url(forResource: "SentimentClassifier", withExtension: "mlmodelc") {
            do {
                let mlModel = try MLModel(contentsOf: modelURL)
                self.nlModel = try NLModel(mlModel: mlModel)
            } catch {
                print("⚠️ Не удалось загрузить ML модель: \(error.localizedDescription)")
                // Создаем модель программно
                self.nlModel = createCustomModel()
            }
        } else {
            // Если модель не найдена, создаем кастомную модель
            self.nlModel = createCustomModel()
        }
    }
    
    // MARK: - Public Interface
    
    /// Возвращает ML модель для использования в NLModel
    /// Если обученная модель не найдена, возвращает nil (используйте getNLModel() напрямую)
    var model: MLModel? {
        // Пытаемся загрузить обученную модель из бандла
        if let modelURL = Bundle.main.url(forResource: "SentimentClassifier", withExtension: "mlmodelc") {
            return try? MLModel(contentsOf: modelURL)
        }
        // Если модель не найдена, возвращаем nil
        // В этом случае код должен использовать getNLModel() или analyze() напрямую
        return nil
    }
    
    /// Прямой анализ тональности текста
    func predictSentiment(for text: String) -> (label: String, confidence: Double)? {
        guard let model = nlModel else {
            return nil
        }
        
        let predictions = model.predictedLabelHypotheses(for: text, maximumCount: 3)
        guard let topPrediction = predictions.max(by: { $0.value < $1.value }) else {
            return nil
        }
        
        return (topPrediction.key, topPrediction.value)
    }
    
    // MARK: - Private Methods
    
    /// Создает кастомную NLModel программно
    /// Возвращает nil, так как программное создание модели требует обученных данных
    /// В этом случае будет использоваться fallback метод analyzeByKeywords
    private func createCustomModel() -> NLModel? {
        // Для программного создания NLModel требуется обученный набор данных
        // В текущей реализации используем fallback на анализ по ключевым словам
        // Если в будущем понадобится программная модель, можно использовать:
        // let trainingData: [(String, String)] = [...]
        // return try? NLModel(trainingData: trainingData)
        return nil
    }
    
    
    /// Анализ текста с использованием внутренней модели
    func analyze(_ text: String) -> (sentiment: String, confidence: Double) {
        // Сначала пробуем использовать NLModel
        if let result = predictSentiment(for: text) {
            return (result.label, result.confidence)
        }
        
        // Fallback на анализ по ключевым словам
        return analyzeByKeywords(text)
    }
    
    /// Анализ на основе ключевых слов (fallback)
    private func analyzeByKeywords(_ text: String) -> (sentiment: String, confidence: Double) {
        let lowercasedText = text.lowercased()
        var positiveScore = 0
        var negativeScore = 0
        
        // Подсчет положительных слов
        for word in positiveWords {
            if lowercasedText.contains(word) {
                positiveScore += 1
            }
        }
        
        // Подсчет отрицательных слов
        for word in negativeWords {
            if lowercasedText.contains(word) {
                negativeScore += 1
            }
        }
        
        // Определение результата
        let totalScore = positiveScore + negativeScore
        guard totalScore > 0 else {
            return ("neutral", 0.5)
        }
        
        let positiveRatio = Double(positiveScore) / Double(totalScore)
        let negativeRatio = Double(negativeScore) / Double(totalScore)
        
        if positiveRatio > negativeRatio {
            let confidence = min(0.9, 0.6 + positiveRatio * 0.3)
            return ("positive", confidence)
        } else if negativeRatio > positiveRatio {
            let confidence = min(0.9, 0.6 + negativeRatio * 0.3)
            return ("negative", confidence)
        } else {
            return ("neutral", 0.5)
        }
    }
}

// MARK: - Extension for MLModel compatibility

extension SentimentClassifier {
    /// Создает NLModel из MLModel или возвращает существующую модель
    func getNLModel() -> NLModel? {
        return nlModel
    }
    
    /// Альтернативный способ получения модели для использования в NLModel(mlModel:)
    /// Если есть обученная CoreML модель, она будет использована
    /// Иначе используется программно созданная модель
    func getMLModelForNLModel() throws -> MLModel {
        // Пытаемся загрузить из бандла
        if let modelURL = Bundle.main.url(forResource: "SentimentClassifier", withExtension: "mlmodelc") {
            return try MLModel(contentsOf: modelURL)
        }
        
        // Если модель не найдена, выбрасываем ошибку
        // В этом случае код должен использовать getNLModel() напрямую
        throw NSError(
            domain: "SentimentClassifier",
            code: 404,
            userInfo: [NSLocalizedDescriptionKey: "ML модель не найдена. Используйте getNLModel() для программно созданной модели."]
        )
    }
}

