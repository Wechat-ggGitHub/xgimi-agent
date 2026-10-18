#!/usr/bin/env python3
"""Build the menu bar app and its nested wake helper; never install or launch."""
from pathlib import Path
import plistlib, subprocess, shutil
BASE=Path(__file__).resolve().parent
APP=BASE/'dist/极米遥控.app'
HELPER=APP/'Contents/Helpers/极米开机助手.app'
APP_ID='io.github.wechatgg.xgimi-agent'
if APP.exists(): shutil.rmtree(APP)
for bundle,identifier,executable,title in [(APP,APP_ID,'Z7XRemote','极米遥控'),(HELPER,APP_ID+'.wake','Z7XWakeHelper','极米开机助手')]:
    for directory in ['MacOS','Resources']:(bundle/'Contents'/directory).mkdir(parents=True,exist_ok=True)
    meta={'CFBundleIdentifier':identifier,'CFBundleName':title,'CFBundleDisplayName':title,
          'CFBundleExecutable':executable,'CFBundlePackageType':'APPL','CFBundleShortVersionString':'1.0.0',
          'CFBundleVersion':'1','LSMinimumSystemVersion':'13.0','LSUIElement':True,'NSHighResolutionCapable':True,
          'NSBluetoothAlwaysUsageDescription':'学习并发送你自己的极米投影仪开机广播；信号仅保存在本机。',
          'NSBluetoothPeripheralUsageDescription':'使用这台 Mac 的蓝牙唤醒你配置的极米投影仪。',
          'NSLocalNetworkUsageDescription':'通过同一局域网控制你配置的极米投影仪。'}
    (bundle/'Contents/Info.plist').write_bytes(plistlib.dumps(meta))
# Icons are generated from code; no screenshots or captured user assets are bundled.
iconset=BASE/'build/AppIcon.iconset';iconset.parent.mkdir(exist_ok=True)
subprocess.run(['xcrun','swift',str(BASE/'app/MakeIcon.swift'),str(iconset)],check=True)
subprocess.run(['iconutil','-c','icns',str(iconset),'-o',str(APP/'Contents/Resources/AppIcon.icns')],check=True)
meta=plistlib.loads((APP/'Contents/Info.plist').read_bytes());meta['CFBundleIconFile']='AppIcon'
(APP/'Contents/Info.plist').write_bytes(plistlib.dumps(meta))
common=['xcrun','swiftc','-swift-version','5','-O','-parse-as-library','-target','arm64-apple-macosx13.0']
subprocess.run(common+[str(BASE/'app'/n) for n in ['WakeHelper.swift','BeaconSignal.swift','WakeIPC.swift']]+['-o',str(HELPER/'Contents/MacOS/Z7XWakeHelper')],check=True)
subprocess.run(['codesign','--force','--sign','-',str(HELPER)],check=True)
subprocess.run(common+[str(BASE/'app'/n) for n in ['App.swift','RemoteCore.swift','BeaconWake.swift','BeaconSignal.swift','WakeIPC.swift']]+['-o',str(APP/'Contents/MacOS/Z7XRemote')],check=True)
subprocess.run(['codesign','--force','--sign','-',str(APP)],check=True)
print('Built',APP)
