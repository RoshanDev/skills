---
name: md2docx
version: 1.1.0
description: "Convert Markdown files to professional Word (.docx) documents using docx-js with proper table rendering, image embedding, heading styles, code blocks, and CJK font support. Use when the user wants to convert Markdown to Word, generate DOCX from MD source, or batch-convert multiple Markdown files into styled Word documents. Handles: tables, mermaid diagrams (pre-rendered PNG), code blocks, nested lists, blockquotes, inline formatting, headers/footers with page numbers, and A4/Letter page layouts."
description_zh: "将 Markdown 文件转换为专业的 Word (.docx) 文档，使用 docx-js 实现正确的表格渲染、图片嵌入、标题样式、代码块和中文字体支持。当用户需要将 Markdown 转 Word、从 MD 源文件生成 DOCX、或批量转换多个 Markdown 文件为带样式的 Word 文档时使用。支持：表格、Mermaid 图（预渲染 PNG）、代码块、嵌套列表、引用块、行内格式、页眉页脚页码、A4/Letter 页面布局。"
---

# Markdown to Word (DOCX) Conversion

## Overview

Use `docx-js` (npm package `docx`) to programmatically convert Markdown into OOXML-compliant `.docx` files. This skill covers the complete pipeline from parsing to generation, with lessons learned from large-scale document production (7000+ line MD sources, 100+ embedded images, 300+ tables).

## Quick Start

```bash
npm install docx   # in the working directory
node md2docx.js    # run the converter
```

## Architecture

```
MD Source → Parse (line-by-line) → Element Array → docx-js Document → Packer.toBuffer → .docx
```

The converter is a single Node.js script. Each Markdown construct maps to one or more docx-js elements.

---

## Critical Rules (Lessons Learned)

### 1. Tables MUST Use `<w:tbl>` — Never Pipe Characters

**THE #1 FAILURE MODE**: If your converter outputs pipe `|` characters as plain text instead of proper Word table XML, the document is broken.

```javascript
// ✅ CORRECT — detect table lines and build proper Table objects
if (line.trim().startsWith('|') && line.trim().endsWith('|') && line.indexOf('|', 1) > 0) {
  // Collect all consecutive | lines, parse header + body, build Table
}

// ❌ WRONG — treating table lines as regular paragraphs
elements.push(new Paragraph({ children: [new TextRun(line)] }));
```

**Detection**: A line is a table row if it starts AND ends with `|`. The separator row (containing `---`) must be skipped when building body rows.

**Validation**: After generation, check the docx ZIP for pipe remnants:
```python
import zipfile, re
z = zipfile.ZipFile('output.docx')
xml = z.read('word/document.xml').decode('utf-8')
pipe_count = len(re.findall(r'<w:t[^>]*>[^<]*\|[^<]*</w:t>', xml))
# pipe_count should be < 10 (only legitimate in-text pipe usage)
```

### 2. Table Row Parsing: Strip Leading AND Trailing Pipe

```javascript
// ✅ CORRECT — strip outer pipes first, then split
function parseTableRow(line) {
  return line.replace(/^\||\|$/g, '').split('|').map(c => c.trim());
}

// ❌ WRONG — creates ghost empty column at end
function parseTableRow(line) {
  return line.split('|').map(c => c.trim()).filter((c, i, arr) => i > 0 && i < arr.length);
}
// Bug: `i < arr.length` is ALWAYS true, so trailing empty '' from `|A|B|` split is kept
```

**Symptom**: Tables have an extra blank column on the right side. The root cause is `.filter((c, i, arr) => i > 0 && i < arr.length)` — this only removes the first empty string (index 0), NOT the last one (arr.length - 1), because `i < arr.length` is trivially true for all valid indices.

### 3. Table Column Widths Must Be DXA, Sum to Table Width

```javascript
const tableWidth = 9026; // A4 content width (11906 - 2*1440 margins)
const colWidths = computeProportional(headerCells, tableWidth);
// colWidths MUST sum exactly to tableWidth — fix rounding on last column
colWidths[colWidths.length - 1] += tableWidth - colWidths.reduce((a, b) => a + b, 0);

new Table({
  width: { size: tableWidth, type: WidthType.DXA },  // NEVER use PERCENTAGE
  columnWidths: colWidths,
  rows: [...]
});
```

