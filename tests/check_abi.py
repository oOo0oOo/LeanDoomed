#!/usr/bin/env python3
"""Compare the C declarations and DrawColumn layout with the current compiler."""
import pathlib
import re
import subprocess
import tempfile

with tempfile.TemporaryDirectory(prefix="leansdl-abi-") as tmp:
    generated = pathlib.Path(tmp) / "SDL.c"
    subprocess.run(["lake", "env", "lean", "SDL.lean", "-c", str(generated)], check=True)
    source = generated.read_text()
    pattern = r"^lean_object\* sdl_\w+\([^\n]*\);"
    expected = {declaration.replace("();", "(void);") for declaration in re.findall(pattern, source, re.M)}
    actual = set(re.findall(pattern, pathlib.Path("c/sdl_abi.h").read_text(), re.M))
    assert expected == actual, f"ABI header differs: missing {expected-actual}, extra {actual-expected}"
    assert len(expected) == 19
    layout = pathlib.Path(tmp) / "Layout.c"
    subprocess.run(["lake", "env", "lean", "tests/Layout.lean", "-c", str(layout)], check=True)
    source = layout.read_text()
    for field, offset, scalar in [("x", 0, "uint32"), ("y", 4, "uint32"), ("height", 8, "uint32"),
                                  ("texX", 12, "uint32"), ("texYStart", 16, "uint32"),
                                  ("texYEnd", 20, "uint32"), ("shade", 24, "uint8")]:
        match = re.search(r"test_column_" + field + r"\([^)]*\)\{(.*?)\n\}", source, re.S)
        assert match and re.search(r"lean_ctor_get_" + scalar + r"\([^,]+, " + str(offset) + r"\)", match[1]), field
print("Generated ABI and DrawColumn layout match")
