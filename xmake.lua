-- 设置工程名
set_project("stm32-xmake")

-- 设置工程版本
set_version("1.0.0")

add_rules("mode.debug", "mode.release")

-- 自定义工具链
toolchain("arm-none-eabi")
    -- 标记为独立工具链
    set_kind("standalone")
    -- 定义交叉编译工具链地址
    set_sdkdir("C:\\gcc-arm-none-eabi\\10 2021.10")
    --set_bindir("C:\\Program Files (x86)\\GNU Arm Embedded Toolchain\\10 2021.10\\bin")
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
       -- 添加启动文件
    add_files("startup_stm32f103xe.s");
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
        "-x assembler-with-cpp",
        "-Wall",
        "-fdata-sections", 
        "-ffunction-sections",
        "-g -gdwarf-2",
        {force = true}
    )

    add_ldflags(
        "-Og",
        "-mcpu=cortex-m3",
        "-TSTM32F103ZETx_FLASH.ld",
        "-Wl,--gc-sections",
        "--specs=nosys.specs",
        "-u _printf_float",  
        {force = true}
    )

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