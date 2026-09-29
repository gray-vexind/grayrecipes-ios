import SwiftUI

/// Loads an image from an absolute or relative Gray Recipes URL, attaching the
/// bearer token so protected image routes (/api/images) work.
struct RemoteImageView: View {
    let urlString: String?
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var failed = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                ZStack {
                    Rectangle().fill(Color.gray.opacity(0.15))
                    if isLoading {
                        ProgressView()
                    } else {
                        Image(systemName: failed ? "photo.badge.exclamationmark" : "photo")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .task(id: urlString) { await load() }
    }

    private func load() async {
        image = nil
        failed = false
        guard let urlString, !urlString.isEmpty else { return }

        let resolved: URL?
        if urlString.hasPrefix("http") {
            resolved = URL(string: urlString)
        } else {
            resolved = URL(string: urlString, relativeTo: AppConfig.baseURL)?.absoluteURL
        }
        guard let url = resolved else { failed = true; return }

        isLoading = true
        defer { isLoading = false }

        var request = URLRequest(url: url)
        if let token = await APIClient.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let ui = UIImage(data: data) else {
                failed = true
                return
            }
            image = ui
        } catch {
            failed = true
        }
    }
}
