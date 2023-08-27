#!/bin/sh
tmp=/data/local/tmp/Kernel && [ ! -d "$tmp" ] && mkdir -p "$tmp"

function echo_color() {
 # 随机选择一种颜色
 colors=("31" "32" "33" "34" "35" "36")
 random_index=$((RANDOM % ${#colors[@]}))
 selected_color=${colors[$random_index]}
 # 输出带有随机颜色的文本
 echo -e "\033[0;${selected_color}m$1\033[0m"
}

function unpack(){
 $tmp/magiskboot unpack "$1" 2>&1 | while IFS= read -r line; do
  echo_color "$line"
 done
}

function repack(){
 $tmp/magiskboot repack "$1" 2>&1 | while IFS= read -r line; do
  echo_color "$line"
 done
}

function getEventKey() {
 local event_input=$(getevent -qlc 1 | awk '{ print $3 }')
 if [[ "$event_input" == "KEY_VOLUMEUP" ]]; then
  echo "+"
 elif [[ "$event_input" == "KEY_VOLUMEDOWN" ]]; then
  echo "-"
 fi
}

function getIMGPath() {
 local IMGFile=$1
 if [ -e "/dev/block/bootdevice/by-name/$IMGFile" ]; then
  echo "/dev/block/bootdevice/by-name/$IMGFile"
  return
 elif [ -e "/dev/block/by-name/$IMGFile" ]; then
  echo "/dev/block/by-name/$IMGFile"
  return
 fi
}

# 检查 VPN 连接状态的命令
if [ -z "$(ip route | grep tun)" ]; then
 echo_color "未开启 VPN 因为访问的目标是github"
 # exit 1;
fi

if [ -f "$tmp/magiskboot" ]; then
 echo_color "magiskboot 已存在."
else
 echo_color "magiskboot 不存在，正在下载..."
 sleep 1.5s
 HTTP_STATUS=$(curl -sLo "$tmp/magiskboot" "https://raw.githubusercontent.com/getcurl/magiskboot/getcurl/magiskboot" -w "%{http_code}" && chmod 755 "$tmp/magiskboot")
 md5_check=$(md5sum "$tmp/magiskboot" 2>/dev/null | awk '{print $1}')
 if [ "$HTTP_STATUS" = "200" ] && [ "$md5_check" = "5caeb96e338021fabc5398143e02a575" ]; then
  echo_color "magiskboot 下载完成，设置权限为755."
 else
  echo_color "magiskboot 下载失败，请重新运行或者检查代理是否有效"
  rm -f "$tmp/magiskboot"
  exit 1
 fi
fi

# Kernel version
ker_ver=$(echo "$(uname -r)" | awk -F '-' '{print $1}')
# KernelSU version
ksu_ver=$(pm dump "me.weishu.kernelsu" | grep -m 1 versionName | sed -n 's/.*=//p')
[ -z "$ksu_ver" ] && {
 echo_color "未安装 KernelSU 执行泥马"
 exit 1
}

echo_color "内核版本: $ker_ver"
echo_color "KernelSU版本：$ksu_ver"

suffix="$(getprop ro.boot.slot_suffix)"
[ -z "$suffix" ] && {
 echo_color "无法获取当前系统分区"
 exit 1
}
#echo_color "分区路径为：$(getIMGPath boot${boot_suffix})"

local init_boot=$(getIMGPath "boot${suffix}")
if [ -n "$init_boot" ] && [ -e "$init_boot" ]; then
 echo_color "存在 init_boot 分区"
 mkdir -p $tmp/backup
 #dd if="$init_boot" of="$tmp/init_boot" 2>/dev/null
 cp -p $tmp/boot $tmp/backup
 echo "dd提取完成"

 unpack "$tmp/boot"

 if [ -e ramdisk.cpio ]; then
  mv ramdisk.cpio $tmp
  find_magisk=$(cpio -t <"$tmp/ramdisk.cpio" | grep "overlay.d/sbin/magisk.*.xz")

  if [[ $find_magisk == *"overlay.d/sbin/magisk"* ]]; then
   echo "init_boot 发现 Magisk"
   echo " "
   echo "(!) 发现Magisk "
   echo "(?) 是否移除 Magisk"
   echo "- 按下 [音量+] 选择 移除\n- 按下 [音量-] 选择 保留"
   if [ "$(getEventKey)" == "+" ]; then
  
   #unpack "$tmp/boot"

    $tmp/magiskboot cpio $tmp/ramdisk.cpio restore 2>&1 | while IFS= read -r line; do
  echo_color "$line"
 done
 
 repack $tmp/boot
 
    
   fi
  fi

 fi

fi

# 使用grep和sed截取内容
kernel_boot=$(echo "$(curl -sL https://github.com/tiann/KernelSU/releases/expanded_assets/$ksu_ver)" | grep -o 'class="Truncate-text text-bold">.*</span>' | sed 's/class="Truncate-text text-bold">//; s/<\/span>//' | grep -E 'boot\.img')
kernel_name=$(echo "$kernel_boot" | grep "$ker_ver")

echo $kernel_name
#curl -# -Lo "$tmp/$kernel_name" "https://github.com/tiann/KernelSU/releases/download/$ksu_ver/$kernel_name"

# https://github.com/getcurl/magiskboot/raw/getcurl/magiskboot

# ./magiskboot cpio ramdisk.cpio restore 卸载magisk
