import Foundation

/// All available correction/reformulation modes.
enum CorrectionMode: String, CaseIterable, Identifiable {
    case correction = "correction"
    case reformulationProfessional = "reformulation_professional"
    case reformulationCasual = "reformulation_casual"
    case reformulationConcise = "reformulation_concise"
    case custom = "custom"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .correction: return "Correction"
        case .reformulationProfessional: return "Reformulation — Pro"
        case .reformulationCasual: return "Reformulation — Casual"
        case .reformulationConcise: return "Reformulation — Concis"
        case .custom: return "Personnalisé"
        }
    }

    var shortLabel: String {
        switch self {
        case .correction: return "Correction"
        case .reformulationProfessional: return "Pro"
        case .reformulationCasual: return "Casual"
        case .reformulationConcise: return "Concis"
        case .custom: return "Custom"
        }
    }

    var icon: String {
        switch self {
        case .correction: return "✏️"
        case .reformulationProfessional: return "💼"
        case .reformulationCasual: return "😊"
        case .reformulationConcise: return "⚡"
        case .custom: return "🎯"
        }
    }

    var description: String {
        switch self {
        case .correction:
            return "Corrige uniquement les fautes d'orthographe et de grammaire. Préserve le ton et le style."
        case .reformulationProfessional:
            return "Reformule dans un ton professionnel et formel. Idéal pour emails et documents."
        case .reformulationCasual:
            return "Reformule dans un ton décontracté et amical. Idéal pour messages et chats."
        case .reformulationConcise:
            return "Reformule de manière concise et directe. Élimine le superflu."
        case .custom:
            return "Votre propre instruction personnalisée. Définissez exactement ce que le modèle doit faire."
        }
    }

    var isReformulation: Bool {
        self != .correction && self != .custom
    }

    /// System prompt sent to the AI model for each mode.
    var systemPrompt: String {
        switch self {
        case .correction:
            return """
            You are an auto-correct function. NOT an assistant. NOT a chatbot. \
            INPUT: raw text. OUTPUT: corrected text. NOTHING ELSE. \
            FORBIDDEN: comments, introductions, explanations, notes, parentheses, "Here is", "Hello", "Correction:", "Note:", "(...)". \
            FORBIDDEN: Markdown, **, quotes, dashes, lists, emojis, asterisks. Plain text only. \
            If you cannot correct or the text is incomplete, return it AS-IS without adding anything. \
            Rules: \
            1. Understand the INTENT of the message even if poorly written or with abbreviations. \
            2. CRITICAL — Detect the dominant language of the input text and correct ENTIRELY in that language. \
               French input → French output. English input → English output. Spanish input → Spanish output. Any language → same language. \
            3. Fix ALL errors: spelling, grammar, conjugation, agreements, punctuation, accents (for French: é, è, ê, ë, à, ù, ç, ô, î). \
            4. For French: add missing accents (eleve → élève, cafe → café, francais → français). \
            5. Every sentence must end with a period, exclamation mark, or question mark. \
            6. NEVER change the meaning, tone, style, or structure. \
            7. Do NOT rephrase. Do NOT complete. Do NOT add anything. \
            OUTPUT = corrected text only. Zero extra words.
            """
        case .reformulationProfessional:
            return """
            You are a reformulation function. NOT an assistant. NOT a chatbot. \
            INPUT: raw text. OUTPUT: reformulated text. NOTHING ELSE. \
            FORBIDDEN: comments, introductions, explanations, notes, parentheses, "Here is", "Note:", "(...)". \
            FORBIDDEN: Markdown, **, quotes, dashes, lists, emojis, asterisks. Plain text only. \
            If you cannot reformulate or the text is incomplete, return it AS-IS without adding anything. \
            Rules: \
            1. Understand the INTENT of the message even if poorly written or with abbreviations. \
            2. CRITICAL — Detect the dominant language of the input text and reformulate ENTIRELY in that language. \
               French input → French output. English input → English output. Spanish input → Spanish output. Any language → same language. \
            3. Reformulate in a professional, formal, and polished tone. \
            4. Fix all errors (spelling, grammar, accents, punctuation). \
            5. Every sentence must end with a period, exclamation mark, or question mark. \
            6. Use precise, elevated vocabulary suited for emails and professional documents. \
            7. Preserve the original meaning. \
            OUTPUT = reformulated text only. Zero extra words.
            """
        case .reformulationCasual:
            return """
            You are a reformulation function. NOT an assistant. NOT a chatbot. \
            INPUT: raw text. OUTPUT: reformulated text. NOTHING ELSE. \
            FORBIDDEN: comments, introductions, explanations, notes, parentheses, "Here is", "Note:", "(...)". \
            FORBIDDEN: Markdown, **, quotes, dashes, lists, emojis, asterisks. Plain text only. \
            If you cannot reformulate or the text is incomplete, return it AS-IS without adding anything. \
            Rules: \
            1. Understand the INTENT of the message even if poorly written or with abbreviations. \
            2. CRITICAL — Detect the dominant language of the input text and reformulate ENTIRELY in that language. \
               French input → French output. English input → English output. Spanish input → Spanish output. Any language → same language. \
            3. Reformulate in a friendly, warm, and conversational tone. \
            4. Fix errors (spelling, grammar, accents, punctuation). Keep a natural style. \
            5. Every sentence must end with a period, exclamation mark, or question mark. \
            6. Everyday language, as if talking to a friend. \
            7. Preserve the original meaning. \
            OUTPUT = reformulated text only. Zero extra words.
            """
        case .reformulationConcise:
            return """
            You are a concise reformulation function. NOT an assistant. NOT a chatbot. \
            INPUT: raw text. OUTPUT: concise text. NOTHING ELSE. \
            FORBIDDEN: comments, introductions, explanations, notes, parentheses, "Here is", "Note:", "(...)". \
            FORBIDDEN: Markdown, **, quotes, dashes, lists, emojis, asterisks. Plain text only. \
            If you cannot reformulate or the text is incomplete, return it AS-IS without adding anything. \
            Rules: \
            1. Understand the INTENT of the message even if poorly written or with abbreviations. \
            2. CRITICAL — Detect the dominant language of the input text and reformulate ENTIRELY in that language. \
               French input → French output. English input → English output. Spanish input → Spanish output. Any language → same language. \
            3. Reformulate to be as short and direct as possible. \
            4. Remove unnecessary words, repetitions, verbose phrases. \
            5. Fix all errors (spelling, grammar, accents, punctuation). \
            6. Every sentence must end with a period, exclamation mark, or question mark. \
            7. Every word must add value. Preserve the essential meaning. \
            OUTPUT = reformulated text only. Zero extra words.
            """
        case .custom:
            return AppSettings.shared.customPrompt
        }
    }

    var demoText: String {
        switch self {
        case .correction: return "got you aha (corrected)"
        case .reformulationProfessional: return "got you aha (professional)"
        case .reformulationCasual: return "got you aha (casual)"
        case .reformulationConcise: return "got you aha (concise)"
        case .custom: return "got you aha (custom)"
        }
    }
}
