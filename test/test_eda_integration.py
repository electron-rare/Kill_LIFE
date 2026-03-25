#!/usr/bin/env python3
"""
test_eda_integration.py — Integration test for the EDA BOM analysis workflow.

Tests the full pipeline:
  1. Parse a minimal KiCad schematic (inline fixture)
  2. Extract BOM via bom_analyzer.py
  3. Suggest LCSC alternatives
  4. Generate Markdown report
  5. Verify report structure and content
  6. LCSC price API (graceful fallback)
  7. DFM check against JLCPCB capabilities

Part of Kill_LIFE Plan 26, T-EDA-013.
"""

import csv
import io
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch, MagicMock

# Ensure tools/industrial is importable
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "tools" / "industrial"))

import bom_analyzer
from bom_analyzer import (
    BomLine,
    parse_bom,
    deduplicate,
    suggest_alternatives,
    generate_report,
    write_csv,
    classify_assembly,
    fetch_lcsc_prices,
    dfm_check_api,
    JLCPCB_BASIC,
    JLCPCB_EXTENDED,
    JLCPCB_UNAVAILABLE,
    JLCPCB_DFM_CAPABILITIES,
    LCSC_PATTERN,
)


# ---------------------------------------------------------------------------
# Minimal KiCad 7+ schematic fixture (S-expression format)
# Contains: 4x 10K resistors, 2x 100nF caps, 1x ESP32 module, 1x LED
# ---------------------------------------------------------------------------
MINIMAL_KICAD_SCH = """\
(kicad_sch (version 20230121) (generator eeschema)
  (uuid "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")
  (paper "A4")
  (lib_symbols)
  (symbol (lib_id "Device:R") (at 50 50 0) (unit 1)
    (property "Reference" "R1" (at 52 49 0))
    (property "Value" "10K" (at 52 51 0))
    (property "Footprint" "Resistor_SMD:R_0603_1608Metric" (at 50 50 0))
    (property "LCSC" "" (at 50 50 0))
  )
  (symbol (lib_id "Device:R") (at 60 50 0) (unit 1)
    (property "Reference" "R2" (at 62 49 0))
    (property "Value" "10K" (at 62 51 0))
    (property "Footprint" "Resistor_SMD:R_0603_1608Metric" (at 60 50 0))
    (property "LCSC" "" (at 60 50 0))
  )
  (symbol (lib_id "Device:R") (at 70 50 0) (unit 1)
    (property "Reference" "R3" (at 72 49 0))
    (property "Value" "10K" (at 72 51 0))
    (property "Footprint" "Resistor_SMD:R_0603_1608Metric" (at 70 50 0))
    (property "LCSC" "" (at 70 50 0))
  )
  (symbol (lib_id "Device:R") (at 80 50 0) (unit 1)
    (property "Reference" "R4" (at 82 49 0))
    (property "Value" "10K" (at 82 51 0))
    (property "Footprint" "Resistor_SMD:R_0603_1608Metric" (at 80 50 0))
    (property "LCSC" "" (at 80 50 0))
  )
  (symbol (lib_id "Device:C") (at 100 50 0) (unit 1)
    (property "Reference" "C1" (at 102 49 0))
    (property "Value" "100nF" (at 102 51 0))
    (property "Footprint" "Capacitor_SMD:C_0603_1608Metric" (at 100 50 0))
    (property "LCSC" "" (at 100 50 0))
  )
  (symbol (lib_id "Device:C") (at 110 50 0) (unit 1)
    (property "Reference" "C2" (at 112 49 0))
    (property "Value" "100nF" (at 112 51 0))
    (property "Footprint" "Capacitor_SMD:C_0603_1608Metric" (at 110 50 0))
    (property "LCSC" "" (at 110 50 0))
  )
  (symbol (lib_id "RF_Module:ESP32-S3-WROOM-1") (at 150 80 0) (unit 1)
    (property "Reference" "U1" (at 152 79 0))
    (property "Value" "ESP32-S3-WROOM-1" (at 152 81 0))
    (property "Footprint" "RF_Module:ESP32-S3-WROOM-1" (at 150 80 0))
    (property "LCSC" "" (at 150 80 0))
  )
  (symbol (lib_id "Device:LED") (at 120 50 0) (unit 1)
    (property "Reference" "D1" (at 122 49 0))
    (property "Value" "LED" (at 122 51 0))
    (property "Footprint" "LED_SMD:LED_0805_2012Metric" (at 120 50 0))
    (property "LCSC" "" (at 120 50 0))
  )
)
"""


