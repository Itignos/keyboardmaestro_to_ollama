#!/bin/bash
# Keyboard Maestro passes parameters as environment variables prefixed with KMPARAM_.
# Spaces in parameter names are replaced with underscores.

OLLAMA_URL="$KMPARAM_Ollama_URL"
MODEL="$KMPARAM_Model"
PROMPT="$KMPARAM_Prompt"
INPUT_TEXT="$KMPARAM_Input_Text"

export OLLAMA_URL MODEL PROMPT INPUT_TEXT

# Keyboard Maestro does not reliably surface stderr from third-party actions.
if ! result="$(python3 -c '
import json
import os
import sys
import urllib.error
import urllib.request

base_url = os.environ.get("OLLAMA_URL", "http://localhost:11434").strip().rstrip("/")
model = os.environ.get("MODEL", "llama3").strip()
prompt = os.environ.get("PROMPT", "")
input_text = os.environ.get("INPUT_TEXT", "")

if not base_url:
    print("Ollama URL is required.", file=sys.stderr)
    sys.exit(1)
if not model:
    print("Model is required.", file=sys.stderr)
    sys.exit(1)

if prompt and input_text:
    full_prompt = prompt + "\n\n" + input_text
elif prompt:
    full_prompt = prompt
else:
    full_prompt = input_text

request = urllib.request.Request(
    base_url + "/api/generate",
    data=json.dumps({"model": model, "prompt": full_prompt, "stream": False}).encode("utf-8"),
    headers={"Content-Type": "application/json"},
)

try:
    with urllib.request.urlopen(request) as response:
        payload = json.loads(response.read().decode("utf-8"))
except urllib.error.HTTPError as error:
    response_body = error.read().decode("utf-8", errors="replace")
    print(f"Ollama returned HTTP {error.code}: {response_body}", file=sys.stderr)
    sys.exit(1)
except (urllib.error.URLError, OSError) as error:
    print(f"Could not communicate with Ollama: {error}", file=sys.stderr)
    sys.exit(1)
except json.JSONDecodeError as error:
    print(f"Ollama returned invalid JSON: {error}", file=sys.stderr)
    sys.exit(1)

content = payload.get("response")
if not isinstance(content, str) or not content:
    print("Ollama returned empty or non-text response content.", file=sys.stderr)
    sys.exit(1)

print(content)
' 2>&1
)"; then
    osascript -e 'on run argv
display alert "Ollama request failed" message (item 1 of argv) as critical
end run' -- "$result" >/dev/null 2>&1 || true
    printf '%s\n' "$result" >&2
    exit 1
fi

printf '%s\n' "$result"
