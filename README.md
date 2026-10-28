# iStoreOS 自动构建 — RK3588 BDY-G98

参考 [Jaykwok2999/istoreos-actions](https://github.com/Jaykwok2999/istoreos-actions)，并按 [ophub/amlogic-s9xxx-armbian](https://github.com/ophub/amlogic-s9xxx-armbian) `model_database.conf r123` 里登记的 **BDY-G98** 真实硬件档案定制。

## BDY-G98 硬件档案（已从 ophub 数据库核实）

| 项 | 值 |
|---|---|
| SoC | Rockchip RK3588 |
| RAM | 16 GB |
| 存储 | 2× NVMe + 1× SATA |
| 网口 | **2× 2.5GbE**（RK3588 GMAC）+ **8× 1GbE**（YT9215S 交换芯片） |
| DT blob | `rk3588-bdy-g98.dtb` |
| U-Boot | `u-boot.itb` + `idbloader.img` |
| boot 配置 | `armbianEnv.txt` |
| 内核基线 | ophub `rk3588/stable/6.18.y` |
| 贡献者 | jxhexi, amlkiller |

> 8 个千兆口由 **YT9215S** 交换芯片扩展——也就是你之前在调的那颗。

## 核心特性

- 🐚 **编译前在线 SSH 窗口**：默认 10 分钟，可上去 `make menuconfig` / `make kernel_menuconfig` 改 `.config`；改完 `touch /tmp/continue` 立刻继续。
- 🧩 **G98 硬件配置已写死**：NVMe/SATA/2.5G/YT9215S/PWM 风扇相关 kmod 都在 config 里。
- 🌀 **PWM 风扇脚本**：`diy/diy.sh` 已内置一套温度→占空比脚本（40/50/60/70℃ 五档），并注册成 procd 服务 `fan-control`。
- 🌐 **网口初始配置**：默认 br-lan 桥接 8 个 YT9215S 口，eth0 做 WAN。
- 📦 工具链缓存 + 自动发 Release。

## 目录结构

```
.
├── .github/workflows/build-istoreos-rk3588-bdy-g98.yml
├── configs/rk3588-bdy-g98.config      # G98 硬件 config
└── diy/diy.sh                        # dts注入 + 风扇脚本 + 网络配置
```

## 使用

1. 把本目录内容 push 到你自己的 GitHub 仓库根目录。
2. Settings → Actions → General → 打开 Read and write permissions。
3. Actions 页 Run workflow：
   - `ENABLE_SSH=true`、`SSH_MINUTES=10`
   - 开跑后等「🐚 在线 SSH 调试窗口」这一步，日志里复制 `ssh ...tmate.io...` 连进去。
4. SSH 里常用：
   ```bash
   cd $OPENWRT_PATH
   make menuconfig          # 补插件
   make kernel_menuconfig   # 调 YT9215S / PWM 驱动
   make defconfig
   touch /tmp/continue      # 提前结束 SSH
   ```

## 你可能要再调的地方

- **dts 注入**：把你移植好的 `rk3588-bdy-g98.dts` 放到 `diy/` 下，diy.sh 会自动拷进内核源码树并登记 Makefile。
- **PWM 通道**：风扇脚本里 `/sys/class/hwmon/hwmon0/pwm1` 按你板子实际 pwmN 改（G98 一般在 PWM8/PWM9_M1）。
- **YT9215S**：如果内核里 swconfig 识别不到，SSH 里 `make kernel_menuconfig` 开 `CONFIG_YT9215` 或对应 DSA 驱动。
- **网口编号**：`files/etc/config/network` 里的 `lan1..lan8` 改成你 dts 里实际的 PHY 口名。
