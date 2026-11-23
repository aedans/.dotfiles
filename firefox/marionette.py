# Drives a headless Firefox over Marionette (its remote control protocol) to
# run scripts inside extension pages, where the extensions' own APIs are.

import json
import os
import socket
import subprocess
import time

PORT = 2828


class Marionette:
    def __init__(self, port=PORT, timeout=30):
        deadline = time.monotonic() + timeout
        while True:
            try:
                self.sock = socket.create_connection(("127.0.0.1", port))
                break
            except OSError:
                if time.monotonic() > deadline:
                    raise
                time.sleep(0.2)
        self.buffer = b""
        self.id = 0
        self.read()  # the server's greeting

    def read(self):
        while b":" not in self.buffer:
            self.recv()
        length, self.buffer = self.buffer.split(b":", 1)
        while len(self.buffer) < int(length):
            self.recv()
        message, self.buffer = self.buffer[: int(length)], self.buffer[int(length) :]
        return json.loads(message)

    def recv(self):
        chunk = self.sock.recv(1 << 16)
        if not chunk:
            raise ConnectionError("Firefox closed the Marionette connection")
        self.buffer += chunk

    def command(self, name, params=None):
        self.id += 1
        message = json.dumps([0, self.id, name, params or {}]).encode()
        self.sock.sendall(str(len(message)).encode() + b":" + message)
        _, _, error, result = self.read()
        if error:
            raise RuntimeError(f"{name}: {error['message']}")
        return result

    def execute(self, script, *args):
        # Marionette awaits a returned promise.
        body = f"return (async (...args) => {{\n{script}\n}})(...arguments);"
        return self.command("WebDriver:ExecuteScript", {"script": body, "args": list(args)})["value"]


class Firefox:
    """A headless Firefox on `profile` (Firefox's own choice when None)."""

    def __init__(self, profile=None):
        self.profile = profile

    def __enter__(self):
        command = ["firefox", "--headless", "--marionette", "--remote-allow-system-access", "--no-remote"]
        if self.profile:
            command += ["--profile", self.profile]
        # Newer Firefox ignores --remote-allow-system-access without this.
        env = {**os.environ, "MOZ_REMOTE_ALLOW_SYSTEM_ACCESS": "1"}
        self.process = subprocess.Popen(command, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            self.marionette = Marionette()
            self.marionette.command("WebDriver:NewSession", {"capabilities": {}})
            self.marionette.command("WebDriver:SetTimeouts", {"script": 300_000, "pageLoad": 60_000})
        except BaseException:
            self.process.kill()
            raise
        return self

    def __exit__(self, *exc):
        try:
            self.marionette.command("Marionette:Quit", {"flags": ["eAttemptQuit"]})
            self.process.wait(30)
        except Exception:
            self.process.kill()

    def open_extension(self, id, page, timeout=120):
        """Navigates to one of the add-on's pages, waiting for it to be
        installed first: policies install add-ons in the background."""
        m = self.marionette
        m.command("Marionette:SetContext", {"value": "chrome"})
        host = m.execute(
            """
            const [id, timeout] = args;
            for (const deadline = Date.now() + timeout; Date.now() < deadline; ) {
              const policy = WebExtensionPolicy.getByID(id);
              if (policy) return policy.mozExtensionHostname;
              await new Promise(resolve => setTimeout(resolve, 500));
            }
            return null;
            """,
            id,
            timeout * 1000,
        )
        if not host:
            raise RuntimeError(f"{id} isn't installed (is it in extensions.txt?)")
        m.command("Marionette:SetContext", {"value": "content"})
        m.command("WebDriver:Navigate", {"url": f"moz-extension://{host}/{page}"})
