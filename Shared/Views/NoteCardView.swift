import SwiftUI
import PDFKit

/// Minimalist note card with clean typography
public struct NoteCardView: View {
    let note: NoteAnnotation
    let isSelected: Bool
    let isEditing: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var editText: String = ""
    @State private var isHovering = false
    @State private var showCopied = false

    public init(
        note: NoteAnnotation,
        isSelected: Bool = false,
        isEditing: Bool = false,
        onTap: @escaping () -> Void,
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onSave: @escaping (String) -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        self.note = note
        self.isSelected = isSelected
        self.isEditing = isEditing
        self.onTap = onTap
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onSave = onSave
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Highlighted text with quote styling
            quoteSection

            // Note content or editor
            if isEditing {
                editorSection
            } else if !note.noteText.isEmpty {
                noteSection
            } else {
                addNotePrompt
            }
        }
        .padding(16)
        .padding(.bottom, 4)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(selectionBorder)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
        .onTapGesture { if !isEditing { onTap() } }
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit Note", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .onChange(of: isEditing) { editing in
            if editing {
                editText = note.noteText
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .animation(.easeInOut(duration: 0.15), value: isEditing)
    }

    // MARK: - Quote Section

    private var quoteSection: some View {
        HStack(alignment: .top, spacing: 12) {
            // Accent bar
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color(nsColor: note.highlightColor))
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 8) {
                // Quoted text
                Text("\"\(note.highlightedText)\"")
                    .font(.system(size: 13.5, weight: .regular, design: .serif))
                    .foregroundColor(.primary.opacity(0.8))
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)

                // Copy button (shows on hover)
                if isHovering || showCopied {
                    Button(action: copyHighlightedText) {
                        HStack(spacing: 4) {
                            Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 10))
                            Text(showCopied ? "Copied" : "Copy")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(showCopied ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
        }
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .animation(.easeOut(duration: 0.15), value: showCopied)
    }

    private func copyHighlightedText() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(note.highlightedText, forType: .string)
        showCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showCopied = false
        }
    }

    // MARK: - Note Section

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .padding(.vertical, 14)

            Text(note.noteText)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.primary.opacity(0.9))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 8)
        }
    }

    // MARK: - Add Note Prompt

    private var addNotePrompt: some View {
        Text("Right-click to add note...")
            .font(.system(size: 12, weight: .regular))
            .foregroundColor(.secondary.opacity(0.4))
            .padding(.top, 12)
            .opacity(isHovering || isSelected ? 1 : 0)
            .animation(.easeOut(duration: 0.15), value: isHovering)
    }

    // MARK: - Editor Section

    private var editorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .padding(.top, 14)

            TextField("Add your note...", text: $editText)
                .font(.system(size: 13))
                .textFieldStyle(.plain)

            HStack {
                Spacer()

                Button("Cancel") {
                    withAnimation(.easeOut(duration: 0.15)) {
                        onCancel()
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])

                Button("Save") {
                    saveAndClose()
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.accentColor)
                .buttonStyle(.plain)
                .padding(.leading, 12)
            }
            .padding(.bottom, 4)
        }
    }

    private func saveAndClose() {
        withAnimation(.easeOut(duration: 0.15)) {
            onSave(editText)
        }
    }

    // MARK: - Background & Border

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(isSelected
                ? Color(nsColor: .controlBackgroundColor)
                : Color(nsColor: .windowBackgroundColor))
    }

    private var selectionBorder: some View {
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(
                isSelected ? Color.accentColor.opacity(0.4) : Color.clear,
                lineWidth: 1.5
            )
    }
}


// MARK: - Preview

#if DEBUG
struct NoteCardView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            NoteCardView(
                note: NoteAnnotation(
                    highlightedText: "The most profound technologies are those that disappear.",
                    noteText: "This reminds me of Mark Weiser's vision.",
                    pageIndex: 2,
                    bounds: .zero
                ),
                isSelected: true,
                onTap: {},
                onEdit: {},
                onDelete: {},
                onSave: { _ in }
            )

            NoteCardView(
                note: NoteAnnotation(
                    highlightedText: "Design is how it works.",
                    noteText: "",
                    pageIndex: 4,
                    bounds: .zero,
                    highlightColor: .systemPink
                ),
                isSelected: false,
                onTap: {},
                onEdit: {},
                onDelete: {},
                onSave: { _ in }
            )
        }
        .padding(20)
        .frame(width: 320)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
#endif
