#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS="$SCRIPT_DIR/.external-docs"
VENV="$SCRIPT_DIR/.venv/bin/python"
INGEST="$SCRIPT_DIR/ingest.py"

mkdir -p "$DOCS"

[ -f "$SCRIPT_DIR/.venv/bin/activate" ] && source "$SCRIPT_DIR/.venv/bin/activate"

# ─── Утилита загрузки ─────────────────────────────────────────────

dl() {
    local url="$1" sub="$2" name="$3" lang="$4" cat="$5"
    local repo=$(basename "$url" .git)
    local target="$DOCS/$repo"
    echo -e "\n📥 $name..."
    if [ -d "$target" ]; then
        (cd "$target" && git pull --quiet 2>/dev/null) || true
    else
        git clone --depth 1 --quiet "$url" "$target" 2>/dev/null || { echo "  ⚠ clone failed: $url"; return; }
    fi
    local path="$target"
    [ -n "$sub" ] && path="$target/$sub"
    if [ -d "$path" ]; then
        local extra_args=""
        [ -n "$cat" ] && extra_args="--category $cat"
        "$VENV" "$INGEST" --path "$path" --source "$name" --language "$lang" $extra_args || echo "  ⚠ ingest failed"
    else
        echo "  ⚠ path not found: $path"
    fi
}

# Для очень больших репозиториев — клонируем только нужную папку
dl_sparse() {
    local url="$1" sub="$2" name="$3" lang="$4" cat="$5"
    local repo=$(basename "$url" .git)
    local target="$DOCS/$repo"
    echo -e "\n📥 $name (sparse: $sub)..."
    if [ -d "$target/$sub" ]; then
        (cd "$target" && git pull --quiet 2>/dev/null) || true
    else
        rm -rf "$target"
        mkdir -p "$target"
        (
            cd "$target"
            git init --quiet
            git remote add origin "$url"
            git config core.sparseCheckout true
            echo "$sub" >> .git/info/sparse-checkout
            git pull --depth 1 --quiet origin main 2>/dev/null || \
            git pull --depth 1 --quiet origin master 2>/dev/null || \
            { echo "  ⚠ sparse clone failed: $url"; return; }
        )
    fi
    local path="$target/$sub"
    if [ -d "$path" ]; then
        local extra_args=""
        [ -n "$cat" ] && extra_args="--category $cat"
        "$VENV" "$INGEST" --path "$path" --source "$name" --language "$lang" $extra_args || echo "  ⚠ ingest failed"
    else
        echo "  ⚠ path not found: $path"
    fi
}

# ═══════════════════════════════════════════════════════════════════
#  PYTHON
# ═══════════════════════════════════════════════════════════════════

do_python() {
    echo -e "\n🐍 ══════ Python ══════"

    # --- Стандартная библиотека ---
    # CPython — официальная документация Python (stdlib, howto, tutorial)
    dl_sparse "https://github.com/python/cpython"      "Doc"           "Python Official Docs"  python ""

    # --- Web-фреймворки ---
    # FastAPI — async REST API
    dl "https://github.com/tiangolo/fastapi"            "docs/en/docs"  "FastAPI Docs"          python ""
    # Django — полноценный web-фреймворк
    dl "https://github.com/django/django"               "docs"          "Django Docs"           python ""
    # Flask — микрофреймворк
    dl "https://github.com/pallets/flask"               "docs"          "Flask Docs"            python ""
    # Starlette — ASGI фреймворк (основа FastAPI)
    dl "https://github.com/encode/starlette"            "docs"          "Starlette Docs"        python ""

    # --- HTTP/Networking клиенты ---
    # HTTPX — async HTTP клиент
    dl "https://github.com/encode/httpx"                "docs"          "HTTPX Docs"            python ""
    # aiohttp — async HTTP клиент и сервер
    dl "https://github.com/aio-libs/aiohttp"            "docs"          "aiohttp Docs"          python ""

    # --- ORM / Базы данных ---
    # SQLAlchemy — ORM и SQL toolkit
    dl "https://github.com/sqlalchemy/sqlalchemy"       "doc/build"     "SQLAlchemy Docs"       python ""
    # psycopg — PostgreSQL адаптер (psycopg3)
    dl "https://github.com/psycopg/psycopg"             "docs"          "Psycopg3 Docs"         python ""

    # --- Валидация / Сериализация ---
    # Pydantic v2 — валидация данных
    dl "https://github.com/pydantic/pydantic"           "docs"          "Pydantic Docs"         python ""
    # Jinja2 — шаблонизатор
    dl "https://github.com/pallets/jinja"               "docs"          "Jinja2 Docs"           python ""
    # Click — CLI фреймворк
    dl "https://github.com/pallets/click"               "docs"          "Click Docs"            python ""
    # Werkzeug — WSGI утилиты
    dl "https://github.com/pallets/werkzeug"            "docs"          "Werkzeug Docs"         python ""

    # --- Тестирование ---
    # Pytest — тестовый фреймворк
    dl "https://github.com/pytest-dev/pytest"           "doc/en"        "Pytest Docs"           python ""

    # --- Задачи / Очереди ---
    # Celery — распределённые задачи
    dl "https://github.com/celery/celery"               "docs"          "Celery Docs"           python ""

    # --- Сборка / Зависимости ---
    # Poetry — менеджер зависимостей
    dl "https://github.com/python-poetry/poetry"        "docs"          "Poetry Docs"           python ""

    # --- Data Science ---
    # NumPy — работа с массивами
    dl "https://github.com/numpy/numpy"                 "doc"           "NumPy Docs"            python ""
    # Pandas — работа с данными
    dl "https://github.com/pandas-dev/pandas"           "doc"           "Pandas Docs"           python ""
}

# ═══════════════════════════════════════════════════════════════════
#  C / C++
# ═══════════════════════════════════════════════════════════════════

