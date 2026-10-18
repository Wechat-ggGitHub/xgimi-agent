#!/usr/bin/env python3
"""Local Z7X remote. Reuse the installed Mac app's wake signal and helper."""
import argparse
import contextlib
import fcntl
import ipaddress
import json
import os
from pathlib import Path
import plistlib
import socket
import subprocess
import sys
import time
import uuid

DOMAIN = 'io.github.wechatgg.xgimi-agent'
DEFAULT_HOST = None
CODES = {'up': 36, 'down': 38, 'left': 50, 'right': 37, 'ok': 49,
         'back': 48, 'home': 35, 'menu': 139, 'volume-down': 114,
         'volume-up': 115, 'mute': 113, 'off': 30}
CACHE = Path.home() / 'Library/Caches' / DOMAIN


def preferences():
    r = subprocess.run(['/usr/bin/defaults', 'export', DOMAIN, '-'],
                       capture_output=True, timeout=5)
    return plistlib.loads(r.stdout) if r.returncode == 0 else {}


def valid_signal(value):
    return (isinstance(value, bytes) and len(value) == 21
            and value[6:9] == b'\xff\xff\xff'
            and value[9:15] == b'3CRKTM' and value[15:] == bytes(6))


def find_helper():
    for app in [Path.home() / 'Applications/极米遥控.app', Path('/Applications/极米遥控.app')]:
        helper = app / 'Contents/Helpers/极米开机助手.app'
        info = helper / 'Contents/Info.plist'
        if info.is_file():
            meta = plistlib.loads(info.read_bytes())
            if (meta.get('CFBundleIdentifier') == 'io.github.wechatgg.xgimi-agent.wake'
                    and meta.get('CFBundleExecutable') == 'Z7XWakeHelper'
                    and (helper / 'Contents/MacOS/Z7XWakeHelper').is_file()):
                return helper, meta.get('CFBundleShortVersionString')
    return None, None


def reachable(host, timeout=0.8):
    try:
        with socket.create_connection((host, 8080), timeout=timeout):
            return True
    except OSError:
        return False


def send_key(host, action, count=1, delay=0.25, port=16735):
    if action not in CODES or not 1 <= count <= 20:
        raise ValueError('Unsupported key or repeat count')
    if action in ('off', 'mute') and count != 1:
        raise ValueError('Power and mute are sent once only')
    payload = f'KEYPRESSES:{CODES[action]}'.encode('ascii')
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.settimeout(2)
        for i in range(count):
            sent = sock.sendto(payload, (host, port))
            if sent != len(payload):
                raise OSError('Incomplete UDP packet')
            if i + 1 < count:
                time.sleep(delay)
    return {'status': 'sent', 'action': action, 'count': count,
            'transport': 'wifi_udp', 'device_acknowledged': False}


@contextlib.contextmanager
def control_lock():
    CACHE.mkdir(parents=True, exist_ok=True)
    with (CACHE / 'AgentControl.lock').open('a') as handle:
        try:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError('Another projector command is running; do not resend yet')
        try:
            yield
        finally:
            fcntl.flock(handle, fcntl.LOCK_UN)


