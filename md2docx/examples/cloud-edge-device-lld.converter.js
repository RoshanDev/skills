/**
 * Markdown to DOCX converter - V1.0 单文件版（使用拆分高清图）
 * Source: 合并版 MD（12 章，已去除卷元数据）
 * Images: docs/assets/mermaid_rendered_split（高分图切片）
 * Tables: 正确 Word 表格渲染（修复多列幽灵问题）
 *
 * 用法：node md2docx_v5_final.js
 * 输入：//wsl.localhost/.../docs/云边端协同容器架构体系方案_详细设计文档_完整版.md
 * 输出：//wsl.localhost/.../docs/云边端协同容器架构体系方案_详细设计_VX.X_完整版.docx
 */
const fs = require('fs');
const path = require('path');
const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  ImageRun, Header, Footer, AlignmentType, HeadingLevel, BorderStyle,
  WidthType, ShadingType, PageNumber, PageBreak, LevelFormat,
  VerticalAlign
} = require('docx');

// ===== Configuration =====
// 根目录：docs/（assets 已移入此目录）
const DOCS_DIR = '//wsl.localhost/Ubuntu-22.04/home/roshan/Developer/gh-ceec/docs';
const MD_FILE = path.join(DOCS_DIR, '云边端协同容器架构体系方案_详细设计文档_完整版.md');
const SPLIT_DIR = path.join(DOCS_DIR, 'assets', 'mermaid_rendered_split');
const ORIG_DIR = path.join(DOCS_DIR, 'assets', 'mermaid_rendered');
const OUTPUT_DIR = DOCS_DIR;

// Load manifest for split images
const manifest = JSON.parse(fs.readFileSync(path.join(SPLIT_DIR, 'manifest.json'), 'utf-8'));

const OUTPUT_FILE = '云边端协同容器架构体系方案_详细设计_V1.0_完整版.docx';

// ===== Style definitions =====
const S = {
  font: 'Microsoft YaHei',
  monoFont: 'Consolas',
  bodySize: 24,        // 12pt
  h1Size: 40,          // 20pt
  h2Size: 32,          // 16pt
  h3Size: 28,          // 14pt
  h4Size: 26,          // 13pt
  h5Size: 24,          // 12pt
  codeSize: 20,        // 10pt
  tableSize: 21,       // 10.5pt for table text
  primary: '1A5276',
  secondary: '2C3E50',
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

// ===== PNG Dimension Reader =====
function getPngDimensions(buffer) {
  if (buffer.length < 24) return null;
  if (buffer[0] !== 0x89 || buffer[1] !== 0x50 || buffer[2] !== 0x4E || buffer[3] !== 0x47) return null;
  return { width: buffer.readUInt32BE(16), height: buffer.readUInt32BE(20) };
}

function scaleImage(origWidth, origHeight) {
  let w = origWidth, h = origHeight;
  if (w > MAX_IMG_WIDTH) { const r = MAX_IMG_WIDTH / w; w = MAX_IMG_WIDTH; h = Math.round(h * r); }
  if (h > MAX_IMG_HEIGHT) { const r = MAX_IMG_HEIGHT / h; h = MAX_IMG_HEIGHT; w = Math.round(w * r); }
  return { width: w, height: h };
}

// ===== Markdown Parsing =====
function parseFrontmatter(content) {
  if (content.startsWith('---')) {
    const end = content.indexOf('---', 3);
    if (end !== -1) return content.substring(end + 3).trim();
  }
  return content;
}

function parseInlineFormatting(text, opts = {}) {
  const runs = [];
  const fontSize = opts.size || S.bodySize;
  const fontName = opts.font || S.font;
  const color = opts.color || S.bodyColor;
  const bold = opts.bold || false;

  const regex = /(\*\*(.+?)\*\*|\*(.+?)\*|`([^`]+)`|([^*`]+))/g;
  let match;
  while ((match = regex.exec(text)) !== null) {
    if (match[2]) {
      runs.push(new TextRun({ text: match[2], bold: true, font: fontName, size: fontSize, color }));
    } else if (match[3]) {
      runs.push(new TextRun({ text: match[3], italics: true, font: fontName, size: fontSize, color }));
    } else if (match[4]) {
      runs.push(new TextRun({ text: match[4], font: S.monoFont, size: S.codeSize, color: S.codeColor, shading: { fill: S.codeBgColor, type: ShadingType.CLEAR } }));
    } else if (match[5]) {
      runs.push(new TextRun({ text: match[5], bold, font: fontName, size: fontSize, color }));
    }
  }
  if (runs.length === 0) {
    runs.push(new TextRun({ text: text, bold, font: fontName, size: fontSize, color }));
  }
  return runs;
}

