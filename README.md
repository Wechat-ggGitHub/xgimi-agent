# XGIMI Agent · 极米 App Use

用 Mac 菜单栏 App 和 Agent Skill 控制自己的极米投影仪：通过 Wi-Fi 发送遥控按键、按需获取画面，让 Agent 看着画面进入应用、查找观看记录；通过学习自己的蓝牙广播尝试唤醒待机设备。

本项目源自一台极米 Z7X 的实际折腾。**已在这台 Z7X 上跑通遥控、蓝牙开机、原生截图、进入腾讯视频并查看播放记录。其他型号、系统、固件尚未验证。** 非极米或 OpenAI 官方产品。

## 能做什么

| 能力 | 实现与状态 |
|---|---|
| 方向、确认、返回、主页、菜单、音量、静音、关机 | 局域网 UDP 按键；发送成功不等于设备执行成功 |
| 蓝牙开机 | 从自己的 iPhone 官方极米 App 学习后，由 Mac 助手发送；实验性方式 |
| 获取画面 | 局域网请求一张截图并下载，非连续视频流 |
| 操作腾讯等应用 | Agent 查看图片后逐步导航；没有固定按键宏，也没有读取账号历史的私有接口 |
| 菜单栏遥控器 | SwiftUI/AppKit；开机进度在面板显示；可手动启用登录项 |

不是破解家庭 Wi-Fi 密码。本项目研究并复用了投影仪已有的局域网与蓝牙控制机制。

## 环境与兼容性

- Apple Silicon Mac；当前构建目标为 macOS 13+。Intel 构建未验证。
- Xcode Command Line Tools：`xcode-select --install`。
- Python 3.10+（构建和 Skill 脚本只用标准库）。
- Mac 与投影仪在同一可信局域网；投影仪待机时仍接电源。
- 蓝牙学习需要 iPhone 上的官方「极米」App，并能先用它把你的投影仪开机。
- 主 App 和内置助手可能分别请求蓝牙权限，由用户确认。
- 开机使用非公开 CoreBluetooth 字段，可能受 macOS 更新影响；不承诺 Mac App Store 分发兼容。

## 从源码构建

```bash
git clone https://github.com/Wechat-ggGitHub/xgimi-agent.git
cd xgimi-agent
python3 build.py
```

得到 `dist/极米遥控.app`，将它复制到 `~/Applications` 或 `/Applications` 再打开。构建只生成文件，不安装、不启动、不连接设备。

本地构建使用临时签名，没有 Developer ID 公证。如果 macOS 阻止你运行，请先检查源码，再通过系统「隐私与安全性」的正常打开流程处理；不需要关闭系统整体安全保护。

公开版采用独立设置域，不读取开发者原来使用的个人版 App 配置。

## 第一次配置

1. 打开菜单栏投影仪图标 → 设置。
2. 在投影仪网络详情查看自己的 IPv4，填入设置并保存。本项目不包含默认设备地址。
3. 在可观察的页面测试一次方向键，确认焦点移动。
4. 需要蓝牙开机时打开「配置蓝牙开机」，让自己的 iPhone 靠近 Mac。
5. 点击「开始学习」，只用 iPhone 官方极米 App 给目标投影仪开机。不要同时操作其他极米设备。
6. 学习完成后，让投影仪关机，稍等，再点 Mac 的「测试开机」。只有实际亮起后才点击确认成功。

学习到的广播包含设备相关标识，仅存在本机设置。**仓库没有实际广播、MAC 地址、家庭 IP 或抓包。** 广播被系统接受不等于实际开机成功。若学习未捕获或型号不匹配，停止并检查设备/权限，不随意复制网上的开机数据。

## 安装 Skill

将仓库 `skills/xgimi-remote` 复制到 Codex 的技能目录（默认 `~/.codex/skills/`）；若已存在同名 Skill，先备份再更新，按宿主要求刷新技能列表。

在支持执行 Python 和查看本地图片的 Agent 中使用，例如：

- 「打开投影仪。」
- 「打开腾讯视频，找到之前看的综艺，停在播放记录给我看。」
- 「向右两次，然后确认。」

Agent 先调用脚本取图，再读取图片、决定下一步。脚本本身不调用模型，不自动识图；模型和工具权限由 Agent 宿主提供。关机或音量等明确指令不必执行完整视觉流程。

## 命令行

先在 App 设置自己的地址；也可用 `--host YOUR_PROJECTOR_IP` 单次指定。以下均从仓库根目录运行：

```bash
python3 skills/xgimi-remote/scripts/control.py status
python3 skills/xgimi-remote/scripts/control.py right --count 2
python3 skills/xgimi-remote/scripts/control.py off
python3 skills/xgimi-remote/scripts/control.py on
python3 skills/xgimi-remote/scripts/control.py screenshot --output ./outputs/frame.jpg
python3 skills/xgimi-remote/scripts/app_use.py observe --output-dir ./outputs/session
python3 skills/xgimi-remote/scripts/app_use.py act ok --settle 1 --output-dir ./outputs/session
```

仅检查参数，完全不操作设备：

```bash
python3 skills/xgimi-remote/scripts/control.py right --host 127.0.0.1 --dry-run
python3 skills/xgimi-remote/scripts/app_use.py act right --host 127.0.0.1 --dry-run
```

按键后截图失败时，重新 observe，不重发上一按键。状态含义、端口和协议见 [协议说明](skills/xgimi-remote/references/device-protocol.md)。截图可能同时留在投影仪自己的截图目录。

## 隐私与数据流

- App 设置及开机数据：本机 UserDefaults `io.github.wechatgg.xgimi-agent`。
- 助手 IPC：`~/Library/Caches/io.github.wechatgg.xgimi-agent/WakeResults/`。
- Skill 截图和步骤记录：你选择的 output-dir，包含可见屏幕内容，可能有观看记录或账号昵称。
- 脚本仅连接你配置的投影仪；项目没有分析统计或云端上传服务。
- Agent 为理解图片可能向其模型服务发送图片/文字，取决于你使用的 Agent 和设置，不能把整个链路称为离线。
- 不要将端口暴露到公网，也不要把本地 captures/settings/outputs 提交到 GitHub。

## 离线验证

```bash
python3 tests/test_skill_control.py
python3 tests/test_app_use.py
./dist/极米遥控.app/Contents/MacOS/Z7XRemote --self-test
```

测试使用 loopback 和模拟对象，覆盖按键编码、重复限制、无网络 dry-run、互斥、开机助手回执、截图失败不重复按键。它们不能证明你的实际型号一定支持本协议。

## 结构

```text
app/                    菜单栏 App、学习器、开机助手
skills/xgimi-remote/     Skill、控制/截图/观察脚本、协议说明
tests/                  无设备测试
build.py                Apple Silicon 本地构建
```

## 当前限制

截图是按需抓取；播放中的 DRM 画面可能变黑。没有直接读取腾讯观看历史、通用文本输入或全型号兼容能力。断电的投影仪不能通过本方案开机。App 不包含用户的设备配置，首次配置是必须的。

## 与语音入口组合

[Voice Control Agent](https://github.com/Wechat-ggGitHub/voice-control-agent) 可以把唤醒后的语音文字发到固定 Codex 会话，再朗读最终回复。让目标会话安装本 Skill，即可尝试把语音目标交给投影仪 Agent。两项目各自的功能已实测；任意自然语言的一句话播放并非对所有场景的成功保证。

## 许可证

原创代码采用 MIT。极米、腾讯、Apple、Codex 等名称属于各自权利人。本仓库不包含官方 App 安装包或反编译代码、个人抓包和观看截图。
