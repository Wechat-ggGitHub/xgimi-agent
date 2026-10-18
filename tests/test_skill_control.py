import contextlib
import importlib.util
import io
import json
import socket
import tempfile
from pathlib import Path
from unittest.mock import patch

path=Path(__file__).resolve().parents[1]/'skills/xgimi-remote/scripts/control.py'
spec=importlib.util.spec_from_file_location('control',path)
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
# Real socket transmission stays on loopback with an OS-assigned local port.
with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as receiver:
    receiver.bind(('127.0.0.1',0));receiver.settimeout(1)
    port=receiver.getsockname()[1]
    m.send_key('127.0.0.1','right',3,delay=0.001,port=port)
    assert [receiver.recvfrom(100)[0] for _ in range(3)]==[b'KEYPRESSES:37']*3
    for action,expected in [('left',50),('off',30),('mute',113),('home',35)]:
        m.send_key('127.0.0.1',action,port=port)
        assert receiver.recvfrom(100)[0]==f'KEYPRESSES:{expected}'.encode()
    for action,count in [('off',2),('mute',2),('left',0),('right',21)]:
        try:m.send_key('127.0.0.1',action,count,port=port)
        except ValueError:pass
        else:raise AssertionError('invalid repeat was not rejected')
# Dry-run must not even open a network socket or launch an app.
for action in ['on','off','right','status']:
    with patch.object(m.socket,'socket',side_effect=AssertionError('network forbidden')):
        capture=io.StringIO()
        with contextlib.redirect_stdout(capture):
            assert m.main([action,'--host','127.0.0.1','--dry-run'])==0
        assert json.loads(capture.getvalue())['side_effects'] is False
with tempfile.TemporaryDirectory() as directory:
    with patch.object(m,'CACHE',Path(directory)):
        with m.control_lock():
            try:
                with m.control_lock():raise AssertionError('concurrent command accepted')
            except RuntimeError:pass
# A reachable projector must not launch a helper or advertise again.
with patch.object(m,'reachable',return_value=True),patch.object(m,'find_helper',side_effect=AssertionError('must not launch')):
    assert m.wake('127.0.0.1',{},0)['status']=='already_reachable'
print('PASS: loopback packets/repeats, dry-run has no network, concurrency lock, already-online skips wake')
# Exercise the helper IPC contract without running an app or using Bluetooth.
import subprocess
import uuid
for accepted in (True,False):
    with tempfile.TemporaryDirectory() as directory:
        token=uuid.UUID('0df21362-c2b4-45d4-a01c-434e0a332250')
        cache=Path(directory)
        def fake_run(command,**kwargs):
            if command[0].endswith('pgrep'):
                return subprocess.CompletedProcess(command,1,stdout=b'',stderr=b'')
            assert command[:4]==['/usr/bin/open','-n','-g','/mock/极米开机助手.app']
            result=cache/'WakeResults'/(str(token).upper()+'.json')
            result.parent.mkdir()
            result.write_text(json.dumps({'attempt':str(token).upper(),'accepted':accepted,'completed':True,'message':'test'}))
            return subprocess.CompletedProcess(command,0,stdout='',stderr='')
        signal=b'abcdef'+b'\xff'*3+b'3CRKTM'+bytes(6)
        with patch.object(m,'CACHE',cache),patch.object(m.uuid,'uuid4',return_value=token),patch.object(m,'reachable',side_effect=[False,True]),patch.object(m,'find_helper',return_value=(Path('/mock/极米开机助手.app'),'1.5')),patch.object(m.subprocess,'run',side_effect=fake_run):
            result=m.wake('127.0.0.1',{'wakeBeaconData':signal},0)
            assert result['status']==('device_reachable' if accepted else 'wake_failed')
            assert result['projection_confirmed'] is False
            assert not list((cache/'WakeResults').glob('*.json'))
print('PASS: wake helper success/failure IPC, correlation, result cleanup; no real helper or Bluetooth used')