do_cpp() {
    echo -e "\n⚙️  ══════ C/C++ ══════"

    # --- Стандарты и гайдлайны ---
    # C++ Core Guidelines (Stroustrup, Sutter)
    dl "https://github.com/isocpp/CppCoreGuidelines"    ""              "C++ Core Guidelines"   cpp ""
    # SEI CERT C Coding Standard — безопасное написание кода на C
    dl "https://github.com/SEI-CERT/secure-c-coding-standard" ""        "CERT C Coding Standard" c ""
    # C FAQ — часто задаваемые вопросы по C (Harbison & Steele стиль)
    dl "https://github.com/mackyle/cstdfaq"             ""              "C Standard FAQ"        c  ""

    # --- Популярные библиотеки C++ ---
    # Abseil — утилиты от Google (строки, хеши, синхронизация)
    dl "https://github.com/abseil/abseil-cpp"           ""              "Abseil C++"            cpp ""
    # fmt — форматирование строк (основа std::format)
    dl "https://github.com/fmtlib/fmt"                  "doc"           "fmt Library"           cpp ""
    # nlohmann/json — JSON для C++
    dl "https://github.com/nlohmann/json"               "docs"          "nlohmann/json"         cpp ""
    # spdlog — быстрое логирование
    dl "https://github.com/gabime/spdlog"               ""              "spdlog"                cpp ""
    # Folly — утилиты от Facebook (futures, async, containers)
    dl "https://github.com/facebook/folly"              ""              "Facebook Folly"        cpp ""
    # ConcurrentQueue — lock-free очередь
    dl "https://github.com/cameron314/concurrentqueue"  ""              "ConcurrentQueue"       cpp ""
    # Boost — крупнейшая коллекция C++ библиотек (filesystem, asio, beast, regex, spirit)
    dl_sparse "https://github.com/boostorg/boost"       "libs"          "Boost C++ Libraries"   cpp ""
    # LLVM — компиляторная инфраструктура (IR, passes, analysis)
    dl_sparse "https://github.com/llvm/llvm-project"    "llvm/docs"     "LLVM Docs"             cpp ""
    # libcxx — реализация C++ Standard Library (libc++)
    dl_sparse "https://github.com/llvm/llvm-project"    "libcxx/docs"   "libc++ Docs"           cpp ""

    # --- Популярные библиотеки C ---
    # GLib — кроссплатформенные утилиты (GObject, GThread, GMainLoop, GHashTable)
    dl "https://github.com/GNOME/glib"                  "docs"          "GLib Docs"             c  ""
    # libuv — асинхронный I/O (основа Node.js): event loop, timers, TCP, UDP, файлы
    dl "https://github.com/libuv/libuv"                 "docs"          "libuv Docs"            c  ""
    # libcurl — передача данных по URL (HTTP, FTP, SFTP, SMTP и др.)
    dl "https://github.com/curl/curl"                   "docs"          "libcurl Docs"          c  ""
    # OpenSSL — криптография и TLS (EVP, X.509, BIO, SSL_CTX)
    dl_sparse "https://github.com/openssl/openssl"      "doc"           "OpenSSL Docs"          c  ""
    # cJSON — лёгкий JSON-парсер на C
    dl "https://github.com/DaveGamble/cJSON"            ""              "cJSON Library"         c  ""
    # Unity — unit-тестирование для C (embedded/bare-metal)
    dl "https://github.com/ThrowTheSwitch/Unity"        "docs"          "Unity Test C"          c  ""

    # --- Межъязыковое взаимодействие ---
    # pybind11 — C++ ↔ Python привязки
    dl "https://github.com/pybind/pybind11"             "docs"          "pybind11 Docs"         cpp ""
    # SWIG — обёртки C/C++ для Python, Java, etc.
    dl "https://github.com/swig/swig"                   "Doc"           "SWIG Docs"             cpp ""

    # --- Тестирование ---
    # GoogleTest
    dl "https://github.com/google/googletest"           "docs"          "GoogleTest Docs"       cpp ""
    # Catch2
    dl "https://github.com/catchorg/Catch2"             "docs"          "Catch2 Docs"           cpp ""

    # --- Сериализация / RPC ---
    # Protocol Buffers
    dl "https://github.com/protocolbuffers/protobuf"    "docs"          "Protobuf Docs"         cpp ""
    # gRPC
    dl "https://github.com/grpc/grpc"                   "doc"           "gRPC Docs"             cpp ""
    # MessagePack C/C++ — компактная бинарная сериализация
    dl "https://github.com/msgpack/msgpack-c"           "doc"           "MessagePack C/C++"     cpp ""
    # FlatBuffers — zero-copy сериализация от Google
    dl "https://github.com/google/flatbuffers"          "docs"          "FlatBuffers Docs"      cpp ""

    # --- Системы сборки ---
    # CMake — де-факто стандарт
    dl "https://github.com/Kitware/CMake"               "Help"          "CMake Docs"            cpp ""
    # Meson — современная система сборки
    dl "https://github.com/mesonbuild/meson"            "docs"          "Meson Build Docs"      "" ""
    # Conan — менеджер пакетов C/C++
    dl "https://github.com/conan-io/conan"              "docs"          "Conan Docs"            cpp ""

    # --- Параллелизм / Производительность ---
    # Intel TBB — Threading Building Blocks (параллельные алгоритмы)
    dl "https://github.com/oneapi-src/oneTBB"           "doc"           "Intel TBB Docs"        cpp ""
    # taskflow — параллелизм на основе task graph
    dl "https://github.com/taskflow/taskflow"           "doxygen"       "Taskflow Docs"         cpp ""
}

# ═══════════════════════════════════════════════════════════════════
#  Qt
# ═══════════════════════════════════════════════════════════════════

do_qt() {
    echo -e "\n🎨 ══════ Qt ══════"

    # --- Ядро ---
    # Qt Base — основные модули (Core, Gui, Widgets, Network, SQL, Concurrent)
    dl "https://github.com/qt/qtbase"                   "examples"      "Qt Base Examples"      cpp "qt"
    # Исходники qtbase — лучший источник для API и паттернов
    dl "https://github.com/qt/qtbase"                   "src"           "Qt Base Sources"       cpp "qt"

    # --- QML / Qt Quick ---
    # Qt Declarative — QML и Qt Quick (движок, элементы, примеры)
    dl "https://github.com/qt/qtdeclarative"            "examples"      "Qt QML Examples"       cpp "qt"
    dl "https://github.com/qt/qtdeclarative"            "src"           "Qt QML Sources"        cpp "qt"

    # --- Дополнительные модули ---
    # Qt Charts — графики
    dl "https://github.com/qt/qtcharts"                 "examples"      "Qt Charts Examples"    cpp "qt"
    # Qt 3D — 3D рендеринг и сцены
    dl "https://github.com/qt/qt3d"                     "examples"      "Qt 3D Examples"        cpp "qt"
    # Qt Multimedia — аудио, видео, камера
    dl "https://github.com/qt/qtmultimedia"             "examples"      "Qt Multimedia Examples" cpp "qt"
    # Qt WebSockets
    dl "https://github.com/qt/qtwebsockets"             "examples"      "Qt WebSocket Examples" cpp "qt"
    # Qt SerialPort
    dl "https://github.com/qt/qtserialport"             "examples"      "Qt SerialPort Examples" cpp "qt"
    # Qt Network Auth (OAuth)
    dl "https://github.com/qt/qtnetworkauth"            "examples"      "Qt NetworkAuth Examples" cpp "qt"

    # --- Книги ---
    # Книга Qt6 + Modern C++
    dl "https://github.com/PacktPublishing/Cross-Platform-Development-with-Qt-6-and-Modern-Cpp" "" "Qt6 Book Examples" cpp "qt"
}

# ═══════════════════════════════════════════════════════════════════
#  Алгоритмы и структуры данных
# ═══════════════════════════════════════════════════════════════════

do_algorithms() {
    echo -e "\n🧮 ══════ Algorithms ══════"

    # TheAlgorithms — крупнейшая коллекция алгоритмов на разных языках
    dl "https://github.com/TheAlgorithms/Python"        ""              "Algorithms-Python"     python "algorithm"
    dl "https://github.com/TheAlgorithms/C-Plus-Plus"   ""              "Algorithms-CPP"        cpp    "algorithm"
    dl "https://github.com/TheAlgorithms/C"             ""              "Algorithms-C"          c      "algorithm"
    dl "https://github.com/TheAlgorithms/Rust"          ""              "Algorithms-Rust"       rust   "algorithm"
    dl "https://github.com/TheAlgorithms/Go"            ""              "Algorithms-Go"         go     "algorithm"

    # Design Patterns for Humans — паттерны проектирования с примерами
    dl "https://github.com/kamranahmedse/design-patterns-for-humans" "" "Design Patterns"      "" "algorithm"
    # Python Design Patterns — реализации паттернов на Python
    dl "https://github.com/faif/python-patterns"        ""              "Python Patterns"       python "algorithm"
}

# ═══════════════════════════════════════════════════════════════════
#  Rust
# ═══════════════════════════════════════════════════════════════════

do_rust() {
    echo -e "\n🦀 ══════ Rust ══════"

    # --- Язык ---
    # The Rust Book — главная книга по Rust
    dl "https://github.com/rust-lang/book"              "src"           "Rust Book"             rust ""
    # Rust by Example — примеры
    dl "https://github.com/rust-lang/rust-by-example"   "src"           "Rust by Example"       rust ""
    # Async Book — async/await в Rust
    dl "https://github.com/rust-lang/async-book"        "src"           "Rust Async Book"       rust ""

    # --- Экосистема ---
    # Tokio — async runtime
    dl "https://github.com/tokio-rs/tokio"              ""              "Tokio Runtime"         rust ""
    # Actix-web — web-фреймворк
    dl "https://github.com/actix/actix-web"             ""              "Actix-Web"             rust ""
    # Serde — сериализация/десериализация
    dl "https://github.com/serde-rs/serde"              ""              "Serde"                 rust ""
}

# ═══════════════════════════════════════════════════════════════════
#  Go
# ═══════════════════════════════════════════════════════════════════

