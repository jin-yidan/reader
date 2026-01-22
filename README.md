# Reader

A PDF reader for macOS with highlighting, notes, and English-to-Chinese translation.

![Reader Screenshot](screenshot.png)

## Technical Highlights

### Translation with Domain-Specific Glossary

The app uses Apple's Translation framework (macOS 15.0+) with a two-stage glossary system:

- **Built-in glossary**: ~400 ML/AI/Math/CS terms with correct Chinese translations (e.g., "transformer" → "Transformer" not "变压器", "gradient descent" → "梯度下降")
- **Custom glossary**: Users can add their own term mappings, stored in UserDefaults
- **Mistranslation correction**: Common wrong translations are detected and replaced (e.g., "token" often becomes "令牌" instead of "词元")

Translation flow:
1. Custom terms are replaced with placeholders before translation
2. Apple Translation API processes the text
3. Placeholders are restored with correct Chinese
4. Built-in mistranslation corrections are applied

### Multi-line Highlight Grouping

PDF highlight annotations are rectangular, so multi-line selections need special handling:

- Each line becomes a separate PDF annotation
- All annotations share a Group ID (stored in `/PreviewNotesGroupID` annotation key)
- The sidebar shows one note entry for the entire selection
- Deleting removes all linked annotations together

### Architecture

- SwiftUI views with `NSViewRepresentable` wrapping PDFKit's `PDFView`
- MVVM with `NotesViewModel` managing document state
- Annotations stored directly in PDF files (standard format, compatible with other readers)
- 30-second autosave with `NSFileCoordinator` for safe writes
- Security-scoped resource access for sandboxed file operations

## What It Does

- Open and read PDF files
- Highlight text in 5 colors (yellow, pink, blue, green, orange)
- Add notes to your highlights
- Translate selected English text to Chinese
- Open multiple PDFs in tabs

## Requirements

- macOS 15.0 (Sequoia) or later (for translation feature)
- macOS 13.0 (Ventura) minimum for basic features
- Xcode 15.0 or later to build from source

## How to Build

1. Open `PreviewNotes.xcodeproj` in Xcode
2. Select the "PreviewNotes" scheme
3. Press ⌘R to build and run

## How to Use

### Opening Files

- Click the folder icon or press ⌘O to open a PDF
- Each file opens in its own tab
- Click the X on a tab to close it
- A dot appears next to the tab name when there are unsaved changes

### Highlighting Text

1. Select text by clicking and dragging
2. Right-click to see the context menu
3. Click "Highlight" to highlight with the current color
4. Or click a color name (Yellow, Pink, Blue, Green, Orange) to highlight with that color

### Removing Highlights

Right-click on any highlight and select "Remove Highlight"

### Adding Notes

1. Click on a highlight in the PDF
2. The sidebar will show the note editor
3. Type your note
4. Click Save or Cancel

### Translation

1. Select English text in the PDF
2. Right-click and choose "Translate"
3. A popup shows the Chinese translation
4. Click "Copy" to copy the translation

**Note:** Translation requires macOS 15.0+ and the Chinese language pack installed in System Settings → General → Language & Region.

### Custom Glossary

If you want specific terms translated a certain way:

1. Select the English term
2. Right-click and choose "Add to Glossary"
3. Enter the Chinese translation you want
4. Click Save

The app includes a built-in glossary of 400+ ML/AI/Math/Coding terms with their standard Chinese translations.

### Searching

1. Type in the search box at the top of the sidebar
2. Use the up/down arrows to navigate between results
3. Click X to clear the search

### Zooming

- Click the + and - buttons in the toolbar
- Or use ⌘+ to zoom in, ⌘- to zoom out
- ⌘0 resets to 100%

Available zoom levels: 50%, 75%, 100%, 125%, 150%, 200%

### Saving

- Press ⌘S to save
- Press ⇧⌘S to save as a new file
- The app also auto-saves every 30 seconds if there are changes

### Page Thumbnails

Click the collapsed bar on the left side of the PDF to expand page thumbnails. Click a thumbnail to jump to that page.

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Open | ⌘O |
| Save | ⌘S |
| Save As | ⇧⌘S |
| Close Tab | ⌘W |
| Find | ⌘F |
| Zoom In | ⌘+ |
| Zoom Out | ⌘- |
| Actual Size | ⌘0 |
| Toggle Sidebar | ⌥⌘N |

## Known Limitations

- Translation only works on macOS 15.0+
- Translation requires downloading the Chinese language pack from Apple
- The app saves annotations directly into the PDF file, which may not be compatible with all PDF readers

## License

MIT License
