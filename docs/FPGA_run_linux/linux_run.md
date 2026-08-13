# 使用 U-Boot 网络启动 Linux

启动流程如下：

1. 将 [u-boot.bin](https://gitee.com/loongson-edu/la32r-uboot/releases/download/loongsonsoc-v0.1.0/u-boot.bin) 烧写到 SPI Flash。
2. 下载 SoC bitstream。
3. 通过串口进入 U-Boot。
4. 通过 TFTP 将 `vmlinux` 下载到 DDR。
5. 使用 `bootelf` 启动内核。

## 烧写 U-Boot

使用串口编程 bitstream 将 `u-boot.bin` 写入 Flash，具体步骤见
[串口烧写 Flash 说明](./flash.md)。编程串口波特率为 `230400`，传输方式为
XMODEM。

烧写完成后，换回正常 SoC bitstream。U-Boot 运行串口参数为
`115200 8N1`、无流控。

## 串口连接

Linux 下可使用 minicom：

```bash
minicom -s
sudo minicom
```

Windows 下可使用 SecureCRT 等串口终端。连接成功后应看到：

```text
U-Boot 2019.07
DRAM:  128 MiB
u-boot@LoongsonSoC#
```

可使用 `printenv` 查看当前环境。该版本配置为
`CONFIG_ENV_IS_NOWHERE`，用 `setenv` 修改的环境在复位后不会保留。

## 配置网络

开发板和 TFTP 服务器必须处于同一子网。以下地址仅为示例：

```text
setenv ipaddr 10.90.50.44
setenv serverip 10.90.50.43
setenv netmask 255.255.255.0
ping ${serverip}
```

如果网络不通，依次检查网线、服务器防火墙、TFTP 服务、MAC/PHY 和开发板 IP。

## 加载并启动内核

将裁剪后的 ELF 格式 `vmlinux` 放到 TFTP 根目录，然后执行：

```text
tftpboot 0xa3000000 vmlinux
bootelf 0xa3000000 g console=ttyS0,115200 rdinit=/sbin/init
```

`0xa3000000` 是 ELF 文件的临时下载地址。`bootelf` 会根据 ELF Program Header
把内核段复制到链接地址，再跳转到 ELF 入口。不要把临时下载地址改成当前内核
目标段覆盖的区域。

`g` 作为传递给内核的 `argv[0]` 占位符；当前内核从 `argv[1]` 开始拼接命令行。
当前内置 DTB 也包含串口和 `rdinit` 参数，因此即使固件参数被 DTB 覆盖，仍能
进入 initramfs。

成功启动后应看到 Linux 启动日志和 shell 提示符：

```text
loongson:/#
```

## NAND 启动状态

当前 `la32r-uboot` 的 LoongsonSoC 配置没有启用可用的 NAND 启动链路，同时
环境变量也没有持久化后端。因此现阶段只支持上述 TFTP 启动流程。

在实现自动启动前，需要依次完成：

1. 启用并验证 U-Boot NAND 驱动。
2. 确定 NAND 分区布局和内核镜像格式。
3. 增加 SPI Flash 或 NAND 环境变量后端。
4. 设置并验证持久化 `bootcmd`。
