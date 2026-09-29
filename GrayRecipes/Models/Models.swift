import Foundation

// MARK: - Auth

struct AuthUser: Codable, Equatable {
    let sub: String
    let email: String
    let name: String
    let preferredUsername: String

    enum CodingKeys: String, CodingKey {
        case sub, email, name
        case preferredUsername = "preferred_username"
    }
}

/// Response from POST /api/auth/mobile and /refresh.
struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int
    let user: AuthUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case user
    }
}

// MARK: - Tenants (groups)

struct Tenant: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let slug: String
    let description: String?
    // member_count / recipe_count arrive as strings or numbers depending on PG; decode leniently.
    let memberCount: Int?
    let recipeCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, slug, description
        case memberCount = "member_count"
        case recipeCount = "recipe_count"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        slug = try c.decode(String.self, forKey: .slug)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        memberCount = Self.flexibleInt(c, .memberCount)
        recipeCount = Self.flexibleInt(c, .recipeCount)
    }

    private static func flexibleInt(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Int? {
        if let i = try? c.decodeIfPresent(Int.self, forKey: key) { return i }
        if let s = try? c.decodeIfPresent(String.self, forKey: key) { return Int(s) }
        return nil
    }
}

struct TenantsResponse: Codable {
    let tenants: [Tenant]
}

// MARK: - Recipes

struct RecipeSummary: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let description: String?
    let imageURL: String?
    let prepTime: String?
    let cookTime: String?
    let servings: String?
    let tenantName: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description
        case imageURL = "image_url"
        case prepTime = "prep_time"
        case cookTime = "cook_time"
        case servings
        case tenantName = "tenant_name"
    }
}

struct RecipesResponse: Codable {
    let recipes: [RecipeSummary]
}

struct RecipeDetail: Codable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let ingredients: [String]
    let instructions: [String]
    let servings: String?
    let prepTime: String?
    let cookTime: String?
    let imageURL: String?
    let familyStory: String?
    let authorName: String?
    let tenantName: String?
    let tenantSlug: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description, servings
        case ingredients, instructions
        case prepTime = "prep_time"
        case cookTime = "cook_time"
        case imageURL = "image_url"
        case familyStory = "family_story"
        case authorName = "author_name"
        case tenantName = "tenant_name"
        case tenantSlug = "tenant_slug"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        servings = try c.decodeIfPresent(String.self, forKey: .servings)
        prepTime = try c.decodeIfPresent(String.self, forKey: .prepTime)
        cookTime = try c.decodeIfPresent(String.self, forKey: .cookTime)
        imageURL = try c.decodeIfPresent(String.self, forKey: .imageURL)
        familyStory = try c.decodeIfPresent(String.self, forKey: .familyStory)
        authorName = try c.decodeIfPresent(String.self, forKey: .authorName)
        tenantName = try c.decodeIfPresent(String.self, forKey: .tenantName)
        tenantSlug = try c.decodeIfPresent(String.self, forKey: .tenantSlug)
        // ingredients / instructions are stored as JSON in Postgres and may come
        // back either as a JSON array or as a JSON-encoded string.
        ingredients = Self.decodeStringArray(c, .ingredients)
        instructions = Self.decodeStringArray(c, .instructions)
    }

    private static func decodeStringArray(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> [String] {
        if let arr = try? c.decodeIfPresent([String].self, forKey: key) { return arr }
        if let raw = try? c.decodeIfPresent(String.self, forKey: key),
           let data = raw.data(using: .utf8),
           let arr = try? JSONDecoder().decode([String].self, from: data) {
            return arr
        }
        return []
    }
}

struct RecipeDetailResponse: Codable {
    let recipe: RecipeDetail
}

// MARK: - Extract

/// Response from POST /api/extract (server-side Textract parse).
struct ExtractedRecipe: Codable {
    var title: String
    var ingredients: [String]
    var instructions: [String]
    var servings: String
    var prepTime: String
    var cookTime: String
    var rawText: String
    var s3Key: String?

    enum CodingKeys: String, CodingKey {
        case title, ingredients, instructions, servings
        case prepTime = "prep_time"
        case cookTime = "cook_time"
        case rawText = "raw_text"
        case s3Key = "s3_key"
    }
}

/// A draft recipe assembled from capture + extraction, edited before save.
struct RecipeDraft {
    var title: String = ""
    var description: String = ""
    var ingredients: [String] = []
    var instructions: [String] = []
    var servings: String = ""
    var prepTime: String = ""
    var cookTime: String = ""
    var authorName: String = ""
    var imageData: Data?          // captured page image (JPEG)

    init() {}

    init(from extracted: ExtractedRecipe, imageData: Data?) {
        self.title = extracted.title
        self.ingredients = extracted.ingredients
        self.instructions = extracted.instructions
        self.servings = extracted.servings
        self.prepTime = extracted.prepTime
        self.cookTime = extracted.cookTime
        self.imageData = imageData
    }
}