def kicad_sch_to_csv(sch_text: str) -> str:
    """Minimal S-expression parser: extract BOM-relevant properties from .kicad_sch
    and emit a CSV string suitable for bom_analyzer.parse_bom().
    """
    import re

    components = []
    # Split by top-level (symbol blocks
    sym_blocks = re.findall(
        r'\(symbol \(lib_id "([^"]+)"\).*?\n(.*?)\n  \)',
        sch_text,
        re.DOTALL,
    )

    for lib_id, body in sym_blocks:
        props = {}
        for m in re.finditer(r'\(property "(\w+)" "([^"]*)"', body):
            props[m.group(1)] = m.group(2)

        ref = props.get("Reference", "")
        value = props.get("Value", "")
        footprint = props.get("Footprint", "")
        lcsc = props.get("LCSC", "")

        if not ref or not value:
            continue
        # Skip power symbols
        if value.upper() in ("GND", "VCC", "VDD", "+3V3", "+5V"):
            continue

        components.append({
            "Reference": ref,
            "Value": value,
            "Footprint": footprint,
            "Quantity": "1",
            "LCSC": lcsc,
        })

    out = io.StringIO()
    writer = csv.DictWriter(
        out,
        fieldnames=["Reference", "Value", "Footprint", "Quantity", "LCSC"],
    )
    writer.writeheader()
    writer.writerows(components)
    return out.getvalue()


