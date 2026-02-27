//
//  SentimentAnalyzer.swift
//  SentimentAnalyzerSwiftUI
//
//  Created by Малова Олеся on 23.01.2026.
//

import SwiftUI
import NaturalLanguage
import CoreML

class SentimentAnalyzer {
    // MARK: - Базовый анализ NLP
    func analyze(_
                 text: String) async throws -> TextAnalysisResult {
        var details: [TextAnalysisResult.AnalysisDetail] = []
        // 1. Определение языка
        let language = try await detectLanguage(text)
        details.append(.init(title: "Язык"
                             , value: language, type: .info))
        // 2. Токенизация и статистика
        let (wordCount, sentences) = try await tokenize(text)
        details.append(.init(title: "Статистика"
                             ,
                             value: "\(wordCount) слов, \(sentences) предложений"
                             ,
                             type: .info))
        // 3. Проверка на токсичность (делаем до анализа тональности)
        let isToxic = try await checkToxicity(text)
        // 4. Анализ тональности
        var (sentiment, confidence) = try await analyzeSentiment(text)
        // Если текст токсичный, принудительно устанавливаем негативную тональность
        if isToxic {
            sentiment = .negative
            confidence = max(confidence, 0.8) // Высокая уверенность для токсичного контента
            details.append(.init(title: "⚠️ Предупреждение"
                                 ,
                                 value: "Обнаружен потенциально токсичный контент"
                                 ,
                                 type: .warning))
        }
        // 5. Определение частей речи
        let posDetails = try await analyzePartsOfSpeech(text)
        details.append(contentsOf: posDetails)
        // 6. Поиск именованных сущностей
        let entities = try await findNamedEntities(text)
        if !entities.isEmpty {
            details.append(.init(title: "Именованные сущности"
                                 ,
                                 value: entities.joined(separator: ", "),
                                 type: .info))
        }
        // 7. Определение эмоций
        let emotions = try await detectEmotions(text)
        if !emotions.isEmpty {
            let emotionsString = emotions.map { "\($0.0): \(Int($0.1 * 100))%" }.joined(separator: ", ")
            details.append(.init(title: "Эмоции"
                                 ,
                                 value: emotionsString,
                                 type: .info))
        }
        // 8. Анализ сложности текста
        let readability = try await analyzeReadability(text, wordCount: wordCount, sentenceCount: sentences)
        details.append(.init(title: "Сложность текста"
                             ,
                             value: "\(readability.level) (индекс: \(String(format: "%.1f", readability.score)))",
                             type: .info))
        // 9. Поиск ключевых слов
        let keywords = try await extractKeywords(text)
        if !keywords.isEmpty {
            let keywordsString = keywords.prefix(5).joined(separator: ", ")
            details.append(.init(title: "Ключевые слова"
                                 ,
                                 value: keywordsString,
                                 type: .info))
        }
        return TextAnalysisResult(
            text: text,
            sentiment: sentiment,
            confidence: confidence,
            language: language,
            wordCount: wordCount,
            entities: entities,
            details: details,
            timestamp: Date()
        )
    }
    // MARK: - Детектирование языка
    private func detectLanguage(_ text: String) async throws -> String {
    let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let language = recognizer.dominantLanguage else {
            return "Не определен"
        }
        return language.rawValue
    }
    
    // MARK: - Токенизация
    private func tokenize(_ text: String) async throws -> (wordCount: Int, sentenceCount: Int) {
        let tagger = NLTagger(tagSchemes: [.tokenType])
        tagger.string = text
        
        var wordCount = 0
        var sentenceCount = 0
        
        // Подсчет слов
        tagger.enumerateTags(in: text.startIndex..<text.endIndex,
                             unit: .word,
                             scheme: .tokenType,
                             options: [.omitPunctuation, .omitWhitespace]) { _, _ in
            wordCount += 1
            return true
        }
        
        // Подсчет предложений
        tagger.enumerateTags(in: text.startIndex..<text.endIndex,
                             unit: .sentence,
                             scheme: .tokenType) { _, _ in
            sentenceCount += 1
            return true
        }
        return (wordCount, sentenceCount)
    }
    
    // MARK: - Анализ тональности
    private func analyzeSentiment(_ text: String) async throws -> (Sentiment, Double) {
        // Сначала пробуем встроенный анализатор
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text
        if let sentimentTag = tagger.tag(at: text.startIndex,
                                         unit: .paragraph,
                                         scheme: .sentimentScore).0,
           let score = Double(sentimentTag.rawValue) {
            let sentiment: Sentiment
            switch score {
            case 0.3...:
                sentiment =
                    .positive
            case -0.3..<0.3:
                sentiment =
                    .neutral
            default:
                sentiment =
                    .negative
            }
            return (sentiment, abs(score))
        }
        // Если встроенный не сработал, используем кастомную модель
        return try await analyzeWithCustomModel(text)
    }
    