do_go() {
    echo -e "\n🐹 ══════ Go ══════"

    # --- Язык ---
    # Go stdlib docs
    dl_sparse "https://github.com/golang/go"            "doc"           "Go Official Docs"      go ""
    # Go stdlib source — примеры из стандартной библиотеки
    dl_sparse "https://github.com/golang/go"            "src"           "Go Stdlib Source"      go ""

    # --- Web-фреймворки ---
    # Gin — самый популярный HTTP фреймворк
    dl "https://github.com/gin-gonic/gin"               ""              "Gin HTTP"              go ""
    # Fiber — Express-like фреймворк (fasthttp)
    dl "https://github.com/gofiber/fiber"               ""              "Go Fiber"              go ""
    # Gorilla Mux — HTTP router
    dl "https://github.com/gorilla/mux"                 ""              "Gorilla Mux"           go ""

    # --- Утилиты ---
    # samber/lo — lodash для Go (generics)
    dl "https://github.com/samber/lo"                   ""              "Go Lo (generics)"      go ""
    # Zap — быстрое логирование от Uber
    dl "https://github.com/uber-go/zap"                 ""              "Go Zap Logger"         go ""
    # Testify — тестирование
    dl "https://github.com/stretchr/testify"            ""              "Go Testify"            go ""
}

# ═══════════════════════════════════════════════════════════════════
#  TypeScript / JavaScript
# ═══════════════════════════════════════════════════════════════════

do_typescript() {
    echo -e "\n📘 ══════ TypeScript / JavaScript ══════"

    # TypeScript Handbook — официальная документация
    dl_sparse "https://github.com/microsoft/TypeScript" "doc"           "TypeScript Docs"       typescript ""
    # TypeScript — исходники компилятора (для понимания типов)
    dl_sparse "https://github.com/microsoft/TypeScript" "src"           "TypeScript Sources"    typescript ""
}

# ═══════════════════════════════════════════════════════════════════
#  FPGA / Xilinx / HDL
# ═══════════════════════════════════════════════════════════════════

do_fpga() {
    echo -e "\n🔌 ══════ FPGA / Xilinx / HDL ══════"

    # --- HDL Симуляторы ---
    # GHDL — VHDL симулятор с открытым исходным кодом (IEEE 1076-2008/2019)
    dl "https://github.com/ghdl/ghdl"                   "doc"           "GHDL VHDL Simulator"   "" "fpga"
    # Icarus Verilog — Verilog компилятор и симулятор
    dl "https://github.com/steveicarus/iverilog"         ""              "Icarus Verilog"        "" "fpga"
    # Verilator — быстрый Verilog/SystemVerilog симулятор (C++ backend)
    dl "https://github.com/verilator/verilator"         "docs"          "Verilator Docs"        "" "fpga"

    # --- Тестирование HDL ---
    # cocotb — Python-based coroutine testbench для Verilog/VHDL
    dl "https://github.com/cocotb/cocotb"               "docs"          "cocotb HDL Testing"    python "fpga"
    # VUnit — unit testing для VHDL и SystemVerilog
    dl "https://github.com/VUnit/vunit"                  "docs"          "VUnit HDL Testing"     "" "fpga"

    # --- Синтез / Тулчейны ---
    # Yosys — синтез RTL с открытым кодом (для Xilinx, Lattice, Intel)
    dl "https://github.com/YosysHQ/yosys"               "docs"          "Yosys Synthesis"       "" "fpga"
    # nextpnr — place-and-route (Xilinx, Lattice iCE40/ECP5, Gowin)
    dl "https://github.com/YosysHQ/nextpnr"             ""              "nextpnr P&R"           "" "fpga"
    # SymbiFlow — полный FOSS toolchain для Xilinx (Artix-7, Spartan-6)
    dl "https://github.com/SymbiFlow/symbiflow-examples" ""              "SymbiFlow Examples"    "" "fpga"

    # --- Xilinx/AMD специфика ---
    # Vitis HLS — High-Level Synthesis для Xilinx (C/C++ → RTL)
    dl "https://github.com/Xilinx/Vitis-HLS-Introductory-Examples" ""   "Vitis HLS Examples"    cpp "fpga"
    # PYNQ — Python productivity для ZYNQ (AXI, DMA, overlays, Jupyter)
    dl "https://github.com/Xilinx/PYNQ"                 ""              "PYNQ Framework"        python "fpga"
    # PYNQ Examples — примеры использования PYNQ
    dl "https://github.com/Xilinx/PYNQ_Workshop"        ""              "PYNQ Workshop Examples" python "fpga"
    # Vitis AI — AI inference на FPGA (quantization, deployment)
    dl "https://github.com/Xilinx/Vitis-AI"             "docs"          "Vitis AI Docs"         python "fpga"
    # Xilinx AXI BRAM Controller — пример AXI4 IP core
    dl "https://github.com/Xilinx/embeddedsw"           "XilinxProcessorIPLib/drivers" "Xilinx Driver Library" c "fpga"
    # DMA proxy — пример AXI DMA для Linux (Zynq)
    dl "https://github.com/Xilinx/dma_ip_drivers"       ""              "Xilinx DMA IP Drivers" c "fpga"

    # --- AXI протокол и шины ---
    # AXI4 Reference (ARM) — примеры и тесты AXI4/AXI4-Lite/AXI4-Stream
    dl "https://github.com/alexforencich/verilog-axi"   ""              "Verilog AXI Components" "" "fpga"
    # AXI Stream FIFO — примеры потоковых интерфейсов
    dl "https://github.com/alexforencich/verilog-axis"  ""              "Verilog AXI Stream"    "" "fpga"

    # --- Примеры и учебники ---
    # fpga4fun — примеры FPGA проектов (UART, VGA, SPI, I2C)
    dl "https://github.com/nandland/getting-started-with-fpgas" ""      "FPGA Getting Started"  "" "fpga"
    # ZipCPU — блог и примеры FPGA (Verilog, формальная верификация)
    dl "https://github.com/ZipCPU/zipcpu"               ""              "ZipCPU RISC Core"      "" "fpga"
    # OpenMIPS — учебный MIPS-процессор на Verilog
    dl "https://github.com/leishangwen/OpenMIPS"         ""              "OpenMIPS CPU"          "" "fpga"

    # --- Формальная верификация ---
    # SymbiYosys — формальная верификация HDL (SVA assertions)
    dl "https://github.com/YosysHQ/sby"                 "docs"          "SymbiYosys Formal"     "" "fpga"

    # --- IP Cores коллекции ---
    # OpenCores-подобные репозитории
    dl "https://github.com/alexforencich/verilog-ethernet" ""           "Verilog Ethernet MAC"  "" "fpga"
    # RISC-V реализации на FPGA
    dl "https://github.com/SpinalHDL/VexRiscv"          ""              "VexRiscv RISC-V"       "" "fpga"
    # PicoRV32 — маленький RISC-V для FPGA
    dl "https://github.com/YosysHQ/picorv32"            ""              "PicoRV32 RISC-V"       "" "fpga"

    # --- SDR на FPGA ---
    # OpenCPI — компонентная радиосистема для FPGA+CPU
    dl "https://github.com/davis-hoover/opencpi"        "doc"           "OpenCPI Radio Docs"    "" "fpga"
    # LimeSDR — SDR на FPGA Cyclone (Altera/Intel)
    dl "https://github.com/myriadrf/LimeSDR-Mini"       ""              "LimeSDR Mini FPGA"     "" "fpga"
}

# ═══════════════════════════════════════════════════════════════════
#  Форматы файлов (бинарные структуры)
# ═══════════════════════════════════════════════════════════════════

