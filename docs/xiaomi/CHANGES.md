# 小米适配改动清单

基线：上游 v1.5.6，提交 `6429d34d3230033802f6e5371d93540a19a82751`。

| 改动 | 位置 | 原因与范围 |
| --- | --- | --- |
| 独立应用身份 | AndroidManifest.xml、Java package 声明 | `dev.local.mitvhome` 与原版共存，旧版可保留用于回退 |
| 独立 Home 进程 | AndroidManifest.xml | Activity 在 `:home` 进程；用于改善已测固件的待机行为，不承诺所有固件有效 |
| HDMI 原生入口 | MainActivity.openInput、XiaomiInputs | 对 Xiaomi/Redmi 的已知 MediaTek input ID 调用 EXTSRC_PLAY；整数 input=23/24/25，失败后保留上游路径 |
| 连接状态标色 | MainActivity 的输入回调、卡片和焦点样式 | INPUT_STATE_CONNECTED 为深蓝并标“已连接”；不等同于视频有效信号检测 |
| 输入动态刷新 | TvInputCallback、onResume | 输入注册、移除、状态变化和回到桌面时刷新 |
| 隐藏虚拟第四口 | XiaomiInputs.isPhantom | 仅 MiTV-MFTP0 的 HW8；其他型号不受影响 |
| 电视设置 | MainActivity.openTvSettings | 优先小米 entry.MainActivity，其次上游标准设置 |
| 图像 / 亮度 | MainActivity.openBrightness | 仅已测型号走小米 SettingsBroadcastReceiver，打开原生图像设置；其余保留原逻辑 |
| 安装和恢复 | scripts/Install-Xiaomi.ps1、Restore-Xiaomi.ps1、两个 sh 脚本 | 默认试装；先记录原状态；切默认、停用小米桌面需要明确选择；不批量精简 |
| 通用构建 | build.sh、build-windows.ps1 | 修正独立包名，支持标准 Android SDK 路径，不含开发者机器路径 |
| 验证 | tests、xiaomi-build.yml | 输入映射、虚拟口过滤、脚本语法、APK 编译和签名校验 |

公开版不包含家庭设备 IP、MAC、序列号、备份、个人应用列表或签名密钥。
没有修改固件，没有自动关闭更新，也没有以后台服务持续抢回前台。

早期部署时用于补足设置和 HDMI 入口的独立适配组件已由公开版内置逻辑取代，普通用户无需再安装该组件。
