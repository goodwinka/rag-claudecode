#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS="$SCRIPT_DIR/.external-docs"
VENV="$SCRIPT_DIR/.venv/bin/python"
INGEST="$SCRIPT_DIR/ingest.py"

mkdir -p "$DOCS"

[ -f "$SCRIPT_DIR/.venv/bin/activate" ] && source "$SCRIPT_DIR/.venv/bin/activate"

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

do_python() {
    echo -e "\n🐍 ══════ Python ══════"
    dl "https://github.com/tiangolo/fastapi"       "docs/en/docs"  "FastAPI Docs"   python ""
    dl "https://github.com/pydantic/pydantic"       "docs"          "Pydantic Docs"  python ""
    dl "https://github.com/pallets/flask"            "docs"          "Flask Docs"     python ""
    dl "https://github.com/encode/httpx"             "docs"          "HTTPX Docs"     python ""
    dl "https://github.com/pytest-dev/pytest"        "doc/en"        "Pytest Docs"    python ""
    dl "https://github.com/sqlalchemy/sqlalchemy"    "doc/build"     "SQLAlchemy"     python ""
    dl "https://github.com/python-poetry/poetry"     "docs"          "Poetry Docs"    python ""
}

do_cpp() {
    echo -e "\n⚙️  ══════ C/C++ ══════"
    dl "https://github.com/isocpp/CppCoreGuidelines" ""             "C++ Guidelines" cpp ""
    dl "https://github.com/abseil/abseil-cpp"        ""              "Abseil C++"     cpp ""
    dl "https://github.com/fmtlib/fmt"               "doc"           "fmt lib"        cpp ""
    dl "https://github.com/nlohmann/json"            "docs"          "nlohmann/json"  cpp ""
    dl "https://github.com/google/googletest"        "docs"          "GoogleTest"     cpp ""
    dl "https://github.com/gabime/spdlog"            ""              "spdlog"         cpp ""
}

do_qt() {
    echo -e "\n🎨 ══════ Qt ══════"
    # Официальные примеры Qt (qtbase — проверенный источник)
    dl "https://github.com/qt/qtbase"                "examples"      "Qt Base Examples"   cpp "qt"
    # Qt Quick / QML примеры
    dl "https://github.com/qt/qtdeclarative"         "examples"      "Qt QML Examples"    cpp "qt"
    # Книга по Qt6 с примерами
    dl "https://github.com/PacktPublishing/Cross-Platform-Development-with-Qt-6-and-Modern-Cpp" "" "Qt6 Book Examples" cpp "qt"
}

do_algorithms() {
    echo -e "\n🧮 ══════ Algorithms ══════"
    dl "https://github.com/TheAlgorithms/Python"     ""              "Algorithms-Py"  python "algorithm"
    dl "https://github.com/TheAlgorithms/C-Plus-Plus" ""             "Algorithms-CPP" cpp    "algorithm"
    dl "https://github.com/TheAlgorithms/C"          ""              "Algorithms-C"   c      "algorithm"
}

do_rust() {
    echo -e "\n🦀 ══════ Rust ══════"
    dl "https://github.com/rust-lang/book"           "src"           "Rust Book"      rust ""
    dl "https://github.com/rust-lang/rust-by-example" "src"          "Rust Examples"  rust ""
}

do_networking() {
    echo -e "\n🌐 ══════ Networking & Protocols ══════"
    # Объяснение что происходит при вводе URL — охватывает DNS, TCP, HTTP, TLS
    dl "https://github.com/alex/what-happens-when"   ""              "What Happens When" "" "networking"
    # Большая книга по системному дизайну (сети, протоколы, масштабирование)
    dl "https://github.com/donnemartin/system-design-primer" "" "System Design Primer" "" "networking"
    # Книга по сетям для хакеров — практические примеры протоколов
    dl "https://github.com/forrest-orr/practical-networking" "" "Practical Networking" "" "networking" 2>/dev/null || true
    # Wireshark/libpcap примеры и документация сетевых протоколов
    dl "https://github.com/boundary/wireshark"       "doc"           "Wireshark Docs"     "" "networking" 2>/dev/null || \
    dl "https://github.com/the-tcpdump-group/libpcap" ""             "libpcap"            "c" "networking"
    # Реализации сетевого стека и примеры сокетов
    dl "https://github.com/beej-guides/bgnet"        ""              "Beej Network Guide" "c" "networking"
}

