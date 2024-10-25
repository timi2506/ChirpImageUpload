import SwiftUI
import PhotosUI
import Alamofire

struct ContentView: View {
    @State private var selectedImage: UIImage?
    @State private var imageURL: String = ""
    @State private var showingPicker = false
    @State private var isUploading = false
    @State private var githubToken: String = ""

    private let githubUsername = "chirpimageupload"
    private let repositoryName = "chirp-post-images"
    
    var body: some View {
        VStack {
            if let selectedImage = selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300, height: 300)
            } else {
                Text("No image selected")
                    .padding()
            }
            
            if !imageURL.isEmpty {
                Text("Uploaded URL:")
                Text(imageURL)
                    .foregroundColor(.blue)
                    .padding()
                    .onTapGesture {
                        UIPasteboard.general.string = imageURL
                    }
            }
            
            if isUploading {
                ProgressView("Uploading...")
                    .padding()
            }
            
            HStack {
                Button("Photo Picker") {
                    showingPicker = true
                }
                .padding()
                
                Button("Import from Clipboard") {
                    importFromClipboard()
                }
                .padding()
            }
            
            if !imageURL.isEmpty {
                Button("Copy to Clipboard") {
                    UIPasteboard.general.string = imageURL
                }
                .padding()
                
                Button("Share") {
                    shareURL()
                }
                .padding()
            }
        }
        .sheet(isPresented: $showingPicker) {
            PhotoPicker(selectedImage: $selectedImage, onImagePicked: uploadImage)
        }
        .onAppear(perform: fetchToken)
    }
    
    func fetchToken() {
        guard let url = URL(string: "https://raw.githubusercontent.com/timi2506/chirp-image-uploadtoken/refs/heads/main/token.txt") else { return }
        
        AF.request(url).responseString { response in
            switch response.result {
            case .success(let token):
                // Combine the prefix with the fetched token
                githubToken = "ghp_" + token.trimmingCharacters(in: .whitespacesAndNewlines)
            case .failure(let error):
                print("Error fetching token: \(error.localizedDescription)")
            }
        }
    }
    
    func importFromClipboard() {
        if let image = UIPasteboard.general.image {
            selectedImage = image
            uploadImage(image: image)
        }
    }
    
    func uploadImage(image: UIImage) {
        guard let imgData = image.jpegData(compressionQuality: 0.7) else { return }
        isUploading = true
        
        let targetFileName = "image-\(UUID().uuidString).jpg"
        let url = "https://api.github.com/repos/\(githubUsername)/\(repositoryName)/contents/\(targetFileName)"
        
        let headers: HTTPHeaders = [
            "Authorization": "token \(githubToken)", // Use the token directly
            "Accept": "application/vnd.github.v3+json"
        ]
        
        let parameters: [String: Any] = [
            "message": "Upload \(targetFileName)",
            "content": imgData.base64EncodedString() // Base64 encode the image data for upload
        ]
        
        AF.request(url, method: .put, parameters: parameters, encoding: JSONEncoding.default, headers: headers).responseJSON { response in
            isUploading = false
            if let data = response.data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let content = json["content"] as? [String: Any],
               let downloadUrl = content["download_url"] as? String {
                imageURL = downloadUrl
            } else {
                print("Error uploading file: \(response.error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    func shareURL() {
        let activityController = UIActivityViewController(activityItems: [imageURL], applicationActivities: nil)
        UIApplication.shared.windows.first?.rootViewController?.present(activityController, animated: true, completion: nil)
    }
}

struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    var onImagePicked: (UIImage) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker

        init(_ parent: PhotoPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }

            provider.loadObject(ofClass: UIImage.self) { (image, error) in
                DispatchQueue.main.async {
                    if let image = image as? UIImage {
                        self.parent.selectedImage = image
                        self.parent.onImagePicked(image)
                    }
                }
            }
        }
    }
}
