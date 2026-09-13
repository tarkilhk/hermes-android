"""Run unchanged official staging/path functions in a disposable local fixture.

No backend process, credentials, network or deployment is involved.
"""
import ast
import base64
import os
from pathlib import Path
import tempfile

root = Path(__file__).resolve().parents[2] / "build" / "official-desktop-qa"
scope = {"Path": Path, "os": os}


def load_functions(relative, names):
    tree = ast.parse((root / relative).read_text(encoding="utf-8-sig"))
    nodes = [node for node in tree.body if isinstance(node, ast.FunctionDef)
             and node.name in names]
    assert {node.name for node in nodes} == set(names)
    exec(compile(ast.Module(body=nodes, type_ignores=[]), relative, "exec"), scope)


load_functions("tui_gateway/prompt_attachments.py", [
    "_b64_payload", "_sanitize_attachment_name", "_stage_session_file_attachment",
    "_attachment_ref_path",
])
load_functions("agent/context_references.py", ["_is_under", "_resolve_path"])

with tempfile.TemporaryDirectory(prefix="file-boundary-", dir=root) as fixture:
    fixture = Path(fixture)
    workspace = fixture / "workspace"
    workspace.mkdir()
    # Supply only session location lookups normally provided by the gateway.
    scope["_session_cwd"] = lambda session: str(workspace)
    scope["_session_home_dir"] = lambda session, child: fixture / "profile" / child
    payload = b"The fixture value is amber-729."
    target, uploaded = scope["_stage_session_file_attachment"](
        {}, raw_path="", name="fixture.txt",
        data_url="data:text/plain;base64," + base64.b64encode(payload).decode(),
    )
    assert uploaded and target.read_bytes() == payload
    reference = scope["_attachment_ref_path"]({}, target)
    assert Path(reference).is_absolute()
    try:
        scope["_resolve_path"](workspace, reference, allowed_root=workspace)
    except ValueError as error:
        assert str(error) == "path is outside the allowed workspace"
        print("REPRODUCED: official upload returns a path rejected by official context resolution.")
    else:
        raise AssertionError("Expected current outside-workspace failure")
    control = workspace / "control.txt"
    control.write_bytes(payload)
    assert scope["_resolve_path"](workspace, "control.txt", allowed_root=workspace) == control
    print("CONTROL PASSED: file inside workspace resolves normally.")
