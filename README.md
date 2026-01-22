# Reader

A minimalist PDF reader for macOS with built-in highlighting, note-taking, and search capabilities.

## Features

- **Multi-tab support** - Open multiple PDFs in evenly-sized tabs
- **Search** - Find text within the document (⌘F)
- **Highlight text** - Select text and click Highlight (multiple colors available)
- **Add notes to highlights** - Click on any highlight to add a note
- **View notes in sidebar** - All notes organized by page number
- **Click note to jump to highlight** - Navigate directly to annotated passages
- **Edit/delete notes** - Hover to show delete button, double-click to edit
- **Right-click to remove** - Right-click any highlight to remove it
- **Zoom controls** - 50%, 75%, 100%, 125%, 150%, 200%
- **Auto-save** - Changes are saved automatically
- **Notes saved in PDF** - Notes are stored directly in the PDF file

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later (for building)

## Building the Project

### Using Xcode

1. Open `PreviewNotes.xcodeproj` in Xcode
2. Select the "PreviewNotes" scheme
3. Build and run (⌘R)

## Usage

### Opening PDFs

1. Launch **Reader**
2. Click the **folder icon** or press **⌘O**
3. Each PDF opens in a **new tab**
4. Tabs are evenly sized across the window
5. Click **×** on a tab to close it

### Searching

1. Click the **magnifying glass** icon or press **⌘F**
2. Type your search term
3. Use **↑↓** buttons to navigate between results
4. Click **Done** to close search

### Highlighting Text

1. **Select text** by clicking and dragging
2. A **Highlight** button appears right below your selection
3. Click the button to add a highlight
4. Optionally choose a color from the dropdown

### Removing Highlights

- **Right-click** any highlight → "Remove Highlight"
- Or hover over a note in the sidebar and click the **trash icon**

### Adding Notes

1. **Click on any highlight** in the PDF
2. The note editor will open in the sidebar
3. Type your note
4. Click **Save** or click outside to save

### Zooming

- Use the **+/−** buttons in the toolbar
- Or use keyboard shortcuts:
  - **⌘+** to zoom in
  - **⌘-** to zoom out
  - **⌘0** for actual size (100%)

### Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Open PDF | ⌘O |
| Close Tab | ⌘W |
| Save | ⌘S |
| Find | ⌘F |
| Zoom In | ⌘+ |
| Zoom Out | ⌘- |
| Actual Size | ⌘0 |
| Toggle Sidebar | ⌥⌘N |

## Toolbar Layout

```
[📁 Open]     [🔍 Search] | [➖ 100% ➕]     [Sidebar]
```

- **Left**: Open file
- **Center**: Search button, Zoom controls
- **Right**: Toggle sidebar

## License

MIT License
