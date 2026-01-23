# Read It Tomorrow

**A lightweight PDF reader for reading academic papers on macOS.**

![Reader Screenshot](screenshot.png)

Highlight & annotate with one right-click — no more digging through menus.
Translate English to Chinese with 400+ ML/AI/Math terms built-in.
Open multiple papers in tabs, just like a browser.

[中文版](README_CN.md)

## Why This Over Preview?

| Feature | Preview | 明天读 |
|---------|---------|--------|
| Quick highlight | Hidden in menus | Right-click |
| Multi-color highlights | Limited | 5 colors |
| Translation | No | Built-in EN→CN |
| ML/AI term glossary | No | 400+ terms |
| Multi-tab | No | Yes |
| Auto-save | No | Every 30 seconds |

## Perfect For

- Researchers reading English papers
- Students studying ML/AI/CS
- Anyone tired of Preview's annotation UX

## Download

[Download the latest release](../../releases/latest)

### Installation

1. Download `Reader.zip`
2. Unzip and run the app
3. **First launch:** System Settings → Privacy & Security → Click "Open Anyway"

## Requirements

- macOS 13.0+ for basic features
- macOS 15.0+ for translation
- Xcode 15.0+ to build from source

## How to Use

### Highlighting

1. Select text
2. Right-click → "Highlight" or choose a color

### Adding Notes

1. Click on a highlight
2. Type your note in the sidebar
3. Click Save

### Translation

1. Select English text
2. Right-click → "Translate"
3. View Chinese translation in popup

**Note:** Requires macOS 15.0+ and Chinese language pack (System Settings → General → Language & Region).

### Custom Glossary

1. Select a term
2. Right-click → "Add to Glossary"
3. Enter your preferred translation

Built-in glossary includes 400+ terms:
- "transformer" → "Transformer" (not "变压器")
- "gradient descent" → "梯度下降"
- "token" → "词元" (not "令牌")

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

## Technical Details

**Translation System**
- Apple Translation framework with two-stage glossary
- Custom terms replaced with placeholders before translation
- Mistranslation corrections applied post-translation

**Multi-line Highlights**
- Each line stored as separate PDF annotation
- Linked by Group ID for unified display/deletion

**Architecture**
- SwiftUI + PDFKit (NSViewRepresentable)
- MVVM pattern
- Standard PDF annotation format (compatible with other readers)
- NSFileCoordinator for safe auto-save

## Known Limitations

- Translation requires macOS 15.0+
- Translation requires Chinese language pack download
- Annotations saved directly in PDF (may not work in all readers)

## License

MIT License
