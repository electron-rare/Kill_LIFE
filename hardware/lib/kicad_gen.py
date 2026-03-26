"""Shared KiCad schematic generation helpers.

Provides symbol extraction, coordinate transforms, and schematic element
builders used by all Kill_LIFE generator scripts.
"""

import re
import uuid
import math
import pathlib

SYMLIB = pathlib.Path("/usr/share/kicad/symbols")


def gen_uuid():
    return str(uuid.uuid4())


def pin_screen(sx, sy, angle_deg, px_lib, py_lib):
    """Screen coordinate of a pin given symbol placement and library pin offset.

    KiCad library uses Y-up; schematic uses Y-down.
    Transform: rotate (px, py) by angle_deg CCW in lib coords, then flip Y.
    """
    a = math.radians(angle_deg)
    rx = px_lib * math.cos(a) - py_lib * math.sin(a)
    ry = px_lib * math.sin(a) + py_lib * math.cos(a)
    return (round(sx + rx, 4), round(sy - ry, 4))


def extract_symbol(lib_file: pathlib.Path, sym_name: str) -> str:
    text = lib_file.read_text(errors="replace")
    start_pat = re.compile(r'\n\t\(symbol "' + re.escape(sym_name) + r'"')
    m = start_pat.search(text)
    if not m:
        raise ValueError(f"Symbol '{sym_name}' not found in {lib_file}")
    pos = m.start() + 1
    depth = 0
    i = pos
    while i < len(text):
        if text[i] == '(':
            depth += 1
        elif text[i] == ')':
            depth -= 1
            if depth == 0:
                return text[pos:i+1]
        i += 1
    raise ValueError(f"Unmatched parens for '{sym_name}'")


def lib_sym_entry(lib_name: str, sym_name: str) -> str:
    """Return a fully self-contained lib_symbols entry for lib_name:sym_name.

    If sym_name uses (extends "Parent"), the parent's sub-symbols (drawings +
    pins) are injected directly so the embedded entry needs no runtime lookup.
    """
    lib_file = SYMLIB / f"{lib_name}.kicad_sym"
    raw = extract_symbol(lib_file, sym_name)

    # If sym_name extends a parent, flatten: inject parent sub-symbols.
    extends_m = re.search(r'\(extends "([^"]+)"\)', raw)
    if extends_m:
        parent_name = extends_m.group(1)
        try:
            parent_raw = extract_symbol(lib_file, parent_name)
        except ValueError:
            parent_raw = None

        if parent_raw:
            sub_pat = re.compile(
                r'\t\t\(symbol "' + re.escape(parent_name) + r'_\d+_\d+".*?(?=\n\t\t\(symbol |\n\t\(embedded_fonts|\n\t\))',
                re.DOTALL,
            )
            parent_subs = sub_pat.findall(parent_raw)

            if parent_subs:
                renamed_subs = []
                for sub in parent_subs:
                    renamed_sub = sub.replace(
                        f'(symbol "{parent_name}_',
                        f'(symbol "{sym_name}_',
                        1,
                    )
                    renamed_subs.append(renamed_sub)

                raw = raw.replace(f'(extends "{parent_name}")\n', '', 1)
                injection = "\n".join(renamed_subs)
                last_paren = raw.rfind('\n\t)')
                if last_paren >= 0:
                    raw = raw[:last_paren] + "\n" + injection + raw[last_paren:]

    renamed = raw.replace(f'(symbol "{sym_name}"', f'(symbol "{lib_name}:{sym_name}"', 1)
    return "\n".join("\t" + line for line in renamed.split("\n"))


# -- Schematic element builders ------------------------------------------------

def prop(name, value, x, y, angle=0, hide=False, size=1.27):
    hide_str = "\n\t\t\t\t(hide yes)" if hide else ""
    return f"""\t\t(property "{name}" "{value}"
\t\t\t(at {x:.4f} {y:.4f} {angle})
\t\t\t(show_name no)
\t\t\t(do_not_autoplace no){hide_str}
\t\t\t(effects
\t\t\t\t(font
\t\t\t\t\t(size {size} {size})
\t\t\t\t)
\t\t\t)
\t\t)"""


