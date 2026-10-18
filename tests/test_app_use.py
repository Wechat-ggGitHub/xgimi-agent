import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
from unittest.mock import patch
import contextlib

scripts=Path(__file__).resolve().parents[1]/'skills/xgimi-remote/scripts'
sys.path.insert(0,str(scripts))
import app_use

with tempfile.TemporaryDirectory() as directory:
    base=Path(directory)
    order=[]
    def sent(host,key,count):
        order.append(('key',key,count))
        return {'status':'sent','device_acknowledged':False}
    def frame(host,output):
        order.append(('capture',))
        output.parent.mkdir(parents=True,exist_ok=True)
        output.write_bytes(b'test frame data')
        return {'status':'captured','path':str(output)}
    with patch.object(app_use.control,'CACHE',base/'cache'),patch.object(app_use.control,'send_key',side_effect=sent) as send,patch.object(app_use,'capture',side_effect=frame),patch.object(app_use.time,'sleep'):
        r=app_use.run_step('127.0.0.1',base/'session','right',2)
        assert order==[('key','right',2),('capture',)]
        assert r['status']=='acted_and_captured' and r['goal_verified'] is False
        assert Path(r['frame']['path']).is_file()
        r2=app_use.run_step('127.0.0.1',base/'session')
        assert r2['status']=='captured' and send.call_count==1
        assert r2['step_id']!=r['step_id']
        events=[json.loads(line) for line in (base/'session/events.jsonl').read_text().splitlines()]
        assert len(events)==2 and events[0]['count']==2 and events[1]['count']==0
    with patch.object(app_use.control,'CACHE',base/'cache'),patch.object(app_use.control,'send_key',side_effect=sent) as send,patch.object(app_use,'capture',side_effect=RuntimeError('image timeout')),patch.object(app_use.time,'sleep'):
        r=app_use.run_step('127.0.0.1',base/'failed','ok')
        assert r['status']=='action_sent_capture_failed'
        assert send.call_count==1 and r['goal_verified'] is False
        event=json.loads((base/'failed/events.jsonl').read_text())
        assert event['key']=='ok' and event['message']=='image timeout'
    with patch.object(app_use.control,'send_key',side_effect=AssertionError('No device action')),patch.object(app_use,'capture',side_effect=AssertionError('No network')):
        r=app_use.run_step('127.0.0.1',base/'dry','left',3,dry_run=True)
        assert r['side_effects'] is False and not (base/'dry').exists()
        for key,count in [('off',1),('mute',2),('left',4),(None,2)]:
            try:app_use.run_step('127.0.0.1',base/'invalid',key,count,dry_run=True)
            except ValueError:pass
            else:raise AssertionError('Invalid action accepted')
print('PASS: key-before-capture ordering; observe sends no keys; failed capture never repeats action; per-step files/logs; dry-run no network/files; unsafe repeats rejected')
