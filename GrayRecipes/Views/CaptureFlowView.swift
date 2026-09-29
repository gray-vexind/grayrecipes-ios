import SwiftUI
import VisionKit

struct CaptureFlowView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var model = CaptureViewModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Capture")
                .fullScreenCover(isPresented: scanningBinding) {
                    DocumentScanner(
                        onComplete: { images in model.handleScanned(images: images) },
                        onCancel: { model.cancelScan() }
                    )
                    .ignoresSafeArea()
                }
        }
    }

    private var scanningBinding: Binding<Bool> {
        Binding(
            get: { model.phase == .scanning },
            set: { newValue in if !newValue && model.phase == .scanning { model.cancelScan() } }
        )
    }

    @ViewBuilder
    private var content: some View {
        // Capturing/saving a recipe requires an account, so gate the flow behind
        // "Sign in with Vex" when signed out (website parity: browsing is public,
        // contributing is not).
        if !session.isSignedIn {
            signInGate
        } else {
            phaseContent
        }
    }

    private var signInGate: some View {
        ScrollView {
            VexSignInView(prompt: "Sign in with your Vex account to scan and save recipes to your groups.")
                .padding(.top, 40)
        }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch model.phase {
        case .idle:
            startView
        case .scanning:
            Color.black.ignoresSafeArea() // scanner presented over this
        case .processing:
            processingView
        case .review, .saving:
            RecipeReviewView(model: model)
        case .saved(let id):
            savedView(id: id)
        }
    }

    private var startView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 72))
                .foregroundStyle(Color.brandPrimary)
            VStack(spacing: 8) {
                Text("Scan a Recipe").font(.title2.bold())
                Text("Point your camera at a recipe card, cookbook page, or printout. The edges are detected automatically.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Button {
                if VNDocumentCameraViewController.isSupported {
                    model.startScan()
                } else {
                    model.errorMessage = "Document scanning isn't supported on this device."
                }
            } label: {
                Label("Start Scanning", systemImage: "doc.viewfinder")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.brandPrimary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)
            if let error = model.errorMessage {
                Text(error).font(.footnote).foregroundStyle(.red)
            }
            Spacer()
        }
    }

    private var processingView: some View {
        VStack(spacing: 20) {
            if let image = model.capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary))
            }
            ProgressView()
            Text(model.statusMessage.isEmpty ? "Processing…" : model.statusMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !model.onDeviceLines.isEmpty {
                Text("Detected \(model.onDeviceLines.count) lines on device")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
    }

    private func savedView(id: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
            Text("Recipe Saved!").font(.title2.bold())
            Text("Your recipe has been added to \(model.selectedTenant?.name ?? "your group").")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                model.startScan()
            } label: {
                Label("Scan Another", systemImage: "camera.viewfinder")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.brandPrimary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)
            Button("Done") { model.reset() }
                .padding(.top, 4)
            Spacer()
        }
        .padding()
    }
}

#Preview {
    CaptureFlowView().environmentObject(SessionStore())
}
