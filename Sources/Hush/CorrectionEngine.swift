import Foundation

/// Handles text correction/reformulation via OpenRouter API.
final class CorrectionEngine {
    static let apiURL = "https://openrouter.ai/api/v1/chat/completions"
    static let model = "mistralai/ministral-3b-2512"

    func correct(text: String, mode: CorrectionMode) async -> String {
        // License check — dispersed verification (anti-crack)
        if !LicenseManager.shared.isLicensed {
            Log.warn("License check failed — returning original text")
            return text
        }

        Log.step("CorrectionEngine received \(text.count) chars — mode: \(mode.label)")
        Log.info("  Input: \"\(text.prefix(80))\(text.count > 80 ? "..." : "")\"")

        if AppSettings.shared.useLocalModel {
            Log.warn("Local model selected — not yet available, returning original text")
            return text
        }

        let apiKey = AppSettings.shared.apiKey
        guard !apiKey.isEmpty else {
            Log.error("No API key configured — open Paramètres to set it")
            return text
        }

        guard let url = URL(string: Self.apiURL) else { return text }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("https://hush.app", forHTTPHeaderField: "HTTP-Referer")
        request.timeoutInterval = 15

        let systemPrompt = mode.systemPrompt
        Log.info("  System: \"\(systemPrompt.prefix(70))...\"")

        let body: [String: Any] = [
            "model": Self.model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text],
            ],
            "max_tokens": 1000,
            "temperature": 0.1,
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let start = CFAbsoluteTimeGetCurrent()

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let latency = CFAbsoluteTimeGetCurrent() - start

            guard let httpResponse = response as? HTTPURLResponse else {
                Log.error("Invalid response")
                return text
            }

            guard httpResponse.statusCode == 200 else {
                let body = String(data: data, encoding: .utf8) ?? ""
                Log.error("API error \(httpResponse.statusCode): \(body.prefix(100))")
                return text
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let first = choices.first,
                  let message = first["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                Log.error("Failed to parse API response")
                return text
            }

            let corrected = content.trimmingCharacters(in: .whitespacesAndNewlines)

            // Log usage
            if let usage = json["usage"] as? [String: Any] {
                let promptTok = usage["prompt_tokens"] as? Int ?? 0
                let completionTok = usage["completion_tokens"] as? Int ?? 0
                let cost = usage["cost"] as? Double ?? 0
                Log.success("API response in \(String(format: "%.2f", latency))s — \(promptTok)+\(completionTok) tokens — $\(String(format: "%.6f", cost))")
            }

            Log.info("  Output: \"\(corrected.prefix(80))\(corrected.count > 80 ? "..." : "")\"")

            if corrected.isEmpty {
                Log.warn("Empty response — keeping original text")
                return text
            }

            return corrected

        } catch {
            Log.error("Network error: \(error.localizedDescription)")
            return text
        }
    }
}
