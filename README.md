# TV Detox 小米 / Redmi 适配分支

基于 [Ansub/tv-detox v1.5.6](https://github.com/Ansub/tv-detox/tree/v1.5.6) 的独立社区分支，MIT 许可。不是小米官方项目，不是电视系统或刷机包。

**首个公开预览版：重点适配 Redmi MiTV-MFTP0（alita），Android 9 / SDK 28、固件 23.2.10.6129。其他小米型号尚未验证，不能保证通用。**

[下载 APK](https://github.com/tala2010/tv-detox/releases/tag/xiaomi-v1.0.0) · [改动清单](docs/xiaomi/CHANGES.md) · [适配与验证记录](docs/xiaomi/COMPATIBILITY.md) · [恢复说明](docs/xiaomi/RECOVERY.md) · [上游原说明](README.upstream.md)

## 这个分支改了什么

- HDMI 1～3 通过小米原生播放器切换，修复点击后没有反应。
- 已连接 HDMI 使用深蓝色卡片，并写明“已连接”；其他接口显示“未连接”。支持连接状态回调与回到桌面时刷新。
- 连接状态表示电视报告的连接，不承诺设备正在输出有效画面。
- 仅在已验证的 MiTV-MFTP0 上隐藏系统误报的 HDMI 4；不删其他型号的第四口。
- “电视设置”和“亮度”接入小米原生设置、图像 / 背光界面，无需额外安装适配插件。
- 独立 `:home` 进程，用于改善此机型待机时对桌面主进程的干预；原机型完成过重启与约 93 秒待机唤醒验证。
- 包名 `dev.local.mitvhome`，与原版 `com.ansub.tvhome` 共存。电视应用列表中显示 **Home 小米适配版**。

不包含个人设备 IP、MAC、应用排列、电视备份或签名私钥。没有自动禁用更新服务、批量清理系统应用、强开 ADB、循环抢前台或自动打开无障碍服务。

## 安装：先试用，再决定是否设为默认

电脑装好 [Android Platform Tools](https://developer.android.com/tools/releases/platform-tools)，电视和电脑在同一局域网，在电视上开启 ADB 调试并允许电脑连接。

```sh
git clone --branch xiaomi-support https://github.com/tala2010/tv-detox.git
cd tv-detox
```

### Windows / PowerShell

将下方 `TV_IP` 换成电视的 IP；没有配对要求的机型默认使用 5555 端口。脚本会下载带 SHA256 校验的公开预览版；也可以传入自己编译的 `-ApkPath`。

```powershell
# 默认仅试装；保留当前默认桌面，不停用任何应用。
.\scripts\Install-Xiaomi.ps1 -TvAddress TV_IP

# 确认遥控器、设置、HDMI 正常后，才设为默认。
.\scripts\Install-Xiaomi.ps1 -TvAddress TV_IP -SetDefault

# 若小米桌面仍抢回主屏键，再明确选择只停用小米原桌面。
.\scripts\Install-Xiaomi.ps1 -TvAddress TV_IP -SetDefault -DisableStockHome
```

脚本先将原默认桌面、停用清单和三类设置保存到本机 `backups/`，然后才安装 / 改动；这不是整机镜像，不包含应用私有数据。默认设置校验失败时尝试恢复原桌面配置，并保留备份。**电视若已不能启动或 ADB 不可达，恢复脚本无法保证救回。**

不识别的型号会停止；详细阅读兼容说明后，可自行用 `-AllowUntestedModel` 试装。这只是解除脚本限制，不是适配保证。脚本不自动卸载签名冲突的旧版，避免丢失桌面数据。

### macOS / Linux

```sh
sh install.sh TV_IP
```

同样默认只试装，先备份，不停用系统应用。macOS/Linux 的默认切换与恢复步骤见 [恢复说明](docs/xiaomi/RECOVERY.md)。

### 只用遥控器打开

也可以从 Release 下载 APK 自行安装。以后进入电视“应用 / 我的应用”，点击 **Home 小米适配版** 即可打开。手动打开不等于系统默认值已锁定；应用被卸载或恢复出厂后需要重新安装。

## 使用前后检查

1. 试用电视设置、亮度、常用应用和 HDMI。
2. 设为默认后，测试实体遥控器主屏键。
3. 真正待机至少一分钟后唤醒，并重启一次，确认仍是新桌面。
4. 在小米“关于 → 智能更新”中检查开关；本分支只读取记录，不擅自关闭更新。
5. 验证后关闭 ADB 调试。OLED 电视保留合适的屏保和面板保护。

该桌面没有推荐广告；电视开机广告、原生屏保内容及视频 App 内的广告不由本桌面控制。系统升级、恢复出厂或厂商修改策略后，默认桌面仍可能改变，不能承诺永久锁定。

## 编译

推荐 JDK 17，Android SDK `platforms;android-34` 与 `build-tools;34.0.0`，并设置 `ANDROID_HOME`。

```sh
# macOS / Linux：产物 out/tvhome.apk
sh build.sh
```

```powershell
# Windows：产物 out/tvhome-xiaomi.apk
.\build-windows.ps1
```

Windows 使用较新 JDK 时，如旧 D8 编译器不兼容，可用 `-D8Jar` 指向新版官方 R8/D8 JAR。首次本地编译会创建私有签名密钥，后续更新应保留同一密钥。密钥已加入忽略规则，不要提交。CI 工件采用临时测试签名，不能直接覆盖 Release 签名安装；普通用户请使用 Releases APK。

## 验证与反馈

基础小米适配已在上述机型实测；公开版集成路径和通用安装脚本仍是预览状态，详见兼容说明，不把其他固件当作已测。CI 检查编译、APK 签名和输入映射回归测试，不代表全部真机行为。

反馈请提供型号、Android 版本、固件、具体按钮和表现；请遮住 IP、MAC、序列号等个人信息。保留上游 MIT 许可及作者署名。
