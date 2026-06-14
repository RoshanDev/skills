# Converter Template

A complete working converter script for Markdown → DOCX conversion.

## Dependencies

```bash
npm install docx
```

## Complete Script

```javascript
const fs = require('fs');
const path = require('path');
const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  ImageRun, Header, Footer, AlignmentType, HeadingLevel, BorderStyle,
  WidthType, ShadingType, PageNumber, PageBreak, LevelFormat, VerticalAlign
} = require('docx');

// ===== Configuration =====
const STYLE = {
  font: 'Microsoft YaHei',    // CJK-capable font
  monoFont: 'Consolas',
  bodySize: 24,               // 12pt (half-points)
  h1Size: 40, h2Size: 32, h3Size: 28, h4Size: 26, h5Size: 24,
  codeSize: 20, tableSize: 21,
  primary: '1A5276',          // Deep blue for H1/H2
  secondary: '2C3E50',        // Dark slate for H3-H5
  bodyColor: '2C3E50',
  codeColor: 'C0392B',
  codeBgColor: 'F8F9FA',
  codeBlockBorder: 'DEE2E6',
  tableHeaderBg: '1A5276',
  tableHeaderText: 'FFFFFF',
  tableBorder: 'BDC3C7',
  tableAltRow: 'F2F8FC',
  footerColor: '7F8C8D',
};

const MAX_IMG_WIDTH = 560;
const MAX_IMG_HEIGHT = 700;

// ===== Utility Functions =====

function getPngDimensions(buffer) {
  if (buffer.length < 24) return null;
  if (buffer[0] !== 0x89 || buffer[1] !== 0x50 || buffer[2] !== 0x4E || buffer[3] !== 0x47) return null;
  return { width: buffer.readUInt32BE(16), height: buffer.readUInt32BE(20) };
}

function scaleImage(w, h) {
  if (w > MAX_IMG_WIDTH) { const r = MAX_IMG_WIDTH / w; w = MAX_IMG_WIDTH; h = Math.round(h * r); }
  if (h > MAX_IMG_HEIGHT) { const r = MAX_IMG_HEIGHT / h; h = MAX_IMG_HEIGHT; w = Math.round(w * r); }
  return { width: w, height: h };
}

function parseFrontmatter(content) {
  if (content.startsWith('---')) {
    const end = content.indexOf('---', 3);
    if (end !== -1) return content.substring(end + 3).trim();
  }
  return content;
}

// ===== Inline Formatting Parser =====

function parseInlineFormatting(text, opts = {}) {
  const runs = [];
  const fontSize = opts.size || STYLE.bodySize;
  const fontName = opts.font || STYLE.font;
  const color = opts.color || STYLE.bodyColor;
  const bold = opts.bold || false;

  const regex = /(\*\*(.+?)\*\*|\*(.+?)\*|`([^`]+)`|([^*`]+))/g;
  let match;
  while ((match = regex.exec(text)) !== null) {
    if (match[2]) {
      runs.push(new TextRun({ text: match[2], bold: true, font: fontName, size: fontSize, color }));
    } else if (match[3]) {
      runs.push(new TextRun({ text: match[3], italics: true, font: fontName, size: fontSize, color }));
    } else if (match[4]) {
      runs.push(new TextRun({ text: match[4], font: STYLE.monoFont, size: STYLE.codeSize, color: STYLE.codeColor,
        shading: { fill: STYLE.codeBgColor, type: ShadingType.CLEAR } }));
    } else if (match[5]) {
      runs.push(new TextRun({ text: match[5], bold, font: fontName, size: fontSize, color }));
    }
  }
  if (runs.length === 0) runs.push(new TextRun({ text, bold, font: fontName, size: fontSize, color }));
  return runs;
}

// ===== Table Builder =====

function parseTableRow(line) {
  // Strip leading/trailing | to avoid ghost empty columns
  return line.replace(/^\||\|$/g, '').split('|').map(c => c.trim());
}

function isTableSeparator(line) {
  return /^\|[\s\-:|]+\|$/.test(line.trim());
}

function buildTable(headerCells, bodyRows) {
  const tableWidth = 9026; // A4 content width
  const numCols = headerCells.length;
  if (numCols === 0) return null;

  // Proportional column widths based on content length
  const colMaxLen = new Array(numCols).fill(0);
  headerCells.forEach((c, i) => { colMaxLen[i] = Math.max(colMaxLen[i], c.length); });
  bodyRows.forEach(row => row.forEach((c, i) => { if (i < numCols) colMaxLen[i] = Math.max(colMaxLen[i], c.length); }));
  const totalLen = colMaxLen.reduce((a, b) => a + Math.max(b, 3), 0);
  const colWidths = colMaxLen.map(len => Math.round((Math.max(len, 3) / totalLen) * tableWidth));
  colWidths[colWidths.length - 1] += tableWidth - colWidths.reduce((a, b) => a + b, 0); // Fix rounding

  const borderDef = { style: BorderStyle.SINGLE, size: 1, color: STYLE.tableBorder };
  const allBorders = { top: borderDef, bottom: borderDef, left: borderDef, right: borderDef };

  function makeCell(text, isHeader, colWidth, rowIndex) {
    let shading;
    if (isHeader) shading = { fill: STYLE.tableHeaderBg, type: ShadingType.CLEAR };
    else if (rowIndex % 2 === 1) shading = { fill: STYLE.tableAltRow, type: ShadingType.CLEAR };
    const textColor = isHeader ? STYLE.tableHeaderText : STYLE.bodyColor;
    return new TableCell({
      borders: allBorders, width: { size: colWidth, type: WidthType.DXA }, shading,
      margins: { top: 80, bottom: 80, left: 120, right: 120 },
      verticalAlign: VerticalAlign.CENTER,
      children: [new Paragraph({ children: parseInlineFormatting(text, { size: STYLE.tableSize, color: textColor, bold: isHeader }), spacing: { before: 20, after: 20 } })]
    });
  }

  const rows = [];
  rows.push(new TableRow({ tableHeader: true, children: headerCells.map((c, i) => makeCell(c, true, colWidths[i], 0)) }));
  bodyRows.forEach((row, ri) => {
    const cells = [];
    for (let ci = 0; ci < numCols; ci++) cells.push(makeCell(ci < row.length ? row[ci] : '', false, colWidths[ci], ri));
    rows.push(new TableRow({ children: cells }));
  });
  return new Table({ width: { size: tableWidth, type: WidthType.DXA }, columnWidths: colWidths, rows });
}

// ===== Code Block Builder =====

function createCodeBlock(lines) {
  const paragraphs = [];
  paragraphs.push(new Paragraph({ children: [], spacing: { before: 160, after: 0 },
    border: { top: { style: BorderStyle.SINGLE, size: 1, color: STYLE.codeBlockBorder } } }));
  for (const line of lines) {
    paragraphs.push(new Paragraph({
      children: [new TextRun({ text: line || ' ', font: STYLE.monoFont, size: STYLE.codeSize, color: '2C3E50' })],
      spacing: { before: 0, after: 0 }, shading: { fill: STYLE.codeBgColor, type: ShadingType.CLEAR },
      indent: { left: 360, right: 360 },
    }));
  }
  paragraphs.push(new Paragraph({ children: [], spacing: { before: 0, after: 160 },
    border: { bottom: { style: BorderStyle.SINGLE, size: 1, color: STYLE.codeBlockBorder } } }));
  return paragraphs;
}

// ===== Main Converter =====
// Adapt convertMarkdownToElements() and generateDocx() to your specific use case.
// Key pattern: iterate lines, match headings/tables/code/lists/paragraphs, push elements.
//
// CRITICAL: Headings MUST use parseInlineFormatting — never raw TextRun:
//   new Paragraph({ heading: HeadingLevel.HEADING_3,
//     children: parseInlineFormatting(text, { size: S.h3Size, color: S.secondary, bold: true }) });
//
// IMPORTANT: Skip volume description metadata ("# 第 X 卷说明") in multi-volume merges:
//   if (/^#\s+第\s*\d+\s*卷说明/.test(line)) { skipVolumeDescription = true; i++; continue; }
//   if (skipVolumeDescription && /^#\s+/.test(line)) { skipVolumeDescription = false; }
//
// IMPORTANT: Skip internal QC sections ("## XX.XX 交付自检清单"):
//   if (/^##\s+.*交付自检清单/.test(line)) { skipSelfCheck = true; i++; continue; }
//   if (skipSelfCheck && /^#{1,2}\s+/.test(line)) { skipSelfCheck = false; }
//   else if (skipVolumeDescription) { i++; continue; }
```

## Usage Pattern

```javascript
// 1. Read and strip frontmatter
let content = fs.readFileSync('input.md', 'utf-8');
content = parseFrontmatter(content);

// 2. Convert to elements
const elements = convertMarkdownToElements(content);

// 3. Build document — footer with page numbers only (no confidentiality marks)
const doc = new Document({
  styles: { /* ... */ },
  numbering: { /* ... */ },
  sections: [{
    properties: { page: { /* ... */ } },
    headers: {
      default: new Header({ children: [new Paragraph({
        alignment: AlignmentType.RIGHT,
        children: [new TextRun({ text: 'Document Title', font: STYLE.font, size: 18, color: STYLE.footerColor, italics: true })],
        border: { bottom: { style: BorderStyle.SINGLE, size: 1, color: 'D5D8DC' } }
      })] })
    },
    footers: {
      default: new Footer({ children: [new Paragraph({
        alignment: AlignmentType.CENTER,
        children: [
          new TextRun({ text: '第 ', font: STYLE.font, size: 18, color: STYLE.footerColor }),
          new TextRun({ children: [PageNumber.CURRENT], font: STYLE.font, size: 18, color: STYLE.footerColor }),
          new TextRun({ text: ' 页 / 共 ', font: STYLE.font, size: 18, color: STYLE.footerColor }),
          new TextRun({ children: [PageNumber.TOTAL_PAGES], font: STYLE.font, size: 18, color: STYLE.footerColor }),
          new TextRun({ text: ' 页', font: STYLE.font, size: 18, color: STYLE.footerColor }),
        ],
        border: { top: { style: BorderStyle.SINGLE, size: 1, color: 'D5D8DC' } }
      })] })
    },
    children: elements
  }]
});

// 4. Write to file
const buffer = await Packer.toBuffer(doc);
fs.writeFileSync('output.docx', buffer);
```

## Image Handling Patterns

### Single image per diagram
```javascript
const imgData = fs.readFileSync(imgPath);
const dims = getPngDimensions(imgData);
const { width, height } = scaleImage(dims.width, dims.height);
new Paragraph({
  children: [new ImageRun({ type: 'png', data: imgData, transformation: { width, height },
    altText: { title: 'Diagram', description: 'Description', name: 'name' } })],
  alignment: AlignmentType.CENTER, spacing: { before: 240, after: 240 }
});
```

### Split parts (tall diagrams)
```javascript
const manifest = JSON.parse(fs.readFileSync('manifest.json', 'utf-8'));
const entry = manifest.find(e => e.diagram === diagramName);
for (const partFile of entry.parts) {
  const imgData = fs.readFileSync(path.join(splitDir, partFile));
  const dims = getPngDimensions(imgData);
  const { width, height } = scaleImage(dims.width, dims.height);
  paragraphs.push(new Paragraph({
    children: [new ImageRun({ type: 'png', data: imgData, transformation: { width, height },
      altText: { title: partFile, description: 'Diagram part', name: partFile.replace('.png', '') } })],
    alignment: AlignmentType.CENTER, spacing: { before: 60, after: 60 }
  }));
}
```

## Multi-File Merging Pattern

```javascript
const allElements = [];
for (let i = 0; i < volumes.length; i++) {
  if (i > 0) allElements.push(new Paragraph({ children: [new PageBreak()] }));
  const content = parseFrontmatter(fs.readFileSync(volumes[i].file, 'utf-8'));
  const { elements } = convert(content, volumes[i].diagramStart);
  allElements.push(...elements);
}
// Pass allElements as children of the single section
```