do_math() {
    echo -e "\n📐 ══════ Mathematics & Geometry ══════"
    # Математика через код (векторы, матрицы, кватернионы в markdown+code)
    dl "https://github.com/Jam3/math-as-code"        ""              "Math as Code"       "" "math"
    # 3Blue1Brown — линейная алгебра (markdown-объяснения)
    dl "https://github.com/3b1b/manim"               ""              "3Blue1Brown Manim"  python "math"
    # Численные методы: scipy, numpy примеры
    dl "https://github.com/scipy/scipy"              "doc/source"    "SciPy Docs"         python "math"
    # SymPy — символьная математика
    dl "https://github.com/sympy/sympy"              "doc/src"       "SymPy Docs"         python "math"
    # Геометрия и вычислительная геометрия
    dl "https://github.com/CGAL/cgal"               "Documentation" "CGAL Geometry"      cpp "math"
}

do_radar() {
    echo -e "\n📡 ══════ Radar & Signal Processing ══════"
    # Python для обработки сигналов (FFT, фильтры, радар)
    dl "https://github.com/unpingco/Python-for-Signal-Processing" "" "Python Signal Processing" python "radar"
    # PySDR — учебник по SDR и обработке сигналов
    dl "https://github.com/777arc/PySDR"             ""              "PySDR Book"         python "radar"
    # GNU Radio — блоки DSP (C++)
    dl "https://github.com/gnuradio/gnuradio"        "docs"          "GNU Radio Docs"     cpp "radar"
    # Радарные алгоритмы на Python
    dl "https://github.com/RadarCODE/radarsimpy"     ""              "RadarSimPy"         python "radar"
    # SciPy Signal processing (фильтры, FFT)
    dl "https://github.com/scipy/scipy"              "scipy/signal"  "SciPy Signal"       python "radar"
}

do_simulation() {
    echo -e "\n🔬 ══════ Simulation & Modeling ══════"
    # Box2D — физический движок (широко используется)
    dl "https://github.com/erincatto/box2d"          ""              "Box2D Physics"      cpp "simulation"
    # Bullet Physics — 3D физическая симуляция
    dl "https://github.com/bulletphysics/bullet3"    "docs"          "Bullet Physics"     cpp "simulation"
    # SimPy — дискретно-событийная симуляция на Python
    dl "https://github.com/sympy/sympy"              "doc/src"       "SimPy Docs"         python "simulation" 2>/dev/null || true
    dl "https://github.com/niccolox/simpy-doc"       ""              "SimPy Manual"       python "simulation" 2>/dev/null || true
    # Численные методы: дифференциальные уравнения
    dl "https://github.com/scipy/scipy"              "scipy/integrate" "SciPy ODE Solvers" python "simulation"
    # Taichi — параллельная физическая симуляция (GPU/CPU)
    dl "https://github.com/taichi-dev/taichi"        "docs"          "Taichi Lang"        python "simulation"
}

