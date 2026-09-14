cmake_minimum_required(VERSION 3.16)
project(km16_custom_firmware_scaffold VERSION 0.1.0 LANGUAGES C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

add_library(km16_core STATIC
    src/board_profile.c
    src/debounce.c
    src/encoder.c
    src/led_pwm.c
    src/uart_frame.c
)
target_include_directories(km16_core PUBLIC include)

if(CMAKE_C_COMPILER_ID MATCHES "Clang|GNU")
    target_compile_options(km16_core PRIVATE -Wall -Wextra -Wpedantic -Werror)
endif()

add_executable(km16_custom_demo examples/simulated_demo.c)
target_link_libraries(km16_custom_demo PRIVATE km16_core)

include(CTest)
if(BUILD_TESTING)
    add_executable(km16_core_tests tests/test_core.c)
    target_link_libraries(km16_core_tests PRIVATE km16_core)
    if(CMAKE_C_COMPILER_ID MATCHES "Clang|GNU")
        target_compile_options(km16_core_tests PRIVATE -Wall -Wextra -Wpedantic -Werror)
    endif()
    add_test(NAME km16_core_tests COMMAND km16_core_tests)
endif()

find_program(KM16_CLANG_EXECUTABLE NAMES clang)
if(KM16_CLANG_EXECUTABLE)
    set(KM16_CORTEX_OBJECT_DIR "${CMAKE_CURRENT_BINARY_DIR}/cortex-m3")
    set(KM16_CORTEX_FLAGS
        --target=arm-none-eabi -mcpu=cortex-m3 -mthumb -std=c11
        -ffreestanding -fno-builtin -Wall -Wextra -Wpedantic -Werror
        -I${CMAKE_CURRENT_SOURCE_DIR}/include
    )
    add_custom_target(cortex-m3-objects
        COMMAND ${CMAKE_COMMAND} -E make_directory "${KM16_CORTEX_OBJECT_DIR}"
        COMMAND ${KM16_CLANG_EXECUTABLE} ${KM16_CORTEX_FLAGS} -c ${CMAKE_CURRENT_SOURCE_DIR}/src/board_profile.c -o ${KM16_CORTEX_OBJECT_DIR}/board_profile.o
        COMMAND ${KM16_CLANG_EXECUTABLE} ${KM16_CORTEX_FLAGS} -c ${CMAKE_CURRENT_SOURCE_DIR}/src/debounce.c -o ${KM16_CORTEX_OBJECT_DIR}/debounce.o
        COMMAND ${KM16_CLANG_EXECUTABLE} ${KM16_CORTEX_FLAGS} -c ${CMAKE_CURRENT_SOURCE_DIR}/src/encoder.c -o ${KM16_CORTEX_OBJECT_DIR}/encoder.o
        COMMAND ${KM16_CLANG_EXECUTABLE} ${KM16_CORTEX_FLAGS} -c ${CMAKE_CURRENT_SOURCE_DIR}/src/led_pwm.c -o ${KM16_CORTEX_OBJECT_DIR}/led_pwm.o
        COMMAND ${KM16_CLANG_EXECUTABLE} ${KM16_CORTEX_FLAGS} -c ${CMAKE_CURRENT_SOURCE_DIR}/src/uart_frame.c -o ${KM16_CORTEX_OBJECT_DIR}/uart_frame.o
        COMMENT "Compile portable core objects for ARM Cortex-M3 (no link or firmware image)"
        VERBATIM
    )
endif()
