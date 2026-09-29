import SwiftUI

@MainActor
final class CaptureViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case scanning
        case processing      // on-device OCR + server extract running
        case review          // draft ready for editing
        case saving
        case saved(id: String)
    }

    @Published var phase: Phase = .idle
    @Published var draft = RecipeDraft()
    @Published var onDeviceLines: [String] = []
    @Published var capturedImage: UIImage?
    @Published var statusMessage: String = ""
    @Published var errorMessage: String?
    @Published var usedServerExtract = false

    // Group selection for saving
    @Published var tenants: [Tenant] = []
    @Published var selectedTenant: Tenant?

    private var imageData: Data?

    func startScan() {
        reset()
        phase = .scanning
    }

    func reset() {
        phase = .idle
        draft = RecipeDraft()
        onDeviceLines = []
        capturedImage = nil
        statusMessage = ""
        errorMessage = nil
        usedServerExtract = false
        imageData = nil
    }

    /// Called when the document scanner returns pages. We use the first page.
    func handleScanned(images: [UIImage]) {
        guard let first = images.first else {
            phase = .idle
            return
        }
        capturedImage = first
        imageData = first.jpegDataForUpload()
        draft.imageData = imageData
        phase = .processing
        Task { await process(image: first) }
    }

    func cancelScan() {
        if phase == .scanning { phase = .idle }
    }

    private func process(image: UIImage) async {
        // 1. Instant on-device OCR for immediate feedback.
        statusMessage = "Reading text on device…"
        let lines = await OnDeviceOCR.recognizeText(in: image)
        onDeviceLines = lines
        // Pre-fill a draft from the on-device text so the form isn't empty even
        // if the server call is slow or fails.
        draft = mergeDraft(into: draft, from: LocalRecipeParser.parse(lines: lines), image: imageData)

        // 2. Higher-accuracy server extraction (AWS Textract) if we have image data.
        if let data = imageData {
            statusMessage = "Enhancing with server extraction…"
            do {
                let extracted = try await GrayRecipesAPI.extract(imageData: data)
                let serverDraft = RecipeDraft(from: extracted, imageData: imageData)
                draft = mergeDraft(into: draft, from: serverDraft, image: imageData)
                usedServerExtract = true
            } catch {
                // Non-fatal: keep the on-device draft, note the fallback.
                usedServerExtract = false
                statusMessage = "Using on-device text (server extraction unavailable)."
            }
        }

        statusMessage = ""
        phase = .review

        // Kick off tenant loading for the save step if needed.
        if tenants.isEmpty { await loadTenants() }
    }

    /// Prefer non-empty server values, but keep on-device values where the
    /// server returned nothing.
    private func mergeDraft(into base: RecipeDraft, from new: RecipeDraft, image: Data?) -> RecipeDraft {
        var merged = base
        if !new.title.isEmpty && new.title.lowercased() != "untitled recipe" { merged.title = new.title }
        if !new.ingredients.isEmpty { merged.ingredients = new.ingredients }
        if !new.instructions.isEmpty { merged.instructions = new.instructions }
        if !new.servings.isEmpty { merged.servings = new.servings }
        if !new.prepTime.isEmpty { merged.prepTime = new.prepTime }
        if !new.cookTime.isEmpty { merged.cookTime = new.cookTime }
        merged.imageData = image
        return merged
    }

    func loadTenants() async {
        do {
            let list = try await GrayRecipesAPI.tenants()
            tenants = list
            if selectedTenant == nil { selectedTenant = list.first }
        } catch {
            // Group list is best-effort; user can still edit and retry.
        }
    }

    var canSave: Bool {
        !draft.title.trimmingCharacters(in: .whitespaces).isEmpty
            && selectedTenant != nil
            && (phase == .review)
    }

    func save() async {
        guard let tenant = selectedTenant else {
            errorMessage = "Choose a group to save this recipe to."
            return
        }
        phase = .saving
        errorMessage = nil
        do {
            let created = try await GrayRecipesAPI.createRecipe(draft, tenantSlug: tenant.slug)
            phase = .saved(id: created.id)
        } catch let APIError.forbidden(message) {
            errorMessage = message.isEmpty
                ? "You don't have permission to add recipes to \(tenant.name)."
                : message
            phase = .review
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            phase = .review
        }
    }
}
