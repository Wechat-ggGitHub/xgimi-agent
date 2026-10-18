---
name: xgimi-remote
description: 极米 App Use：通过已配置的局域网遥控和按需截图操作极米投影仪。用于开关机、方向导航、进入应用、查看观看记录、找节目、续播和设置调整。也适用于明确投影仪上下文中的“往左、确认、返回”。研究、写文章或修改工具本身不操作设备；不控制 Mac 或 iPhone App。
---

# 极米 App Use

用“看画面 → 决定一步 → 操作 → 再看画面”完成投影仪任务。脚本位于本 skill 的 `scripts/`，相对于 SKILL.md 定位并使用实际绝对路径调用。

## 首次使用

先在「极米遥控」Mac App 的设置填写自己的投影仪 IPv4；开机另需在 App 中学习自己的蓝牙信号。没有配置时停止并说明，不猜 IP，不复制他人的广播。

也可为单次操作传 `--host YOUR_PROJECTOR_IP`。对工具自身的测试使用 `--dry-run`，不得为了验证安装随意按键或开关机。

## 操作界面

1. 执行 `python3 <skill>/scripts/app_use.py observe --output-dir <本地会话目录>`，用图片查看工具读取返回的 `frame.path`。不习惯性按主页打断现有页面。
2. 从画面识别应用、文字、选中焦点、弹窗和目标入口。
3. 用 `app_use.py act right --output-dir <同一目录>` 操作一步。只有焦点与路径明确时，才合并最多三次同方向移动；确认、返回、主页和菜单通常一次。
4. 看新的截图再决定下一步；`sent` 和 `acted_and_captured` 不是任务完成证明，`goal_verified` 始终为 false，由 Agent 看图验证。
5. 达到用户目标即停下，需要时展示最终截图。只要求查看记录时，不开始播放。

截图失败而按键已经发出时，只重新 observe，不重复按键。页面加载时等待后再观察。同一位置两次无进展，检查焦点、弹窗或换可见入口，不无限循环。

示例（先把 `<skill>` 替换为本 skill 的绝对路径）：

```bash
python3 <skill>/scripts/app_use.py observe --output-dir /absolute/path/session
python3 <skill>/scripts/app_use.py act right --count 2 --output-dir /absolute/path/session
python3 <skill>/scripts/app_use.py act ok --settle 1 --output-dir /absolute/path/session
```

act 支持 `up down left right ok back home menu volume-up volume-down mute`。默认等待 0.4 秒后截图；加载慢可用 `--settle 1` 或重新观察。脚本不识图、不猜节目、不自动重试，Agent 负责推理。

## 单次遥控

明确按键或电源指令用 `control.py`：

| 目标 | action |
|---|---|
| 开机、关机 | on、off |
| 上下左右、确认、返回、主页、菜单 | up、down、left、right、ok、back、home、menu |
| 音量、静音切换 | volume-up、volume-down、mute |
| 状态 | status |
| 截图 | screenshot --output /absolute/path/frame.jpg |

默认一次；明确“向右三次”用 `--count 3`。开关机和静音只发一次；静音状态未知时，只报告按下静音键。

## 根据目标行动

- 进入应用后截图确认。腾讯视频电视端名称可能显示为「云视听极光」。
- 找之前的节目时先进入实际观看历史，核对节目名、季数、期数和进度，不把推荐卡片当观看记录。多个候选无法区分才问具体问题。
- 用户要求续播才开始播放。受保护的视频截图变黑，不代表播放失败。
- 搜索先观察屏上输入法；直接文本输入尚未实现，不假装已输入。
- 调整设置后观察实际值。登录、购买、删除等超出当前任务的操作按用户授权处理。

## 设备状态与结果

设备离线时，仅在目标明确需要使用投影仪时执行一轮 on；仅查询状态不唤醒。网络可达不证明光机亮起，开机后用新截图确认界面。

本项目曾在 Z7X 上验证遥控、蓝牙唤醒、桌面和腾讯视频页面截图、进入播放记录。其他型号/固件需自行验证；按需截图不等于连续视频流，也没有直接读取腾讯账号历史的接口。

协议、配置和错误状态见 [references/device-protocol.md](references/device-protocol.md)，只在排查需要时读取。不要修改用户原始蓝牙信号、安装、登录项或调试权限来完成日常操作。