function parseTableRow(line) {
  // Strip leading/trailing | to avoid ghost empty columns
  return line.replace(/^\||\|$/g, '').split('|').map(c => c.trim());
}

function isTableSeparator(line) {
  return /^\|[\s\-:|]+\|$/.test(line.trim());
}

// ===== Table Builder =====
function createTableCell(text, isHeader, colWidth, rowIndex) {
  const borderDef = { style: BorderStyle.SINGLE, size: 1, color: S.tableBorder };
  const allBorders = { top: borderDef, bottom: borderDef, left: borderDef, right: borderDef };

  let shading;
  if (isHeader) shading = { fill: S.tableHeaderBg, type: ShadingType.CLEAR };
  else if (rowIndex % 2 === 1) shading = { fill: S.tableAltRow, type: ShadingType.CLEAR };

  const textColor = isHeader ? S.tableHeaderText : S.bodyColor;
  const runs = parseInlineFormatting(text, { size: S.tableSize, color: textColor, bold: isHeader });

  return new TableCell({
    borders: allBorders,
    width: { size: colWidth, type: WidthType.DXA },
    shading,
    margins: { top: 80, bottom: 80, left: 120, right: 120 },
    verticalAlign: VerticalAlign.CENTER,
    children: [new Paragraph({ children: runs, spacing: { before: 20, after: 20 } })]
  });
}

function buildTable(headerCells, bodyRows) {
  const tableWidth = 9026;
  const numCols = headerCells.length;
  if (numCols === 0) return null;

  const colMaxLen = new Array(numCols).fill(0);
  headerCells.forEach((c, i) => { colMaxLen[i] = Math.max(colMaxLen[i], c.length); });
  bodyRows.forEach(row => { row.forEach((c, i) => { if (i < numCols) colMaxLen[i] = Math.max(colMaxLen[i], c.length); }); });

  const totalLen = colMaxLen.reduce((a, b) => a + Math.max(b, 3), 0);
  const colWidths = colMaxLen.map(len => Math.round((Math.max(len, 3) / totalLen) * tableWidth));
  colWidths[colWidths.length - 1] += tableWidth - colWidths.reduce((a, b) => a + b, 0);

  const rows = [];
  rows.push(new TableRow({ tableHeader: true, children: headerCells.map((cell, i) => createTableCell(cell, true, colWidths[i], 0)) }));
  bodyRows.forEach((row, rowIdx) => {
    const cells = [];
    for (let ci = 0; ci < numCols; ci++) cells.push(createTableCell(ci < row.length ? row[ci] : '', false, colWidths[ci], rowIdx));
    rows.push(new TableRow({ children: cells }));
  });

  return new Table({ width: { size: tableWidth, type: WidthType.DXA }, columnWidths: colWidths, rows });
}

// ===== Code Block =====
function createCodeBlock(lines) {
  const paragraphs = [];
  paragraphs.push(new Paragraph({ children: [], spacing: { before: 160, after: 0 }, border: { top: { style: BorderStyle.SINGLE, size: 1, color: S.codeBlockBorder } } }));
  for (const line of lines) {
    paragraphs.push(new Paragraph({
      children: [new TextRun({ text: line || ' ', font: S.monoFont, size: S.codeSize, color: '2C3E50' })],
      spacing: { before: 0, after: 0 },
      shading: { fill: S.codeBgColor, type: ShadingType.CLEAR },
      indent: { left: 360, right: 360 },
    }));
  }
  paragraphs.push(new Paragraph({ children: [], spacing: { before: 0, after: 160 }, border: { bottom: { style: BorderStyle.SINGLE, size: 1, color: S.codeBlockBorder } } }));
  return paragraphs;
}