class TestEdaIntegrationWorkflow(unittest.TestCase):
    """Full workflow: KiCad schematic -> CSV BOM -> analyze -> report."""

    @classmethod
    def setUpClass(cls):
        """Create temp CSV from the inline KiCad schematic fixture."""
        cls.tmpdir = tempfile.mkdtemp(prefix="eda_integ_")
        cls.sch_path = os.path.join(cls.tmpdir, "test.kicad_sch")
        cls.csv_path = os.path.join(cls.tmpdir, "bom.csv")

        # Write schematic fixture
        with open(cls.sch_path, "w") as f:
            f.write(MINIMAL_KICAD_SCH)

        # Parse schematic to CSV
        csv_text = kicad_sch_to_csv(MINIMAL_KICAD_SCH)
        with open(cls.csv_path, "w") as f:
            f.write(csv_text)

    # -- Step 1: Parse --

    def test_01_parse_csv_bom(self):
        """parse_bom reads the generated CSV and returns BomLine items."""
        lines = parse_bom(self.csv_path)
        self.assertGreater(len(lines), 0, "Should parse at least 1 BOM line")
        # We expect: R1, R2, R3, R4, C1, C2, U1, D1 = 8 raw lines
        self.assertEqual(len(lines), 8, f"Expected 8 lines, got {len(lines)}")

    def test_02_deduplicate_merges_identical(self):
        """Identical value+footprint lines are merged, quantities summed."""
        lines = parse_bom(self.csv_path)
        deduped = deduplicate(lines)
        # 4x 10K R_0603 -> 1 line, 2x 100nF C_0603 -> 1, U1 -> 1, D1 -> 1 = 4
        self.assertEqual(len(deduped), 4, f"Expected 4 deduped lines, got {len(deduped)}")

        # Find the 10K resistor group
        r10k = [bl for bl in deduped if "10K" in bl.value.upper()]
        self.assertEqual(len(r10k), 1)
        self.assertEqual(r10k[0].quantity, 4, "4x 10K should be merged")

    # -- Step 2: Suggest LCSC --

    def test_03_suggest_alternatives(self):
        """suggest_alternatives populates LCSC part numbers for known components."""
        lines = parse_bom(self.csv_path)
        deduped = deduplicate(lines)
        for bl in deduped:
            suggest_alternatives(bl)

        with_lcsc = [bl for bl in deduped if bl.lcsc and LCSC_PATTERN.match(bl.lcsc)]
        # 10K 0603, 100nF 0603, LED 0805 should all match; ESP32-S3 may match too
        self.assertGreaterEqual(
            len(with_lcsc), 3,
            f"Expected >= 3 LCSC matches, got {len(with_lcsc)}: "
            + ", ".join(f"{bl.value}={bl.lcsc}" for bl in with_lcsc),
        )

    def test_04_classify_assembly_categories(self):
        """Each line gets a JLCPCB assembly category."""
        lines = parse_bom(self.csv_path)
        deduped = deduplicate(lines)
        for bl in deduped:
            suggest_alternatives(bl)

        categories = {bl.assembly_category for bl in deduped}
        # At minimum we expect basic and/or extended
        self.assertTrue(
            categories & {JLCPCB_BASIC, JLCPCB_EXTENDED},
            f"Expected at least one basic/extended category, got {categories}",
        )

    # -- Step 3: Generate report --

    def test_05_generate_report_structure(self):
        """Report contains expected Markdown sections."""
        lines = parse_bom(self.csv_path)
        deduped = deduplicate(lines)
        for bl in deduped:
            suggest_alternatives(bl)

        report = generate_report(deduped, self.csv_path)

        # Verify required sections
        self.assertIn("# BOM Analysis Report", report)
        self.assertIn("## Summary", report)
        self.assertIn("## Component Details", report)
        self.assertIn("## Issues", report)

        # Verify summary metrics
        self.assertIn("Unique line items", report)
        self.assertIn("Total component count", report)
        self.assertIn("LCSC coverage", report)
        self.assertIn("JLCPCB Basic parts", report)
        self.assertIn("Assembly status", report)

    def test_06_report_contains_components(self):
        """Report table includes our test components."""
        lines = parse_bom(self.csv_path)
        deduped = deduplicate(lines)
        for bl in deduped:
            suggest_alternatives(bl)

        report = generate_report(deduped, self.csv_path)

        # At least 10K resistor and 100nF cap should appear
        self.assertIn("10K", report)
        self.assertIn("100nF", report)

    def test_07_write_csv_roundtrip(self):
        """write_csv produces a valid CSV that can be re-parsed."""
        lines = parse_bom(self.csv_path)
        deduped = deduplicate(lines)
        for bl in deduped:
            suggest_alternatives(bl)

        out_path = os.path.join(self.tmpdir, "output.csv")
        write_csv(deduped, out_path)

        # Re-parse
        reparsed = parse_bom(out_path)
        self.assertGreater(len(reparsed), 0)

    # -- Step 4: Full end-to-end --

    def test_08_full_workflow_end_to_end(self):
        """Complete workflow: parse -> dedup -> suggest -> report -> verify."""
        # 1. Parse
        lines = parse_bom(self.csv_path)
        self.assertEqual(len(lines), 8)

        # 2. Deduplicate
        deduped = deduplicate(lines)
        self.assertEqual(len(deduped), 4)
        total_qty = sum(bl.quantity for bl in deduped)
        self.assertEqual(total_qty, 8, "Total qty must equal original line count")

        # 3. Suggest
        for bl in deduped:
            suggest_alternatives(bl)

        # 4. Report
        report = generate_report(deduped, self.csv_path)

        # 5. Verify report completeness
        self.assertIn("# BOM Analysis Report", report)
        self.assertIn("## Summary", report)
        self.assertIn("## Component Details", report)
        self.assertIn("## Issues", report)

        # Verify line count in summary
        self.assertIn("4", report)  # 4 unique line items
        self.assertIn("8", report)  # 8 total components


