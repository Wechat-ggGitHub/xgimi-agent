# 连接与协议

- Mac App 设置域：`io.github.wechatgg.xgimi-agent`。读取 `projectorIP`，没有默认家庭地址。
- `wakeBeaconData` 是用户自己学习的 21 字节开机数据，可能包含设备标识，仅存在本机 UserDefaults。不提交、不分享实际信号。
- 按键：UDP 16735，`KEYPRESSES:<code>`。无执行回执，码表以 control.py 为准。
- 截图：发送 UDP 16750 的 JSON：`{"action":20000,"msgid":"2","controlCmd":{"mode":9,"type":1,"time":0,"delayTime":0}}`。本机 UDP 16751 接收 action=30235 的 imagePath，从同一投影仪 HTTP 16741 下载。
- capture.py 验证回复来源、下载目标、图片格式与大小，不需要 ADB。截图可能也会写入投影仪本身的 Pictures/Screenshots。
- 同一 Mac 的调用用文件锁串行；另一个接收器占用端口时明确报错。

# 开机

on 先检查 TCP 8080 可达性，已在线不广播；离线时通过已安装的嵌套助手发送一次约 8 秒广播，随后等待网络。

开机助手使用非公开 CoreBluetooth 广播字典字段和应用类型切换。这是本机实验获得的兼容性方式，不是 Apple 稳定 API，不适合承诺所有 Mac/固件或 Mac App Store 上架。主应用和助手可能分别要求蓝牙权限。

没有自己的信号时先在 App 学习。信号格式严格匹配已研究的 Z7X 路线，其他型号可能不匹配。广播被系统接受不代表投影仪已启动。助手在运行时不另启一次，失败不自动重复广播。

# 返回值

- captured：新截图已保存，Agent 读取后才能描述画面。
- acted_and_captured：按键已发出并已截取后续画面，由 Agent 验证结果。
- action_sent_capture_failed：按键可能生效，只补取截图，不重发按键。
- sent：仅发送成功，无设备执行回执。
- already_reachable / device_reachable：网络在线，不证明光机亮起。
- broadcast_sent：广播结束但网络未响应，不能因此断言未开机。
- wake_failed / wake_timeout / error：说明具体原因，不自动重发。
- dry_run：无网络、无广播、无助手启动、无截图和步骤目录创建。

首次学习需要官方手机 App 配合；之后无需每次使用手机。仅测试自己配置并有权操作的设备。
