"""Transport tests use a private mock socket; never change real hardware."""
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import threading
import unittest

BINARY = Path(__file__).resolve().parents[1] / 'bin/rog-ipc-bridge'

class BridgeTests(unittest.TestCase):
    def request(self, response, method='monitoring.get', params='{}', fragmented=False):
        with tempfile.TemporaryDirectory(prefix='rog-ipc-test-') as runtime:
            server = socket.socket(socket.AF_UNIX)
            server.bind(runtime + '/ghelper.sock')
            server.listen(1)
            observed = []
            def serve():
                with server:
                    connection, _ = server.accept()
                    with connection:
                        request = json.loads(connection.makefile('rb').readline())
                        observed.append(request)
                        reply = response(request)
                        if reply is not None:
                            data = json.dumps(reply).encode() + b'\n'
                            if fragmented:
                                for part in (data[:8], data[8:]): connection.sendall(part)
                            else: connection.sendall(data)
            thread = threading.Thread(target=serve, daemon=True)
            thread.start()
            result = subprocess.run([str(BINARY), method, params], env={**os.environ, 'XDG_RUNTIME_DIR':runtime}, text=True, capture_output=True, timeout=5)
            thread.join(2)
            return result, json.loads(result.stdout), observed

    def test_fragmented_success_and_request(self):
        result, reply, seen = self.request(lambda r: dict(version=1,id=r['id'],ok=True,result={'cpuTemperatureC':55}), fragmented=True)
        self.assertEqual(result.returncode,0)
        self.assertEqual(reply['result']['cpuTemperatureC'],55)
        self.assertEqual(seen[0]['method'],'monitoring.get')
        self.assertEqual(seen[0]['params'],{})

    def test_mutation_outcomes_preserved(self):
        for state in ('applied','failed','blocked','busy','pending','reboot_required'):
            with self.subTest(state=state):
                _, reply, seen = self.request(lambda r: dict(version=1,id=r['id'],ok=True,result={'state':state,'rebootRequired':True}), 'gpu.set', '{"mode":"ultimate"}')
                self.assertEqual(reply['result']['state'],state)
                self.assertTrue(reply['result']['rebootRequired'])
                self.assertEqual(len(seen),1) # Mutations never retry.

    def test_protocol_error_preserved(self):
        _, reply, _ = self.request(lambda r: dict(version=1,id=r['id'],ok=False,error={'code':'unsupported','message':'Unsupported GPU mode'}))
        self.assertEqual(reply['error']['code'],'unsupported')

    def test_mismatched_id(self):
        result, reply, _ = self.request(lambda r: dict(version=1,id='wrong',ok=True))
        self.assertEqual(result.returncode,1)
        self.assertIn('mismatch',reply['error']['message'])

    def test_incomplete_frame(self):
        result, reply, _ = self.request(lambda r: None)
        self.assertEqual(result.returncode,1)
        self.assertIn('Incomplete',reply['error']['message'])

    def test_invalid_params(self):
        result = subprocess.run([str(BINARY),'gpu.set','[]'], text=True,capture_output=True)
        self.assertEqual(result.returncode,1)
        self.assertIn('object',json.loads(result.stdout)['error']['message'])

    def test_unsafe_runtime(self):
        with tempfile.TemporaryDirectory(prefix='rog-ipc-test-') as runtime:
            os.chmod(runtime,0o755)
            result = subprocess.run([str(BINARY),'monitoring.get'],env={**os.environ,'XDG_RUNTIME_DIR':runtime},text=True,capture_output=True)
            self.assertEqual(result.returncode,1)
            self.assertIn('Unsafe',json.loads(result.stdout)['error']['message'])

if __name__ == '__main__': unittest.main()
