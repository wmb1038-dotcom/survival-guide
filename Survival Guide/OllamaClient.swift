import Foundation

// MARK: - Ollama API Client

struct OllamaClient {

    static let baseURL = URL(string: "http://localhost:11434")!

    // MARK: Availability

    static func isAvailable() async -> Bool {
        guard let url = URL(string: "http://localhost:11434/api/tags") else { return false }
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch { return false }
    }

    static func availableModels() async -> [String] {
        guard let url = URL(string: "http://localhost:11434/api/tags") else { return [] }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            struct Resp: Decodable { struct M: Decodable { let name: String }; let models: [M] }
            return try JSONDecoder().decode(Resp.self, from: data).models.map(\.name)
        } catch { return [] }
    }

    // MARK: Generate (non-streaming)

    static func generate(model: String, system: String, prompt: String) async throws -> String {
        let url = baseURL.appendingPathComponent("api/generate")

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 600

        struct Body: Encodable {
            let model: String
            let system: String
            let prompt: String
            let stream: Bool
            let options: Options
            struct Options: Encodable { let num_predict: Int }
        }

        req.httpBody = try JSONEncoder().encode(
            Body(model: model, system: system, prompt: prompt, stream: false,
                 options: .init(num_predict: 2048))
        )

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 600
        config.timeoutIntervalForResource = 600
        let session = URLSession(configuration: config)

        let (data, _) = try await session.data(for: req)

        struct Resp: Decodable { let response: String }
        return try JSONDecoder().decode(Resp.self, from: data).response
    }
}
