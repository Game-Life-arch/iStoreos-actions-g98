#!/bin/bash
# ============================================================
#  diy.sh  —  iStoreOS RK3588 BDY-G98 自定义脚本
#  硬件档案（ophub model_database.conf r123）：
#    rk3588 / 16G RAM / 2x NVMe / SATA
#    2x 2.5GbE (GMAC) + 8x 1GbE (YT9215S switch)
#    FDT: rk3588-bdy-g98.dtb
#    U-Boot: u-boot.itb + idbloader.img
# ============================================================
set -e
cd "$OPENWRT_PATH"

BDY_DTB="rk3588-bdy-g98.dtb"

echo ">>> [diy] 应用 BDY-G98 自定义改动..."

# ---------- 1. 注入 G98 的 dts ----------
# 方式 A：你自己把 dts 放进本仓库 diy/ 下，直接拷进内核源码树
if [ -f "$GITHUB_WORKSPACE/diy/rk3588-bdy-g98.dts" ]; then
  echo ">>> 注入本地 rk3588-bdy-g98.dts"
  cp "$GITHUB_WORKSPACE/diy/rk3588-bdy-g98.dts" \
     linux-*/arch/arm64/boot/dts/rockchip/ 2>/dev/null || true
  # 在 Makefile 里登记
  DTS_MK=$(find linux-* -path '*/boot/dts/rockchip/Makefile' | head -1)
  if [ -n "$DTS_MK" ] && ! grep -q 'rk3588-bdy-g98' "$DTS_MK"; then
    echo 'dtb-$(CONFIG_ARCH_ROCKCHIP) += rk3588-bdy-g98.dtb' >> "$DTS_MK"
  fi
fi

# 方式 B：从 ophub/kernel release 直接拿编译好的 dtb（更快）
# ophub 的 rk3588 内核 release 里带了各板 dtb 包
# curl -L -o /tmp/dtb.tar.gz \
#   "https://github.com/ophub/kernel/releases/download/kernel_rk3588/..."
# tar xzf /tmp/dtb.tar.gz -C /tmp/
# cp "/tmp/dtb/${BDY_DTB}" target/linux/rockchip/image/ 2>/dev/null || true

# ---------- 2. PWM 风扇温控脚本 ----------
# G98 风扇一般挂在 RK3588 PWM8/PWM9。
# 下面是一个简单的 温度->占空比 脚本，放到 /usr/bin/fan-control，并加个 rc 启动
mkdir -p files/usr/bin files/etc/init.d
cat > files/usr/bin/fan-control <<'FANEOF'
#!/bin/sh
# BDY-G98 PWM 风扇温控（按你实际 PWM 通道改 pwmN）
PWM="/sys/class/hwmon/hwmon0/pwm1"
ENABLE="/sys/class/hwmon/hwmon0/pwm1_enable"
[ -e "$ENABLE" ] && echo 1 > "$ENABLE"
while :; do
  T=$(awk '{print int($1/1000)}' /sys/class/thermal/thermal_zone0/temp)
  if   [ "$T" -lt 40 ]; then P=0
  elif [ "$T" -lt 50 ]; then P=80
  elif [ "$T" -lt 60 ]; then P=140
  elif [ "$T" -lt 70 ]; then P=200
  else P=255
  fi
  echo "$P" > "$PWM" 2>/dev/null || true
  sleep 5
done
FANEOF
chmod +x files/usr/bin/fan-control

cat > files/etc/init.d/fan-control <<'INITEOF'
#!/bin/sh /etc/rc.common
START=99
start() { procd_open_instance; procd_set_param command /usr/bin/fan-control; procd_set_param respawn; procd_close_instance; }
stop() { killall fan-control; }
INITEOF
chmod +x files/etc/init.d/fan-control

# ---------- 3. 网口初始配置（2x2.5G=WAN/LAN，8x1G 走 YT9215S 桥） ----------
mkdir -p files/etc/config
cat > files/etc/config/network <<NETEOF
config interface 'loopback'
  option device 'lo'
  option proto 'static'
  option ipaddr '127.0.0.1'
  option netmask '255.0.0.0'

config device
  option name 'br-lan'
  option type 'bridge'
  list ports 'lan1'
  list ports 'lan2'
  list ports 'lan3'
  list ports 'lan4'
  list ports 'lan5'
  list ports 'lan6'
  list ports 'lan7'
  list ports 'lan8'

config interface 'lan'
  option device 'br-lan'
  option proto 'static'
  option ipaddr '192.168.2.1'
  option netmask '255.255.255.0'

config interface 'wan'
  option device 'eth0'
  option proto 'dhcp'
NETEOF

echo ">>> [diy] 完成"