do_fileformats() {
    echo -e "\n📦 ══════ File Formats (Binary Structures) ══════"

    # --- Описания бинарных форматов ---
    # Kaitai Struct — декларативный язык описания бинарных форматов + компилятор
    dl "https://github.com/kaitai-io/kaitai_struct"     "doc"           "Kaitai Struct Docs"    "" "file-format"
    # Kaitai format library — описания форматов: PNG, ELF, PE, ZIP, GIF, WAV, MP3...
    dl "https://github.com/kaitai-io/kaitai_struct_formats" ""          "Kaitai Format Library" "" "file-format"

    # --- Универсальные парсеры ---
    # construct — декларативный Python-парсер бинарных форматов
    dl "https://github.com/construct/construct"         "docs"          "Construct Bin Parser"  python "file-format"
    # hachoir — парсер бинарных файлов (EXE, MP3, JPEG, Flash, ZIP)
    dl "https://github.com/vstinner/hachoir"            "doc"           "Hachoir File Parser"   python "file-format"

    # --- Изображения ---
    # libpng — официальная реализация PNG (спецификация, chunks, фильтры)
    dl "https://github.com/pnggroup/libpng"             ""              "libpng PNG Format"     c  "file-format"
    # libjpeg-turbo — JPEG кодирование/декодирование (DCT, Huffman)
    dl "https://github.com/libjpeg-turbo/libjpeg-turbo" ""             "libjpeg-turbo JPEG"    c  "file-format"
    # libwebp — WebP формат от Google
    dl "https://github.com/webmproject/libwebp"         "doc"           "libwebp WebP Format"   c  "file-format"
    # libtiff — TIFF формат (многостраничный, геопривязка, сжатие)
    dl "https://github.com/libsdl-org/libtiff"          "doc"           "libtiff TIFF Format"   c  "file-format"
    # OpenEXR — HDR изображения (ACES, VFX, CG production)
    dl "https://github.com/AcademySoftwareFoundation/openexr" "docs"    "OpenEXR HDR Format"    cpp "file-format"

    # --- Аудио/Видео ---
    # FFmpeg — все мультимедийные форматы (MP4, MKV, MP3, AAC, H.264, VP9...)
    dl_sparse "https://github.com/FFmpeg/FFmpeg"        "doc"           "FFmpeg Docs"           c  "file-format"
    # libsndfile — аудиоформаты (WAV, AIFF, FLAC, OGG)
    dl "https://github.com/libsndfile/libsndfile"       "doc"           "libsndfile Audio"      c  "file-format"
    # FLAC — спецификация lossless аудио формата
    dl "https://github.com/xiph/flac"                   "doc"           "FLAC Audio Format"     c  "file-format"
    # Vorbis (OGG) — спецификация сжатого аудио
    dl "https://github.com/xiph/vorbis"                 "doc"           "OGG Vorbis Format"     c  "file-format"

    # --- Документы ---
    # PDF — парсеры и библиотеки (понимание внутренней структуры)
    dl "https://github.com/pymupdf/PyMuPDF"             "docs"          "PyMuPDF PDF Docs"      python "file-format"
    # pdfminer — извлечение текста из PDF (понимание структуры)
    dl "https://github.com/pdfminer/pdfminer.six"       "docs"          "PDFMiner Docs"         python "file-format"

    # --- Архивы ---
    # libarchive — tar, zip, 7z, cpio, xar и т.д.
    dl "https://github.com/libarchive/libarchive"       "doc"           "libarchive Formats"    c  "file-format"
    # zlib — алгоритм DEFLATE (основа ZIP, PNG, gzip)
    dl "https://github.com/madler/zlib"                 ""              "zlib DEFLATE"          c  "file-format"
    # zstd — современный алгоритм сжатия от Facebook
    dl "https://github.com/facebook/zstd"               "doc"           "Zstd Compression"      c  "file-format"

    # --- Научные форматы ---
    # HDF5 — иерархический формат данных (численное моделирование, ML датасеты)
    dl "https://github.com/HDFGroup/hdf5"               "doc"           "HDF5 Format Docs"      c  "file-format"
    # NetCDF — сетевые данные (климат, океанография, атмосфера)
    dl "https://github.com/Unidata/netcdf-c"            "docs"          "NetCDF Format Docs"    c  "file-format"
    # Apache Parquet (C++ реализация — arrow) — колоночный формат данных
    dl "https://github.com/apache/arrow"                "docs"          "Apache Arrow/Parquet"  cpp "file-format"

    # --- Бинарные сериализаторы ---
    # CBOR — Concise Binary Object Representation (RFC 8949)
    dl "https://github.com/nicowillis/cbor-spec"        ""              "CBOR Binary Format"    "" "file-format" 2>/dev/null || \
        dl "https://github.com/cabo/cn-cbor"            ""              "CBOR C Library"        c  "file-format"
    # Apache Avro — бинарная сериализация со схемой (Kafka)
    dl "https://github.com/apache/avro"                 "doc"           "Apache Avro Format"    "" "file-format"
    # Apache Thrift — сериализация и RPC (Facebook)
    dl "https://github.com/apache/thrift"               "doc"           "Apache Thrift"         "" "file-format"
    # Cap'n Proto — бинарная сериализация без парсинга (zero-copy)
    dl "https://github.com/capnproto/capnproto"         "doc"           "Cap'n Proto Docs"      cpp "file-format"

    # --- Форматы 3D/CAD ---
    # OpenCASCADE — STEP, IGES форматы CAD (B-Rep геометрия)
    dl "https://github.com/Open-Cascade-SAS/OCCT"       "dox"           "OpenCASCADE CAD"       cpp "file-format"
    # LibreCAD — DXF формат AutoCAD
    dl "https://github.com/LibreCAD/LibreCAD"           "librecad/src"  "LibreCAD DXF"          cpp "file-format"

    # --- ELF/PE/DWARF ---
    # pyelftools — разбор ELF, DWARF отладочной информации
    dl "https://github.com/eliben/pyelftools"           ""              "ELF pyelftools"        python "file-format"
    # pefile — разбор PE/COFF (Windows .exe/.dll)
    dl "https://github.com/erocarrera/pefile"           ""              "PE File Parser"        python "file-format"
    # LIEF — библиотека для разбора ELF, PE, MachO форматов
    dl "https://github.com/lief-project/LIEF"           "doc"           "LIEF Binary Formats"   cpp "file-format"

    # --- Медицинские форматы ---
    # pydicom — DICOM медицинские изображения
    dl "https://github.com/pydicom/pydicom"             "docs"          "pydicom DICOM Format"  python "file-format"
}

# ═══════════════════════════════════════════════════════════════════
#  Сети и протоколы
# ═══════════════════════════════════════════════════════════════════

