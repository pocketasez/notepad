# ACORD PII redaction: ideas to improve the fe-tools pipeline

2026-11-06. Repo: `~/me/multi/bigbang/modern/fe-tools`. Built from these sources:

- `~/me/docs/research/acord125-pii-redaction.md` (2026-10-07)
- `~/me/docs/deep-research/acord-form-pii-parsing.md` (2026-10-31)
- `~/me/docs/deep-research/acord-sov-non-ai-extraction.md` (2026-11-01)
- `~/me/docs/reports/20261101-001714_multi-bigbang-modern-fe-tools_deep-research-redact-docs-secrets-sov/report.md`

Nothing below was run. The code was checked by grep and by reading it.

## Already in the code

```python
# src/fe_tools/redact/pipeline_pdf.py:56-61
_drop_xfa(doc); doc.scrub(); doc.set_metadata({}); doc.del_xml_metadata()
jsn.write_private(out_path, doc.tobytes(garbage=4, deflate=True))
# src/fe_tools/redact/label_bars.py:47
page.apply_redactions(images=2, graphics=0, text=0)
```

- Widgets are read before `bake()` (D91), so the stale `/AP` leak is closed.
- The label font size is fixed (D91).
- The widget validators use `stdnum`.

## Already logged

- **W361**: the OCR settings (144 DPI, `--psm 3`, Otsu), SOV headers and schema matching, ISO construction codes, and digital PDFs that are still rasterized for Claude.
- **W303**: the scan path. It skips the file when Tesseract finds 0 words, so handwriting is left unredacted.

## Ideas (not in the code or the backlog)

1. **A post-write leak gate that fails closed.** Before redacting, collect every value that will be removed: the widget `/V` values (before `bake`) and the matched spans. Search the output for each one, raw and normalised, in three places:
   - `page.get_text()`
   - every decompressed stream (pikepdf)
   - the raw bytes

   Any hit sends the file to quarantine instead of `write_private`. Also check that the output has 0 widgets, no AcroForm and one `%%EOF`.
   *Done when:* a test fixture with a value planted in a stream gets quarantined.
2. **The box width still leaks the value's length.** The font size is fixed, but the redaction box is the span's tight rectangle, which is the width side channel described in arXiv 2206.02285. Widen the box to the field's cell: the widget rect, or the ruling grid from `page.get_drawings()`. This is from reading the code; not verified.
   *Done when:* the box widths for two values of different lengths in the same field are equal.
3. **A field-name policy table per edition.** It replaces the `\bname\b` regex (`redact/label_bars_widgets.py:25`). The TOML maps `field → redact | hmac | keep` and is keyed by the footer edition string (`ACORD 125 (2016/03)`). An unknown edition goes to quarantine. It follows the same pattern as `redact/pii_paths.toml`.
   *Done when:* every PII field of 125 2011/09 and 2016/03 is listed, and an unknown edition is quarantined.
4. **A per-document deny-list for free text.** Take the name, contact and address values from the same form's fields. Match them in remarks, on other pages and in the SOV: exact with Aho-Corasick, fuzzy with rapidfuzz.
   *Done when:* a fixture with the insured's name in a remark that has no label next to it comes out redacted.
5. **Optional: HMAC tokens.** For joins across documents, replace the fixed `[REDACTED-*]` labels with `HMAC-SHA256(key, normalize(v))`, with the key in Key Vault.

Suggested order: 1, then 2, 3, 4. The gate is the only item that catches the mistakes the others miss.

Work-stack mapping: the gate is a data-quality expectation on the redaction stage, so it can run as a Databricks expectation.
