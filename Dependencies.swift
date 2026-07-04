import SwiftUI

// MARK: - Color Extension

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Layout Constants

enum AppConst {
    static let defaultPadding: CGFloat = 8
    static let defaultCornerRadius: CGFloat = 6
}

// MARK: - Theme Colors

enum AppTheme {
    static func border(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x575F67) : Color.black.opacity(0.12)
    }

    static func secondaryText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0xDBE4ED) : Color.black.opacity(0.58)
    }

    static func success(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x59D98E) : Color(hex: 0x1F8A57)
    }

    static func error(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0xFF6B6B) : Color(hex: 0xC54141)
    }
}

// MARK: - Request Models (minimal for CurlEditorService)

enum HTTPMethod: String, CaseIterable, Codable, Hashable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
    case head = "HEAD"
    case options = "OPTIONS"
}

struct KeyValueRow: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var key: String
    var value: String
    var isEnabled: Bool

    static var empty: KeyValueRow {
        KeyValueRow(key: "", value: "", isEnabled: true)
    }
}

enum AuthorizationType: String, CaseIterable, Codable, Hashable {
    case none = "None"
    case bearer = "Bearer Token"
    case basic = "Basic Auth"
    case apiKey = "API Key"
}

enum APIKeyPlacement: String, Codable, Hashable {
    case header = "Header"
    case query = "Query"
}

struct RequestAuthorization: Codable, Hashable {
    var type: AuthorizationType
    var username: String
    var password: String
    var token: String
    var apiKeyName: String
    var apiKeyValue: String
    var apiKeyPlacement: APIKeyPlacement

    static var none: RequestAuthorization {
        RequestAuthorization(
            type: .none,
            username: "",
            password: "",
            token: "",
            apiKeyName: "",
            apiKeyValue: "",
            apiKeyPlacement: .header
        )
    }

    init(
        type: AuthorizationType,
        username: String = "",
        password: String = "",
        token: String = "",
        apiKeyName: String = "",
        apiKeyValue: String = "",
        apiKeyPlacement: APIKeyPlacement = .header
    ) {
        self.type = type
        self.username = username
        self.password = password
        self.token = token
        self.apiKeyName = apiKeyName
        self.apiKeyValue = apiKeyValue
        self.apiKeyPlacement = apiKeyPlacement
    }
}

enum RequestBodyType: String, CaseIterable, Codable, Hashable {
    case none = "None"
    case json = "JSON"
    case raw = "Raw"
}

struct MonitorConfiguration: Codable, Hashable {
    var isEnabled: Bool
    var interval: TimeInterval
    var expectedStatusCode: Int?
}
