import SwiftUI

@main
struct ReaderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var tabsViewModel = TabsViewModel()
    @State private var hasOpenedDocument = false

    var body: some Scene {
        WindowGroup {
            MainContentView(tabsViewModel: tabsViewModel)
                .handlesExternalEvents(preferring: Set(["*"]), allowing: Set(["*"]))
                .onOpenURL { url in
                    Task { @MainActor in
                        await tabsViewModel.openDocument(from: url)
                        hasOpenedDocument = true
                        closeDuplicateWindows()
                    }
                }
                .onAppear {
                    appDelegate.tabsViewModel = tabsViewModel

                    // Close duplicate windows - only allow one window
                    closeDuplicateWindows()

                    // Hide window and show file picker on launch
                    // Use a small delay to allow .onOpenURL to fire first when app is launched by opening a file
                    if !tabsViewModel.hasOpenTabs {
                        if let window = NSApplication.shared.windows.first {
                            window.orderOut(nil)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            // Check again - .onOpenURL may have opened a document
                            if !tabsViewModel.hasOpenTabs && !hasOpenedDocument {
                                self.openDocumentOrQuit()
                            } else if let window = NSApplication.shared.windows.first {
                                // Document was opened via .onOpenURL, show the window
                                window.makeKeyAndOrderFront(nil)
                            }
                        }
                    }
                }
                .onChange(of: tabsViewModel.tabs.count) { count in
                    // Quit app when all tabs are closed (but only after having opened something)
                    if count == 0 && hasOpenedDocument {
                        NSApplication.shared.terminate(nil)
                    }
                }
        }
        .handlesExternalEvents(matching: Set(["*"]))
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

    private func openDocumentOrQuit() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            Task { @MainActor in
                await tabsViewModel.openDocument(from: url)
                hasOpenedDocument = true
                // Show window after document is loaded
                if let window = NSApplication.shared.windows.first {
                    window.makeKeyAndOrderFront(nil)
                }
                closeDuplicateWindows()
            }
        } else {
            // User cancelled - quit the app
            NSApplication.shared.terminate(nil)
        }
    }

    private func closeDuplicateWindows() {
        let windows = NSApplication.shared.windows.filter { window in
            // Filter to only app windows (not panels, sheets, etc.)
            window.className == "SwiftUI.SwiftUIWindow" ||
            window.className.contains("AppKitWindow")
        }
        guard windows.count > 1 else { return }

        // Keep only the first window, close the rest
        for window in windows.dropFirst() {
            window.close()
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var tabsViewModel: TabsViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Disable "New Window" menu item if it exists
        DispatchQueue.main.async {
            if let windowMenu = NSApplication.shared.mainMenu?.item(withTitle: "Window")?.submenu {
                windowMenu.items.removeAll { $0.title == "New Window" }
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // When user clicks dock icon with no visible windows, show the main window
        if !flag {
            if let window = sender.windows.first {
                window.makeKeyAndOrderFront(nil)
            }
        }
        return true
    }
}

extension Notification.Name {
    static let toggleSidebar = Notification.Name("toggleSidebar")
    static let toggleSearch = Notification.Name("toggleSearch")
    static let zoomChanged = Notification.Name("zoomChanged")
}
