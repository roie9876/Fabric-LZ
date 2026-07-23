import importlib.util
from pathlib import Path


def load_app_module():
    module_path = Path(__file__).with_name("app.py")
    spec = importlib.util.spec_from_file_location("external_agent_app", module_path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_required_setting(monkeypatch):
    module = load_app_module()
    monkeypatch.setenv("SETTING", "value")
    assert module.required_setting("SETTING") == "value"


def test_required_setting_rejects_missing_value(monkeypatch):
    module = load_app_module()
    monkeypatch.delenv("SETTING", raising=False)
    try:
        module.required_setting("SETTING")
    except RuntimeError as exc:
        assert "SETTING" in str(exc)
    else:
        raise AssertionError("required_setting accepted a missing value")