// ===== Image Handler (uses split images) =====
function createImageParagraphs(diagramNum) {
  const diagramName = `diagram_${String(diagramNum).padStart(3, '0')}.png`;
  const entry = manifest.find(e => e.diagram === diagramName);
  
  if (!entry) {
    // Fallback to original single image
    const imgPath = path.join(ORIG_DIR, diagramName);
    if (!fs.existsSync(imgPath)) {
      console.warn(`  Warning: Image not found: ${diagramName}`);
      return [new Paragraph({
        children: [new TextRun({ text: `[图示 ${diagramNum} - 图片缺失]`, italics: true, color: '999999', font: S.font, size: S.bodySize })],
        spacing: { before: 120, after: 120 }
      })];
    }
    const imgData = fs.readFileSync(imgPath);
    const dims = getPngDimensions(imgData);
    let width = 550, height = 300;
    if (dims) { const scaled = scaleImage(dims.width, dims.height); width = scaled.width; height = scaled.height; }
    return [new Paragraph({
      children: [new ImageRun({ type: 'png', data: imgData, transformation: { width, height }, altText: { title: `Diagram ${diagramNum}`, description: `Architecture diagram ${diagramNum}`, name: diagramName } })],
      alignment: AlignmentType.CENTER,
      spacing: { before: 240, after: 240 }
    })];
  }

  // Use split parts
  const paragraphs = [];
  for (const partFile of entry.parts) {
    const partPath = path.join(SPLIT_DIR, partFile);
    if (!fs.existsSync(partPath)) {
      console.warn(`  Warning: Split part not found: ${partFile}`);
      continue;
    }
    const imgData = fs.readFileSync(partPath);
    const dims = getPngDimensions(imgData);
    let width = 550, height = 300;
    if (dims) { const scaled = scaleImage(dims.width, dims.height); width = scaled.width; height = scaled.height; }
    paragraphs.push(new Paragraph({
      children: [new ImageRun({ type: 'png', data: imgData, transformation: { width, height }, altText: { title: `Diagram ${diagramNum} - ${partFile}`, description: `Architecture diagram ${diagramNum}`, name: partFile.replace('.png', '') } })],
      alignment: AlignmentType.CENTER,
      spacing: { before: 60, after: 60 }
    }));
  }
  if (paragraphs.length === 0) {
    return [new Paragraph({
      children: [new TextRun({ text: `[图示 ${diagramNum} - 图片缺失]`, italics: true, color: '999999', font: S.font, size: S.bodySize })],
      spacing: { before: 120, after: 120 }
    })];
  }
  return paragraphs;
}