### 4. Never Construct Paragraph from Spread of Another Paragraph

```javascript
// ❌ FATAL — destroys the Paragraph object, produces empty/broken output
paragraphs[0] = new Paragraph({ ...paragraphs[0], children: undefined });

// ✅ CORRECT — just use the paragraph as-is, or create a new one from scratch
```

### 5. Image Embedding Requires PNG Dimension Reading

```javascript
function getPngDimensions(buffer) {
  if (buffer.length < 24) return null;
  if (buffer[0] !== 0x89 || buffer[1] !== 0x50) return null; // Not PNG
  return { width: buffer.readUInt32BE(16), height: buffer.readUInt32BE(20) };
}

function scaleImage(w, h, maxW = 560, maxH = 700) {
  if (w > maxW) { h = Math.round(h * maxW / w); w = maxW; }
  if (h > maxH) { w = Math.round(w * maxH / h); h = maxH; }
  return { width: w, height: h };
}
```

**Always scale** to fit page content width (~560px at 96dpi for A4 with 1-inch margins).

### 6. Split Large Diagrams into Parts

Tall diagrams (height > 1400px) get compressed to illegibility in Word/PDF. Solution: split into vertical slices (max ~1300px each) and embed as consecutive images.

```javascript
// Use a manifest.json that maps diagram_NNN.png → [part01.png, part02.png, ...]
for (const partFile of entry.parts) {
  const imgData = fs.readFileSync(path.join(SPLIT_DIR, partFile));
  // ... scale and embed each part as a separate centered Paragraph
}
```

### 7. Mermaid Blocks → Pre-Rendered PNG (Never Embed Raw Mermaid)

Word cannot render Mermaid. The workflow is:
1. Pre-render all ```` ```mermaid ```` blocks to PNG (use mermaid-cli or browser-based renderer)
2. Number them sequentially: `diagram_001.png`, `diagram_002.png`, ...
3. In the converter, replace each mermaid code block with the corresponding image(s)

**CRITICAL: Always re-render ALL diagrams when MD source changes.** The converter maps Mermaid blocks to PNGs by sequential counter (1st block = diagram_001, 2nd = diagram_002...). If the MD is edited (blocks added, removed, or reordered), the mapping breaks for ALL subsequent diagrams — not just the modified ones. A partial re-render of "only changed diagrams" will produce WRONG images in the Word output. The correct workflow is:

```bash
# Extract ALL mermaid blocks from current MD and re-render them ALL
mmdc -i diagram_NNN.mmd -o diagram_NNN.png -w 2400 -b transparent --scale 2
# Then rebuild manifest.json and split tall images
```

Track a `diagramCounter` per volume to map mermaid blocks to image files.

### 8. CJK Font Must Be Set Explicitly

```javascript
const S = {
  font: 'Microsoft YaHei',  // or 'SimSun', 'PingFang SC'
  monoFont: 'Consolas',
  bodySize: 24,   // 12pt (half-points)
};
```

Set font in BOTH the document default AND each TextRun to ensure CJK rendering.

### 9. Heading Styles Need outlineLevel for TOC

```javascript
paragraphStyles: [
  { id: 'Heading1', ..., paragraph: { outlineLevel: 0 } },
  { id: 'Heading2', ..., paragraph: { outlineLevel: 1 } },
  // ...
]
```

Without `outlineLevel`, Word navigation pane and Table of Contents won't recognize headings.

### 10. ALL Text Must Pass Through Inline Formatting Parser — Including Headings

**CRITICAL**: Every text element that appears in the final Word document — headings, paragraphs, table cells, blockquotes, list items — MUST pass through `parseInlineFormatting()`. If you output raw text directly via `new TextRun({ text: rawText })`, any Markdown syntax (`` `code` ``, `**bold**`, `*italic*`) will appear as literal characters in the Word document.

```javascript
// ❌ WRONG — raw markdown syntax leaks into output as plain text
// e.g., "### 8.6.1 表 `cluster`" outputs literal backticks in Word
new Paragraph({
  heading: HeadingLevel.HEADING_3,
  children: [new TextRun({ text: h3Match[1], bold: true, font: S.font, size: S.h3Size })]
});