    // MARK: - Кастомная модель
    // Загрузка кастомной модели
    // Предполагается, что модель добавлена в проект
    private func analyzeWithCustomModel(_ text: String) async throws -> (Sentiment, Double) {
        let classifier = SentimentClassifier()
        
        // Пытаемся использовать MLModel через NLModel (если есть обученная модель)
        if let mlModel = classifier.model {
            guard let nlModel = try? NLModel(mlModel: mlModel) else {
                throw AnalysisError.modelNotFound
            }
            
            let predictions = nlModel.predictedLabelHypotheses(for: text, maximumCount: 3)
            guard let topPrediction = predictions.max(by: { $0.value < $1.value }) else {
                return (.neutral, 0.0)
            }
            
            let sentiment: Sentiment
            switch topPrediction.key.lowercased() {
            case "positive", "позитивный":
                sentiment = .positive
            case "negative", "негативный":
                sentiment = .negative
            default:
                sentiment = .neutral
            }
            
            return (sentiment, topPrediction.value)
        }
        
        // Если обученной модели нет, используем программно созданную NLModel
        if let nlModel = classifier.getNLModel() {
            let predictions = nlModel.predictedLabelHypotheses(for: text, maximumCount: 3)
            guard let topPrediction = predictions.max(by: { $0.value < $1.value }) else {
                return (.neutral, 0.0)
            }
            
            let sentiment: Sentiment
            switch topPrediction.key.lowercased() {
            case "positive", "позитивный":
                sentiment = .positive
            case "negative", "негативный":
                sentiment = .negative
            default:
                sentiment = .neutral
            }
            
            return (sentiment, topPrediction.value)
        }
        
        // Последний fallback: прямой анализ через метод analyze
        let result = classifier.analyze(text)
        let sentiment: Sentiment
        switch result.sentiment.lowercased() {
        case "positive", "позитивный":
            sentiment = .positive
        case "negative", "негативный":
            sentiment = .negative
        default:
            sentiment = .neutral
        }
        
        return (sentiment, result.confidence)
    }
    
