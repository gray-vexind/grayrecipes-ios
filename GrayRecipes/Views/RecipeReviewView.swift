import SwiftUI

/// Editable review form for a captured recipe draft. Lets the user fix the
/// extracted text, choose a group, and save.
struct RecipeReviewView: View {
    @ObservedObject var model: CaptureViewModel

    var body: some View {
        Form {
            if let image = model.capturedImage {
                Section {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 180)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            Section("Extraction") {
                Label(
                    model.usedServerExtract ? "Enhanced by server (Textract)" : "On-device text",
                    systemImage: model.usedServerExtract ? "sparkles" : "iphone"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Section("Details") {
                TextField("Title", text: $model.draft.title)
                TextField("Description", text: $model.draft.description, axis: .vertical)
                    .lineLimit(1...3)
                TextField("Author (optional)", text: $model.draft.authorName)
                HStack {
                    TextField("Servings", text: $model.draft.servings)
                    Divider()
                    TextField("Prep", text: $model.draft.prepTime)
                    Divider()
                    TextField("Cook", text: $model.draft.cookTime)
                }
                .font(.callout)
            }

            EditableListSection(title: "Ingredients", placeholder: "Add ingredient", items: $model.draft.ingredients)
            EditableListSection(title: "Instructions", placeholder: "Add step", items: $model.draft.instructions, numbered: true)

            Section("Save to Group") {
                if model.tenants.isEmpty {
                    HStack {
                        Text("Loading groups…").foregroundStyle(.secondary)
                        Spacer()
                        ProgressView()
                    }
                } else {
                    Picker("Group", selection: $model.selectedTenant) {
                        ForEach(model.tenants) { tenant in
                            Text(tenant.name).tag(Optional(tenant))
                        }
                    }
                }
            }

            if let error = model.errorMessage {
                Section {
                    Text(error).foregroundStyle(.red).font(.footnote)
                }
            }

            Section {
                Button {
                    Task { await model.save() }
                } label: {
                    HStack {
                        if model.phase == .saving { ProgressView().tint(.white) }
                        Text(model.phase == .saving ? "Saving…" : "Save Recipe")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(!model.canSave)
                .listRowBackground(model.canSave ? Color.brandPrimary : Color.gray.opacity(0.4))
                .foregroundStyle(.white)

                Button("Discard", role: .destructive) { model.reset() }
                    .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A form section for editing a list of strings (ingredients or steps).
struct EditableListSection: View {
    let title: String
    let placeholder: String
    @Binding var items: [String]
    var numbered: Bool = false

    @State private var newItem = ""

    var body: some View {
        Section(title) {
            ForEach(items.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: 8) {
                    if numbered {
                        Text("\(index + 1).").foregroundStyle(.secondary).monospacedDigit()
                    }
                    TextField("", text: $items[index], axis: .vertical)
                }
            }
            .onDelete { items.remove(atOffsets: $0) }
            .onMove { items.move(fromOffsets: $0, toOffset: $1) }

            HStack {
                TextField(placeholder, text: $newItem, axis: .vertical)
                Button {
                    let trimmed = newItem.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    items.append(trimmed)
                    newItem = ""
                } label: {
                    Image(systemName: "plus.circle.fill").foregroundStyle(Color.brandPrimary)
                }
                .disabled(newItem.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}
