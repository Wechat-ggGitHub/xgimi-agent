"""Capture one Z7X frame through its official-app LAN screenshot protocol."""
import http.client
import ipaddress
import json
from pathlib import Path
import socket
import time
from urllib.parse import urlsplit


def capture(host, output, timeout=8):
    ipaddress.IPv4Address(host)
    started = time.monotonic()
    request = {'action': 20000, 'msgid': '2',
               'controlCmd': {'mode': 9, 'type': 1, 'time': 0, 'delayTime': 0}}
    observed = []
    packet = None
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        try:
            sock.bind(('0.0.0.0', 16751))
        except OSError as exc:
            raise RuntimeError('截图接收端口16751被占用，请结束另一轮截图后再试') from exc
        sock.sendto(json.dumps(request, separators=(',', ':')).encode(), (host, 16750))
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            sock.settimeout(max(.05, deadline - time.monotonic()))
            try:
                data, source = sock.recvfrom(65535)
            except socket.timeout:
                break
            if source[0] != host:
                continue
            try:
                value = json.loads(data)
            except (ValueError, UnicodeDecodeError):
                continue
            if not isinstance(value, dict):
                continue
            observed.append(value.get('action'))
            if value.get('action') == 30235 and value.get('imagePath'):
                packet = value
                break
    if packet is None:
        raise RuntimeError('没有收到投影仪截图地址；已收到的响应动作：' + str(observed[:8]))
    url = packet['imagePath'].replace('%s', host)
    parsed = urlsplit(url)
    if (parsed.scheme != 'http' or parsed.hostname != host or parsed.port != 16741
            or parsed.username or parsed.password):
        raise RuntimeError('投影仪返回了非预期的截图地址，未下载')
    path = parsed.path + ('?' + parsed.query if parsed.query else '')
    conn = http.client.HTTPConnection(host, 16741, timeout=5)
    try:
        conn.request('GET', path)
        response = conn.getresponse()
        body = response.read(8 * 1024 * 1024 + 1)
        if response.status != 200:
            raise RuntimeError('截图下载失败，HTTP ' + str(response.status))
    finally:
        conn.close()
    if len(body) > 8 * 1024 * 1024:
        raise RuntimeError('截图超过大小上限，未保存')
    if not (body.startswith(b'\xff\xd8\xff') or body.startswith(b'\x89PNG\r\n\x1a\n')):
        raise RuntimeError('返回内容不是有效的JPEG/PNG截图，未保存')
    output = Path(output).expanduser().resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(body)
    return {'status': 'captured', 'host': host, 'path': str(output), 'bytes': len(body),
            'capture_started_ms': packet.get('startScreenCapTime'),
            'capture_finished_ms': packet.get('endScreenCapTime'),
            'elapsed_seconds': round(time.monotonic() - started, 3),
            'transport': 'official_app_lan', 'navigation_keys_sent': 0}