class TestLcscPriceApi(unittest.TestCase):
    """T-EDA-031: LCSC price API integration tests."""

    def test_invalid_part_number_format(self):
        """Invalid part numbers return an error without network call."""
        result = fetch_lcsc_prices(["INVALID", "XYZ123"])
        self.assertIn("INVALID", result)
        self.assertIn("error", result["INVALID"])
        self.assertIn("Invalid", result["INVALID"]["error"])
        self.assertEqual(result["INVALID"]["prices"], {})

    def test_valid_format_accepted(self):
        """A valid LCSC format is accepted (even if network fails)."""
        # Patch urlopen to avoid real network calls in tests
        with patch("bom_analyzer.urllib.request.urlopen") as mock_urlopen:
            mock_resp = MagicMock()
            mock_resp.read.return_value = json.dumps({
                "result": {
                    "productModel": "10K 0402 1%",
                    "stockNumber": 500000,
                    "productPriceList": [
                        {"startPurchasedNumber": 1, "productPrice": "0.0100"},
                        {"startPurchasedNumber": 10, "productPrice": "0.0080"},
                        {"startPurchasedNumber": 100, "productPrice": "0.0050"},
                        {"startPurchasedNumber": 1000, "productPrice": "0.0020"},
                    ],
                }
            }).encode("utf-8")
            mock_resp.__enter__ = lambda s: s
            mock_resp.__exit__ = MagicMock(return_value=False)
            mock_urlopen.return_value = mock_resp

            result = fetch_lcsc_prices(["C25744"])

        self.assertIn("C25744", result)
        entry = result["C25744"]
        self.assertIsNone(entry["error"])
        self.assertEqual(entry["stock"], 500000)
        self.assertIn(1, entry["prices"])
        self.assertIn(1000, entry["prices"])
        self.assertAlmostEqual(entry["prices"][1], 0.01)
        self.assertAlmostEqual(entry["prices"][1000], 0.002)

    def test_network_error_graceful_fallback(self):
        """Network errors produce a result with error info, not an exception."""
        import urllib.error
        with patch("bom_analyzer.urllib.request.urlopen") as mock_urlopen:
            mock_urlopen.side_effect = urllib.error.URLError("Connection refused")
            result = fetch_lcsc_prices(["C25744"])

        entry = result["C25744"]
        self.assertIsNotNone(entry["error"])
        self.assertIn("Network error", entry["error"])
        self.assertEqual(entry["prices"], {})

    def test_http_404_graceful(self):
        """HTTP 404 for unknown part returns structured error."""
        import urllib.error
        with patch("bom_analyzer.urllib.request.urlopen") as mock_urlopen:
            mock_urlopen.side_effect = urllib.error.HTTPError(
                url="", code=404, msg="Not Found", hdrs=None, fp=None
            )
            result = fetch_lcsc_prices(["C9999999"])

        entry = result["C9999999"]
        self.assertIsNotNone(entry["error"])
        self.assertIn("404", entry["error"])

    def test_multiple_parts_batch(self):
        """Multiple parts are queried independently."""
        with patch("bom_analyzer.urllib.request.urlopen") as mock_urlopen:
            mock_resp = MagicMock()
            mock_resp.read.return_value = json.dumps({
                "result": {
                    "productModel": "test",
                    "stockNumber": 100,
                    "productPriceList": [
                        {"startPurchasedNumber": 1, "productPrice": "0.05"},
                    ],
                }
            }).encode("utf-8")
            mock_resp.__enter__ = lambda s: s
            mock_resp.__exit__ = MagicMock(return_value=False)
            mock_urlopen.return_value = mock_resp

            result = fetch_lcsc_prices(["C25744", "C14663", "C25804"])

        self.assertEqual(len(result), 3)
        for pn in ["C25744", "C14663", "C25804"]:
            self.assertIn(pn, result)


