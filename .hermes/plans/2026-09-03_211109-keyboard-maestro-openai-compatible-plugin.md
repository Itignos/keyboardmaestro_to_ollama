# Keyboard Maestro OpenAI-Compatible Plugin Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** Deliver a separate Keyboard Maestro plugin for oMLX and other OpenAI-compatible Chat Completions endpoints, without changing the existing Ollama plugin’s protocol or user interface.

**Architecture:** Keep `keyboardmaestro_to_ollama` as an Ollama-native plugin using `POST /api/generate`. Create a sibling plugin named `keyboardmaestro_to_openai` that takes a complete OpenAI-compatible base URL, model ID, prompt, input text, and optional API key; it sends `POST /chat/completions` and returns `choices[0].message.content` to Keyboard Maestro. oMLX is configured without special code as `http://localhost:8000/v1`.

**Tech Stack:** Keyboard Maestro third-party plugin plist, Bash, macOS `python3` stdlib (`json`, `urllib.request`), `plutil`, `curl`.

---

## Current analysis

- The repository is deliberately small: `Action.sh` and `Keyboard Maestro Action.plist` are the runtime implementation; `build.sh` creates the installation archive.
- Current request contract in `Action.sh:23-47` is Ollama-specific:
  - endpoint: `<Ollama URL>/api/generate`
  - request: `{model, prompt, stream: false}`
  - response output: `response`
- oMLX publishes an OpenAI-compatible endpoint at `http://localhost:8000/v1`, specifically `POST /v1/chat/completions`; the expected response text is `choices[0].message.content`.
- Therefore, merely replacing the URL in the current plugin will not work. The endpoint path, JSON request structure, and response parsing are different.
- oMLX does not need a bespoke plugin: its compatibility surface is the generic OpenAI Chat Completions API. A dedicated `keyboardmaestro_to_omlx` plugin would duplicate code and create maintenance work for only one preset.

## Recommendation

Create a **separate `keyboardmaestro_to_openai` plugin**, rather than modifying this Ollama plugin or creating `keyboardmaestro_to_omlx`.

Why:

1. The current plugin remains byte-for-byte compatible for current users and macros.
2. The generic plugin supports oMLX immediately and also LM Studio, llama.cpp server, vLLM, LiteLLM, OpenAI, and similar endpoints implementing Chat Completions.
3. It has only one additional user-facing parameter: an optional API key.
4. oMLX setup stays simple:
   - **Base URL:** `http://localhost:8000/v1`
   - **API Key:** blank by default; set it only if oMLX was started with `--api-key`
   - **Model:** an ID returned from `GET /v1/models` or an oMLX model alias.

## Scope and compatibility decisions

- First release is **text-only, non-streaming Chat Completions**.
- Preserve current macro semantics: `Prompt` is the instruction and `Input Text` is the processed content.
- Map this cleanly to the OpenAI schema as two messages:
  1. `{role: "system", content: Prompt}` when `Prompt` is non-empty.
  2. `{role: "user", content: Input Text}` when input is non-empty.
- If both fields are empty, return a clear local validation error without making an HTTP request.
- Build a canonical endpoint URL: remove trailing `/` from the base URL, then append `/chat/completions`. This means the parameter must include `/v1` for compliant endpoints.
- Send `Authorization: Bearer <API key>` only if the optional key is non-empty. This supports unauthenticated localhost oMLX and authenticated remote providers alike.
- Treat the API key as a Keyboard Maestro action parameter, not a system keychain secret. Document that Keyboard Maestro macro/plugin configuration is not an appropriate secret vault for high-value production credentials. A later keychain integration would be a separate feature, not part of the minimal plugin.

## Task 1: Create the new plugin project from the proven Ollama structure

**Objective:** Start a sibling `keyboardmaestro_to_openai` repository/directory without altering the original source tree’s runtime files.