do_networking() {
    echo -e "\n🌐 ══════ Networking & Protocols ══════"

    # --- Теория и обзоры ---
    # What Happens When — DNS, TCP, HTTP, TLS подробно
    dl "https://github.com/alex/what-happens-when"      ""              "What Happens When"     "" "networking"
    # System Design Primer — сети, масштабирование, кэши, CDN, балансировка
    dl "https://github.com/donnemartin/system-design-primer" ""         "System Design Primer"  "" "networking"

    # --- Практика сокетов ---
    # Beej's Guide to Network Programming — каноническое руководство по сокетам
    dl "https://github.com/beejjorgensen/bgnet0"        ""              "Beej Network Guide"    c  "networking"

    # --- Анализ трафика ---
    # libpcap — захват пакетов (C API)
    dl "https://github.com/the-tcpdump-group/libpcap"   ""              "libpcap"               c  "networking"
    # Wireshark — анализатор протоколов (документация + dissectors)
    dl_sparse "https://github.com/wireshark/wireshark"  "doc"           "Wireshark Docs"        c  "networking"

    # --- Реализации протоколов ---
    # gRPC — RPC framework (документация + примеры)
    dl "https://github.com/grpc/grpc"                   "examples"      "gRPC Examples"         "" "networking"
    # Protobuf — сериализация для gRPC/RPC
    dl "https://github.com/protocolbuffers/protobuf"    "examples"      "Protobuf Examples"     "" "networking"

    # --- aiohttp — async HTTP/WebSocket для Python ---
    dl "https://github.com/aio-libs/aiohttp"            "docs"          "aiohttp Net Docs"      python "networking"

    # --- Промышленные протоколы ---
    # libmodbus — реализация Modbus RTU/TCP (SCADA, PLC, датчики)
    dl "https://github.com/stephane/libmodbus"          "doc"           "libModbus Protocol"    c  "networking"
    # MQTT: Eclipse Paho C/C++ клиент (IoT, SCADA, телеметрия)
    dl "https://github.com/eclipse/paho.mqtt.c"         "doc"           "MQTT Paho C Client"    c  "networking"
    # MQTT: Eclipse Paho Python клиент
    dl "https://github.com/eclipse/paho.mqtt.python"    "docs"          "MQTT Paho Python"      python "networking"
    # MQTT: Mosquitto брокер (документация протокола MQTT 3.1/5.0)
    dl "https://github.com/eclipse/mosquitto"           "docs"          "Mosquitto MQTT Broker" c  "networking"
    # OPC UA — промышленный протокол (открытая реализация open62541)
    dl "https://github.com/open62541/open62541"         "doc"           "OPC UA open62541"      c  "networking"
    # CANopen — стек CANopen поверх CAN (интерфейсы, объектный словарь)
    dl "https://github.com/CANopenNode/CANopenNode"      ""              "CANopen Protocol"      c  "networking"
    # SocketCAN — CAN bus в Linux (сокеты, фреймы, фильтры)
    dl "https://github.com/linux-can/can-utils"         ""              "SocketCAN Utils"       c  "networking"

    # --- Дроны / Авионика ---
    # MAVLink — протокол для беспилотников (сообщения, диалекты, C-заголовки)
    dl "https://github.com/mavlink/mavlink"             "doc"           "MAVLink Protocol"      "" "networking"
    # MAVLink C-заголовки (все диалекты: common, ardupilotmega, ASLUAV)
    dl "https://github.com/mavlink/c_library_v2"        ""              "MAVLink C Headers"     c  "networking"

    # --- Потоковые протоколы ---
    # RTSP/RTP — потоковое мультимедиа (live555)
    dl "https://github.com/rgaufman/live555"            ""              "RTSP live555"          cpp "networking"
    # GStreamer — мультимедийный фреймворк (RTSP, RTP, HLS, WebRTC)
    dl "https://github.com/GStreamer/gstreamer"         "docs"          "GStreamer Docs"         c  "networking"

    # --- Мессенджеры/шины сообщений ---
    # ZeroMQ — высокопроизводительный messaging (REQ/REP, PUB/SUB, PUSH/PULL)
    dl "https://github.com/zeromq/libzmq"               "doc"           "ZeroMQ Docs"           c  "networking"
    # NATS — лёгкая облачная шина сообщений
    dl "https://github.com/nats-io/nats.c"              ""              "NATS C Client"         c  "networking"
    # Apache Kafka C клиент (librdkafka)
    dl "https://github.com/confluentinc/librdkafka"     "INTRODUCTION.md" "Kafka librdkafka"    c  "networking"
    # RabbitMQ C клиент (AMQP 0-9-1)
    dl "https://github.com/alanxz/rabbitmq-c"          "docs"          "RabbitMQ AMQP C"       c  "networking"

    # --- GPS/GNSS ---
    # gpsd — GPS/GNSS демон (протокол NMEA, SiRF, UBX, RTCM)
    dl "https://gitlab.com/gpsd/gpsd"                   ""              "GPSD GNSS Daemon"      c  "networking" 2>/dev/null || \
        echo "  ⚠ gpsd — gitlab clone failed, try manually"

    # --- Встроенные системы / IoT ---
    # lwIP — легковесный TCP/IP стек для MCU
    dl "https://github.com/lwip-tcpip/lwip"             "doc"           "lwIP TCP/IP Stack"     c  "networking"
    # CoAP — Constrained Application Protocol (IoT, RFC 7252)
    dl "https://github.com/obgm/libcoap"                "doc"           "CoAP libcoap"          c  "networking"
    # Zephyr RTOS — networking стек для MCU (BLE, LoRa, 802.15.4, CAN)
    dl_sparse "https://github.com/zephyrproject-rtos/zephyr" "doc/connectivity" "Zephyr Networking" c "networking"
}

# ═══════════════════════════════════════════════════════════════════
#  Математика и геометрия
# ═══════════════════════════════════════════════════════════════════

do_math() {
    echo -e "\n📐 ══════ Mathematics & Geometry ══════"

    # --- Базовая математика через код ---
    # math-as-code — нотация → код (векторы, матрицы, кватернионы)
    dl "https://github.com/Jam3/math-as-code"           ""              "Math as Code"          "" "math"

    # --- Визуализация и анимация ---
    # Manim (3Blue1Brown) — визуализация математики
    dl "https://github.com/3b1b/manim"                  ""              "Manim (3b1b)"          python "math"

    # --- Научные библиотеки ---
    # SciPy — численные методы (оптимизация, интерполяция, FFT, линалг)
    dl "https://github.com/scipy/scipy"                 "doc/source"    "SciPy Docs"            python "math"
    # NumPy — линейная алгебра, массивы (для математических операций)
    dl "https://github.com/numpy/numpy"                 "doc"           "NumPy Math Docs"       python "math"
    # SymPy — символьная математика (интегралы, дифуры, матрицы)
    dl "https://github.com/sympy/sympy"                 "doc/src"       "SymPy Docs"            python "math"

    # --- Вычислительная геометрия ---
    # CGAL — вычислительная геометрия (триангуляция, выпуклая оболочка, Voronoi)
    dl "https://github.com/CGAL/cgal"                   "Documentation" "CGAL Geometry"         cpp "math"
    # GLM — математика OpenGL (вектора, матрицы, кватернионы, трансформации)
    dl "https://github.com/g-truc/glm"                  "doc"           "GLM Math"              cpp "math"

    # --- Eigen (линейная алгебра C++) ---
    dl "https://gitlab.com/libeigen/eigen"              "doc"           "Eigen Linear Algebra"  cpp "math" 2>/dev/null || \
        echo "  ⚠ Eigen (gitlab) — используйте pip install eigen для локальной копии"
}

# ═══════════════════════════════════════════════════════════════════
#  Радиолокация и обработка сигналов
# ═══════════════════════════════════════════════════════════════════

do_radar() {
    echo -e "\n📡 ══════ Radar & Signal Processing ══════"

    # --- Учебники ---
    # PySDR — полный учебник по SDR и обработке сигналов (FFT, фильтры, модуляция)
    dl "https://github.com/777arc/PySDR"                ""              "PySDR Textbook"        python "radar"
    # Python for Signal Processing — практические примеры DSP
    dl "https://github.com/unpingco/Python-for-Signal-Processing" ""    "Python Signal Processing" python "radar"

    # --- Фреймворки ---
    # GNU Radio — SDR фреймворк (C++ блоки + Python API)
    dl_sparse "https://github.com/gnuradio/gnuradio"    "docs"          "GNU Radio Docs"        cpp "radar"
    # GNU Radio — примеры
    dl_sparse "https://github.com/gnuradio/gnuradio"    "gr-filter"     "GNU Radio Filters"     cpp "radar"
    dl_sparse "https://github.com/gnuradio/gnuradio"    "gr-fft"        "GNU Radio FFT"         cpp "radar"

    # --- Scipy.signal ---
    # SciPy Signal — фильтры (FIR, IIR, Butterworth), окна, спектральный анализ
    dl_sparse "https://github.com/scipy/scipy"          "scipy/signal"  "SciPy Signal"          python "radar"
    # SciPy FFTpack
    dl_sparse "https://github.com/scipy/scipy"          "scipy/fft"     "SciPy FFT"             python "radar"
}

# ═══════════════════════════════════════════════════════════════════
#  Моделирование и симуляция
# ═══════════════════════════════════════════════════════════════════

do_simulation() {
    echo -e "\n🔬 ══════ Simulation & Modeling ══════"

    # --- Физические движки ---
    # Box2D — 2D физика (столкновения, joints, rigid body)
    dl "https://github.com/erincatto/box2d"             ""              "Box2D Physics"         cpp "simulation"
    # Bullet Physics — 3D физика (rigid body, soft body, collision)
    dl "https://github.com/bulletphysics/bullet3"       "docs"          "Bullet3 Physics"       cpp "simulation"

    # --- Параллельные вычисления ---
    # Taichi — DSL для параллельных физических симуляций (GPU/CPU)
    dl "https://github.com/taichi-dev/taichi"           "docs"          "Taichi Lang"           python "simulation"

    # --- Численное интегрирование ---
    # SciPy integrate — ОДУ (RK45, RK23, DOP853, LSODA), квадратуры
    dl_sparse "https://github.com/scipy/scipy"          "scipy/integrate" "SciPy ODE Solvers"   python "simulation"
    # SciPy interpolate — интерполяция (сплайны, B-сплайны)
    dl_sparse "https://github.com/scipy/scipy"          "scipy/interpolate" "SciPy Interpolation" python "simulation"

    # --- Дискретно-событийная симуляция ---
    # SimPy (правильный репозиторий)
    dl "https://github.com/teamcomo/simpy"              ""              "SimPy DES"             python "simulation" 2>/dev/null || \
        echo "  ℹ SimPy: pip install simpy; документация на simpy.readthedocs.io"
}