class TestDfmCheck(unittest.TestCase):
    """T-EDA-032: DFM check against JLCPCB capabilities."""

    def test_standard_2layer_passes(self):
        """A typical 2-layer board with standard specs passes."""
        result = dfm_check_api({
            "layers": 2,
            "min_trace_mm": 0.15,
            "min_via_mm": 0.3,
            "min_clearance_mm": 0.15,
            "board_width_mm": 50,
            "board_height_mm": 80,
            "surface_finish": "HASL",
            "board_thickness_mm": 1.6,
        })
        self.assertTrue(result["pass"])
        self.assertEqual(result["manufacturer"], "JLCPCB")
        self.assertIsInstance(result["checks"], list)
        self.assertTrue(len(result["checks"]) > 0)
        # All checks should pass
        for check in result["checks"]:
            self.assertEqual(check["status"], "pass", f"Failed: {check}")

    def test_trace_too_thin_fails(self):
        """Board with trace below minimum fails."""
        result = dfm_check_api({
            "layers": 2,
            "min_trace_mm": 0.05,  # below 0.09 min
        })
        self.assertFalse(result["pass"])
        trace_check = [c for c in result["checks"] if c["rule"] == "min_trace"]
        self.assertEqual(len(trace_check), 1)
        self.assertEqual(trace_check[0]["status"], "fail")

    def test_via_too_small_fails(self):
        """Board with via below minimum fails."""
        result = dfm_check_api({
            "layers": 4,
            "min_via_mm": 0.1,  # below 0.15 min
        })
        self.assertFalse(result["pass"])
        via_check = [c for c in result["checks"] if c["rule"] == "min_via"]
        self.assertEqual(via_check[0]["status"], "fail")

    def test_clearance_too_small_fails(self):
        """Board with clearance below minimum fails."""
        result = dfm_check_api({
            "layers": 2,
            "min_clearance_mm": 0.05,
        })
        self.assertFalse(result["pass"])

    def test_invalid_layer_count(self):
        """Layer count outside range fails."""
        result = dfm_check_api({"layers": 64})
        self.assertFalse(result["pass"])
        layer_check = [c for c in result["checks"] if c["rule"] == "layers"]
        self.assertEqual(layer_check[0]["status"], "fail")

    def test_board_too_large_fails(self):
        """Board exceeding max dimensions fails."""
        result = dfm_check_api({
            "layers": 2,
            "board_width_mm": 600,  # max is 500
        })
        self.assertFalse(result["pass"])

    def test_unsupported_surface_finish(self):
        """Unsupported surface finish is flagged."""
        result = dfm_check_api({
            "layers": 2,
            "surface_finish": "GOLD_PLATED_DIAMOND",
        })
        self.assertFalse(result["pass"])

    def test_unsupported_thickness(self):
        """Non-standard board thickness fails."""
        result = dfm_check_api({
            "layers": 2,
            "board_thickness_mm": 3.5,
        })
        self.assertFalse(result["pass"])

    def test_minimal_params_defaults_pass(self):
        """Minimal params (just layers) should pass for standard values."""
        result = dfm_check_api({"layers": 2})
        self.assertTrue(result["pass"])

    def test_warnings_near_limit(self):
        """Trace width near limit triggers a warning."""
        result = dfm_check_api({
            "layers": 2,
            "min_trace_mm": 0.10,  # above 0.09 but within 1.5x
        })
        self.assertTrue(result["pass"])
        self.assertTrue(len(result["warnings"]) > 0, "Expected a warning for near-limit trace")

    def test_return_structure(self):
        """Verify the full return dict structure."""
        result = dfm_check_api({"layers": 2})
        self.assertIn("pass", result)
        self.assertIn("checks", result)
        self.assertIn("warnings", result)
        self.assertIn("manufacturer", result)
        self.assertIsInstance(result["pass"], bool)
        self.assertIsInstance(result["checks"], list)
        self.assertIsInstance(result["warnings"], list)

    def test_multiple_failures_reported(self):
        """Multiple violations are all reported."""
        result = dfm_check_api({
            "layers": 64,
            "min_trace_mm": 0.01,
            "min_via_mm": 0.01,
            "min_clearance_mm": 0.01,
        })
        self.assertFalse(result["pass"])
        failures = [c for c in result["checks"] if c["status"] == "fail"]
        self.assertGreaterEqual(len(failures), 4)


if __name__ == "__main__":
    unittest.main()