**Files:**
- Create: sibling project `keyboardmaestro_to_openai/Action.sh`
- Create: sibling project `keyboardmaestro_to_openai/Keyboard Maestro Action.plist`
- Create: sibling project `keyboardmaestro_to_openai/build.sh`
- Create: sibling project `keyboardmaestro_to_openai/README.md`
- Create: sibling project `keyboardmaestro_to_openai/tests/test_action.py`

**Step 1: Copy structure only**

Copy the four source files as a starting point, but set all plugin identity strings to `keyboardmaestro_to_openai`. Do not change the existing `keyboardmaestro_to_ollama` files.

**Step 2: Define action parameters in `Keyboard Maestro Action.plist`**

Use these parameters in this order:

| Label | Type | Default |
|---|---|---|
| OpenAI Base URL | String | `http://localhost:8000/v1` |
| API Key | String | empty |
| Model | String | empty |
| Prompt | Text | `Summarize the following text:` |
| Input Text | TokenText | `%SystemClipboard%` |

Set the title to `OpenAI Generate with %Param%Model%`.

**Step 3: Verify plist and shell syntax**

Run:

```bash
plutil -lint 'Keyboard Maestro Action.plist'
bash -n Action.sh
```

Expected: `Keyboard Maestro Action.plist: OK` and no shell diagnostic.

## Task 2: Implement a focused OpenAI Chat Completions request client

**Objective:** Send text requests to any compliant endpoint and emit only the assistant text on stdout.

**Files:**
- Modify: sibling project `Action.sh`
- Test: sibling project `tests/test_action.py`

**Step 1: Write failing contract tests using a local Python HTTP server**

The test server must capture the request and return fixture responses. Cover:

1. Base URL `http://127.0.0.1:<port>/v1` becomes `POST /v1/chat/completions`.
2. The request body has `model`, `messages`, and `stream: false`.
3. Non-empty prompt becomes the first `system` message.
4. Input text becomes the `user` message without string concatenation or quoting errors.
5. Blank API key produces no `Authorization` header.
6. A supplied API key produces exactly `Authorization: Bearer <value>`.
7. A valid `choices[0].message.content` is printed exactly to stdout.

**Step 2: Run the test to confirm failure**

Run:

```bash
python3 -m unittest -v tests.test_action
```

Expected: failure until the generic request format exists.

**Step 3: Implement request construction**

Replace the Ollama-specific environment names with `OPENAI_BASE_URL`, `API_KEY`, `MODEL`, `PROMPT`, and `INPUT_TEXT`.

Use Python stdlib code embedded in the shell script, as the existing plugin does:

- construct a `messages` list conditionally;
- encode JSON with `json.dumps`;
- set `Content-Type: application/json`;
- add `Authorization` only for a non-empty key;
- call the derived `/chat/completions` URL;
- extract a string from `res["choices"][0]["message"]["content"]`.

Do not add the OpenAI Python SDK; it is unnecessary and would make the Keyboard Maestro plugin dependent on an external Python package.

**Step 4: Add actionable error handling**

Handle separately:

- empty base URL/model/input validation;
- HTTP status errors, including the response body when safely decodable;
- transport failures;
- syntactically valid but non-Chat-Completions JSON responses;
- empty or non-text response content.

All errors go to stderr and result in a non-zero exit code. Do not print errors to stdout, because Keyboard Maestro treats stdout as the action result.

**Step 5: Re-run focused tests**

Run:

```bash
python3 -m unittest -v tests.test_action
```

Expected: all local request/response contract tests pass.

## Task 3: Package and smoke-test the Keyboard Maestro plugin archive

**Objective:** Produce an installable archive and verify its exact contents.

**Files:**
- Modify: sibling project `build.sh`

**Step 1: Set the new archive identity**

Set `PLUGIN_NAME="keyboardmaestro_to_openai"`, retain the current packaging layout, and include only `Keyboard Maestro Action.plist` and executable `Action.sh`.

**Step 2: Build**

Run:

