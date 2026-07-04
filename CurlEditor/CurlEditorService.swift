import Foundation

// MARK: - cURL Import Result

/// Structured result of parsing a cURL command.
public struct CurlImportResult {
    public let method: HTTPMethod
    public let url: String
    public let queryItems: [KeyValueRow]
    public let headers: [KeyValueRow]
    public let body: String
    public let bodyType: RequestBodyType
    public let authorization: RequestAuthorization
}

// MARK: - Validation

public struct CurlEditorValidation {
    public let isValid: Bool
    public let detail: String?

    public var statusText: String {
        if isValid {
            return "valid"
        }
        guard let detail, !detail.isEmpty else {
            return "invalid"
        }
        return "invalid: \(detail)"
    }
}

// MARK: - Service

/// Parses cURL commands into structured API request components.
public struct CurlEditorService {

    public init() {}

    // MARK: - Public API

    public func validateCommand(_ command: String) -> CurlEditorValidation {
        do {
            _ = try importCommand(command)
            return CurlEditorValidation(isValid: true, detail: nil)
        } catch let error as LocalizedError {
            return CurlEditorValidation(isValid: false, detail: error.errorDescription)
        } catch {
            return CurlEditorValidation(isValid: false, detail: nil)
        }
    }

    public func importCommand(_ command: String) throws -> CurlImportResult {
        let normalizedCommand = normalize(command)
        guard !normalizedCommand.isEmpty else {
            throw CurlEditorError.emptyCommand
        }

        let tokens = try tokenize(normalizedCommand)
        guard !tokens.isEmpty else {
            throw CurlEditorError.invalidCommand(reason: nil)
        }

        var index = 0
        if tokens.first?.lowercased() == "curl" {
            index = 1
        }

        var explicitMethod: HTTPMethod?
        var resolvedURL: String?
        var headers: [KeyValueRow] = []
        var bodySegments: [String] = []
        var additionalQueryItems: [KeyValueRow] = []
        var authorization: RequestAuthorization = .none
        var useGetMode = false
        var useHeadMode = false

        while index < tokens.count {
            let token = tokens[index]

            switch token {
            case "-X", "--request":
                let value = try value(after: &index, option: token, tokens: tokens)
                explicitMethod = HTTPMethod(rawValue: value.uppercased()) ?? explicitMethod
            case "-H", "--header":
                let value = try value(after: &index, option: token, tokens: tokens)
                if let header = parseHeader(value) {
                    headers.append(header)
                }
            case "-d", "--data", "--data-raw", "--data-binary", "--data-ascii":
                let value = try value(after: &index, option: token, tokens: tokens)
                if useGetMode {
                    additionalQueryItems.append(parseQueryItem(value))
                } else {
                    bodySegments.append(value)
                }
            case "--get", "-G":
                useGetMode = true
            case "--head", "-I":
                useHeadMode = true
            case "-u", "--user":
                let value = try value(after: &index, option: token, tokens: tokens)
                authorization = parseBasicAuthorization(value)
            case "-b", "--cookie":
                let value = try value(after: &index, option: token, tokens: tokens)
                headers.append(KeyValueRow(key: "Cookie", value: value, isEnabled: true))
            case "--url":
                let value = try value(after: &index, option: token, tokens: tokens)
                resolvedURL = value
            default:
                if token.hasPrefix("http://") || token.hasPrefix("https://") {
                    resolvedURL = token
                } else if token.hasPrefix("-") {
                    // Unrecognized flag, ignore
                } else if resolvedURL == nil {
                    resolvedURL = token
                }
            }

            index += 1
        }

        guard let resolvedURL else {
            throw CurlEditorError.missingURL
        }

        let urlSplit = splitURLAndQuery(resolvedURL)
        let inferredMethod = inferredMethod(
            explicitMethod: explicitMethod,
            useGetMode: useGetMode,
            useHeadMode: useHeadMode,
            hasBody: !bodySegments.isEmpty
        )
        let queryItems = urlSplit.queryItems + (useGetMode ? bodySegments.map(parseQueryItem) : []) + additionalQueryItems
        let bodyText = useGetMode ? "" : bodySegments.joined(separator: "&")
        let bodyType = inferBodyType(bodyText)

        return CurlImportResult(
            method: inferredMethod,
            url: urlSplit.baseURL,
            queryItems: queryItems,
            headers: headers,
            body: bodyText,
            bodyType: bodyType,
            authorization: authorization
        )
    }

    // MARK: - Tokenization

