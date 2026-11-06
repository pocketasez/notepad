---
status: current
summary: removing PII from ACORD 125 PDFs without PII models — field-level for fillable, true redaction for vector, template registration for scans, rule-based detection and HMAC tokens
applies_to: []   # research only (D4); no code here uses it
updated: 2026-10-07
---

# ACORD 125 PII removal without AI

Web research on 2026-10-07 by three agents, plus two tests run in the session
scratchpad (log `../log/20261007_141509_RESEARCH_acord125-pii-no-ai.md`).
Scope is D4: mixed digital and scanned input; classical OCR and OpenCV
allowed; no NER, LLM or ML PII detector; output is a redacted PDF plus HMAC
tokens.

## Route each page

| Page kind | Test (PyMuPDF) | Path |
|---|---|---|
| Fillable | AcroForm has fields | field-level: blank `/V`, `/DV`, `/AP`, drop `/XFA`, flatten |
| Vector, flattened | words present, footer `ACORD 125 (YYYY/MM)` extracts | true redaction at the edition's template rectangles |
| Scan, fax, OCR'd, or text that does not extract | ~0 words, images ≥90 % of page, GlyphLessFont, labels missing | register to template, burn boxes into pixels, rebuild with img2pdf |
| Unknown edition or page | footer not on the allow-list, registration below threshold | quarantine (fail closed) |

## Measured here