// ✅ CORRECT — inline formatting parsed, `cluster` renders as mono-font code
new Paragraph({
  heading: HeadingLevel.HEADING_3,
  children: parseInlineFormatting(h3Match[1], { size: S.h3Size, color: S.secondary, bold: true })
});
```

**The general principle**: Never trust that text content is "plain". All Markdown source text is potentially formatted. Route EVERYTHING through the inline parser. This applies to:
- Headings (H1–H5) — commonly contain `` `code` `` for API names, table names, etc.
- Paragraphs — obvious
- Table cells — already handled by `buildTable`
- Blockquotes — must parse inline content within `>` blocks
- List items — must parse inline content within `-`/`*`/`1.` items

### 11. Footer/Header: Do NOT Add Confidentiality Marks Unless Explicitly Asked

```javascript
// ✅ CORRECT — clean page number footer
footers: {
  default: new Footer({
    children: [new Paragraph({
      alignment: AlignmentType.CENTER,
      children: [
        new TextRun({ text: '第 ', font: S.font, size: 18, color: S.footerColor }),
        new TextRun({ children: [PageNumber.CURRENT], font: S.font, size: 18, color: S.footerColor }),
        new TextRun({ text: ' 页 / 共 ', font: S.font, size: 18, color: S.footerColor }),
        new TextRun({ children: [PageNumber.TOTAL_PAGES], font: S.font, size: 18, color: S.footerColor }),
        new TextRun({ text: ' 页', font: S.font, size: 18, color: S.footerColor }),
      ]
    })]
  })
}

// ❌ WRONG — adding "机密 · 内部受控" without user request
new TextRun({ text: '机密 · 内部受控  ·  第 ', ... })
```

Default to neutral page numbers only. Do NOT prepend confidentiality labels like "机密 · 内部受控" unless the user explicitly requests document classification marking.

### 12. Skip Volume Description Metadata Sections in Multi-Volume Merge

When merging multi-volume documents, each volume may start with a `# 第 X 卷说明` heading followed by generation metadata (base document SHA-256, generation timestamp, etc.). This content is for production tracking and MUST be excluded from the final merged document.

```javascript
// Skip "第 X 卷说明" and everything until the next H1
if (/^#\s+第\s*\d+\s*卷说明/.test(line)) {
  skipVolumeDescription = true;
  i++; continue;
}
if (skipVolumeDescription) {
  if (/^#\s+/.test(line) && !/^#\s+第\s*\d+\s*卷说明/.test(line)) {
    skipVolumeDescription = false;
    // Fall through to process this heading
  } else { i++; continue; }
}
```

### 13. Skip Internal QC Sections (交付自检清单)

Sections like "交付自检清单" (delivery self-check checklists) are internal production QC artifacts and MUST be excluded from the final delivered document. They look abrupt and unprofessional in the output.

```javascript
// Skip "交付自检清单" section (from H2 to the next H2 or higher)
if (/^##\s+.*交付自检清单/.test(line)) {
  skipSelfCheck = true;
  i++; continue;
}
if (skipSelfCheck) {
  if (/^#{1,2}\s+/.test(line) && !/交付自检清单/.test(line)) {
    skipSelfCheck = false;
    // Fall through to process this heading
  } else { i++; continue; }
}
```

---

## Converter Template

See [converter-template.md](converter-template.md) for a complete working converter script.

---

## Element Mapping Reference

