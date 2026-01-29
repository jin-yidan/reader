import SwiftUI
import UniformTypeIdentifiers

/// Tab bar for managing multiple open documents - tabs evenly divide available width
public struct TabBarView: View {
    @ObservedObject var tabsViewModel: TabsViewModel
    @State private var draggingTab: DocumentTab?

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
                    onRename: {
                        tabsViewModel.renameDocument(tab: tab)
                    },
                    onSaveTo: {
                        tabsViewModel.saveDocumentAs(tab: tab)
                    }
                )
                .opacity(draggingTab?.id == tab.id ? 0.5 : 1.0)
                .onDrag {
                    draggingTab = tab
                    return NSItemProvider(object: tab.id.uuidString as NSString)
                }
                .onDrop(of: [UTType.text], delegate: TabDropDelegate(
                    tab: tab,
                    tabs: $tabsViewModel.tabs,
                    draggingTab: $draggingTab
                ))
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.9)),
                    removal: .opacity.combined(with: .scale(scale: 0.9))
                ))
            }
        }
        .frame(height: 36)
        .background(Color(nsColor: .windowBackgroundColor))
        .animation(.easeInOut(duration: 0.2), value: tabsViewModel.tabs.count)
        .animation(.easeInOut(duration: 0.15), value: tabsViewModel.tabs.map { $0.id })
    }
}

/// Drop delegate for tab reordering
struct TabDropDelegate: DropDelegate {
    let tab: DocumentTab
    @Binding var tabs: [DocumentTab]
    @Binding var draggingTab: DocumentTab?

    func performDrop(info: DropInfo) -> Bool {
        draggingTab = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let dragging = draggingTab,
              dragging.id != tab.id,
              let fromIndex = tabs.firstIndex(where: { $0.id == dragging.id }),
              let toIndex = tabs.firstIndex(where: { $0.id == tab.id }) else {
            return
        }

        withAnimation(.easeInOut(duration: 0.15)) {
            tabs.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

/// Individual tab item with right-click context menu for rename/save
struct TabItemView: View {
    let tab: DocumentTab
    let isActive: Bool
    let hasUnsavedChanges: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let onRename: () -> Void
    let onSaveTo: () -> Void

    @State private var isHovering = false

    var body: some View {
        ZStack {
            // Background
            tabBackground

            // Content
            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 12))
                    .foregroundColor(isActive ? .accentColor : .secondary)

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
        .onTapGesture {
            onSelect()
        }
        .contextMenu {
            Button {
                onRename()
            } label: {
                Label("Rename...", systemImage: "pencil")
            }

            Button {
                onSaveTo()
            } label: {
                Label("Save to...", systemImage: "square.and.arrow.down")
            }

            Divider()

            Button(role: .destructive) {
                onClose()
            } label: {
                Label("Close", systemImage: "xmark")
            }
        }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isActive)
        .animation(.easeInOut(duration: 0.1), value: hasUnsavedChanges)
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .buttonStyle(.plain)
        .frame(width: 24, height: 24)
        .contentShape(Rectangle())
        .background(
            Circle()
                .fill(Color(nsColor: .controlBackgroundColor))
                .opacity(isHovering ? 1 : 0)
                .frame(width: 18, height: 18)
        )
        .opacity(isHovering || isActive ? 1 : 0.3)
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