def wake(host, prefs, wait_seconds):
    if reachable(host):
        return {'status': 'already_reachable', 'action': 'on',
                'network_reachable': True, 'projection_confirmed': False}
    if not valid_signal(prefs.get('wakeBeaconData')):
        raise RuntimeError('No saved wake signal. Learn it in the installed 极米遥控 app')
    helper, version = find_helper()
    if helper is None:
        raise RuntimeError('Installed 极米遥控 app or its wake helper is missing')
    running = subprocess.run(['/usr/bin/pgrep', '-x', 'Z7XWakeHelper'],
                             capture_output=True, timeout=3)
    if running.returncode == 0:
        raise RuntimeError('The wake helper is already running; do not start another broadcast')
    attempt = str(uuid.uuid4()).upper()
    result_path = CACHE / 'WakeResults' / (attempt + '.json')
    opened = subprocess.run(['/usr/bin/open', '-n', '-g', str(helper), '--args',
                             '--attempt', attempt], capture_output=True, text=True, timeout=8)
    if opened.returncode != 0:
        raise RuntimeError('macOS could not launch the existing wake helper: ' + opened.stderr.strip())
    deadline = time.monotonic() + 32
    result = None
    try:
        while time.monotonic() < deadline:
            if result_path.is_file():
                try:
                    value = json.loads(result_path.read_text())
                    if value.get('attempt', '').upper() == attempt:
                        result = value
                        if value.get('completed') is True:
                            break
                except (OSError, ValueError):
                    pass
            time.sleep(0.25)
        else:
            return {'status': 'wake_timeout', 'action': 'on',
                    'broadcast_accepted': bool(result and result.get('accepted')),
                    'message': 'Wake result timed out. Do not automatically rebroadcast.',
                    'projection_confirmed': False}
        if result.get('accepted') is not True:
            return {'status': 'wake_failed', 'action': 'on',
                    'broadcast_accepted': False, 'message': result.get('message'),
                    'projection_confirmed': False}
        deadline = time.monotonic() + wait_seconds
        online = reachable(host)
        while not online and time.monotonic() < deadline:
            time.sleep(1)
            online = reachable(host)
        return {'status': 'device_reachable' if online else 'broadcast_sent',
                'action': 'on', 'broadcast_accepted': True,
                'network_reachable': online, 'projection_confirmed': False,
                'message': result.get('message'), 'helper_version': version}
    finally:
        # Only this invocation's result, never other attempts or app settings.
        result_path.unlink(missing_ok=True)


def parse_args(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('action', choices=['status', 'on', 'screenshot'] + list(CODES))
    p.add_argument('--count', type=int, default=1, help='Key presses, 1–20; power/mute once')
    p.add_argument('--output', help='Local screenshot file; default outputs/xgimi-screen-TIMESTAMP.jpg')
    p.add_argument('--host', help='Explicit projector IPv4 override, otherwise use the Mac app setting')
    p.add_argument('--wait', type=int, default=18, help='After wake broadcast, wait 0–20 seconds for network')
    p.add_argument('--dry-run', action='store_true', help='Read config only; no network or app launch')
    a = p.parse_args(argv)
    if not 1 <= a.count <= 20 or not 0 <= a.wait <= 20:
        p.error('count must be 1–20 and wait must be 0–20')
    if a.action in ('status', 'on', 'off', 'mute', 'screenshot') and a.count != 1:
        p.error('This action must run once')
    return a


def main(argv=None):
    a = parse_args(argv)
    try:
        prefs = preferences()
        host = a.host or prefs.get('projectorIP') or DEFAULT_HOST
        if not host:
            raise ValueError('No projector configured. Save its IPv4 in 极米遥控 settings, or pass --host YOUR_PROJECTOR_IP')
        ipaddress.IPv4Address(host)
        if a.dry_run:
            helper, version = find_helper()
            result = {'status': 'dry_run', 'action': a.action, 'host': host,
                      'count': a.count, 'wake_signal_saved': valid_signal(prefs.get('wakeBeaconData')),
                      'helper_installed': helper is not None, 'helper_version': version,
                      'packet': None if a.action not in CODES else f'KEYPRESSES:{CODES[a.action]}',
                      'side_effects': False}
        elif a.action == 'status':
            result = {'status': 'observed', 'host': host,
                      'network_reachable': reachable(host),
                      'wake_signal_saved': valid_signal(prefs.get('wakeBeaconData')),
                      'projection_confirmed': False}
        else:
            with control_lock():
                if a.action == 'screenshot':
                    from capture import capture
                    output = a.output or str(Path.cwd() / 'outputs' / ('xgimi-screen-' + time.strftime('%Y%m%d-%H%M%S') + '.jpg'))
                    result = capture(host, output)
                else:
                    result = wake(host, prefs, a.wait) if a.action == 'on' else send_key(host, a.action, a.count)
        print(json.dumps(result, ensure_ascii=False))
        return 1 if result['status'] in ('wake_failed', 'wake_timeout') else 0
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as exc:
        print(json.dumps({'status': 'error', 'message': str(exc)}, ensure_ascii=False))
        return 1


if __name__ == '__main__':
    sys.exit(main())
