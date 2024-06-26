import os

from nvim_doc_tools import (
    Vimdoc,
    VimdocSection,
    generate_md_toc,
    indent,
    parse_directory,
    read_section,
    render_md_api2,
    render_vimdoc_api2,
    replace_section,
)
from nvim_doc_tools.apidoc import render_api

HERE = os.path.dirname(__file__)
ROOT = os.path.abspath(os.path.join(HERE, os.path.pardir))
README = os.path.join(ROOT, "README.md")
DOC = os.path.join(ROOT, "doc")
VIMDOC = os.path.join(DOC, "three.txt")


def update_setup_opts():
    config_file = os.path.join(ROOT, "lua", "three", "config.lua")
    opt_lines = read_section(config_file, r"^local default_config =", r"^}$")
    replace_section(
        README,
        r"^require\(\"three\"\).setup\({$",
        r"^}\)$",
        opt_lines,
    )


def get_options_vimdoc() -> "VimdocSection":
    section = VimdocSection("options", "three-options")
    config_file = os.path.join(ROOT, "lua", "three", "config.lua")
    opt_lines = read_section(config_file, r"^local default_config =", r"^}$")
    lines = ["\n", ">\n", '    require("three").setup({\n']
    lines.extend(indent(opt_lines, 4))
    lines.extend(["    })\n", "<\n"])
    section.body = lines
    return section


def generate_vimdoc():
    doc = Vimdoc("three.txt", "three")
    types = parse_directory(os.path.join(ROOT, "lua"))
    doc.sections.extend(
        [
            get_options_vimdoc(),
            VimdocSection(
                "bufferline API",
                "three-bufferline-api",
                render_vimdoc_api2(
                    "three", types.files["three/bufferline/state.lua"].functions, types
                ),
            ),
            VimdocSection(
                "windows API",
                "three-windows-api",
                render_vimdoc_api2(
                    "three", types.files["three/windows/init.lua"].functions, types
                ),
            ),
            VimdocSection(
                "projects API",
                "three-projects-api",
                render_vimdoc_api2(
                    "three", types.files["three/projects/init.lua"].functions, types
                ),
            ),
        ]
    )

    with open(VIMDOC, "w", encoding="utf-8") as ofile:
        ofile.writelines(doc.render())


def update_md_toc(filename: str):
    toc = ["\n"] + generate_md_toc(filename) + ["\n"]
    replace_section(
        filename,
        r"^<!-- TOC -->$",
        r"^<!-- /TOC -->$",
        toc,
    )


def update_readme_toc():
    toc = generate_md_toc(README)
    replace_section(
        README,
        r"^<!-- TOC -->$",
        r"^<!-- /TOC -->$",
        ["\n"] + toc + ["\n"],
    )


def generate_api():
    # Bufferline
    types = parse_directory(os.path.join(ROOT, "lua"))
    file = types.files["three/bufferline/state.lua"]
    replace_section(
        os.path.join(ROOT, "lua", "three", "init.lua"),
        r"^-- BUFFERLINE API$",
        r"^-- /BUFFERLINE API$",
        ["\n"]
        + render_api(
            file,
            types,
            lambda f, t: f'M.{f.name} = lazy("bufferline.state", "{f.name}")',
        )
        + ["\n"],
    )

    # Windows
    file = types.files["three/windows/init.lua"]
    replace_section(
        os.path.join(ROOT, "lua", "three", "init.lua"),
        r"^-- WINDOWS API$",
        r"^-- /WINDOWS API$",
        ["\n"]
        + render_api(
            file, types, lambda f, t: f'M.{f.name} = lazy("windows", "{f.name}")'
        )
        + ["\n"],
    )

    # Projects
    file = types.files["three/projects/init.lua"]
    replace_section(
        os.path.join(ROOT, "lua", "three", "init.lua"),
        r"^-- PROJECTS API$",
        r"^-- /PROJECTS API$",
        ["\n"]
        + render_api(
            file, types, lambda f, t: f'M.{f.name} = lazy("projects", "{f.name}")'
        )
        + ["\n"],
    )


def update_md_api():
    types = parse_directory(os.path.join(ROOT, "lua"))
    funcs = types.files["three/bufferline/state.lua"].functions
    lines = ["\n"] + render_md_api2(funcs, types) + ["\n"]
    replace_section(
        README,
        r"^<!-- bufferline API -->$",
        r"^<!-- /bufferline API -->$",
        lines,
    )

    funcs = types.files["three/windows/init.lua"].functions
    lines = ["\n"] + render_md_api2(funcs, types) + ["\n"]
    replace_section(
        README,
        r"^<!-- windows API -->$",
        r"^<!-- /windows API -->$",
        lines,
    )

    funcs = types.files["three/projects/init.lua"].functions
    lines = ["\n"] + render_md_api2(funcs, types) + ["\n"]
    replace_section(
        README,
        r"^<!-- projects API -->$",
        r"^<!-- /projects API -->$",
        lines,
    )


def main() -> None:
    """Update the README"""
    generate_api()
    # TODO generate docs for highlight groups
    update_setup_opts()
    update_md_api()
    generate_vimdoc()
    update_readme_toc()
