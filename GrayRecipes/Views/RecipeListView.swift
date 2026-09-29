import SwiftUI

@MainActor
final class RecipeListViewModel: ObservableObject {
    @Published var tenants: [Tenant] = []
    @Published var selectedTenant: Tenant?
    @Published var recipes: [RecipeSummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func loadTenants() async {
        do {
            let list = try await GrayRecipesAPI.tenants()
            tenants = list
            if selectedTenant == nil { selectedTenant = list.first }
            await loadRecipes()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func loadRecipes() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            recipes = try await GrayRecipesAPI.recipes(tenantSlug: selectedTenant?.slug)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

struct RecipeListView: View {
    @StateObject private var model = RecipeListViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if model.isLoading && model.recipes.isEmpty {
                    ProgressView("Loading recipes…")
                } else if let error = model.errorMessage, model.recipes.isEmpty {
                    ContentUnavailableView {
                        Label("Couldn't load recipes", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Retry") { Task { await model.loadRecipes() } }
                    }
                } else if model.recipes.isEmpty {
                    ContentUnavailableView("No recipes yet", systemImage: "book.closed",
                                           description: Text("Capture your first recipe from the Capture tab."))
                } else {
                    recipeList
                }
            }
            .navigationTitle("Recipes")
            .toolbar {
                if !model.tenants.isEmpty {
                    ToolbarItem(placement: .topBarLeading) { groupMenu }
                }
            }
            .task { if model.tenants.isEmpty { await model.loadTenants() } }
            .refreshable { await model.loadRecipes() }
        }
    }

    private var recipeList: some View {
        List(model.recipes) { recipe in
            NavigationLink(value: recipe) {
                RecipeRow(recipe: recipe)
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: RecipeSummary.self) { recipe in
            RecipeDetailView(recipeID: recipe.id)
        }
    }

    private var groupMenu: some View {
        Menu {
            ForEach(model.tenants) { tenant in
                Button {
                    model.selectedTenant = tenant
                    Task { await model.loadRecipes() }
                } label: {
                    if model.selectedTenant?.id == tenant.id {
                        Label(tenant.name, systemImage: "checkmark")
                    } else {
                        Text(tenant.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(model.selectedTenant?.name ?? "All Groups")
                    .lineLimit(1)
                Image(systemName: "chevron.down").font(.caption2)
            }
        }
    }
}

struct RecipeRow: View {
    let recipe: RecipeSummary

    var body: some View {
        HStack(spacing: 12) {
            RemoteImageView(urlString: recipe.imageURL)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.title)
                    .font(.headline)
                    .lineLimit(2)
                if let desc = recipe.description, !desc.isEmpty {
                    Text(desc).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
                HStack(spacing: 10) {
                    if let s = recipe.servings, !s.isEmpty { metaLabel("person.2", s) }
                    if let p = recipe.prepTime, !p.isEmpty { metaLabel("timer", p) }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func metaLabel(_ icon: String, _ text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

#Preview {
    RecipeListView()
}
