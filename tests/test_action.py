import json
import os
import subprocess
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
ACTION_SCRIPT = PROJECT_ROOT / "Action.sh"


class _OllamaErrorHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        response = json.dumps({"error": "model is unavailable"}).encode("utf-8")
        self.send_response(500)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(response)))
        self.end_headers()
        self.wfile.write(response)

    def log_message(self, format, *args):
        pass


class OllamaActionTests(unittest.TestCase):
    def setUp(self):
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), _OllamaErrorHandler)
        self.thread = threading.Thread(target=self.server.serve_forever)
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()

    def test_shows_dialog_when_ollama_endpoint_returns_an_error(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            temporary_path = Path(temporary_directory)
            osascript_args = temporary_path / "osascript-args.txt"
            osascript = temporary_path / "osascript"
            osascript.write_text(
                "#!/bin/sh\nprintf '%s\\n' \"$@\" > \"$KM_OSASCRIPT_ARGS\"\n"
            )
            osascript.chmod(0o755)
            environment = os.environ | {
                "KMPARAM_Ollama_URL": f"http://127.0.0.1:{self.server.server_address[1]}",
                "KMPARAM_Model": "test-model",
                "KMPARAM_Prompt": "Reply only with OK.",
                "KMPARAM_Input_Text": "",
                "KM_OSASCRIPT_ARGS": str(osascript_args),
                "PATH": f"{temporary_directory}:{os.environ['PATH']}",
            }

            result = subprocess.run(
                [str(ACTION_SCRIPT)],
                cwd=PROJECT_ROOT,
                env=environment,
                capture_output=True,
                text=True,
                check=False,
            )

            self.assertNotEqual(result.returncode, 0)
            self.assertIn("HTTP 500", result.stderr)
            self.assertTrue(osascript_args.exists())
            self.assertIn("model is unavailable", osascript_args.read_text())


if __name__ == "__main__":
    unittest.main()
