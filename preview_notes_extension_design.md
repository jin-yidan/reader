# Preview Notes Extension - Design Document

## Overview
A macOS extension for Preview that enhances academic paper reading by adding note-taking capabilities to Preview's native highlight system.

**Core Principle**: Leverage Preview's existing highlighting tools and add a complementary note layer, rather than rebuilding functionality.

---

## User Problem Statement
Academic researchers need to:
- Annotate papers while reading
- Capture thoughts and questions quickly
- Review notes later without re-reading entire papers
- Export notes for writing/citation

Current solutions require switching apps or using clunky PDF annotation tools.

---

## Design Philosophy

**Minimalism**: Do one thing well. No extra features, no clutter.

### What We Use from Preview
- Native text highlighting (yellow, pink, blue, etc.)
- PDF rendering and navigation
- PDF file storage (notes saved directly in PDF)

### What We Add
- Note text attached to highlights
- Simple sidebar to view notes
- That's it.

---

## Core Features

### 1. Note Creation

**Single Trigger Method:**
- Click on existing highlight → note field appears in sidebar
- Type your note
- Click outside or press Enter → auto-saves to PDF

**Note Input:**
- Plain text only
- Auto-saves to PDF
- No formatting, no markdown, no complexity

### 2. Sidebar Interface

**Simple Layout:**
```
┌──────────────────────────────────┐
│                                  │
│ Page 3                           │
│ ┌──────────────────────────────┐│
│ │ "results demonstrate..."     ││
│ │                              ││
│ │ This finding contradicts     ││
│ │ previous work by Smith.      ││
│ │                              ││
│ └──────────────────────────────┘│
│                                  │
│ Page 5                           │
│ ┌──────────────────────────────┐│
│ │ "methodology section"        ││
│ │                              ││
│ │ Check if they controlled for ││
│ │ confounding variables.       ││
│ │                              ││
│ └──────────────────────────────┘│
│                                  │
└──────────────────────────────────┘
```

**Sidebar Features:**
- Shows all notes, organized by page
- Click note card → jump to highlight in PDF
- That's all

### 3. Note Card Design

**Card Contents:**
- Highlighted text snippet (first 50 characters + "...")
- Note text
- Page number
  
**Card Actions:**
- Click → navigate to location
- Click to edit inline
- Delete (small × button)

### 4. Data Persistence

**Storage: Directly in PDF**
- Notes saved as PDF annotations
- No external files needed
- Notes persist with the PDF file
- Works across devices if PDF is synced (iCloud, Dropbox, etc.)

---

## Technical Architecture

### Extension Type
**Action Extension** or **App Extension** for macOS

### Data Storage

**Storage Method:**
- Notes saved directly as PDF annotations (text annotations)
- Uses PDF standard annotation format
- No external database or files
- Notes travel with the PDF

**Data Structure (PDF Annotation):**
- Standard PDF text annotation
- Links to highlight annotation
- Contains note text as annotation content

### Key Technical Challenges

1. **PDF Annotation Integration**
   - Write notes as standard PDF text annotations
   - Link text annotations to highlight annotations

2. **Sidebar Display**
   - Read annotations from PDF
   - Display in sidebar interface
   - Keep in sync with PDF state

---

## User Workflows

### Workflow 1: First-Time Reading
1. Open academic paper in Preview
2. Enable extension sidebar
3. Highlight important passages (using Preview's highlight tool)
4. Click highlight → add note in sidebar
5. Notes saved directly in PDF

### Workflow 2: Returning to Paper
1. Open previously annotated paper
2. Notes appear automatically in sidebar (read from PDF)
3. Click note to jump to location
4. Edit or add new notes

### Workflow 3: Quick Review
1. Open paper
2. Scan sidebar to see all notes
3. Click notes to jump to sections

---

## UI/UX Details

### Visual Design
- **Minimal**: Clean, no decoration
- **System font**: San Francisco
- **System colors**: Match macOS appearance
- **White cards**: Simple, flat design

### Interactions
- Click highlight → add/edit note
- Click note card → jump to highlight
- That's all

### Keyboard Shortcuts
- None needed for v1 (keep it simple)

---

## MVP Feature Set (Version 1.0)

**Only These Features:**
- ✅ Click highlight to add note
- ✅ View notes in sidebar
- ✅ Click note to jump to highlight
- ✅ Edit/delete notes
- ✅ Save notes in PDF

**Explicitly NOT Including:**
- ❌ Export
- ❌ Search
- ❌ Filters
- ❌ Tags
- ❌ Note types
- ❌ Keyboard shortcuts
- ❌ Any other complexity

---

## Open Questions

1. **PDF Annotation Format**: Can we reliably write and read text annotations linked to highlights?

2. **Sidebar Integration**: Floating window vs true sidebar in Preview?

3. **Highlight Selection**: How does user "click" a highlight to add a note? (Click detection, accessibility API?)

---

## Success Metrics

**Simple Goals:**
- Can add note in < 3 seconds
- Can find and jump to note in < 5 seconds
- Notes persist when reopening PDF
- Interface stays out of the way

---

## Next Steps

1. **Research**: Can we write PDF annotations from an extension?
2. **Prototype**: Minimal proof-of-concept
3. **Test**: Use it yourself on real papers
4. **Polish**: Fix what's annoying
5. **Ship**: Keep it simple

---

## Questions for Discussion

- Sidebar or floating window?
- How should clicking a highlight work exactly?
- Plain text notes only, right? No formatting?

