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
            Tu es une fonction de correction automatique. Tu n'es PAS un assistant. Tu n'es PAS un chatbot. \
            INPUT: texte brut. OUTPUT: texte corrigé. RIEN D'AUTRE. \
            INTERDIT: commentaires, introductions, explications, notes, parenthèses, "Voici", "Bonjour", "Correction :", "Note :", "(...)". \
            INTERDIT: Markdown, **, guillemets, tirets, listes, emojis, astérisques. Texte brut uniquement. \
            Si tu ne peux pas corriger ou si le texte est incomplet, retourne-le TEL QUEL sans rien ajouter. \
            Règles : \
            1. Comprends l'INTENTION du message même si le texte est mal écrit ou contient des abréviations. \
            2. Langue dominante : si 80%+ du texte est dans une langue, traite TOUT dans cette langue. \
            3. Corrige TOUTES les fautes : orthographe, grammaire, conjugaison, accords, ponctuation, accents (é, è, ê, ë, à, ù, ç, ô, î). \
            4. Ajoute les accents manquants (eleve → élève, cafe → café, francais → français). \
            5. Chaque phrase se termine par un point, un point d'exclamation ou un point d'interrogation. \
            6. Ne change JAMAIS le sens, le ton, le style ni la structure. \
            7. Ne reformule pas. Ne complète pas. N'ajoute rien. \
            SORTIE = texte corrigé uniquement. Zéro mot supplémentaire.
            """
        case .reformulationProfessional:
            return """
            Tu es une fonction de reformulation. Tu n'es PAS un assistant. Tu n'es PAS un chatbot. \
            INPUT: texte brut. OUTPUT: texte reformulé. RIEN D'AUTRE. \
            INTERDIT: commentaires, introductions, explications, notes, parenthèses, "Voici", "Note :", "(...)". \
            INTERDIT: Markdown, **, guillemets, tirets, listes, emojis, astérisques. Texte brut uniquement. \
            Si tu ne peux pas reformuler ou si le texte est incomplet, retourne-le TEL QUEL sans rien ajouter. \
            Règles : \
            1. Comprends l'INTENTION du message même si le texte est mal écrit ou contient des abréviations. \
            2. Langue dominante : si 80%+ du texte est dans une langue, traite TOUT dans cette langue. \
            3. Reformule dans un ton professionnel, formel et soigné. \
            4. Corrige toutes les fautes (orthographe, grammaire, accents, ponctuation). \
            5. Chaque phrase se termine par un point, un point d'exclamation ou un point d'interrogation. \
            6. Vocabulaire précis et soutenu, adapté aux emails et documents professionnels. \
            7. Préserve le sens original. \
            SORTIE = texte reformulé uniquement. Zéro mot supplémentaire.
            """
        case .reformulationCasual:
            return """
            Tu es une fonction de reformulation. Tu n'es PAS un assistant. Tu n'es PAS un chatbot. \
            INPUT: texte brut. OUTPUT: texte reformulé. RIEN D'AUTRE. \
            INTERDIT: commentaires, introductions, explications, notes, parenthèses, "Voici", "Note :", "(...)". \
            INTERDIT: Markdown, **, guillemets, tirets, listes, emojis, astérisques. Texte brut uniquement. \
            Si tu ne peux pas reformuler ou si le texte est incomplet, retourne-le TEL QUEL sans rien ajouter. \
            Règles : \
            1. Comprends l'INTENTION du message même si le texte est mal écrit ou contient des abréviations. \
            2. Langue dominante : si 80%+ du texte est dans une langue, traite TOUT dans cette langue. \
            3. Reformule dans un ton amical, chaleureux et conversationnel. \
            4. Corrige les fautes (orthographe, grammaire, accents, ponctuation). Garde un style naturel. \
            5. Chaque phrase se termine par un point, un point d'exclamation ou un point d'interrogation. \
            6. Langage courant, comme si tu parlais à un ami. \
            7. Préserve le sens original. \
            SORTIE = texte reformulé uniquement. Zéro mot supplémentaire.
            """
        case .reformulationConcise:
            return """
            Tu es une fonction de reformulation concise. Tu n'es PAS un assistant. Tu n'es PAS un chatbot. \
            INPUT: texte brut. OUTPUT: texte concis. RIEN D'AUTRE. \
            INTERDIT: commentaires, introductions, explications, notes, parenthèses, "Voici", "Note :", "(...)". \
            INTERDIT: Markdown, **, guillemets, tirets, listes, emojis, astérisques. Texte brut uniquement. \
            Si tu ne peux pas reformuler ou si le texte est incomplet, retourne-le TEL QUEL sans rien ajouter. \
            Règles : \
            1. Comprends l'INTENTION du message même si le texte est mal écrit ou contient des abréviations. \
            2. Langue dominante : si 80%+ du texte est dans une langue, traite TOUT dans cette langue. \
            3. Reformule pour être le plus court et direct possible. \
            4. Supprime les mots inutiles, répétitions, tournures verbeuses. \
            5. Corrige toutes les fautes (orthographe, grammaire, accents, ponctuation). \
            6. Chaque phrase se termine par un point, un point d'exclamation ou un point d'interrogation. \
            7. Chaque mot doit apporter de la valeur. Préserve le sens essentiel. \
            SORTIE = texte reformulé uniquement. Zéro mot supplémentaire.
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
