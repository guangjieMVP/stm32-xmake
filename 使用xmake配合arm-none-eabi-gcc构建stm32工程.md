
# 准备工程
* 用过MDK都知道STM32工程必然有个启动文件`(汇编.s)`，没有启动无法设置栈跳转到C语言世界
* MDK通过UI界面直观地设置内存分配情况，本质也是MDK根据设置生成`散列文件(.sct)`，在GNU那里这种叫`链接文件(.ld)`
![在这里插入图片描述](https://img-blog.csdnimg.cn/3752f1997e3e41d0a02c62697a2ccc5e.png)

如何得到链接文件和启动文件：
* 自己编写，太麻烦。
* 安装完arm-none-eabi工具链后 根目录的`share\gcc-arm-none-eabi\samples` 下有链接文件和启动文件的模板
* 通过STM32CubeMx生成STM32工程，选择 `Toolchain / IDE的方式为Makefile`，生成的工程就带有启动文件和链接文件


为了方便选择STM32CubeMx 的方式生成工程，`还可以方便参照生成的makefile来设置编译链接选项`。
![在这里插入图片描述](https://img-blog.csdnimg.cn/521ec31c19364ccca82f4a357e41eda7.png)

# 编写xmake.lua文件

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
    -- set toolchain sdk path
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
            add_files(dir.."/*.c"); 
            add_includedirs(dir);
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

* add_defines( "USE_HAL_DRIVER", "STM32F103xE") 设置宏，类似MDK以下设置
  ![在这里插入图片描述](https://img-blog.csdnimg.cn/8baaf5448d7041ad828206097c484dc2.png)

* 执行**xmake** 编译,默认是**release**

  ```lua
  xmake f -m debug  -- 配置模式切换为debug
  xmake -- 执行编译
  ```

  
# 错误解决
arm-none-eabi-gcc 报错 undefined reference to `_exit'解决方案_Pz_mstr的博客-CSDN博客
[https://blog.csdn.net/qq_35544379/article/details/104805295](https://blog.csdn.net/qq_35544379/article/details/104805295)

工具链已经设置到环境变量测试已经生效，但在Vscode上的终端还是无法生效的解决办法：
windows 修改环境变量后在 vscode 的终端不生效的解决方法 | 码农家园
[https://www.codenong.com/jsf9a5c0fed195/](https://www.codenong.com/jsf9a5c0fed195/)
# 参考
stm32-xmake: 使用xmake来编译cubemx生成的项目
[https://gitee.com/luodeb/stm32-xmake](https://gitee.com/luodeb/stm32-xmake)

GNU（gcc-arm-none-eabi）编译stm32代码，重定向printf问题_一个逍遥怪的博客-CSDN博客_gcc printf 重定向
[https://blog.csdn.net/qq_42704360/article/details/102853340](https://blog.csdn.net/qq_42704360/article/details/102853340)