# ═══════════════════════════════════════════════════════════════════
#  3D моделирование и рендеринг
# ═══════════════════════════════════════════════════════════════════

do_3d() {
    echo -e "\n🎮 ══════ 3D Modeling & Rendering ══════"

    # --- Обучающие рендереры ---
    # TinyRenderer — рендерер с нуля (растеризация, z-buffer, шейдеры)
    dl "https://github.com/ssloy/tinyrenderer"          ""              "TinyRenderer"          cpp "3d"
    # TinyRayTracer — ray tracing с нуля
    dl "https://github.com/ssloy/tinyraytracer"         ""              "TinyRayTracer"         cpp "3d"

    # --- Физически корректный рендеринг ---
    # PBRT v4 — книга «Physically Based Rendering» (reference implementation)
    dl "https://github.com/mmp/pbrt-v4"                 ""              "PBRT v4"               cpp "3d"

    # --- OpenGL ---
    # LearnOpenGL — полные туториалы (освещение, тени, PBR, SSAO, HDR)
    dl "https://github.com/JoeyDeVries/LearnOpenGL"     ""              "LearnOpenGL"           cpp "3d"

    # --- Vulkan ---
    # Vulkan Examples — примеры Sascha Willems (PBR, compute, raytracing)
    dl "https://github.com/SaschaWillems/Vulkan"        ""              "Vulkan Examples"       cpp "3d"

    # --- Форматы файлов ---
    # glTF спецификация — стандарт передачи 3D данных
    dl "https://github.com/KhronosGroup/glTF"           "specification" "glTF Spec"             "" "3d"
    # Assimp — загрузчик 3D форматов (OBJ, FBX, glTF, Collada, 3DS, STL)
    dl "https://github.com/assimp/assimp"               "doc"           "Assimp Docs"           cpp "3d"

    # --- Математика для 3D ---
    # GLM — OpenGL Mathematics (вектора, матрицы, кватернионы, проекции)
    dl "https://github.com/g-truc/glm"                  "doc"           "GLM 3D Math"           cpp "3d"

    # --- Аудио-фреймворк для мультимедийных приложений ---
    # JUCE — аудио/GUI фреймворк (также используется для визуализаций)
    dl "https://github.com/juce-framework/JUCE"         "docs"          "JUCE Docs"             cpp "3d"
}

# ═══════════════════════════════════════════════════════════════════
#  Системное программирование
# ═══════════════════════════════════════════════════════════════════

do_systems() {
    echo -e "\n💻 ══════ Systems & OS ══════"

    # --- Linux API ---
    # TLPI — примеры из «The Linux Programming Interface» (POSIX, epoll, mmap, signals)
    dl "https://github.com/bradfa/tlpi-dist"            ""              "Linux Programming Interface" c "system"

    # --- Учебные ОС ---
    # xv6 RISC-V — MIT учебная ОС (процессы, файловые системы, виртуальная память)
    dl "https://github.com/mit-pdos/xv6-riscv"         ""              "xv6 RISC-V OS"         c "system"

    # --- Linux Kernel ---
    # Только Documentation (sparse, чтобы не клонировать 2GB+ ядра)
    dl_sparse "https://github.com/torvalds/linux"       "Documentation" "Linux Kernel Docs"     "" "system"
}

# ═══════════════════════════════════════════════════════════════════
#  Базы данных
# ═══════════════════════════════════════════════════════════════════

do_databases() {
    echo -e "\n🗄️  ══════ Databases ══════"

    # --- Реляционные ---
    # PostgreSQL — документация (SQL, индексы, планировщик, расширения)
    dl_sparse "https://github.com/postgres/postgres"    "doc/src"       "PostgreSQL Docs"       sql "database"

    # --- Key-Value ---
    # Redis — исходники (хороший код на C, структуры данных)
    dl "https://github.com/redis/redis"                 ""              "Redis Source"          c "database"

    # --- Адаптеры Python ---
    # psycopg3 — PostgreSQL для Python
    dl "https://github.com/psycopg/psycopg"            "docs"          "Psycopg3 Docs"        python "database"
    # SQLAlchemy — ORM
    dl "https://github.com/sqlalchemy/sqlalchemy"       "doc/build"     "SQLAlchemy DB Docs"   python "database"
}

# ═══════════════════════════════════════════════════════════════════
#  DevOps / Контейнеризация
# ═══════════════════════════════════════════════════════════════════

do_devops() {
    echo -e "\n🐳 ══════ DevOps ══════"

    # Docker — официальная документация
    dl "https://github.com/docker/docs"                 ""              "Docker Docs"           "" "devops"
    # Kubernetes — документация сайта
    dl_sparse "https://github.com/kubernetes/website"   "content/en/docs" "Kubernetes Docs"     "" "devops"
}

# ═══════════════════════════════════════════════════════════════════
#  Безопасность
# ═══════════════════════════════════════════════════════════════════

do_security() {
    echo -e "\n🔒 ══════ Security ══════"

    # OWASP Top 10 — топ уязвимостей
    dl "https://github.com/OWASP/Top10"                 ""              "OWASP Top 10"          "" "security"
    dl "https://github.com/OWASP/www-project-top-ten"   ""              "OWASP Top 10 (www)"    "" "security"
    # Книга секретных знаний — огромная коллекция IT-ссылок и инструментов
    dl "https://github.com/trimstray/the-book-of-secret-knowledge" ""   "Book of Secret Knowledge" "" "security"
}

# ═══════════════════════════════════════════════════════════════════
#  ГИС / Геофайлы / Картография
# ═══════════════════════════════════════════════════════════════════