    // MARK: - Дополнительные функции NLP
    private func analyzePartsOfSpeech(_ text: String) async throws -> [TextAnalysisResult.AnalysisDetail] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        var posCount: [String: Int] = [:]
        tagger.enumerateTags(in: text.startIndex..<text.endIndex,
                             unit: .word,
                             scheme: .lexicalClass,
                             options: [.omitPunctuation, .omitWhitespace]) { tag, _
            in
            if let tag = tag {
                posCount[tag.rawValue, default: 0] += 1
            }
            return true
        }
        return posCount.map { TextAnalysisResult.AnalysisDetail(
            title: "Часть речи: \($0.key)"
            ,
            value: "\($0.value)"
            ,
            type: .info
        )}
    }
    private func findNamedEntities(_
                                   text: String) async throws -> [String] {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        var entities: [String] = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex,
                             unit: .word,
                             scheme: .nameType,
                             options: [.joinNames]) { tag, range in
            if let tag = tag, tag != .otherWord {
                let entity = String(text[range])
                entities.append("\(entity) (\(tag.rawValue))")
            }
            return true
        }
        return entities
    }
    private func checkToxicity(_ text: String) async throws -> Bool {
        // Расширенная проверка по ключевым словам
        // В реальном приложении следует использовать ML модель
        let toxicPatterns = [
            "идиот", "дурак", "тупой", "ненавижу", "убей", "сдохни",
            "тупица", "дебил", "кретин", "мразь", "сволочь", "гад",
            "убить", "умереть", "сдохнуть", "провались", "отвали",
            "ненависть", "ненавидеть", "презираю", "презрение",
            "убийца", "убийство", "ненавистный", "отвратительный",
            "иди к черту", "пошел вон", "убирайся", "провали",
            "черт", "черт возьми", "проклятый", "проклятье"
        ]
        let lowercasedText = text.lowercased()
        // Проверяем наличие токсичных слов (точное совпадение или как часть слова)
        for pattern in toxicPatterns {
            if lowercasedText.contains(pattern) {
                return true
            }
        }
        return false
    }
    
    // MARK: - Определение эмоций
    private func detectEmotions(_ text: String) async throws -> [(String, Double)] {
        let lowercasedText = text.lowercased()
        var emotions: [(String, Double)] = []
        
        // Словари для определения эмоций
        let joyWords = ["радость", "счастье", "рад", "счастлив", "веселье", "радостный",
                       "восторг", "восхищение", "ликование", "ура", "отлично", "прекрасно"]
        let sadnessWords = ["грусть", "печаль", "грустный", "печальный", "тоска", "тоскливо",
                           "уныние", "отчаяние", "плохо", "плохой", "ужасно", "ужасный"]
        let angerWords = ["злость", "злой", "злиться", "гнев", "гневный", "ярость", "яростный",
                         "раздражение", "раздраженный", "бешенство", "бешеный", "ненависть"]
        
        var joyScore = 0.0
        var sadnessScore = 0.0
        var angerScore = 0.0
        
        let words = lowercasedText.components(separatedBy: CharacterSet.whitespacesAndNewlines)
        let totalWords = Double(words.count)
        
        for word in words {
            let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)
            if joyWords.contains(cleanWord) {
                joyScore += 1.0
            }
            if sadnessWords.contains(cleanWord) {
                sadnessScore += 1.0
            }
            if angerWords.contains(cleanWord) {
                angerScore += 1.0
            }
        }
        
        // Нормализуем оценки
        if totalWords > 0 {
            joyScore = min(1.0, joyScore / totalWords * 10)
            sadnessScore = min(1.0, sadnessScore / totalWords * 10)
            angerScore = min(1.0, angerScore / totalWords * 10)
        }
        
        // Добавляем только эмоции с достаточной уверенностью
        if joyScore > 0.1 {
            emotions.append(("Радость", joyScore))
        }
        if sadnessScore > 0.1 {
            emotions.append(("Грусть", sadnessScore))
        }
        if angerScore > 0.1 {
            emotions.append(("Злость", angerScore))
        }
        
        // Сортируем по убыванию
        return emotions.sorted { $0.1 > $1.1 }
    }
    
    // MARK: - Анализ сложности текста (индекс удобочитаемости)
    private func analyzeReadability(_ text: String, wordCount: Int, sentenceCount: Int) async throws -> (level: String, score: Double) {
        guard wordCount > 0 && sentenceCount > 0 else {
            return ("Не определен", 0.0)
        }
        
        // Формула Flesch Reading Ease (адаптированная для русского языка)
        // Более простой вариант: средняя длина предложения и средняя длина слова
        let avgSentenceLength = Double(wordCount) / Double(sentenceCount)
        let avgWordLength = text.replacingOccurrences(of: " ", with: "").count / wordCount
        
        // Упрощенный индекс удобочитаемости
        // Чем больше предложений и короче слова, тем проще текст
        let readabilityScore = 100.0 - (avgSentenceLength * 1.5) - (Double(avgWordLength) * 2.0)
        let normalizedScore = max(0, min(100, readabilityScore))
        
        let level: String
        switch normalizedScore {
        case 80...100:
            level = "Очень легко"
        case 60..<80:
            level = "Легко"
        case 40..<60:
            level = "Средне"
        case 20..<40:
            level = "Сложно"
        default:
            level = "Очень сложно"
        }
        
        return (level, normalizedScore)
    }
    
    // MARK: - Поиск ключевых слов
    private func extractKeywords(_ text: String) async throws -> [String] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        
        var wordFrequencies: [String: Int] = [:]
        let stopWords: Set<String> = [
            "и", "в", "на", "с", "по", "для", "от", "до", "из", "к", "о", "об",
            "а", "но", "или", "что", "как", "так", "это", "то", "он", "она", "они",
            "быть", "был", "была", "было", "были", "есть", "быть", "этот", "эта", "это",
            "the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with"
        ]
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex,
                             unit: .word,
                             scheme: .lexicalClass,
                             options: [.omitPunctuation, .omitWhitespace]) { tag, range in
            if let tag = tag, tag == .noun || tag == .adjective {
                let word = String(text[range]).lowercased()
                let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)
                if !stopWords.contains(cleanWord) && cleanWord.count > 3 {
                    wordFrequencies[cleanWord, default: 0] += 1
                }
            }
            return true
        }
        
        // Сортируем по частоте и возвращаем топ-10
        return wordFrequencies.sorted { $0.value > $1.value }
            .prefix(10)
            .map { $0.key.capitalized }
    }
    // MARK: - Ошибки
    enum AnalysisError: Error {
        case modelNotFound
        case invalidText
        case analysisFailed
    }
}
