#!/bin/bash
# Keyboard Maestro passes parameters as environment variables prefixed with KMPARAM_
# Spaces in parameter names are replaced with underscores.

OLLAMA_URL="$KMPARAM_Ollama_URL"
MODEL="$KMPARAM_Model"
PROMPT="$KMPARAM_Prompt"
INPUT_TEXT="$KMPARAM_Input_Text"

# Export them so python3 can access them
export OLLAMA_URL
export MODEL
export PROMPT
export INPUT_TEXT

# We use python3 to construct the JSON and make the request to avoid needing jq
python3 -c '
import os
import json
import urllib.request
import sys

url = os.environ.get("OLLAMA_URL", "http://localhost:11434").rstrip("/") + "/api/generate"
model = os.environ.get("MODEL", "llama3")
prompt = os.environ.get("PROMPT", "")
input_text = os.environ.get("INPUT_TEXT", "")

# Combine prompt and input text. If both are present, add newlines between them.
if prompt and input_text:
    full_prompt = prompt + "\n\n" + input_text
elif prompt:
    full_prompt = prompt
else:
    full_prompt = input_text

data = {
    "model": model,
    "prompt": full_prompt,
    "stream": False
}

req = urllib.request.Request(url, data=json.dumps(data).encode("utf-8"), headers={"Content-Type": "application/json"})

try:
    with urllib.request.urlopen(req) as response:
        res = json.loads(response.read().decode("utf-8"))
        print(res.get("response", ""))
except Exception as e:
    print(f"Error communicating with Ollama: {e}", file=sys.stderr)
    sys.exit(1)
'
