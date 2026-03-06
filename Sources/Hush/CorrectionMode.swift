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

    /// The built-in system prompt for Ollama (custom mode uses AppSettings.customPrompt)
    var systemPrompt: String {
        switch self {
        case .correction:
            return """
            You are a grammar and spelling corrector. Detect the language of the input text automatically. \
            Return ONLY the corrected text, with no explanations, no notes, no prefix, no quotes. \
            Preserve the original tone, style, structure and language. Fix only spelling mistakes and grammar errors.
            """
        case .reformulationProfessional:
            return """
            You are a professional text rewriter. Detect the language of the input text automatically. \
            Return ONLY the rewritten text, with no explanations, no notes, no prefix, no quotes. \
            Rewrite the text in a professional, formal tone suitable for business emails and documents. \
            Preserve the original meaning and language. Also fix any spelling or grammar errors.
            """
        case .reformulationCasual:
            return """
            You are a casual text rewriter. Detect the language of the input text automatically. \
            Return ONLY the rewritten text, with no explanations, no notes, no prefix, no quotes. \
            Rewrite the text in a friendly, casual, conversational tone. \
            Preserve the original meaning and language. Also fix any spelling or grammar errors.
            """
        case .reformulationConcise:
            return """
            You are a concise text rewriter. Detect the language of the input text automatically. \
            Return ONLY the rewritten text, with no explanations, no notes, no prefix, no quotes. \
            Rewrite the text to be as concise and direct as possible. Remove filler words, redundancies, \
            and unnecessary details. Preserve the original meaning and language. Also fix any spelling or grammar errors.
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
