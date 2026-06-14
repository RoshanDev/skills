# Real-world Examples

This directory contains **production converters** built on top of the skill — useful when `converter-template.md` alone isn't enough and you want a concrete reference that already handles the hard cases (Mermaid pre-rendering, image splitting, multi-volume merge, internal-QC skipping, etc.).

These scripts are **project-specific** (paths, output filenames, asset directories are hardcoded). Treat them as a starting point: copy → adjust the `Configuration` block → run.

---

## `cloud-edge-device-lld.converter.js`

**Source project**: Cloud–Edge–Device collaborative container architecture, Low-Level Design document (`云边端协同容器架构体系方案_详细设计文档.md`).

**Scale handled**:

- Single MD source ~ 552 KB / 8,146 lines
- 3,866 docx elements produced
- 100+ embedded Mermaid diagrams (pre-rendered to PNG, some split into vertical parts)
- 300+ tables
- Final output: ~ 8.8 MB `.docx`

**Features it demonstrates** (beyond the basic template):

1. **Mermaid PNG manifest** — `assets/mermaid_rendered_split/manifest.json` maps each diagram to one or more split PNG parts (so tall diagrams stay legible in Word).
2. **Skipping production metadata** — `# 第 X 卷说明` headings followed by SHA-256 / generation timestamps are excluded.
3. **Skipping internal QC sections** — `## ... 交付自检清单` blocks are excluded from delivery.
4. **PNG dimension reading + proportional scaling** — `getPngDimensions()` + `scaleImage()` from raw PNG header bytes (no image library needed).
5. **DXA column width balancing** — proportional widths sum exactly to table width with a rounding fix on the last column.
6. **Heading inline-formatting parser** — `parseInlineFormatting()` runs on every heading too, so `` ### 表 `cluster` `` renders correctly.

## How to adapt for your own project

Open the script and edit the `Configuration` block at the top:

```javascript
const DOCS_DIR   = '/path/to/your/docs';
const MD_FILE    = path.join(DOCS_DIR, 'your-source.md');
const SPLIT_DIR  = path.join(DOCS_DIR, 'assets', 'mermaid_rendered_split');
const ORIG_DIR   = path.join(DOCS_DIR, 'assets', 'mermaid_rendered');
const OUTPUT_FILE = 'your-output.docx';
```

Then:

```bash
cd /path/to/your/docs
npm install docx
node /path/to/cloud-edge-device-lld.converter.js
```

If your project doesn't use Mermaid, you can:

- Remove the `manifest.json` load and stub out `createImageParagraphs()` to return an empty array, **or**
- Leave the Mermaid path untouched but never write any ```` ```mermaid ```` blocks in your MD (the counter simply won't advance).

## Contributing more examples

Add new converters here with a descriptive filename like `<project-shortname>.converter.js` and document the project's scale and any unusual features above.
