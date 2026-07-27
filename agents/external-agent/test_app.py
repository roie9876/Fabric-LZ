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


def test_external_agent_id_default(monkeypatch):
    module = load_app_module()
    monkeypatch.delenv("OTEL_AGENT_ID", raising=False)
    assert module.os.getenv("OTEL_AGENT_ID", "external-agent-v1") == "external-agent-v1"


def test_set_token_usage():
    module = load_app_module()

    class Span:
        attributes = {}

        def set_attribute(self, name, value):
            self.attributes[name] = value

    span = Span()
    module.set_token_usage(
        span,
        {"input_token_count": 21, "output_token_count": 8},
    )

    assert span.attributes == {
        "gen_ai.usage.input_tokens": 21,
        "gen_ai.usage.output_tokens": 8,
    }


def test_set_token_usage_accepts_missing_usage():
    module = load_app_module()

    class Span:
        def set_attribute(self, name, value):
            raise AssertionError("No attributes should be set")

    module.set_token_usage(Span(), None)