// ===== Main Converter =====
function convertMarkdownToElements(content, startDiagramNum) {
  const elements = [];
  const lines = content.split('\n');
  let i = 0;
  let diagramCounter = startDiagramNum;
  let skipVolumeDescription = false;
  let skipSelfCheck = false;

  while (i < lines.length) {
    const line = lines[i];
    if (line.trim() === '') { i++; continue; }
    if (line.trim() === '\\newpage') { elements.push(new Paragraph({ children: [new PageBreak()] })); i++; continue; }

    // Skip "第 X 卷说明" section (volume description metadata)
    if (/^#\s+第\s*\d+\s*卷说明/.test(line)) {
      skipVolumeDescription = true;
      i++;
      continue;
    }
    // End skip when hitting the next H1 heading
    if (skipVolumeDescription) {
      if (/^#\s+/.test(line) && !/^#\s+第\s*\d+\s*卷说明/.test(line)) {
        skipVolumeDescription = false;
        // Fall through to process this heading normally
      } else {
        i++;
        continue;
      }
    }

    // Skip "交付自检清单" sections (internal QC, not for delivery)
    if (/^##\s+.*交付自检清单/.test(line)) {
      skipSelfCheck = true;
      i++;
      continue;
    }
    if (skipSelfCheck) {
      // End skip when hitting the next H2 or higher heading
      if (/^#{1,2}\s+/.test(line) && !/交付自检清单/.test(line)) {
        skipSelfCheck = false;
        // Fall through to process this heading normally
      } else {
        i++;
        continue;
      }
    }

    // Headings — MUST use parseInlineFormatting to handle `code`, **bold**, *italic* in heading text
    const h5Match = line.match(/^#{5}\s+(.+)/);
    if (h5Match) { elements.push(new Paragraph({ heading: HeadingLevel.HEADING_5, children: parseInlineFormatting(h5Match[1], { size: S.h5Size, color: S.secondary, bold: true }), spacing: { before: 200, after: 100 } })); i++; continue; }

    const h4Match = line.match(/^#{4}\s+(.+)/);
    if (h4Match) { elements.push(new Paragraph({ heading: HeadingLevel.HEADING_4, children: parseInlineFormatting(h4Match[1], { size: S.h4Size, color: S.secondary, bold: true }), spacing: { before: 240, after: 120 } })); i++; continue; }

    const h3Match = line.match(/^#{3}\s+(.+)/);
    if (h3Match) { elements.push(new Paragraph({ heading: HeadingLevel.HEADING_3, children: parseInlineFormatting(h3Match[1], { size: S.h3Size, color: S.secondary, bold: true }), spacing: { before: 280, after: 140 } })); i++; continue; }

    const h2Match = line.match(/^#{2}\s+(.+)/);
    if (h2Match) { elements.push(new Paragraph({ heading: HeadingLevel.HEADING_2, children: parseInlineFormatting(h2Match[1], { size: S.h2Size, color: S.primary, bold: true }), spacing: { before: 320, after: 160 } })); i++; continue; }

    const h1Match = line.match(/^#\s+(.+)/);
    if (h1Match) { elements.push(new Paragraph({ heading: HeadingLevel.HEADING_1, children: parseInlineFormatting(h1Match[1], { size: S.h1Size, color: S.primary, bold: true }), spacing: { before: 400, after: 200 } })); i++; continue; }

    // Code block
    if (line.trim().startsWith('```')) {
      const lang = line.trim().substring(3).trim();
      const codeLines = []; i++;
      while (i < lines.length && !lines[i].trim().startsWith('```')) { codeLines.push(lines[i]); i++; }
      i++;
      if (lang === 'mermaid') { elements.push(...createImageParagraphs(diagramCounter)); diagramCounter++; }
      else { elements.push(...createCodeBlock(codeLines)); }
      continue;
    }

    // Table - improved detection: line starts with | and contains at least one more |
    if (line.trim().startsWith('|') && line.trim().endsWith('|') && line.indexOf('|', 1) > 0) {
      const tableLines = [];
      while (i < lines.length && lines[i].trim().startsWith('|') && lines[i].trim().endsWith('|')) { tableLines.push(lines[i]); i++; }
      if (tableLines.length >= 2) {
        const headerCells = parseTableRow(tableLines[0]);
        const bodyRows = [];
        for (let t = 1; t < tableLines.length; t++) { if (!isTableSeparator(tableLines[t])) bodyRows.push(parseTableRow(tableLines[t])); }
        if (headerCells.length > 0) {
          const table = buildTable(headerCells, bodyRows);
          if (table) {
            elements.push(new Paragraph({ children: [], spacing: { before: 160, after: 0 } }));
            elements.push(table);
            elements.push(new Paragraph({ children: [], spacing: { before: 0, after: 160 } }));
          }
        }
      }
      continue;
    }

    // Blockquote (> prefixed lines)
    if (line.trim().startsWith('>')) {
      const quoteLines = [];
      while (i < lines.length && lines[i].trim().startsWith('>')) {
        quoteLines.push(lines[i].replace(/^>\s*/, ''));
        i++;
      }
      const quoteText = quoteLines.join(' ').trim();
      if (quoteText) {
        elements.push(new Paragraph({
          children: parseInlineFormatting(quoteText, { color: '5D6D7E' }),
          indent: { left: 480 },
          spacing: { before: 100, after: 100 },
          border: { left: { style: BorderStyle.SINGLE, size: 3, color: '1A5276' } }
        }));
      }
      continue;
    }

    // Bullet list
    if (line.match(/^(\s*)[-*]\s+/)) {
      while (i < lines.length && lines[i].match(/^(\s*)[-*]\s+/)) {
        const indentMatch = lines[i].match(/^(\s*)[-*]\s+(.*)/);
        const level = Math.min(Math.floor(indentMatch[1].length / 2), 2);
        elements.push(new Paragraph({ numbering: { reference: 'bullets', level }, children: parseInlineFormatting(indentMatch[2]), spacing: { before: 60, after: 60 } }));
        i++;
      }
      continue;
    }

    // Numbered list
    if (line.match(/^\d+\.\s+/)) {
      while (i < lines.length && lines[i].match(/^\d+\.\s+/)) {
        elements.push(new Paragraph({ numbering: { reference: 'numbers', level: 0 }, children: parseInlineFormatting(lines[i].replace(/^\d+\.\s+/, '')), spacing: { before: 60, after: 60 } }));
        i++;
      }
      continue;
    }

    // Horizontal rule
    if (line.match(/^-{3,}$/) || line.match(/^\*{3,}$/) || line.match(/^_{3,}$/)) {
      elements.push(new Paragraph({ children: [], spacing: { before: 120, after: 120 }, border: { bottom: { style: BorderStyle.SINGLE, size: 1, color: 'D5D8DC' } } }));
      i++; continue;
    }

    // Regular paragraph
    elements.push(new Paragraph({ children: parseInlineFormatting(line), spacing: { before: 100, after: 100 } }));
    i++;
  }

  return { elements, diagramCounter };
}

// ===== Document Generation (merged) =====
async function generateMergedDocx() {
  console.log('=== Generating V1.0 DOCX (单文件合并版) ===\n');

  const allElements = [];

  console.log(`Reading: ${path.basename(MD_FILE)}`);
  let content = fs.readFileSync(MD_FILE, 'utf-8');
  content = parseFrontmatter(content);

  // 单文件模式：diagramCounter 从 1 开始，按 MD 中的出现顺序递增
  const { elements } = convertMarkdownToElements(content, 1);
  console.log(`  Elements: ${elements.length}`);
  allElements.push(...elements);

  console.log(`\nTotal elements: ${allElements.length}`);

  const headerTitle = '云边端协同容器架构体系方案详细设计文档';

  const doc = new Document({
    styles: {
      default: { document: { run: { font: S.font, size: S.bodySize, color: S.bodyColor } } },
      paragraphStyles: [
        { id: 'Heading1', name: 'Heading 1', basedOn: 'Normal', next: 'Normal', quickFormat: true, run: { size: S.h1Size, bold: true, font: S.font, color: S.primary }, paragraph: { spacing: { before: 400, after: 200 }, outlineLevel: 0 } },
        { id: 'Heading2', name: 'Heading 2', basedOn: 'Normal', next: 'Normal', quickFormat: true, run: { size: S.h2Size, bold: true, font: S.font, color: S.primary }, paragraph: { spacing: { before: 320, after: 160 }, outlineLevel: 1 } },
        { id: 'Heading3', name: 'Heading 3', basedOn: 'Normal', next: 'Normal', quickFormat: true, run: { size: S.h3Size, bold: true, font: S.font, color: S.secondary }, paragraph: { spacing: { before: 280, after: 140 }, outlineLevel: 2 } },
        { id: 'Heading4', name: 'Heading 4', basedOn: 'Normal', next: 'Normal', quickFormat: true, run: { size: S.h4Size, bold: true, font: S.font, color: S.secondary }, paragraph: { spacing: { before: 240, after: 120 }, outlineLevel: 3 } },
        { id: 'Heading5', name: 'Heading 5', basedOn: 'Normal', next: 'Normal', quickFormat: true, run: { size: S.h5Size, bold: true, font: S.font, color: S.secondary }, paragraph: { spacing: { before: 200, after: 100 }, outlineLevel: 4 } },
      ]
    },
    numbering: {
      config: [
        { reference: 'bullets', levels: [
          { level: 0, format: LevelFormat.BULLET, text: '\u2022', alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 720, hanging: 360 } } } },
          { level: 1, format: LevelFormat.BULLET, text: '\u25E6', alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 1440, hanging: 360 } } } },
          { level: 2, format: LevelFormat.BULLET, text: '\u25AA', alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 2160, hanging: 360 } } } },
        ]},
        { reference: 'numbers', levels: [{ level: 0, format: LevelFormat.DECIMAL, text: '%1.', alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 720, hanging: 360 } } } }] },
      ]
    },
    sections: [{
      properties: {
        page: {
          size: { width: 11906, height: 16838 },
          margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 }
        }
      },
      headers: {
        default: new Header({
          children: [new Paragraph({
            alignment: AlignmentType.RIGHT,
            children: [new TextRun({ text: headerTitle, font: S.font, size: 18, color: S.footerColor, italics: true })],
            border: { bottom: { style: BorderStyle.SINGLE, size: 1, color: 'D5D8DC' } },
            spacing: { after: 120 }
          })]
        })
      },
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
            ],
            border: { top: { style: BorderStyle.SINGLE, size: 1, color: 'D5D8DC' } },
            spacing: { before: 120 }
          })]
        })
      },
      children: allElements,
    }]
  });

  const buffer = await Packer.toBuffer(doc);
  const outputPath = path.join(OUTPUT_DIR, OUTPUT_FILE);
  fs.writeFileSync(outputPath, buffer);
  console.log(`\nDone: ${OUTPUT_FILE} (${(buffer.length / 1024 / 1024).toFixed(2)} MB)`);
}

generateMergedDocx().catch(console.error);