do_geo() {
    echo -e "\n🌍 ══════ GIS / Geo Formats / Cartography ══════"

    # --- Ядро ГИС ---
    # GDAL — фундаментальная библиотека ГИС (чтение/запись 200+ форматов растров и векторов)
    dl "https://github.com/OSGeo/gdal"                  "doc"           "GDAL GIS Library"      cpp "geo"
    # PROJ — трансформации координатных систем (CRS, WGS84, UTM, Mercator)
    dl "https://github.com/OSGeo/PROJ"                  "docs"          "PROJ Coordinate Sys"   cpp "geo"
    # GEOS — геометрические операции (пересечение, буфер, объединение, DE-9IM)
    dl "https://github.com/libgeos/geos"                "doxygen"       "GEOS Geometry Ops"     cpp "geo"

    # --- Python ГИС ---
    # GeoPandas — геопространственные датафреймы (Shapefile, GeoJSON, GeoParquet)
    dl "https://github.com/geopandas/geopandas"         "doc"           "GeoPandas Docs"        python "geo"
    # Shapely — геометрические объекты в Python (Point, LineString, Polygon)
    dl "https://github.com/shapely/shapely"             "docs"          "Shapely Geometry"      python "geo"
    # Fiona — чтение/запись векторных форматов (Shapefile, GeoJSON, GDB, KML)
    dl "https://github.com/Toblerity/Fiona"             "docs"          "Fiona Vector IO"       python "geo"
    # pyproj — Python обёртка PROJ (трансформация координат)
    dl "https://github.com/pyproj4/pyproj"              "docs"          "pyproj CRS Python"     python "geo"
    # Rasterio — чтение/запись растровых данных (GeoTIFF, NetCDF, HDF5)
    dl "https://github.com/rasterio/rasterio"           "docs"          "Rasterio Raster IO"    python "geo"
    # pyogrio — быстрый ввод/вывод OGR форматов (vectorized, Arrow)
    dl "https://github.com/geopandas/pyogrio"           "docs"          "pyogrio Vector IO"     python "geo"

    # --- Форматы ---
    # GeoJSON спецификация (RFC 7946) + валидаторы
    dl "https://github.com/geojson/geojson-spec"        ""              "GeoJSON Spec RFC7946"  "" "geo"
    # GeoJSON примеры и утилиты
    dl "https://github.com/jazzband/geojson"            ""              "GeoJSON Python"        python "geo"
    # TopoJSON — топологически связанный GeoJSON
    dl "https://github.com/topojson/topojson-specification" ""          "TopoJSON Spec"         "" "geo"
    # KML/KMZ спецификация и библиотека (Google Earth формат)
    dl "https://github.com/cleder/fastkml"              "docs"          "KML Python Library"    python "geo"
    # GPX — GPS Exchange Format (треки, маршруты, точки)
    dl "https://github.com/tkrajina/gpxpy"              ""              "GPX Python Parser"     python "geo"
    # Shapefile формат (ESRI): spatialpandas, pyshp
    dl "https://github.com/GeospatialPython/pyshp"      ""              "Shapefile pyshp"       python "geo"
    # PMTiles — облачный формат тайлов (MapLibre, MapTiler)
    dl "https://github.com/protomaps/PMTiles"           "spec"          "PMTiles Spec"          "" "geo"
    # GeoParquet — геопространственное расширение Apache Parquet
    dl "https://github.com/geoparquet/geoparquet"       ""              "GeoParquet Spec"       "" "geo"
    # Cloud Optimized GeoTIFF (COG) — спецификация
    dl "https://github.com/cogeotiff/cog-spec"          ""              "COG GeoTIFF Spec"      "" "geo"

    # --- Тайлинг / Отображение ---
    # MapLibre GL JS — веб-картография (MVT тайлы, векторный рендеринг)
    dl "https://github.com/maplibre/maplibre-gl-js"     "docs"          "MapLibre GL Docs"      typescript "geo"
    # Leaflet — классическая веб-карта (тайлы, слои, маркеры)
    dl "https://github.com/Leaflet/Leaflet"             "docs"          "Leaflet Map Docs"      "" "geo"
    # Tippecanoe — генерация векторных тайлов MVT из GeoJSON
    dl "https://github.com/felt/tippecanoe"             ""              "Tippecanoe MVT"        cpp "geo"
    # Martin — быстрый tile-сервер (PostGIS, MBTiles, PMTiles)
    dl "https://github.com/maplibre/martin"             "docs"          "Martin Tile Server"    "" "geo"

    # --- Базы данных ГИС ---
    # PostGIS — пространственное расширение PostgreSQL (geometry, geography, raster)
    dl "https://github.com/postgis/postgis"             "doc"           "PostGIS Spatial DB"    sql "geo"
    # SpatiaLite — пространственное расширение SQLite
    dl "https://github.com/gaia-gis/libspatialite"      ""              "SpatiaLite SQLite GIS" c  "geo"

    # --- Спутниковые данные / ДЗЗ ---
    # sentinelsat — скачивание данных Sentinel (ESA Copernicus)
    dl "https://github.com/sentinelsat/sentinelsat"     "docs"          "Sentinel Satellite"    python "geo"
    # sat-search / pystac-client — STAC API для поиска спутниковых данных
    dl "https://github.com/stac-utils/pystac-client"    "docs"          "STAC Satellite Search" python "geo"
    # pystac — Python реализация SpatioTemporal Asset Catalog
    dl "https://github.com/stac-utils/pystac"           "docs"          "PySTAC Docs"           python "geo"
    # stackstac — анализ спутниковых данных (STAC + xarray + Dask)
    dl "https://github.com/gjoseph92/stackstac"         "docs"          "stackstac Satellite"   python "geo"

    # --- Высоты / Рельеф ---
    # elevation — загрузка SRTM/DEM данных рельефа
    dl "https://github.com/bopen/elevation"             ""              "DEM Elevation Data"    python "geo"
    # richdem — анализ цифровых моделей рельефа (DEM analysis)
    dl "https://github.com/r-barnes/richdem"            "docs"          "RichDEM Analysis"      cpp "geo"
}

# ═══════════════════════════════════════════════════════════════════
#  Космос / Аэрокосмические технологии / Луна
# ═══════════════════════════════════════════════════════════════════

do_space() {
    echo -e "\n🚀 ══════ Space / Aerospace / Moon ══════"

    # --- Астрономия / Астродинамика ---
    # Astropy — астрономические расчёты (координаты, время, единицы, спектры)
    dl "https://github.com/astropy/astropy"             "docs"          "Astropy Astronomy"     python "space"
    # Poliastro — орбитальная механика (Kepler, Lambert, маневры, Холман)
    dl "https://github.com/poliastro/poliastro"         "docs"          "Poliastro Orbital"     python "space"
    # Skyfield — точные астрономические координаты (планеты, спутники, звёзды)
    dl "https://github.com/brandon-rhodes/skyfield"     "skyfield/documentation" "Skyfield Astronomy" python "space"
    # PyEphem — эфемериды планет и спутников
    dl "https://github.com/brandon-rhodes/pyephem"      "docs"          "PyEphem Ephemeris"     python "space"

    # --- SPICE / NAIF ---
    # SpiceyPy — Python обёртка NASA NAIF SPICE (геометрия, системы отсчёта, тела)
    dl "https://github.com/AndrewAnnex/SpiceyPy"        "docs"          "SpiceyPy NAIF SPICE"   python "space"
    # SPICE Toolkit документация (GF, SPK, CK, EK, PDS форматы)
    dl "https://github.com/AndrewAnnex/spiceypy_notebooks" ""           "SpiceyPy Notebooks"    python "space"

    # --- Спутниковые орбиты / TLE ---
    # Orekit Python — орбитальная механика (TLE, SGP4, J2, манёвры)
    dl "https://github.com/petrushy/orekit_python_artifacts" ""         "Orekit Python Orbital" python "space"
    # sgp4 — SGP4/SDP4 пропагатор для TLE (Vallado алгоритм)
    dl "https://github.com/brandon-rhodes/python-sgp4"  ""              "SGP4 TLE Propagator"   python "space"
    # TLE API / спецификация двухстрочных элементов
    dl "https://github.com/treyhunner/tle"              ""              "TLE Format Reference"  python "space"
    # Skyfield satellites — пример работы с TLE и NORAD
    dl "https://github.com/skyfielders/python-skyfield" "skyfield"      "Skyfield Sources"      python "space"

    # --- Наземные станции / Связь ---
    # GNU Radio OOT модули для спутниковой связи
    dl "https://github.com/daniestevez/gr-satellites"   "docs"          "GR Satellite Decoders" python "space"
    # SatNOGS — наземная сеть спутниковых станций
    dl "https://github.com/satnogs/satnogs-client"      "docs"          "SatNOGS Ground Station" python "space"

    # --- CCSDS / Космические протоколы ---
    # CCSDS Space Packet Protocol реализация
    dl "https://github.com/daniestevez/ccsds"           ""              "CCSDS Space Protocol"  python "space"
    # libccsds — C реализация CCSDS пакетов (Space Packet, TM, TC, AOS)
    dl "https://github.com/yamcs/yamcs"                 "docs"          "YAMCS Mission Control" "" "space"
    # OpenSatKit — открытый комплект для спутниковых миссий (cFE, OSAL)
    dl "https://github.com/OpenSatKit/OpenSatKit"       ""              "OpenSatKit cFS"        c  "space"
    # NASA cFS — Core Flight System (FSW, EVS, SB, TBL, ES)
    dl "https://github.com/nasa/cFS"                    "docs"          "NASA cFS Framework"    c  "space"

    # --- NASA Open Source ---
    # NASA WorldWind — геопространственный 3D глобус (Lua, Java, Web)
    dl "https://github.com/NASAWorldWind/WebWorldWind"  "docs"          "NASA WorldWind Geo"    "" "space"
    # OpenMCT — Mission Control Framework (телеметрия, дашборды)
    dl "https://github.com/nasa/openmct"                "docs"          "NASA OpenMCT"          "" "space"
    # NASA Astrobee — SPHERES/Astrobee FSW (робот на МКС)
    dl "https://github.com/nasa/astrobee"               "doc"           "NASA Astrobee FSW"     cpp "space"
    # F' (F Prime) — NASA компонентная FSW платформа (Ingenuity вертолёт)
    dl "https://github.com/nasa/fprime"                 "docs"          "NASA F Prime FSW"      cpp "space"

    # --- Луна ---
    # LunarPy — расчёты орбиты Луны
    dl "https://github.com/iamhsa/lunarpy"              ""              "Lunar Orbit Python"    python "space" 2>/dev/null || \
        echo "  ℹ lunarpy — используйте astropy.coordinates.get_body('moon')"
    # Moon Trek — NASA лунный портал данных
    dl "https://github.com/NASA-AMMOS/MMGIS"            "docs"          "NASA MMGIS Lunar GIS"  "" "space"
    # LOLA — Lunar Orbiter Laser Altimeter данные (DEM Луны)
    dl "https://github.com/AndrewAnnex/SpiceyPy"        "docs"          "SPICE Lunar Geometry"  python "space"

    # --- Автопилоты БПЛА / SpacePlane ---
    # ArduPilot — открытый автопилот (самолёты, коптеры, ровер, лодки)
    dl "https://github.com/ArduPilot/ardupilot"         "libraries/AP_NavEKF3" "ArduPilot EKF"  cpp "space"
    dl_sparse "https://github.com/ArduPilot/ardupilot"  "docs"          "ArduPilot Docs"        cpp "space"
    # PX4 — профессиональный автопилот (Dronecode)
    dl "https://github.com/PX4/PX4-user_guide"         ""              "PX4 Autopilot Guide"   "" "space"
    # MAVSDK — MAVLink SDK для управления дронами (Python, C++, Swift)
    dl "https://github.com/mavlink/MAVSDK"              "docs"          "MAVSDK Drone Control"  cpp "space"

    # --- Физика атмосферы / Аэродинамика ---
    # OpenFOAM — вычислительная гидродинамика (CFD)
    dl "https://github.com/OpenFOAM/OpenFOAM-12"        "applications"  "OpenFOAM CFD"          cpp "space"
    # SU2 — мультифизический CFD (NASA аэродинамика, оптимизация)
    dl "https://github.com/su2code/SU2"                 "docs"          "SU2 CFD Solver"        cpp "space"

    # --- Визуализация ---
    # Cesium — 3D глобус и визуализация орбит (WebGL)
    dl "https://github.com/CesiumGS/cesium"             "Documentation" "Cesium 3D Globe"       typescript "space"
    # Rerun — визуализация данных роботов и дронов в реальном времени
    dl "https://github.com/rerun-io/rerun"              "docs"          "Rerun Viz Framework"   "" "space"
}