```bash
./build.sh
unzip -l keyboardmaestro_to_openai.zip
```

Expected archive layout:

```text
keyboardmaestro_to_openai/Keyboard Maestro Action.plist
keyboardmaestro_to_openai/Action.sh
```

**Step 3: Inspect installation artifact**

Verify `Action.sh` retains executable mode in the ZIP and `plutil -lint` succeeds for the archived plist after extraction to a temporary directory.

## Task 4: Verify against a real local oMLX server

**Objective:** Confirm real rather than simulated compatibility.

**Files:**
- No code changes expected.

**Step 1: Confirm oMLX availability and select a model ID**

Run:

```bash
curl --fail --silent --show-error http://localhost:8000/v1/models
```

If oMLX is configured on another port, use its configured base URL. Select an actual `data[].id` model value.

**Step 2: Test without authentication**

Run the plugin script with Keyboard Maestro-shaped environment variables against the local oMLX server, using a deterministic instruction such as `Reply only with: OK`.

Expected: stdout is `OK` (or the model’s exact requested output), stderr is empty, and exit status is zero.

**Step 3: Test authenticated oMLX only when the user has enabled `--api-key`**

Repeat with the configured API key supplied only through the test process environment. Do not write, log, commit, or include the key in tests or documentation.

Expected: request succeeds with the optional Bearer header.

## Task 5: Document the distinct plugins and endpoint examples

**Objective:** Make the right choice discoverable without blurring the Ollama and OpenAI protocols.

**Files:**
- Modify: sibling project `README.md`
- Optional Modify: this repository `README.md` only to link to the new repository after it exists

**Step 1: Document protocol distinction**

State that the original plugin is for Ollama’s native `/api/generate` API and the new plugin is for OpenAI-compatible `/v1/chat/completions` APIs.

**Step 2: Add configuration examples**

Include:

| Provider | Base URL | API Key |
|---|---|---|
| oMLX | `http://localhost:8000/v1` | blank unless server auth is enabled |
| OpenAI | `https://api.openai.com/v1` | required |
| LM Studio / llama.cpp / vLLM | their documented `/v1` base URL | provider-specific |

**Step 3: Document security boundary**

Explain that a non-empty API key is sent as a standard Bearer token to the configured URL. Advise HTTPS for non-local endpoints and never include real keys in shared macros, screenshots, repositories, or issue reports.

## Validation matrix

| Scenario | Required result |
|---|---|
| Existing Ollama plugin | No source or behavior change |
| oMLX without `--api-key` | Works with `http://localhost:8000/v1`, no Authorization header |
| oMLX with `--api-key` | Works with optional Bearer token |
| Generic compliant endpoint | Works with manual model ID and `/v1` base URL |
| API failure | Stderr diagnostic, non-zero status, no accidental stdout result |
| Packaging | Plugin ZIP contains exactly the executable action and valid plist |

## Risks and trade-offs

- **API equivalence is not perfect:** “OpenAI-compatible” servers vary. This plan intentionally targets the stable Chat Completions subset, not tools, JSON schema, vision, streaming, or the newer Responses API.
- **Prompt semantics change slightly:** Ollama receives one concatenated prompt; OpenAI-compatible servers receive explicit system/user roles. This is semantically preferable, but generated output may differ for the same model.
- **Credentials:** a plain `API Key` action parameter is easy to use but not dedicated secure storage. Keychain-backed lookup is possible later if this becomes a requirement.
- **No model auto-discovery in v1:** model IDs remain manual. A “Test / list models” UI would be more work and is not needed to make oMLX usable.

## Completion criteria

- The existing Ollama repository has no runtime code changes.
- `keyboardmaestro_to_openai.zip` installs as a separate Keyboard Maestro third-party action.
- Contract tests pass locally.
- A real oMLX `POST /v1/chat/completions` request succeeds using a discovered model ID.
- README documents oMLX and API-key configuration without exposing any credential.