do_3d() {
    echo -e "\n🎮 ══════ 3D Modeling & Rendering ══════"
    # Tinyrenderer — мини-рендерер с нуля (понимание 3D pipeline)
    dl "https://github.com/ssloy/tinyrenderer"       ""              "TinyRenderer"       cpp "3d"
    # Tinyraytracer — трассировка лучей с нуля
    dl "https://github.com/ssloy/tinyraytracer"      ""              "TinyRayTracer"      cpp "3d"
    # PBRT — физически корректный рендеринг (книга+код)
    dl "https://github.com/mmp/pbrt-v4"              ""              "PBRT v4"            cpp "3d"
    # Assimp — загрузка 3D форматов (OBJ, FBX, GLTF, Collada)
    dl "https://github.com/assimp/assimp"            "doc"           "Assimp Docs"        cpp "3d"
    # GLM — математика для OpenGL (векторы, матрицы, кватернионы)
    dl "https://github.com/g-truc/glm"               "doc"           "GLM Math"           cpp "3d"
    # LearnOpenGL — туториалы по OpenGL/GLSL
    dl "https://github.com/JoeyDeVries/LearnOpenGL"  ""              "LearnOpenGL"        cpp "3d"
    # Vulkan туториалы
    dl "https://github.com/SaschaWillems/Vulkan"     ""              "Vulkan Examples"    cpp "3d"
    # GLTF спецификация и примеры форматов
    dl "https://github.com/KhronosGroup/glTF"        "specification" "glTF Spec"          "" "3d"
}

do_systems() {
    echo -e "\n💻 ══════ Systems & OS ══════"
    # The Linux Programming Interface (примеры)
    dl "https://github.com/bradfa/tlpi-dist"         ""              "Linux Programming Interface" "c" "system"
    # Операционные системы (xv6 — учебная ОС с документацией)
    dl "https://github.com/mit-pdos/xv6-riscv"      ""              "xv6 RISC-V OS"      "c" "system"
    # Linux kernel docs (только Documentation/)
    dl "https://github.com/torvalds/linux"           "Documentation/admin-guide" "Linux Kernel Docs" "" "system" 2>/dev/null || \
        echo "  ⚠ Linux kernel слишком большой, пропускаем"
}

do_security() {
    echo -e "\n🔒 ══════ Security ══════"
    dl "https://github.com/OWASP/www-project-top-ten" "" "OWASP Top 10"    "" "security"
    dl "https://github.com/trimstray/the-book-of-secret-knowledge" "" "Book of Secret Knowledge" "" "security"
}

case "${1:-help}" in
    python|py)          do_python ;;
    cpp|c++)            do_cpp ;;
    qt)                 do_qt ;;
    algorithms|algo)    do_algorithms ;;
    rust|rs)            do_rust ;;
    networking|net)     do_networking ;;
    math|geometry)      do_math ;;
    radar|signal|dsp)   do_radar ;;
    simulation|sim)     do_simulation ;;
    3d|rendering|render) do_3d ;;
    systems|os)         do_systems ;;
    security|sec)       do_security ;;
    all)
        do_python
        do_cpp
        do_qt
        do_algorithms
        do_rust
        do_networking
        do_math
        do_radar
        do_simulation
        do_3d
        do_systems
        do_security
        ;;
    *)
        echo "Скачивание и индексация внешней документации"
        echo ""
        echo "Использование: $0 <набор>"
        echo "  python       FastAPI, Pydantic, Flask, HTTPX, Pytest, SQLAlchemy"
        echo "  cpp          C++ Core Guidelines, Abseil, fmt, nlohmann/json, GoogleTest"
        echo "  qt           Qt Base, Qt QML, Qt6 Book Examples"
        echo "  algorithms   TheAlgorithms (Python, C++, C)"
        echo "  rust         Rust Book, Rust by Example"
        echo "  networking   TCP/IP, HTTP, DNS, сокеты, системный дизайн"
        echo "  math         Линейная алгебра, численные методы, геометрия (SciPy, SymPy, CGAL)"
        echo "  radar        Обработка сигналов, DSP, SDR, радарные алгоритмы"
        echo "  simulation   Box2D, Bullet Physics, Taichi, численное моделирование"
        echo "  3d           TinyRenderer, PBRT, OpenGL, Vulkan, glTF, Assimp, GLM"
        echo "  systems      Linux API, xv6 OS"
        echo "  security     OWASP Top 10"
        echo "  all          Всё вышеперечисленное"
        ;;
esac

echo -e "\n📊 Итого в базе:"
"$VENV" "$INGEST" --stats