    private func normalize(_ command: String) -> String {
        command
            .replacingOccurrences(
                of: #"\\[ \t]*\r?\n"#,
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func tokenize(_ command: String) throws -> [String] {
        let characters = Array(command)
        var tokens: [String] = []
        var current = ""
        var inSingleQuote = false
        var inDoubleQuote = false
        var escaping = false

        for index in characters.indices {
            let character = characters[index]

            if escaping {
                current.append(character)
                escaping = false
                continue
            }

            switch character {
            case "\\":
                if inSingleQuote {
                    current.append(character)
                } else {
                    escaping = true
                }
            case "\"":
                if inSingleQuote {
                    current.append(character)
                } else {
                    inDoubleQuote.toggle()
                }
            case "'":
                if inDoubleQuote {
                    current.append(character)
                } else if inSingleQuote && isLikelyLiteralApostrophe(characters: characters, index: index) {
                    current.append(character)
                } else {
                    inSingleQuote.toggle()
                }
            case " ", "\t", "\n", "\r":
                if inSingleQuote || inDoubleQuote {
                    current.append(character)
                } else if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
            default:
                current.append(character)
            }
        }

        if escaping {
            throw CurlEditorError.trailingEscape
        }
        if inSingleQuote {
            throw CurlEditorError.unterminatedSingleQuote
        }
        if inDoubleQuote {
            throw CurlEditorError.unterminatedDoubleQuote
        }
        if !current.isEmpty {
            tokens.append(current)
        }

        return tokens
    }

    private func isLikelyLiteralApostrophe(characters: [Character], index: Int) -> Bool {
        guard characters[index] == "'" else { return false }
        let previousIndex = index - 1
        let nextIndex = index + 1
        guard characters.indices.contains(previousIndex), characters.indices.contains(nextIndex) else {
            return false
        }
        let previous = characters[previousIndex]
        let next = characters[nextIndex]
        return isLetterOrNumber(previous) && isLetterOrNumber(next)
    }

    private func isLetterOrNumber(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) }
    }

    // MARK: - Parsing helpers

    private func value(after index: inout Int, option: String, tokens: [String]) throws -> String {
        let nextIndex = index + 1
        guard tokens.indices.contains(nextIndex) else {
            throw CurlEditorError.missingValue(option: option)
        }
        index = nextIndex
        return tokens[nextIndex]
    }

    private func parseHeader(_ value: String) -> KeyValueRow? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let separator = trimmed.firstIndex(of: ":") {
            let key = String(trimmed[..<separator]).trimmingCharacters(in: .whitespacesAndNewlines)
            let headerValue = String(trimmed[trimmed.index(after: separator)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { return nil }
            return KeyValueRow(key: key, value: headerValue, isEnabled: true)
        }

        return KeyValueRow(key: trimmed, value: "", isEnabled: true)
    }

    private func parseBasicAuthorization(_ value: String) -> RequestAuthorization {
        let parts = value.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let username = parts.first.map(String.init) ?? ""
        let password = parts.count > 1 ? String(parts[1]) : ""
        return RequestAuthorization(
            type: .basic,
            username: username,
            password: password,
            token: "",
            apiKeyName: "",
            apiKeyValue: "",
            apiKeyPlacement: .header
        )
    }

    private func splitURLAndQuery(_ rawURL: String) -> (baseURL: String, queryItems: [KeyValueRow]) {
        guard let components = URLComponents(string: rawURL) else {
            return (rawURL, [])
        }

        let queryItems = (components.queryItems ?? []).map {
            KeyValueRow(key: $0.name, value: $0.value ?? "", isEnabled: true)
        }

        var baseComponents = components
        baseComponents.query = nil
        baseComponents.percentEncodedQuery = nil
        let baseURL = baseComponents.string ?? rawURL
        return (baseURL, queryItems)
    }

    private func inferredMethod(
        explicitMethod: HTTPMethod?,
        useGetMode: Bool,
        useHeadMode: Bool,
        hasBody: Bool
    ) -> HTTPMethod {
        if let explicitMethod { return explicitMethod }
        if useHeadMode { return .head }
        if useGetMode { return .get }
        return hasBody ? .post : .get
    }

    private func inferBodyType(_ bodyText: String) -> RequestBodyType {
        let trimmed = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .none }
        if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
            return .json
        }
        return .raw
    }

    private func parseQueryItem(_ value: String) -> KeyValueRow {
        if let separator = value.firstIndex(of: "=") {
            let key = String(value[..<separator]).trimmingCharacters(in: .whitespacesAndNewlines)
            let itemValue = String(value[value.index(after: separator)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return KeyValueRow(key: key, value: itemValue, isEnabled: true)
        }
        return KeyValueRow(key: value.trimmingCharacters(in: .whitespacesAndNewlines), value: "", isEnabled: true)
    }
}

// MARK: - Error Types

public enum CurlEditorError: LocalizedError {
    case emptyCommand
    case invalidCommand(reason: String?)
    case missingURL
    case missingValue(option: String)
    case unterminatedSingleQuote
    case unterminatedDoubleQuote
    case trailingEscape

    public var errorDescription: String? {
        switch self {
        case .emptyCommand:
            return "Please enter a cURL command."
        case .invalidCommand(let reason):
            return reason ?? "Unable to parse the cURL command."
        case .missingURL:
            return "The cURL command is missing a URL."
        case .missingValue(let option):
            return "Missing a value for option \(option)."
        case .unterminatedSingleQuote:
            return "There is an unterminated single quote."
        case .unterminatedDoubleQuote:
            return "There is an unterminated double quote."
        case .trailingEscape:
            return "The command ends with an incomplete escape sequence."
        }
    }
}
