import os
from pathlib import Path
import subprocess
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / 'bluetti2mqtt/rootfs/run.sh'
HARNESS = r'''
set -e
bashio::config() {
    case "$1" in
        mode) printf '%s' "$TEST_MODE" ;;
        scan) printf '%s' "$TEST_SCAN" ;;
        debug) printf false ;;
        ha_config) printf normal ;;
        bt_mac) printf '00:11:22:33:44:55 00:11:22:33:44:66' ;;
        poll_sec) printf 30 ;;
        mqtt_host) printf '%s' "$TEST_HOST" ;;
        mqtt_username) printf '%s' "$TEST_USERNAME" ;;
        mqtt_password) printf '%s' "$TEST_PASSWORD" ;;
    esac
}
bashio::config.has_value() { [ -n "$(bashio::config "$1")" ]; }
bashio::config.true() { [ "$TEST_PACKS" == true ]; }
bashio::services() { printf 'SERVICE_LOOKUP\n' >&2; return 1; }
bashio::log.info() { :; }
bashio::log.fatal() { printf '%s\n' "$*" >&2; }
mkdir() { :; }
bluetti-mqtt() { printf '%s\n' bluetti-mqtt "$@"; }
bluetti-logger() { printf '%s\n' bluetti-logger "$@"; }
bluetti-discovery() { printf '%s\n' bluetti-discovery "$@"; }
source "$1"
'''


def run_script(mode='mqtt', host='', packs='false', scan='false', username='', password=''):
    return subprocess.run(
        ['bash', '-c', HARNESS, 'test', str(SCRIPT)],
        env=dict(os.environ, TEST_MODE=mode, TEST_HOST=host, TEST_PACKS=packs,
                 TEST_SCAN=scan, TEST_USERNAME=username, TEST_PASSWORD=password),
        text=True, capture_output=True,
    )


class StartupTests(unittest.TestCase):
    def test_non_mqtt_modes_do_not_discover_broker(self):
        for mode in ('discovery', 'logger'):
            result = run_script(mode=mode)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.splitlines()[0], 'bluetti-' + mode)
            self.assertNotIn('SERVICE_LOOKUP', result.stderr)

    def test_scan_does_not_need_broker(self):
        result = run_script(scan='true')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), ['bluetti-mqtt', '--scan'])
        self.assertNotIn('SERVICE_LOOKUP', result.stderr)

    def test_mqtt_requires_broker(self):
        result = run_script()
        self.assertEqual(result.returncode, 1)
        self.assertIn('Please set', result.stderr)
        self.assertEqual(result.stdout, '')

    def test_standalone_and_expansion_flags(self):
        for mode in ('mqtt', 'logger'):
            for packs in ('false', 'true'):
                result = run_script(mode=mode, host='broker', packs=packs)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual('--ac200l-standalone' in result.stdout.splitlines(),
                                 packs == 'false')

    def test_default_port_and_empty_credentials(self):
        result = run_script(host='broker')
        self.assertEqual(result.returncode, 0, result.stderr)
        args = result.stdout.splitlines()
        self.assertEqual(args[args.index('--port') + 1], '1883')
        self.assertNotIn('--username', args)
        self.assertNotIn('--password', args)
        self.assertEqual(args[-2:], ['00:11:22:33:44:55', '00:11:22:33:44:66'])

    def test_credentials_preserve_spaces_and_shell_characters(self):
        result = run_script(host='broker', username='user name', password='secret * $()')
        self.assertEqual(result.returncode, 0, result.stderr)
        args = result.stdout.splitlines()
        self.assertEqual(args[args.index('--username') + 1], 'user name')
        self.assertEqual(args[args.index('--password') + 1], 'secret * $()')


if __name__ == '__main__':
    unittest.main()
