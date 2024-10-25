import SwiftUI
import PhotosUI
import Alamofire

struct ContentView: View {
    @State private var selectedImage: UIImage?
    @State private var imageURL: String = ""
    @State private var showingPicker = false
    @State private var isUploading = false
    
    // GitHub repository details
    private let githubUsername = "chirpimageupload"
    private let repositoryName = "chirp-post-images"
    private let githubToken = "Z2hwXjlBQ3Z6U3dNRGxqU3JYRFd0Tk1hYldSRG5IM3Z3eUpXcHdkbGx2ZzN2c29yZW1nbGV1bVh3PQ==" 
    
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
        
        // Encode image data in Base64
        let base64Content = imgData.base64EncodedString()
        
        // GitHub API URL
        let targetFileName = "image-\(UUID().uuidString).jpg"
        let url = "https://api.github.com/repos/\(githubUsername)/\(repositoryName)/contents/\(targetFileName)"
        
        // Request headers
        let headers: HTTPHeaders = [
            "Authorization": "Basic \(githubToken)",
            "Accept": "application/vnd.github.v3+json"
        ]
        
        // Request body
        let parameters: [String: Any] = [
            "message": "Upload \(targetFileName)",
            "content": base64Content
        ]
        
        // Send the PUT request
        AF.request(url, method: .put, parameters: parameters, encoding: JSONEncoding.default, headers: headers).responseJSON { response in
            isUploading = false
            if let data = response.data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let content = json["content"] as? [String: Any],
               let downloadUrl = content["download_url"] as? String {
                imageURL = downloadUrl // Update the UI with the direct URL to the uploaded image
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
