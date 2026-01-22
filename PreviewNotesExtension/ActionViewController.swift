import Cocoa
import SwiftUI
import PDFKit
import UniformTypeIdentifiers

/// Main view controller for the Preview Notes action extension
class ActionViewController: NSViewController {
    
    private var hostingView: NSHostingView<ActionView>?
    private var viewModel = NotesViewModel()
    private var documentURL: URL?
    
    override func loadView() {
        // Create the SwiftUI view
        let actionView = ActionView(
            viewModel: viewModel,
            onDone: { [weak self] in
                self?.done()
            }
        )
        
        let hostingView = NSHostingView(rootView: actionView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        
        // Set minimum size for the extension window
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        containerView.addSubview(hostingView)
        
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: containerView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
        ])
        
        self.hostingView = hostingView
        self.view = containerView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadPDFFromExtensionContext()
    }
    
    /// Load PDF from the extension context
    private func loadPDFFromExtensionContext() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments else {
            return
        }
        
        // Look for PDF file
        for attachment in attachments {
            if attachment.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
                loadPDFAttachment(attachment)
                return
            }
            
            // Also check for file URLs
            if attachment.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                loadFileURLAttachment(attachment)
                return
            }
        }
    }
    
    /// Load PDF from item provider
    private func loadPDFAttachment(_ attachment: NSItemProvider) {
        attachment.loadDataRepresentation(forTypeIdentifier: UTType.pdf.identifier) { [weak self] data, error in
            guard let data = data, error == nil else {
                print("Error loading PDF: \(error?.localizedDescription ?? "Unknown")")
                return
            }
            
            DispatchQueue.main.async {
                if let document = PDFDocument(data: data) {
                    self?.viewModel.loadDocument(document)
                }
            }
        }
    }
    
    /// Load PDF from file URL
    private func loadFileURLAttachment(_ attachment: NSItemProvider) {
        attachment.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, error in
            guard error == nil else {
                print("Error loading file URL: \(error?.localizedDescription ?? "Unknown")")
                return
            }
            
            var url: URL?
            
            if let urlData = item as? Data {
                url = URL(dataRepresentation: urlData, relativeTo: nil)
            } else if let itemURL = item as? URL {
                url = itemURL
            }
            
            guard let pdfURL = url else { return }
            
            DispatchQueue.main.async {
                self?.documentURL = pdfURL
                Task {
                    await self?.viewModel.loadDocument(from: pdfURL)
                }
            }
        }
    }
    
    /// Called when user is done with the extension
    func done() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}

