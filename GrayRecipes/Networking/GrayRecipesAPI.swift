import Foundation

/// Typed endpoint wrappers over `APIClient`.
enum GrayRecipesAPI {
    // MARK: Auth

    struct LoginBody: Encodable {
        let email: String
        let password: String
    }

    static func login(email: String, password: String) async throws -> TokenResponse {
        do {
            return try await APIClient.shared.postJSON(
                "api/auth/mobile",
                body: LoginBody(email: email, password: password),
                authenticated: false
            )
        } catch let APIError.server(status, message) where status == 401 || message == "invalid_credentials" {
            throw APIError.invalidCredentials
        } catch APIError.unauthorized {
            throw APIError.invalidCredentials
        }
    }

    struct ExchangeBody: Encodable {
        let code: String
        let codeVerifier: String
        let redirectUri: String

        enum CodingKeys: String, CodingKey {
            case code
            case codeVerifier = "code_verifier"
            case redirectUri = "redirect_uri"
        }
    }

    /// Complete "Sign in with Vex": exchange an OAuth authorization code (PKCE)
    /// for mobile tokens via the backend. This is the preferred sign-in path.
    static func exchange(code: String, codeVerifier: String, redirectUri: String) async throws -> TokenResponse {
        do {
            return try await APIClient.shared.postJSON(
                "api/auth/mobile/exchange",
                body: ExchangeBody(code: code, codeVerifier: codeVerifier, redirectUri: redirectUri),
                authenticated: false
            )
        } catch let APIError.server(status, _) where status == 401 {
            throw APIError.invalidCredentials
        } catch APIError.unauthorized {
            throw APIError.invalidCredentials
        }
    }

    static func me() async throws -> AuthUser {
        try await APIClient.shared.get("api/auth/mobile/me")
    }

    // MARK: Tenants

    static func tenants() async throws -> [Tenant] {
        let resp: TenantsResponse = try await APIClient.shared.get("api/tenants", authenticated: false)
        return resp.tenants
    }

    // MARK: Recipes

    static func recipes(tenantSlug: String?, limit: Int = 50) async throws -> [RecipeSummary] {
        var query = [URLQueryItem(name: "limit", value: String(limit))]
        if let slug = tenantSlug { query.append(URLQueryItem(name: "tenant", value: slug)) }
        let resp: RecipesResponse = try await APIClient.shared.get("api/recipes", query: query)
        return resp.recipes
    }

    static func recipe(id: String) async throws -> RecipeDetail {
        let resp: RecipeDetailResponse = try await APIClient.shared.get("api/recipes/\(id)")
        return resp.recipe
    }

    // MARK: Extract

    static func extract(imageData: Data, filename: String = "capture.jpg") async throws -> ExtractedRecipe {
        let file = MultipartFile(field: "file", filename: filename, mimeType: "image/jpeg", data: imageData)
        return try await APIClient.shared.postMultipart(
            "api/extract",
            fields: [:],
            files: [file],
            authenticated: false,
            timeout: AppConfig.extractTimeout
        )
    }

    // MARK: Create recipe

    struct CreatedRecipe: Decodable {
        let id: String
        let message: String?
    }

    static func createRecipe(_ draft: RecipeDraft, tenantSlug: String) async throws -> CreatedRecipe {
        var fields: [String: String] = [
            "title": draft.title,
            "description": draft.description,
            "servings": draft.servings,
            "prep_time": draft.prepTime,
            "cook_time": draft.cookTime,
            "tenant_slug": tenantSlug,
            "author_name": draft.authorName,
            "image_tag": "recipe",
            "ingredients": encodeJSONArray(draft.ingredients),
            "instructions": encodeJSONArray(draft.instructions),
        ]
        // family_story is optional; send empty to keep parity with web.
        fields["family_story"] = ""

        var files: [MultipartFile] = []
        if let image = draft.imageData {
            files.append(MultipartFile(field: "uploaded", filename: "recipe.jpg", mimeType: "image/jpeg", data: image))
        }
        return try await APIClient.shared.postMultipart(
            "api/recipes",
            fields: fields,
            files: files,
            authenticated: true
        )
    }

    private static func encodeJSONArray(_ array: [String]) -> String {
        let cleaned = array.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard let data = try? JSONEncoder().encode(cleaned),
              let str = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return str
    }
}