| What | Result | Command |
|---|---|---|
| Blanking `/V` alone (2011/09 form, public copy) | both `/AP /N` streams still held the old name and FEIN; after `bake()` the FEIN is in `page.get_text()` (True) | `uv run --with pypdf==6.19.0 --with pikepdf --with pymupdf python -I scripts/ap.py …` then `doc.bake()` (scratchpad; run by the agent, re-run by the session) |
| PyMuPDF bake → search → redact → `scrub()` → `save(garbage=4, clean=True)` | 0 hits in `pdftotext`, 0 in any decompressed stream (pikepdf) | agent's inline PyMuPDF run (scratchpad) |
| Presidio 2.2.364 with `NoOpNlpEngine` | 16 recognizers, no NER; deny-list 1.0, email 1.0, SSN 0.5, phone 0.4; context words ignored unless passed (`context=["ssn"]` → 0.85); no EIN recognizer (`12-3456789` → driver's licence 0.01); ABA recognizer not in default registry | `uv run --python 3.12 --with presidio-analyzer==2.2.364 python t.py` (agent); import re-checked by the session |
| Field names, 2011/09 vs 125 CA 2023/01 | 601 vs 554 fields; 416 shared; core PII names identical (`NamedInsured_FullName_A`, `NamedInsured_TaxIdentifier_A`, …); 2023/01 also carries `/XFA` | pypdf field listing (agent, scratchpad) |

## Field names that hold PII (both editions read)

```
NamedInsured_FullName_{A,B,C}  NamedInsured_TaxIdentifier_{A,B,C}  # FEIN *or* SSN
NamedInsured_MailingAddress_*  NamedInsured_Primary_{PhoneNumber,WebsiteAddress}_X
NamedInsured_Contact_{FullName,PrimaryPhoneNumber,PrimaryEmailAddress,...}_X
Producer_* (names, address, contact, CustomerIdentifier, NationalIdentifier)
AdditionalInterest_{FullName,MailingAddress_*,AccountNumberIdentifier,...}_X
CommercialStructure_PhysicalAddress_*  Policy_/PriorCoverage_/OtherPolicy_*PolicyNumberIdentifier*
LossHistory_*  CommercialPolicy_RemarkText_A  *Explanation_X  *ResolutionDescription_X  # free text
```

Edition differences exist (`Producer_StateLicenseIdentifier_A` only in 2011/09),
so the policy table is keyed by edition. No official public field list (ACORD
members only, not verified); vendor maps exist (Vertafore AMS360).

## Leaks to close

- Stale `/AP` (measured above); parent `/V` with kid `/AP`; `/DV` defaults;
  XFA `datasets` overriding AcroForm.
- PyMuPDF `apply_redactions` default `graphics=1` deletes form ruling lines in
  the box: pass `graphics=PDF_REDACT_LINE_ART_NONE`.
- Metadata, XMP, incremental revisions, OCGs, all `/Annots`,
  `/EmbeddedFiles`, `/JavaScript`, `/OpenAction`, outlines, thumbnails:
  `doc.scrub()` then a non-incremental save; exiftool edits are appended and
  reversible until `qpdf --linearize` rewrites.
- Scans: handwriting is invisible to Tesseract (no handwriting support), so
  regex cannot be the only control; label-anchored and template zones are.

## Detection without a model

- Main control: a TOML table `field → redact | hmac_token | fpe_ff1 | keep`.
- Validators: python-stdnum 2.2 (`us.ein` IRS prefixes, `us.ssn`, `us.rtn`,
  `luhn`; `us.itin` rejects middle digits 50–65, patch it), phonenumbers
  9.0.40. Values that fail validation are still redacted by label.
- Free text: a per-document deny-list built from the same form's name,
  contact and address fields, matched exactly (Presidio deny_list or
  pyahocorasick) and fuzzily (rapidfuzz 3.14.6). People named only in free
  text (claimants) are missed: redact those fields whole unless recall is
  measured acceptable.
- ML, out of scope: usaddress (CRF), libpostal, spaCy models,
  `SlimSpacyNlpEngine`, presidio-image-redactor (pulls spaCy), philter-ucsf
  (nltk tagger, Stanford NER), Azure AI Language PII, Databricks `ai_mask()`.

## Tokens

- `HMAC-SHA256(key, normalize(value))`, key in Key Vault; an unkeyed hash of
  a 10^9 SSN/EIN space is brute-forced.
- Presidio's hash operator salts randomly per entity since 2.2.361: not
  joinable unless a fixed salt is passed, and it is not HMAC.
- FPE: FF1 only. SP 800-38G Rev 1 second public draft (2025-02-03) removes
  FF3 and FF3-1.
- Sole proprietors' business names and SSNs in the FEIN field are personal
  (CCPA B2B exemption ended 2023-01-01; NAIC #668 covers applicants); legal
  call is compliance's.

## Libraries (PyPI/Maven, 2026-10-07)

| Lib | Version | Licence |
|---|---|---|
| pypdf | 6.19.0 (use ≥, flatten fix) | BSD-3 |
| pikepdf | 10.16.0 | MPL-2.0 |
| qpdf | 12.4.2 | Apache-2.0 |
| PyMuPDF | 1.28.2 | AGPL-3.0 or commercial |
| iText + pdfSweep | 9.8.0 / 5.0.8 | AGPL or commercial |
| PDFBox | 3.0.8 (no built-in true redaction) | Apache-2.0 |
| OCRmyPDF | 17.13.0 | MPL-2.0 |
| Tesseract | 5.5.3 | Apache-2.0 |
| opencv-python | 4.13.0.92 | Apache-2.0 |
| img2pdf | 0.6.3 | LGPL-3.0 (not verified) |
| Presidio analyzer | 2.2.364 | MIT |

Without AGPL: pypdf + pikepdf + qpdf cover the fillable path; the vector path
then needs PDFBox content-stream rewriting or rasterising (the scan path).

## Verification gate (fail closed)

1. Every known value (from `/V`, pre-redaction text, OCR of the source zones),
   raw and normalised, grepped in `pdftotext -raw` of the output, every
   decompressed stream, and the raw bytes; OCR of the output fuzzy-searched
   (edit distance ≤2) for scans.
2. 0 widgets, no AcroForm, XFA, EmbeddedFiles; one `%%EOF`.
3. Redaction rectangles 100 % black (≥99.5 % after JPEG).
4. Registration inliers and line-overlay IoU above threshold, else a person.

Not run: the scan path, rapidfuzz thresholds, any recall number. Not verified:
ACORD licence text (HTTP 403), the 2016/03 field set, G4 page sizes.
