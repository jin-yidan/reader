import SwiftUI

/// Tab bar for managing multiple open documents - tabs evenly divide available width
public struct TabBarView: View {
    @ObservedObject var tabsViewModel: TabsViewModel

    public init(tabsViewModel: TabsViewModel) {
        self.tabsViewModel = tabsViewModel
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(tabsViewModel.tabs) { tab in
                TabItemView(
                    tab: tab,
                    isActive: tabsViewModel.activeTabId == tab.id,
                    hasUnsavedChanges: tabsViewModel.hasUnsavedChanges(for: tab),
                    onSelect: {
                        tabsViewModel.selectTab(tab)
                    },
                    onClose: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            tabsViewModel.closeTab(tab)
                        }
                    },
                    onRename: { newName in
                        tabsViewModel.renameDocument(tab: tab, to: newName)
                    }
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.9)),
                    removal: .opacity.combined(with: .scale(scale: 0.9))
                ))
            }
        }
        .frame(height: 36)
        .background(Color(nsColor: .windowBackgroundColor))
        .animation(.easeInOut(duration: 0.2), value: tabsViewModel.tabs.count)
    }
}

/// Individual tab item with double-click to rename
struct TabItemView: View {
    let tab: DocumentTab
    let isActive: Bool
    let hasUnsavedChanges: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let onRename: (String) -> Void

    @State private var isHovering = false
    @State private var isEditing = false
    @State private var editingName = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        ZStack {
            // Background
            tabBackground

            // Content
            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 12))
                    .foregroundColor(isActive ? .accentColor : .secondary)

                if isEditing {
                    // Editable text field
                    TextField("", text: $editingName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: isActive ? .medium : .regular))
                        .foregroundColor(.primary)
                        .focused($isTextFieldFocused)
                        .onSubmit {
                            commitRename()
                        }
                        .onExitCommand {
                            cancelRename()
                        }
                } else {
                    // Display title with unsaved indicator
                    HStack(spacing: 4) {
                        if hasUnsavedChanges {
                            Circle()
                                .fill(Color.primary.opacity(0.6))
                                .frame(width: 6, height: 6)
                        }
                        Text(tab.title)
                            .font(.system(size: 12, weight: isActive ? .medium : .regular))
                            .foregroundColor(isActive ? .primary : .secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                Spacer(minLength: 4)

                // Close button
                closeButton
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity)
        .overlay(tabBorder)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            startEditing()
        }
        .onTapGesture(count: 1) {
            if !isEditing {
                onSelect()
            }
        }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
        .onChange(of: isTextFieldFocused) { focused in
            if !focused && isEditing {
                commitRename()
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isActive)
        .animation(.easeInOut(duration: 0.1), value: hasUnsavedChanges)
    }

    private var closeButton: some View {
        Image(systemName: "xmark")
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(.secondary.opacity(0.7))
            .frame(width: 18, height: 18)
            .background(
                Circle()
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .opacity(isHovering ? 1 : 0)
            )
            .opacity(isHovering || isActive ? 1 : 0.3)
            .onTapGesture {
                onClose()
            }
            .accessibilityLabel("Close tab")
    }

    private var tabBackground: some View {
        Rectangle()
            .fill(isActive ? Color(nsColor: .controlBackgroundColor) : Color.clear)
    }

    private var tabBorder: some View {
        VStack {
            Spacer()
            if isActive {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(height: 2)
            }
        }
    }

    private func startEditing() {
        // Extract just the filename without extension
        let filename = tab.url?.deletingPathExtension().lastPathComponent ?? tab.title
        editingName = filename
        isEditing = true
        isTextFieldFocused = true
    }

    private func commitRename() {
        let trimmedName = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty && trimmedName != tab.title {
            onRename(trimmedName)
        }
        isEditing = false
    }

    private func cancelRename() {
        isEditing = false
    }
}

// MARK: - Preview

#if DEBUG
struct TabBarView_Previews: PreviewProvider {
    static var previews: some View {
        TabBarView(tabsViewModel: TabsViewModel())
            .frame(width: 600)
    }
}
#endif
