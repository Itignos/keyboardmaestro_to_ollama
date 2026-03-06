# Keyboard Maestro to Ollama Plugin

A Keyboard Maestro Plugin to send text and a prompt to a local Ollama instance and use the response in your macros.

## Installation

1. Create the plugin archive by running `./build.sh`
2. Drag `keyboardmaestro_to_ollama.zip` onto the Keyboard Maestro Dock icon.

## Usage

In Keyboard Maestro, look for the action `keyboardmaestro_to_ollama` under "Third Party Plugins" or by searching.

### Parameters
- **Ollama URL**: The base URL of your Ollama instance (e.g. `http://localhost:11434`).
- **Model**: The model to use (e.g. `llama3`). Ensure you have pulled it via `ollama run llama3` first.
- **Prompt**: The system prompt or instructions (e.g. `Summarize the following:`).
- **Input Text**: The text to process. You can use standard Keyboard Maestro tokens here, such as `%SystemClipboard%` or `%Variable%MyText%`.

The result of the generation is returned natively to Keyboard Maestro, allowing you to "Save to Variable", "Display in Window", or "Save to Clipboard".
