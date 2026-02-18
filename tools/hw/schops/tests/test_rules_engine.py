import importlib.util
from pathlib import Path
import unittest


def load_schops_module():
    schops_path = Path(__file__).resolve().parents[1] / "schops.py"
    spec = importlib.util.spec_from_file_location("schops", schops_path)
    assert spec and spec.loader
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)  # type: ignore
    return mod


class TestRuleMatch(unittest.TestCase):
    def test_ref_prefix(self):
        m = load_schops_module().RuleMatch(ref_prefix="R")
        self.assertTrue(m.matches(ref="R1", lib_id="Device:R", value="10k"))
        self.assertFalse(m.matches(ref="C1", lib_id="Device:R", value="10k"))

    def test_lib_id_prefix(self):
        m = load_schops_module().RuleMatch(lib_id_prefix="Device:R")
        self.assertTrue(m.matches(ref="R1", lib_id="Device:R", value=""))
        self.assertTrue(m.matches(ref="R1", lib_id="Device:R_US", value=""))
        self.assertFalse(m.matches(ref="R1", lib_id="Connector:Conn_01x04", value=""))

    def test_value_regex(self):
        m = load_schops_module().RuleMatch(value_regex=r"^10k")
        self.assertTrue(m.matches(ref="R1", lib_id="Device:R", value="10k"))
        self.assertTrue(m.matches(ref="R1", lib_id="Device:R", value="10k 1%"))
        self.assertFalse(m.matches(ref="R1", lib_id="Device:R", value="100k"))


if __name__ == "__main__":
    unittest.main()