# ═══════════════════════════════════════════════════════════════════
#  ML / AI
# ═══════════════════════════════════════════════════════════════════

do_ml() {
    echo -e "\n🤖 ══════ ML / AI ══════"

    # --- Фреймворки ---
    # PyTorch — документация (тензоры, autograd, модули, CUDA)
    dl_sparse "https://github.com/pytorch/pytorch"      "docs/source"   "PyTorch Docs"          python "ml"
    # scikit-learn — классический ML (классификация, регрессия, кластеризация)
    dl "https://github.com/scikit-learn/scikit-learn"   "doc"           "scikit-learn Docs"     python "ml"

    # --- LLM ---
    # Hugging Face Transformers — NLP модели
    dl "https://github.com/huggingface/transformers"    "docs/source/en" "HF Transformers Docs" python "ml"
    # nanoGPT — минимальная реализация GPT (обучение + inference)
    dl "https://github.com/karpathy/nanoGPT"            ""              "nanoGPT"               python "ml"
}

# ═══════════════════════════════════════════════════════════════════
#  Точка входа
# ═══════════════════════════════════════════════════════════════════

show_help() {
    echo "Скачивание и индексация внешней документации"
    echo ""
    echo "Использование: $0 <набор> [<набор2> ...]"
    echo ""
    echo "Языки и фреймворки:"
    echo "  python       Python stdlib, Django, FastAPI, Flask, SQLAlchemy, NumPy, Pandas..."
    echo "  cpp          C++ Guidelines, Abseil, fmt, nlohmann/json, Boost, LLVM, libuv, libcurl, OpenSSL, pybind11"
    echo "  qt           Qt Base/QML/Charts/3D/Multimedia/WebSockets + Qt6 Book"
    echo "  rust         Rust Book, async-book, Tokio, Actix-web, Serde"
    echo "  go           Go stdlib, Gin, Fiber, Zap, Testify"
    echo "  typescript   TypeScript Handbook + compiler sources"
    echo ""
    echo "Домены:"
    echo "  algorithms   TheAlgorithms (Python/C++/C/Rust/Go), Design Patterns"
    echo "  fpga         GHDL, Icarus Verilog, Verilator, cocotb, Yosys, Xilinx Vitis HLS, PYNQ, AXI, PicoRV32"
    echo "  fileformats  Kaitai Struct, GDAL, FFmpeg, HDF5, NetCDF, Avro, Parquet, ELF/PE, DICOM, zstd"
    echo "  networking   TCP/IP, HTTP, сокеты (Beej), Modbus, MQTT, MAVLink, ZeroMQ, Kafka, CAN, gRPC"
    echo "  math         SciPy, SymPy, NumPy, CGAL, GLM, Manim"
    echo "  radar        PySDR, GNU Radio, SciPy Signal/FFT"
    echo "  simulation   Box2D, Bullet, Taichi, SciPy ODE/interpolation"
    echo "  3d           TinyRenderer, PBRT, LearnOpenGL, Vulkan, glTF, Assimp, GLM"
    echo "  databases    PostgreSQL, Redis, psycopg3, SQLAlchemy"
    echo "  systems      Linux kernel docs, TLPI, xv6"
    echo "  devops       Docker, Kubernetes"
    echo "  security     OWASP Top 10, Book of Secret Knowledge"
    echo "  ml           PyTorch, scikit-learn, HuggingFace Transformers, nanoGPT"
    echo "  geo          GDAL, PROJ, GeoPandas, Shapely, GeoJSON, KML, GPX, PostGIS, MapLibre, STAC"
    echo "  space        Astropy, Poliastro, SGP4, SpiceyPy, NASA cFS, F Prime, MAVLink, ArduPilot, Cesium"
    echo ""
    echo "  all          Всё вышеперечисленное"
    echo ""
    echo "Примеры:"
    echo "  $0 python cpp qt         # Python + C++ + Qt"
    echo "  $0 networking radar      # Сети + радар"
    echo "  $0 fpga                  # FPGA / Xilinx"
    echo "  $0 geo space             # ГИС + Космос"
    echo "  $0 fileformats           # Форматы файлов"
    echo "  $0 all                   # Всё"
}

run_set() {
    case "$1" in
        python|py)                    do_python ;;
        cpp|c|c++)                    do_cpp ;;
        qt)                           do_qt ;;
        algorithms|algo)              do_algorithms ;;
        rust|rs)                      do_rust ;;
        go|golang)                    do_go ;;
        typescript|ts|js)             do_typescript ;;
        fpga|xilinx|hdl|vhdl|verilog) do_fpga ;;
        fileformats|formats|binary)   do_fileformats ;;
        networking|net)               do_networking ;;
        math|geometry)                do_math ;;
        radar|signal|dsp)             do_radar ;;
        simulation|sim)               do_simulation ;;
        3d|rendering|render)          do_3d ;;
        databases|db)                 do_databases ;;
        systems|os)                   do_systems ;;
        devops|docker|k8s)            do_devops ;;
        security|sec)                 do_security ;;
        ml|ai)                        do_ml ;;
        geo|gis|geospatial)           do_geo ;;
        space|aerospace|lunar|moon)   do_space ;;
        all)
            do_python
            do_cpp
            do_qt
            do_algorithms
            do_rust
            do_go
            do_typescript
            do_fpga
            do_fileformats
            do_networking
            do_math
            do_radar
            do_simulation
            do_3d
            do_databases
            do_systems
            do_devops
            do_security
            do_ml
            do_geo
            do_space
            ;;
        *)
            echo "⚠ Неизвестный набор: $1"
            echo ""
            show_help
            return 1
            ;;
    esac
}

if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

# Поддержка нескольких аргументов: ./download-docs.sh python cpp qt
for arg in "$@"; do
    run_set "$arg"
done

echo -e "\n📊 Итого в базе:"
"$VENV" "$INGEST" --stats
