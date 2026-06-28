import re

_REASONING_MODEL_PATTERN = re.compile(r"^(o\d|gpt-5)", re.IGNORECASE)


def is_reasoning_model(model: str) -> bool:
    """True for o-series/gpt-5-family reasoning models, which require a
    `reasoning.effort` request param and reject `temperature` — unlike
    `-chat` variants of the same families, which behave like regular
    chat models."""
    name = model.lower()
    if "chat" in name:
        return False
    return bool(_REASONING_MODEL_PATTERN.match(name))


def extract_output_text(data: dict) -> str:
    """Finds the assistant message in a Responses API payload.
    Reasoning models prepend a `type: reasoning` item with no text, so
    the message can't be assumed to be output[0]."""
    for item in data["output"]:
        if item.get("type") == "message":
            return item["content"][0]["text"]
    raise KeyError("No message item in output")
