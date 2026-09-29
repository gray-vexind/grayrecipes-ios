import SwiftUI

@MainActor
final class RecipeDetailViewModel: ObservableObject {
    @Published var recipe: RecipeDetail?
    @Published var isLoading = true
    @Published var errorMessage: String?

    func load(id: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            recipe = try await GrayRecipesAPI.recipe(id: id)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

struct RecipeDetailView: View {
    let recipeID: String
    @StateObject private var model = RecipeDetailViewModel()

    var body: some View {
        Group {
            if model.isLoading {
                ProgressView()
            } else if let recipe = model.recipe {
                content(recipe)
            } else {
                ContentUnavailableView {
                    Label("Recipe unavailable", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(model.errorMessage ?? "Something went wrong.")
                } actions: {
                    Button("Retry") { Task { await model.load(id: recipeID) } }
                }
            }
        }
        .navigationTitle(model.recipe?.title ?? "Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(id: recipeID) }
    }

    private func content(_ recipe: RecipeDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let img = recipe.imageURL, !img.isEmpty {
                    RemoteImageView(urlString: img)
                        .frame(height: 220)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Text(recipe.title).font(.title.bold())

                if let desc = recipe.description, !desc.isEmpty {
                    Text(desc).foregroundStyle(.secondary)
                }

                metaRow(recipe)

                if !recipe.ingredients.isEmpty {
                    section("Ingredients") {
                        ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { _, item in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "circle.fill").font(.system(size: 5)).padding(.top, 7)
                                Text(item)
                            }
                        }
                    }
                }

                if !recipe.instructions.isEmpty {
                    section("Instructions") {
                        ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { idx, step in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(idx + 1)")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.white)
                                    .frame(width: 24, height: 24)
                                    .background(Color.brandPrimary, in: Circle())
                                Text(step)
                            }
                        }
                    }
                }

                if let story = recipe.familyStory, !story.isEmpty {
                    section("Family Story") { Text(story).italic() }
                }
            }
            .padding()
        }
    }

    private func metaRow(_ recipe: RecipeDetail) -> some View {
        HStack(spacing: 20) {
            if let s = recipe.servings, !s.isEmpty { meta("person.2", "Serves", s) }
            if let p = recipe.prepTime, !p.isEmpty { meta("timer", "Prep", p) }
            if let c = recipe.cookTime, !c.isEmpty { meta("flame", "Cook", c) }
        }
    }

    private func meta(_ icon: String, _ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon).foregroundStyle(Color.brandPrimary)
            Text(value).font(.subheadline.bold())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.title3.bold())
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
