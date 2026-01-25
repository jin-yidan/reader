import SwiftUI

@main
struct ReaderApp: App {
    @StateObject private var tabsViewModel = TabsViewModel()
    
    var body: some Scene {
        WindowGroup {
            MainContentView(tabsViewModel: tabsViewModel)
                .onOpenURL { url in
                    Task { @MainActor in
                        await tabsViewModel.openDocument(from: url)
                    }
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open PDF...") {
                    openDocument()
                }
                .keyboardShortcut("o", modifiers: .command)
                
                Button("Close Tab") {
                    tabsViewModel.closeCurrentTab()
                }
                .keyboardShortcut("w", modifiers: .command)
                .disabled(!tabsViewModel.hasOpenTabs)
            }
            
            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    tabsViewModel.activeViewModel?.saveDocument()
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(tabsViewModel.activeViewModel == nil)

                Button("Save As...") {
                    tabsViewModel.activeViewModel?.saveDocumentAs()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(tabsViewModel.activeViewModel == nil)

                Divider()

                Button("Export Notes...") {
                    tabsViewModel.activeViewModel?.exportNotes()
                }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(tabsViewModel.activeViewModel?.notes.isEmpty ?? true)
            }
            
            // Find menu
            CommandGroup(after: .pasteboard) {
                Divider()
                Button("Find...") {
                    NotificationCenter.default.post(name: .toggleSearch, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
                .disabled(tabsViewModel.activeViewModel == nil)
            }
            
            CommandGroup(after: .sidebar) {
                Button("Toggle Notes Sidebar") {
                    NotificationCenter.default.post(name: .toggleSidebar, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .option])
            }
            
            CommandMenu("View") {
                Button("Zoom In") {
                    if let viewModel = tabsViewModel.activeViewModel,
                       let nextZoom = NotesViewModel.zoomPresets.first(where: { $0 > viewModel.zoomScale }) {
                        viewModel.zoomScale = nextZoom
                        NotificationCenter.default.post(name: .zoomChanged, object: nextZoom)
                    }
                }
                .keyboardShortcut("+", modifiers: .command)
                .disabled(tabsViewModel.activeViewModel == nil)
                
                Button("Zoom Out") {
                    if let viewModel = tabsViewModel.activeViewModel,
                       let prevZoom = NotesViewModel.zoomPresets.last(where: { $0 < viewModel.zoomScale }) {
                        viewModel.zoomScale = prevZoom
                        NotificationCenter.default.post(name: .zoomChanged, object: prevZoom)
                    }
                }
                .keyboardShortcut("-", modifiers: .command)
                .disabled(tabsViewModel.activeViewModel == nil)
                
                Button("Actual Size") {
                    tabsViewModel.activeViewModel?.zoomScale = 1.0
                    NotificationCenter.default.post(name: .zoomChanged, object: CGFloat(1.0))
                }
                .keyboardShortcut("0", modifiers: .command)
                .disabled(tabsViewModel.activeViewModel == nil)
                
                Divider()
                
                ForEach(NotesViewModel.zoomPresets, id: \.self) { scale in
                    Button("\(Int(scale * 100))%") {
                        tabsViewModel.activeViewModel?.zoomScale = scale
                        NotificationCenter.default.post(name: .zoomChanged, object: scale)
                    }
                    .disabled(tabsViewModel.activeViewModel == nil)
                }
            }
        }
    }
    
    private func openDocument() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            Task { @MainActor in
                await tabsViewModel.openDocument(from: url)
            }
        }
    }
}

extension Notification.Name {
    static let toggleSidebar = Notification.Name("toggleSidebar")
    static let toggleSearch = Notification.Name("toggleSearch")
    static let zoomChanged = Notification.Name("zoomChanged")
}