def sym_inst(lib_id, x, y, angle, ref, value, footprint, datasheet, props_extra,
             pin_numbers, mirror=None, unit=1):
    mirror_str = f'\n\t\t(mirror "{mirror}")' if mirror else ""
    props = [
        prop("Reference", ref, x+2.54, y, angle),
        prop("Value", value, x, y+2.54, angle),
        prop("Footprint", footprint, x, y, angle, hide=True),
        prop("Datasheet", datasheet, x, y, angle, hide=True),
        prop("Description", "", x, y, angle, hide=True),
    ]
    for k, v in props_extra.items():
        props.append(prop(k, v, x, y, angle, hide=True))

    pins_str = "\n".join(
        f'\t\t(pin "{n}"\n\t\t\t(uuid "{gen_uuid()}")\n\t\t)' for n in pin_numbers
    )

    return f"""\t(symbol
\t\t(lib_id "{lib_id}")
\t\t(at {x:.4f} {y:.4f} {angle})
\t\t(unit {unit}){mirror_str}
\t\t(body_style 1)
\t\t(exclude_from_sim no)
\t\t(in_bom yes)
\t\t(on_board yes)
\t\t(in_pos_files yes)
\t\t(dnp no)
\t\t(uuid "{gen_uuid()}")
{chr(10).join(props)}
{pins_str}
\t)"""


def power_sym(lib_id, x, y, ref_n, value=None):
    sym_name = lib_id.split(":")[1]
    if value is None:
        value = sym_name
    return f"""\t(symbol
\t\t(lib_id "{lib_id}")
\t\t(at {x:.4f} {y:.4f} 0)
\t\t(unit 1)
\t\t(body_style 1)
\t\t(exclude_from_sim no)
\t\t(in_bom yes)
\t\t(on_board yes)
\t\t(in_pos_files yes)
\t\t(dnp no)
\t\t(uuid "{gen_uuid()}")
\t\t(property "Reference" "#PWR{ref_n:03d}"
\t\t\t(at {x:.4f} {y-1.27:.4f} 0)
\t\t\t(show_name no)
\t\t\t(do_not_autoplace no)
\t\t\t(hide yes)
\t\t\t(effects (font (size 1.27 1.27)))
\t\t)
\t\t(property "Value" "{value}"
\t\t\t(at {x:.4f} {y+1.27:.4f} 0)
\t\t\t(show_name no)
\t\t\t(do_not_autoplace no)
\t\t\t(effects (font (size 1.27 1.27)))
\t\t)
\t\t(property "Footprint" "" (at {x:.4f} {y:.4f} 0) (hide yes) (effects (font (size 1.27 1.27))))
\t\t(property "Datasheet" "" (at {x:.4f} {y:.4f} 0) (hide yes) (effects (font (size 1.27 1.27))))
\t\t(pin "1"
\t\t\t(uuid "{gen_uuid()}")
\t\t)
\t)"""


def wire(x1, y1, x2, y2):
    return f"""\t(wire
\t\t(pts
\t\t\t(xy {x1:.4f} {y1:.4f}) (xy {x2:.4f} {y2:.4f})
\t\t)
\t\t(stroke (width 0) (type default))
\t\t(uuid "{gen_uuid()}")
\t)"""


def junction(x, y):
    return f'\t(junction (at {x:.4f} {y:.4f}) (diameter 0) (color 0 0 0 0) (uuid "{gen_uuid()}"))'


def no_connect(x, y):
    return f'\t(no_connect (at {x:.4f} {y:.4f}) (uuid "{gen_uuid()}"))'


def text(txt, x, y, size=1.27):
    return f"""\t(text "{txt}"
\t\t(at {x:.4f} {y:.4f} 0)
\t\t(effects (font (size {size} {size})))
\t\t(uuid "{gen_uuid()}")
\t)"""


def net_lbl(txt, x, y, angle=0):
    return (f'\t(label "{txt}"\n'
            f'\t\t(at {x:.4f} {y:.4f} {angle})\n'
            f'\t\t(fields_autoplaced yes)\n'
            f'\t\t(effects (font (size 1.27 1.27)) (justify left bottom))\n'
            f'\t\t(uuid "{gen_uuid()}")\n'
            f'\t)')
