# 安装前备份与恢复

## 电视上手动回到桌面

在“应用 / 我的应用”打开 **Home 小米适配版**。这能重新打开桌面，但不代表系统默认值已恢复。

## Windows 安装器的恢复

安装时记录的目录位于本机仓库 `backups/xiaomi-日期时间/`。它包含状态 / 设置快照，不是刷机镜像或私有数据备份。不要公开上传整个目录。

```powershell
.\scripts\Restore-Xiaomi.ps1 -BackupDirectory '.\backups\xiaomi-你的备份目录'
# 如果电视 IP 变了，可追加 -TvAddress 新IP:5555
```

仅当本次安装器实际选择停用了 `com.mitv.tvhome`，才重新启用它；然后恢复记录中的原默认桌面。
不卸载任何 App，不批量启用原本停用的包，不导入整套旧设置。
需要电视可正常连接 ADB；不可达时先在电视开启调试、允许电脑连接。

## macOS / Linux

```sh
sh undo.sh TV_IP backups/安装时打印的目录
```

默认试装不会停用小米原桌面。确认新桌面可用、且已保留 `home-before.txt` 后，可手动设置：

```sh
adb -s TV_IP:5555 shell cmd package set-home-activity dev.local.mitvhome/.MainActivity
```

如果已测机型的原桌面仍抢回主屏键，只有在明确接受停用原桌面的影响后再执行下列步骤。**Google TV 或未验证型号不要照搬。**

```sh
# 先确认原状态：若本就停用，不要新增下面的标记。
adb -s TV_IP:5555 shell pm list packages -d com.mitv.tvhome
# 仅当原来启用、并由本次操作停用时执行：
echo com.mitv.tvhome > backups/本次目录/stock-disabled-by-installer.txt
adb -s TV_IP:5555 shell pm disable-user --user 0 com.mitv.tvhome
adb -s TV_IP:5555 shell cmd package set-home-activity dev.local.mitvhome/.MainActivity
```

等待至少 15 秒保存，再验证主屏键、待机和重启。若有问题，先重新启用原桌面并恢复 `home-before.txt` 中的组件。

```sh
adb -s TV_IP:5555 shell pm enable --user 0 com.mitv.tvhome
adb -s TV_IP:5555 shell cmd package set-home-activity 原先的package/Activity
```

在 ADB 不可达或电视不能进入系统时，命令不保证可救回；安装前了解设备自己的恢复途径。
关闭调试后，恢复脚本需要先重新开启调试。停止使用定制版时，可先恢复默认桌面，再从电视应用管理卸载它。
