# 构建编译使用HAL库的STM32程序

## 环境搭建

xmake-io/xmake下载：
[https://github.com/xmake-io/xmake/releases/tag/v2.6.9](https://github.com/xmake-io/xmake/releases/tag/v2.6.9)

arm-none-eabi-gcc 下载：
Downloads | GNU Arm Embedded Toolchain Downloads – Arm Developer
[https://developer.arm.com/downloads/-/gnu-rm](https://developer.arm.com/downloads/-/gnu-rm)

安装都是一路next下去就可以了。
安装记得勾选添加到环境变量。

xmake入门，构建项目原来可以如此简单
[https://zhuanlan.zhihu.com/p/35051214](https://zhuanlan.zhihu.com/p/35051214)

xmake新增智能代码扫描编译模式，无需手写任何make文件
[https://tboox.org/cn/2017/01/07/build-without-makefile/](https://tboox.org/cn/2017/01/07/build-without-makefile/)

## 准备工作

**对比MDK开发STM32：**

* MDK开发STM32工程必然有个启动文件 `(汇编.s)`，没有启动文件无法设置栈跳转到C语言世界
* MDK通过UI界面直观地设置内存分配，加载地址、链接地址等，本质也是MDK根据设置生成 `散列文件(.sct)`，在GNU那里这种叫 `链接文件(.ld)`或 `链接脚本`
  ![在这里插入图片描述](https://img-blog.csdnimg.cn/3752f1997e3e41d0a02c62697a2ccc5e.png)

如何得到链接文件和启动文件：

* 自己编写，太麻烦。
* 安装完arm-none-eabi工具链后 根目录的 `share\gcc-arm-none-eabi\samples` 下有链接文件和启动文件的模板
* 从ST提供的固件库中copy
* 通过STM32CubeMx生成STM32工程，选择 `Toolchain / IDE的方式为Makefile`，生成的工程就带有启动文件和链接文件
  ![在这里插入图片描述](https://img-blog.csdnimg.cn/79e95d06ef1d410bb3afded5675cb6fa.png)

为了方便选择STM32CubeMx 的方式生成工程，`还可以方便参照生成的makefile来设置编译链接选项`。
![在这里插入图片描述](https://img-blog.csdnimg.cn/521ec31c19364ccca82f4a357e41eda7.png)

## 编写xmake的构建文件xmake.lua文件

```lua
-- 设置工程名
set_project("stm32-xmake")

-- 设置工程版本
set_version("1.0.0")

add_rules("mode.debug", "mode.release")

-- 自定义工具链
toolchain("arm-none-eabi")
    -- 标记为独立工具链
    set_kind("standalone")
    -- 设置工具链路径
    set_sdkdir("C:\\Program Files (x86)\\GNU Arm Embedded Toolchain\\10 2021.10\\")
    set_bindir("C:\\Program Files (x86)\\GNU Arm Embedded Toolchain\\10 2021.10\\bin")
toolchain_end()

target("demo")
    -- 编译为二进制程序
    set_kind("binary") 
    -- 设置使用的交叉编译工具链
    set_toolchains("arm-none-eabi")  

    -- 设置平台
    set_plat("cross")
    -- 设置架构
    set_arch("m3")

    set_filename("demo.elf")

    add_defines(
        "USE_HAL_DRIVER",
        "STM32F103xE"
    )
  
    -- 添加链接库
    add_links("c", "m", "nosys", "rdimon");
  
    -- 添加启动文件
    add_files("startup_stm32f103xe.s");
  
    local link_script = "STM32F103ZETx_FLASH.ld"
  
    -- 汇编编译选项
    local asmflags = {
        "-mcpu=cortex-m3", 
        "-mthumb", 
        "-Og", 
        "-Wall", 
        "-fdata-sections", 
        "-ffunction-sections",  
        "-g -gdwarf-2",
        {force = true}   -- {force = true} 强制启用参数
    }
    -- C编译选项
    local cflags = {
        "-mcpu=cortex-m3",
        "-Og", 
        "-Wall", 
        "-fdata-sections", 
        "-ffunction-sections", 
        "-g -gdwarf-2", 
        {force = true}
    }
    -- 链接选项
    local ldflags = {
        "-mcpu=cortex-m3",
        "--specs=nosys.specs",
        "-Wl,-Map=STM32_XMake.map,--cref",
        "-Wl,--gc-sections",
        "-u _printf_float",  -- 支持 printf %f
        {force = true}
    }   
    -- 设置链接文件的链接选项
    ldflags_link_script = "-T"..link_script

    -- 源文件和头文件路径
    local src_path = {
        "./Core/",
        "./Drivers/STM32F1xx_HAL_Driver/",
    }
    -- 特殊头文件目录，不方便递归遍历的
    local inc_path = {
        "Drivers/CMSIS/Include",
        "Drivers/CMSIS/Device/ST/STM32F1xx/Include"
    }

    -- 排除的文件，不参与编译 模板文件可以直接删除
    remove_files("./Drivers/STM32F1xx_HAL_Driver/Src/stm32f1xx_hal_timebase_tim_template.c")
    remove_files("./Drivers/STM32F1xx_HAL_Driver/Src/stm32f1xx_hal_timebase_rtc_alarm_template.c")
    remove_files("./Drivers/STM32F1xx_HAL_Driver/Src/stm32f1xx_hal_msp_template.c")

    for _, index in ipairs(src_path) do  -- 遍历 src_path
        for _, dir in ipairs(os.dirs(index.."/**")) do  -- 递归搜索子目录
            add_files(dir.."/*.c");  -- 添加源文件
            add_includedirs(dir); -- 添加头文件目录
        end
    end

    -- 添加头文件路径
    for _, inc in ipairs(inc_path) do
        add_includedirs(inc);
    end
   
    if is_mode("debug") then 
        add_cflags("-g", "-gdwarf-2")
    end
    -- 添加c编译选项
    for _, c in ipairs(cflags) do
        add_cflags(c);
    end
    -- 添加汇编编译选项
    for _, as in ipairs(asmflags) do
        add_asflags(as);
    end

    -- 添加链接选项
    for _, ld in ipairs(ldflags) do
        add_ldflags(ld)
    end 
    add_ldflags(ldflags_link_script);

    after_build(
        function(target)
        cprint("Compile finished!!!")
        cprint("Next, generate HEX and bin files.")
        os.exec("arm-none-eabi-objcopy -O ihex ./build/cross/m3/release/demo.elf ./build/demo.hex")
        os.exec("arm-none-eabi-objcopy -O binary ./build/cross/m3/release/demo.elf ./build/demo.bin")
        print("Generate hex and bin files ok!!!")

        print(" ");
        print("********************储存空间占用情况*****************************")
        os.exec("arm-none-eabi-size -Ax ./build/cross/m3/release/demo.elf")
        os.exec("arm-none-eabi-size -Bx ./build/cross/m3/release/demo.elf")
        os.exec("arm-none-eabi-size -Bd ./build/cross/m3/release/demo.elf")
        --print("heap-堆, stack-栈, .data-已初始化的变量全局/静态变量, .bss-未初始化的data, .text-代码和常量")
        --os.run("arm-none-eabi-objdump -D ./build/cross/m3/release/demo.elf > demo.s")
    end)
```

* `add_defines( "USE_HAL_DRIVER", "STM32F103xE")` 设置宏，类似MDK以下设置
* 终端根目录执行xmake编译
  ![在这里插入图片描述](https://img-blog.csdnimg.cn/8baaf5448d7041ad828206097c484dc2.png)

## 错误解决

arm-none-eabi-gcc 报错 undefined reference to `_exit'解决方案_Pz_mstr的博客-CSDN博客
[https://blog.csdn.net/qq_35544379/article/details/104805295](https://blog.csdn.net/qq_35544379/article/details/104805295)

工具链已经设置到环境变量测试已经生效，但在Vscode上的终端还是无法生效的解决办法：
windows 修改环境变量后在 vscode 的终端不生效的解决方法 | 码农家园
[https://www.codenong.com/jsf9a5c0fed195/](https://www.codenong.com/jsf9a5c0fed195/)

## 参考

GNU（gcc-arm-none-eabi）编译stm32代码，重定向printf问题_一个逍遥怪的博客-CSDN博客_gcc printf 重定向
[https://blog.csdn.net/qq_42704360/article/details/102853340](https://blog.csdn.net/qq_42704360/article/details/102853340)

---

# 使用xmake构建使用标准库的实际项目程序

## 编写xmake文件

```c
-- 设置工程名
set_project("stm32-xmake")

-- 设置工程版本
set_version("1.0.0")

add_rules("mode.debug", "mode.release")

-- 自定义工具链
toolchain("arm-none-eabi")
    -- 标记为自定义独立工具链
    set_kind("standalone")
    -- 定义交叉编译工具链地址
    set_sdkdir("C:\\gcc-arm-none-eabi\\10 2021.10")
toolchain_end()

target("LED_DRV.elf")
    -- 编译为二进制程序
    set_kind("binary") 
    -- 设置使用的交叉编译工具链
    set_toolchains("arm-none-eabi")  

    -- 设置平台 表示交叉编译程序
    set_plat("cross")
    -- 设置架构
    set_arch("m3")
  
    add_defines(
        "USE_STDPERIPH_DRIVER",  -- 表示使用标准库
        "STM32F10X_MD"  --  中容量  根据芯片容量选择
    )
  
    -- 添加链接库
    add_links("c", "m", "nosys", "rdimon");  -- 链接选项添加 ：-lc -lm -lnosys -lrdimon 
  
    -- 添加启动文件
    add_files("startup_stm32f10x_md.s");

    add_cflags(
        "-Og",
        "-mcpu=cortex-m3",
        "-mthumb",
        "-Wall",
        "-fdata-sections",
        "-ffunction-sections",
        "-g -gdwarf-2",
        {force = true}
    )

    add_asflags(
        "-Og",
        "-mcpu=cortex-m3",
        "-mthumb",
    --    "-x assembler-with-cpp",
        "-Wall",
        "-fdata-sections", 
        "-ffunction-sections",
        "-g -gdwarf-2",
        {force = true}
    )

    add_ldflags(
        "-Og",
        "-mcpu=cortex-m3",
        "-TSTM32F103C8Tx_FLASH.ld",  -- 不同芯片需要修改链接脚本
        "-Wl,--gc-sections",
        "--specs=nosys.specs",
        "-u _printf_float",  
        {force = true}
    )
  
    -- 源文件和头文件路径
    local src_path = {
        "USER/",
        "Common/src",
        "./MqEvent/",
        "Lib/Fwlib",
        "Lib/Fwlib/src",
        "./Lib/CMSIS/",
        "USER/app/src",
        "USER/bsp/src"
    }
    -- 头文件路径
    local inc_path = {
        "./MqEvent/",
        "./Lib/CMSIS/",
        "Lib/Fwlib/inc",
        "Common/inc",
        "USER/app/inc",
        "USER/bsp/inc"
    }

    -- 排除的文件，不参与编译
    remove_files("Common\\src\\meanFilter.c")
    remove_files("USER\\bsp\\src\\VirtualCOM.c")
  
    for _, dir in ipairs(src_path) do  -- 遍历 src_path
        add_files(dir.."/*.c"); 
    end

    -- 添加头文件路径
    for _, inc in ipairs(inc_path) do
        add_includedirs(inc);
    end
   
    if is_mode("debug") then 
        add_cflags("-g", "-gdwarf-2")
    end

    after_build(
        function(target)
        cprint("Compile finished!!!")
        cprint("Next, generate hex and bin files.")
        os.exec("arm-none-eabi-objcopy -O ihex ./build/cross/m3/release/LED_DRV.elf ./build/LED_DRV.hex")
        os.exec("arm-none-eabi-objcopy -O binary ./build/cross/m3/release/LED_DRV.elf ./build/LED_DRV.bin")
        print("Generate hex and bin files ok!!!")

        print(" ");
        print("********************储存空间占用情况*****************************")
        os.exec("arm-none-eabi-size -Ax ./build/cross/m3/release/LED_DRV.elf")
        os.exec("arm-none-eabi-size -Bx ./build/cross/m3/release/LED_DRV.elf")
        os.exec("arm-none-eabi-size -Bd ./build/cross/m3/release/LED_DRV.elf")
        --print("heap-堆, stack-栈, .data-已初始化的变量全局/静态变量, .bss-未初始化的data, .text-代码和常量")
        -- os.run("arm-none-eabi-objdump.exe -D ./build/cross/m3/release/LED_DRV.elf > LED_DRV.s")
    end)
```

* 在终端中切换到工程根目录执行 `xmake`编译，如果使用的是Vscode，可以在编辑器内就可以打开终端，默认就是根路径；如果使用的编辑器无此功能，则可以打开powershell或bash等shell终端编译。
  **使用Vscode内打开终端编译，在window下实际上打开的也是powershell：**
  ![在这里插入图片描述](https://img-blog.csdnimg.cn/e9d4145c88464f20a007eac6147cb3a7.png)
  ![在这里插入图片描述](https://img-blog.csdnimg.cn/84edc29b966d444ca82ac01e2a98687a.png)
  如果是想单独打开powershell编译，一个实用技巧就是在当前目录路径输入powershell回车就会打开一个powershell终端并且已经切换到工程根路径。
* 如果xmake.lua是拷贝另一个工程，编译此工程可能会还是编译上一个工程的程序，这样可能会出问题，这时候可以执行 `xmake -P .`，表示强制使用当前目录下的 `xmake.lua`编译工程。
* `startup_stm32f10x_md.s` 从标准库标准库固件包中获取，也可以用STM32CubeMx生成的。
* `STM32F103C8Tx_FLASH.ld` 链接脚本使用STM32CubeMx生成的，也可以从标准库固件包中获取。
* Vscode添加源码头文件路径的技巧：对文件目录树的文件或目录右键选择复制相对路径，就可以快速添加目录。

## 解决编译错误

1、解决内联汇编错误

```c
C:\Users\opto\AppData\Local\Temp\cc3sKKIq.s:619: Error: registers may not be the same -- `strexb r0,r0,[r1]'
C:\Users\opto\AppData\Local\Temp\cc3sKKIq.s:650: Error: registers may not be the same -- `strexh r0,r0,[r1]'
stack traceback:
```

参考HAL库头文件 `Drivers\CMSIS\Core_A\Include\cmsis_gcc.h`, 对 `core_cm3.c`做以下修改：

```c
uint32_t __STREXB(uint8_t value, uint8_t *addr)
{
   uint32_t result=0;
  
   //__ASM volatile ("strexb %0, %2, [%1]" : "=r" (result) : "r" (addr), "r" (value) );
   __ASM volatile ("strexb %0, %2, %1" : "=&r" (result), "=Q" (*addr) : "r" ((uint32_t)value) );
   return(result);
}

uint32_t __STREXH(uint16_t value, uint16_t *addr)
{
   uint32_t result=0;
  
   //__ASM volatile ("strexh %0, %2, [%1]" : "=r" (result) : "r" (addr), "r" (value) );
   __ASM volatile ("strexh %0, %2, %1" : "=&r" (result), "=Q" (*addr) : "r" ((uint32_t)value) );
   return(result);
}
```

2、解决 sbrkr.c:(.text._sbrk_r+0xc): undefined reference to `_sbrk' 等问题

```c
error: c:/gcc-arm-none-eabi/10 2021.10/bin/../lib/gcc/arm-none-eabi/10.3.1/../../../../arm-none-eabi/bin/ld.exe: c:/gcc-arm-none-eabi/10 2021.10/bin/../lib/gcc/arm-none-eabi/10.3.1/../../../../arm-none-eabi/lib/thumb/v7-m/nofp\libc.a(lib_a-sbrkr.o): in function `_sbrk_r':
sbrkr.c:(.text._sbrk_r+0xc): undefined reference to `_sbrk'
c:/gcc-arm-none-eabi/10 2021.10/bin/../lib/gcc/arm-none-eabi/10.3.1/../../../../arm-none-eabi/bin/ld.exe: c:/gcc-arm-none-eabi/10 2021.10/bin/../lib/gcc/arm-none-eabi/10.3.1/../../../../arm-none-eabi/lib/thumb/v7-m/nofp\libc.a(lib_a-writer.o): in function `_write_r':
writer.c:(.text._write_r+0x14): undefined reference to `_write'
c:/gcc-arm-none-eabi/10 2021.10/bin/../lib/gcc/arm-none-eabi/10.3.1/../../../../arm-none-eabi/bin/ld.exe: c:/gcc-arm-none-eabi/10 2021.10/bin/../lib/gcc/arm-none-eabi/10.3.1/../../../../arm-none-eabi/lib/thumb/v7-m/nofp\libc.a(lib_a-closer.o): in function `_close_r':
closer.c:(.text._close_r+0xc): undefined reference to `_close'
c:/gcc-arm-none-eabi/10 2021.10/bin/../lib/gcc/arm-none-eabi/10.3.1/../../../../arm-none-eabi/bin/ld.exe: c:/gcc-arm-none-eabi/10 2021.10/bin/../lib/gcc/arm-none-eabi/10.3.1/../../../../arm-none-eabi/lib/thumb/v7-m/nofp\libc.a(lib_a-fstatr.o): in function `_fstat_r':
fstatr.c:(.text._fstat_r+0xe): undefined reference to `_fstat'
c:/gcc-arm-none-eabi/10 2021.10/bin/../lib/gcc/arm-none-eabi/10.3.1/../../../../arm-none-eabi/bin/ld.exe: c:/gcc-arm-none-eabi/10 2021.10/bin/../lib/gcc/arm-none-eabi/10.3.1/../../../../arm-none-eabi/lib/thumb/v7-m/nofp\libc.a(lib_a-isattyr.o): in function `_isatty_r':
isattyr.c:(.text._isatty_r+0xc): undefined reference to `_isatty'
c:/gcc-arm-none-eabi/10 2021.10/bin/../lib/gcc/arm-none-eabi/10.3.1/../../../../arm-none-eabi/bin/ld.exe: c:/gcc-arm-none-eabi/10 2021.10/bin/../lib/gcc/arm-none-eabi/10.3.1/../../../../arm-none-eabi/lib/thumb/v7-m/nofp\libc.a(lib_a-lseekr.o): in function `_lseek_r':
lseekr.c:(.text._lseek_r+0x14): undefined reference to `_lseek'
c:/gcc-arm-none-eabi/10 2021.10/bin/../lib/gcc/arm-none-eabi/10.3.1/../../../../arm-none-eabi/bin/ld.exe: c:/gcc-arm-none-eabi/10 2021.10/bin/../lib/gcc/arm-none-eabi/10.3.1/../../../../arm-none-eabi/lib/thumb/v7-m/nofp\libc.a(lib_a-readr.o): in function `_read_r':
readr.c:(.text._read_r+0x14): undefined reference to `_read'
c:/gcc-arm-none-eabi/10 2021.10/bin/../lib/gcc/arm-none-eabi/10.3.1/../../../../arm-none-eabi/bin/ld.exe: c:/gcc-arm-none-eabi/10 2021.10/bin/../lib/gcc/arm-none-eabi/10.3.1/../../../../arm-none-eabi/lib/thumb/v7-m/nofp\libc.a(lib_a-abort.o): in function `abort':
c:/gcc-arm-none-eabi/10 2021.10/bin/../lib/gcc/arm-none-eabi/10.3.1/../../../../arm-none-eabi/bin/ld.exe: c:/gcc-arm-none-eabi/10 2021.10/bin/../lib/gcc/arm-none-eabi/10.3.1/../../../../arm-none-eabi/lib/thumb/v7-m/nofp\libc.a(lib_a-signalr.o): in function `_kill_r':
signalr.c:(.text._kill_r+0xe): undefined reference to `_kill'
c:/gcc-arm-none-eabi/10 2021.10/bin/../lib/gcc/arm-none-eabi/10.3.1/../../../../arm-none-eabi/bin/ld.exe: c:/gcc-arm-none-eabi/10 2021.10/bin/../lib/gcc/arm-none-eabi/10.3.1/../../../../arm-none-eabi/lib/thumb/v7-m/nofp\libc.a(lib_a-signalr.o): in function `_getpid_r':
signalr.c:(.text._getpid_r+0x0): undefined reference to `_getpid'
collect2.exe: error: ld returned 1 exit status
```

* 解决：加上链接选项：`--specs=nosys.specs`

## STM32标准库修改Flash起始地址

![在这里插入图片描述](https://img-blog.csdnimg.cn/17a8e2a887f245d6ab85f230cff11699.png)

## 修改中断向量

* 修改文件：`Lib\CMSIS\system_stm32f10x.c` ：

```c
128 #define VECT_TAB_OFFSET  0xB000 /*!< Vector Table base offset field. 

264 #ifdef VECT_TAB_SRAM
265  SCB->VTOR = SRAM_BASE | VECT_TAB_OFFSET; /* Vector Table Relocation in Internal SRAM. */
266 #else
267  SCB->VTOR = FLASH_BASE | VECT_TAB_OFFSET; /* Vector Table Relocation in Internal FLASH. */
268 #endif 
```

* 将 `VECT_TAB_OFFSET`  从0x0修改为 `0xB000`
* 也可以调用 `NVIC_SetVectorTable(NVIC_VectTab_FLASH, 0xB000)`;   设置

## 修改链接地址

修改链接地址也就是修改链接文件

```c
/* Specify the memory areas */
MEMORY
{
RAM (xrw)      : ORIGIN = 0x20000000, LENGTH = 20K
FLASH (rx)      : ORIGIN = 0x800B000, LENGTH = 64K
}
```

* 将链接地址从 `0x8000000`改为 `0x800B000`

设置完成后执行xmake编译
然后可以通过生成 `反汇编文件`查看程序链接地址修改是否正常
![在这里插入图片描述](https://img-blog.csdnimg.cn/8b262573c9314f86b56b9fd08f8056eb.png)

**反汇编：**

```c
Disassembly of section .isr_vector:

0800b000 <.isr_vector>:
 800b000:	20005000 	andcs	r5, r0, r0
 800b004:	0800c541 	stmdaeq	r0, {r0, r6, r8, sl, lr, pc}
 800b008:	0800d4d1 	stmdaeq	r0, {r0, r4, r6, r7, sl, ip, lr, pc}
 800b00c:	0800d4d3 	stmdaeq	r0, {r0, r1, r4, r6, r7, sl, ip, lr, pc}
```

可以看到中断向量地址已经从 `0800b000` 开始，说明设置成功。

## printf实现

1、重定向printf
**usart_printf.c：**

```c
#include "stm32f1xx_hal.h"
#include "usart.h"

int _write(int fd, char *buf, int size)
{
    for (int i = 0; i < size; i++)
    {
        while ((USART1->SR & 0X40) == 0); /* wait finised */
        USART1->DR = (uint8_t)buf[i]; /* send data */
    }
    return size;
}
```

2、自己编写printf

```c
void myprintf(const char *format, ...)
{
    char  str[256] = {0};
    va_list   v_args;

    va_start(v_args, format);
   (void)vsnprintf((char       *)&str[0],
                   (size_t      ) sizeof(str),
                   (char const *) format,
                                  v_args);
    va_end(v_args);

    usart1Write((char *)str, strlen(str));
}
```

重定向串口发现bin程序尺寸已经涨了58KB，后经过搜索解决：

* 加入链接选项 `--specs=nano.specs`,编译器会使用 `newlib_nano`库， `newlib_nano`应该是类似MDK micro Lib的一个东西，编译完bin文件尺寸已经降到40KB。

# 测试

除了构建APP工程，还构建了Bootloader工程，测试从Bootloader程序跳转到APP程序都没问题。

# 总结

* 使用这种方式开发适用于所有Cortex-M的芯片，不必受限于某个芯片的专用IDE,如STM32CubeIDE只能用于STM32。
* 所用涉及的软件全为开源免费的软件。
* 不用编写修改Makefile，构建项目容易。
* 可以使用任意编辑器，可以是Vscode、source insight，甚至是记事本。推荐使用Vscode，Vscode内就可以打开终端执行编译，用其他编辑器可能就要另外打开powershell或bash之类的进行编译了。

**使用arm-none-eabi-gcc的缺点：**

* 由于MDK armcc工具针对性做了优化，编译出来的代码尺寸相对较小；arm-none-eabi-编译出来的代码尺寸相比armcc编译的偏大的。