| Markdown | docx-js Element | Key Notes |
|----------|----------------|-----------|
| `# H1` | `Paragraph({ heading: HeadingLevel.HEADING_1 })` | Check longest `#` prefix first |
| `## H2` – `##### H5` | `Paragraph({ heading: HeadingLevel.HEADING_N })` | — |
| Table (`\| ... \|`) | `Table` with `TableRow`/`TableCell` | Must detect separator row |
| Code block | Multiple `Paragraph` with mono font + shading | One paragraph per line |
| ```` ```mermaid ```` | `ImageRun` (pre-rendered PNG) | Replace with numbered diagram |
| `- item` / `* item` | `Paragraph({ numbering: { reference: 'bullets' } })` | Support indent levels |
| `1. item` | `Paragraph({ numbering: { reference: 'numbers' } })` | — |
| `> quote` | `Paragraph` with left border + indent | Collect consecutive `>` lines |
| `**bold**` | `TextRun({ bold: true })` | Via inline regex parser |
| `` `code` `` | `TextRun` with mono font + shading | — |
| `---` | `Paragraph` with bottom border | Horizontal rule |
| `\newpage` | `Paragraph({ children: [new PageBreak()] })` | Custom convention |

---

## Common Pitfalls & Fixes

| Symptom | Cause | Fix |
|---------|-------|-----|
| Tables show as `\| col \| col \|` text | Table detection failed | Ensure startsWith + endsWith `\|` check |
| Images missing in output | `getPngDimensions` returned null, or path wrong | Verify PNG magic bytes, check file exists |
| Only partial images embedded | Dead code corrupting Paragraph array | Never spread/reconstruct Paragraph objects |
| Tiny/blurry diagrams | Source image too large, scaled to tiny size | Split tall images into parts ≤1300px |
| Chinese text shows as boxes | Font not set on TextRun | Set `font` on every TextRun explicitly |
| No page numbers in footer | Missing `PageNumber.CURRENT` import | Import from 'docx' and wrap in TextRun children array |
| File locked error on write | Target .docx is open in Word | Write to `_new.docx` then rename after Word closes |
| `PERCENTAGE` width breaks tables | Google Docs incompatibility | Always use `WidthType.DXA` |
| Table has extra blank last column | `parseTableRow` not stripping trailing `\|` | Use `line.replace(/^\\\|\\|\\\|$/g, '').split('\|')` |
| "机密 · 内部受控" in footer | Hardcoded confidentiality label | Only add if user explicitly requests |
| Volume metadata in merged output | "第 X 卷说明" not skipped | Detect + skip until next H1 heading |
| Internal QC checklist in output | "交付自检清单" not skipped | Detect H2 + skip until next H2/H1 |
| Raw backticks/markdown in headings | Heading text not parsed for inline formatting | Use `parseInlineFormatting()` for ALL text, including headings |

---

## Validation Checklist

After generating a .docx:

1. **ZIP integrity**: `zipfile.ZipFile(f).namelist()` should succeed
2. **Core XML**: `word/document.xml` and `[Content_Types].xml` must exist
3. **Table count**: `doc_xml.count('<w:tbl>')` should match expected tables
4. **No pipe remnants**: Pipe-in-text count < 10
5. **Media files**: Count entries in `word/media/` matches expected images
6. **Section coverage**: Search for each major heading text in the XML

```python
import zipfile, re
z = zipfile.ZipFile('output.docx')
xml = z.read('word/document.xml').decode('utf-8')
print(f"Tables: {xml.count('<w:tbl>')}")
print(f"Pipe remnants: {len(re.findall(r'<w:t[^>]*>[^<]*[|][^<]*</w:t>', xml))}")
print(f"Media: {len([n for n in z.namelist() if n.startswith('word/media/')])}")
```

---

## Multi-Volume Merging

When combining multiple MD files into a single DOCX:

```javascript
for (let vi = 0; vi < volumes.length; vi++) {
  if (vi > 0) allElements.push(new Paragraph({ children: [new PageBreak()] }));
  const { elements } = convertMarkdown(content, vol.diagramStart);
  allElements.push(...elements);
}
```

Key: Track `diagramStart` per volume so mermaid counters map to correct image files.

---

## Page Layout Reference

| Property | A4 Value (DXA) | Letter Value (DXA) |
|----------|---------------|-------------------|
| Width | 11906 | 12240 |
| Height | 16838 | 15840 |
| Margin (1 inch) | 1440 each | 1440 each |
| Content width | 9026 | 9360 |

```javascript
properties: {
  page: {
    size: { width: 11906, height: 16838 },
    margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 }
  }
}
```
