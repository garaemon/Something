#!/usr/bin/env python3
"""Generates docs/python-api.md from the docstrings of the `something` module.

The module is the Python prelude inside Something/PythonExtensionPrelude.swift, so the
docstrings there are the single source of truth. Uses the Python 3 standard library only.

    generate_python_api_docs.py           write docs/python-api.md
    generate_python_api_docs.py --check   write nothing, and exit 1 when the file is stale
"""

import argparse
import ast
import pathlib
import re
import sys

REPOSITORY_ROOT = pathlib.Path(__file__).resolve().parents[2]
PRELUDE_PATH = REPOSITORY_ROOT / "Something" / "PythonExtensionPrelude.swift"
OUTPUT_PATH = REPOSITORY_ROOT / "docs" / "python-api.md"

_SOURCE_PATTERN = re.compile(r'static let source = #"""\n(.*?)\n( *)"""#', re.DOTALL)


class DocumentationError(Exception):
    """The prelude cannot be turned into a reference."""


def extract_prelude(swift_source):
    """Returns the Python text of the prelude, without the Swift indentation."""
    match = _SOURCE_PATTERN.search(swift_source)
    if match is None:
        raise DocumentationError("No `static let source = #\"\"\"` string in the Swift file.")
    body, indent = match.group(1), match.group(2)
    lines = []
    for number, line in enumerate(body.split("\n"), 1):
        if line.strip() and not line.startswith(indent):
            raise DocumentationError(f"Prelude line {number} is indented less than its end.")
        lines.append(line[len(indent):] if line.strip() else "")
    return "\n".join(lines) + "\n"


def is_public(name):
    return not name.startswith("_")


def format_arguments(arguments, skip_first=False):
    """Returns the parameter list of a function, with defaults, as written in Python."""
    positional = arguments.posonlyargs + arguments.args
    defaults = [None] * (len(positional) - len(arguments.defaults)) + arguments.defaults
    parts = []
    for argument, default in zip(positional, defaults):
        parts.append(argument.arg if default is None else f"{argument.arg}={ast.unparse(default)}")
    if arguments.vararg:
        parts.append("*" + arguments.vararg.arg)
    elif arguments.kwonlyargs:
        parts.append("*")
    for argument, default in zip(arguments.kwonlyargs, arguments.kw_defaults):
        parts.append(argument.arg if default is None else f"{argument.arg}={ast.unparse(default)}")
    if arguments.kwarg:
        parts.append("**" + arguments.kwarg.arg)
    return ", ".join(parts[1:] if skip_first else parts)


def require_docstring(node, qualified_name):
    docstring = ast.get_docstring(node)
    if not docstring:
        raise DocumentationError(
            f"The public name `{qualified_name}` has no docstring. "
            "Add one in Something/PythonExtensionPrelude.swift."
        )
    return docstring


def document_function(function, qualified_name, heading_level, skip_first=False):
    signature = f"{qualified_name}({format_arguments(function.args, skip_first)})"
    docstring = require_docstring(function, qualified_name)
    return f"{'#' * heading_level} `{signature}`\n\n{docstring}\n"


def document_class(class_node, module_name):
    qualified_name = f"{module_name}.{class_node.name}"
    docstring = require_docstring(class_node, qualified_name)
    sections = [f"## class `{qualified_name}`\n\n{docstring}\n"]
    for member in class_node.body:
        if isinstance(member, (ast.FunctionDef, ast.AsyncFunctionDef)) and is_public(member.name):
            sections.append(
                document_function(
                    member, f"{class_node.name}.{member.name}", 3, skip_first=True
                )
            )
    return "\n".join(sections)


def render(prelude, module_name="something"):
    tree = ast.parse(prelude)
    introduction = require_docstring(tree, module_name)
    sections = []
    for node in tree.body:
        if isinstance(node, ast.ClassDef) and is_public(node.name):
            sections.append(document_class(node, module_name))
        elif isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and is_public(node.name):
            sections.append(document_function(node, f"{module_name}.{node.name}", 2))
    header = (
        f"# Python API: `{module_name}`\n\n"
        "This file is generated from the docstrings in "
        "`Something/PythonExtensionPrelude.swift` by "
        "`Tools/PythonAPIDocs/generate_python_api_docs.py`. Do not edit it by hand. "
        "Change the docstring, then run `mise run docs`.\n"
    )
    return header + "\n" + introduction + "\n\n" + "\n".join(sections)


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument(
        "--check",
        action="store_true",
        help="write nothing, and exit 1 when docs/python-api.md differs from the docstrings",
    )
    arguments = parser.parse_args()
    try:
        prelude = extract_prelude(PRELUDE_PATH.read_text(encoding="utf-8"))
        generated = render(prelude)
    except DocumentationError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    relative_output = OUTPUT_PATH.relative_to(REPOSITORY_ROOT)
    if arguments.check:
        current = OUTPUT_PATH.read_text(encoding="utf-8") if OUTPUT_PATH.exists() else None
        if current != generated:
            print(
                f"error: {relative_output} is out of date with the docstrings in "
                f"{PRELUDE_PATH.relative_to(REPOSITORY_ROOT)}. Run `mise run docs` and "
                "commit the result.",
                file=sys.stderr,
            )
            return 1
        return 0
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(generated, encoding="utf-8")
    print(f"Wrote {relative_output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
