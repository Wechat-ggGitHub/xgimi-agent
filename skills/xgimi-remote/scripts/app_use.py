#!/usr/bin/env python3
"""Observe a Z7X app screen, or press a key and capture the resulting screen.

The calling agent interprets the image and decides the next step. This program
never guesses a screen location, chooses a programme, or automatically retries.
"""
import argparse
import hashlib
import ipaddress
import json
from pathlib import Path
import subprocess
import sys
import time
import uuid

import control
from capture import capture

UI_KEYS = tuple(key for key in control.CODES if key != 'off')


def run_step(host, directory, key=None, count=1, settle=.4, dry_run=False):
    ipaddress.IPv4Address(host)
    if key is not None and key not in UI_KEYS:
        raise ValueError('Use the dedicated power command for on/off')
    if not 1 <= count <= 3:
        raise ValueError('Visual steps allow 1–3 presses; observe before the next step')
    if key is None and count != 1:
        raise ValueError('Observe does not repeat keys')
    if key == 'mute' and count != 1:
        raise ValueError('Mute is a toggle and must be sent once')
    if not 0 <= settle <= 3:
        raise ValueError('settle must be between 0 and 3 seconds')
    directory = Path(directory).expanduser().resolve()
    if dry_run:
        return {'status': 'dry_run', 'mode': 'act' if key else 'observe',
                'host': host, 'key': key, 'count': count if key else 0,
                'output_dir': str(directory), 'side_effects': False}
    token = time.strftime('%Y%m%d-%H%M%S') + '-' + uuid.uuid4().hex[:8]
    output = directory / (token + '.jpg')
    event = {'step_id': token, 'time_local': time.strftime('%Y-%m-%dT%H:%M:%S%z'),
             'key': key, 'count': count if key else 0, 'goal_verified': False}
    with control.control_lock():
        if key:
            event['command'] = control.send_key(host, key, count)
            if settle:
                time.sleep(settle)
        try:
            frame = capture(host, output)
            event['status'] = 'acted_and_captured' if key else 'captured'
            event['frame'] = frame
            event['sha256'] = hashlib.sha256(output.read_bytes()).hexdigest()
        except (OSError, ValueError, RuntimeError) as exc:
            # A failed observation never resends the already-transmitted key.
            event['status'] = 'action_sent_capture_failed' if key else 'capture_failed'
            event['message'] = str(exc)
    directory.mkdir(parents=True, exist_ok=True)
    with (directory / 'events.jsonl').open('a', encoding='utf8') as log:
        log.write(json.dumps(event, ensure_ascii=False) + '\n')
    return event


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['observe', 'act'])
    parser.add_argument('key', nargs='?', choices=UI_KEYS)
    parser.add_argument('--count', type=int, default=1)
    parser.add_argument('--settle', type=float, default=.4)
    parser.add_argument('--output-dir', default=str(Path.cwd() / 'outputs' / 'xgimi-app-use'))
    parser.add_argument('--host')
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args(argv)
    if (args.mode == 'act') != (args.key is not None):
        parser.error('act requires a key; observe accepts no key')
    try:
        prefs = control.preferences()
        host = args.host or prefs.get('projectorIP') or control.DEFAULT_HOST
        if not host:
            raise ValueError('No projector configured. Save its IPv4 in 极米遥控 settings, or pass --host YOUR_PROJECTOR_IP')
        result = run_step(host, args.output_dir, args.key, args.count, args.settle, args.dry_run)
        print(json.dumps(result, ensure_ascii=False))
        return 1 if result['status'] in ('action_sent_capture_failed', 'capture_failed') else 0
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as exc:
        print(json.dumps({'status': 'error', 'message': str(exc)}, ensure_ascii=False))
        return 1


if __name__ == '__main__':
    sys.exit(main())
