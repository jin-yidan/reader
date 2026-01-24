import Foundation
import PDFKit
import Combine
import AppKit

/// ViewModel managing multiple document tabs
@MainActor
public class TabsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public private(set) var tabs: [DocumentTab] = []
    @Published public var activeTabId: UUID?
    @Published private var viewModels: [UUID: NotesViewModel] = [:]
    
    // MARK: - Computed Properties
    
    public var activeTab: DocumentTab? {
        guard let id = activeTabId else { return nil }
        return tabs.first { $0.id == id }
    }
    
    public var activeViewModel: NotesViewModel? {
        guard let id = activeTabId else { return nil }
        return viewModels[id]
    }
    
    public var hasOpenTabs: Bool {
        !tabs.isEmpty
    }
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Tab Management
    
    /// Open a new document in a new tab
    public func openDocument(from url: URL) async {
        // Check if document is already open
        if let existingTab = tabs.first(where: { $0.url == url }) {
            activeTabId = existingTab.id
            return
        }
        
        // Create new tab
        let tab = DocumentTab(url: url)
        let viewModel = NotesViewModel()
        
        // Load the document
        await viewModel.loadDocument(from: url)
        
        // Add to state
        tabs.append(tab)
        viewModels[tab.id] = viewModel
        activeTabId = tab.id
    }
    
    /// Close a tab
    public func closeTab(_ tab: DocumentTab) {
        // Save before closing
        viewModels[tab.id]?.saveDocument()
        
        // Remove from state
        tabs.removeAll { $0.id == tab.id }
        viewModels.removeValue(forKey: tab.id)
        
        // Select another tab if needed
        if activeTabId == tab.id {
            activeTabId = tabs.last?.id
        }
    }
    
    /// Close current tab
    public func closeCurrentTab() {
        guard let tab = activeTab else { return }
        closeTab(tab)
    }
    
    /// Switch to a tab
    public func selectTab(_ tab: DocumentTab) {
        activeTabId = tab.id
    }
    
    /// Get view model for a specific tab
    public func viewModel(for tab: DocumentTab) -> NotesViewModel? {
        return viewModels[tab.id]
    }

    /// Check if a tab has unsaved changes
    public func hasUnsavedChanges(for tab: DocumentTab) -> Bool {
        return viewModels[tab.id]?.hasUnsavedChanges ?? false
    }
    
    /// Save all open documents
    public func saveAll() {
        for viewModel in viewModels.values {
            viewModel.saveDocument()
        }
    }

    /// Rename a document using NSSavePanel for sandbox compatibility
    public func renameDocument(tab: DocumentTab, to newName: String) {
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }),
              let viewModel = viewModels[tab.id],
              let currentURL = viewModel.getDocumentURL() else {
            return
        }

        // Sanitize the new name
        let sanitizedName = newName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: ":", with: "-")

        guard !sanitizedName.isEmpty else { return }

        // Show NSSavePanel for sandbox-compatible rename
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.nameFieldStringValue = sanitizedName + ".pdf"
        savePanel.directoryURL = currentURL.deletingLastPathComponent()
        savePanel.title = "Rename Document"
        savePanel.prompt = "Rename"

        if savePanel.runModal() == .OK, let newURL = savePanel.url {
            // Save to new location
            if viewModel.saveDocumentAs(to: newURL) {
                // Delete old file if it's different
                if newURL != currentURL {
                    try? FileManager.default.removeItem(at: currentURL)
                }

                // Update tab
                var updatedTab = tabs[index]
                updatedTab.updateAfterRename(newURL: newURL)
                tabs[index] = updatedTab
            }
        }
    }
}

