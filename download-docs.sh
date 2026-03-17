#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS="$SCRIPT_DIR/.external-docs"
VENV="$SCRIPT_DIR/.venv/bin/python"
INGEST="$SCRIPT_DIR/ingest.py"

mkdir -p "$DOCS"

[ -f "$SCRIPT_DIR/.venv/bin/activate" ] && source "$SCRIPT_DIR/.venv/bin/activate"

dl() {
    local url="$1" sub="$2" name="$3" lang="$4"
    local repo=$(basename "$url" .git)
    local target="$DOCS/$repo"
    echo -e "\n📥 $name..."
    if [ -d "$target" ]; then
        (cd "$target" && git pull --quiet 2>/dev/null) || true
    else
        git clone --depth 1 --quiet "$url" "$target" 2>/dev/null || { echo "  ⚠ clone failed"; return; }
    fi
    local path="$target"
    [ -n "$sub" ] && path="$target/$sub"
    [ -d "$path" ] && "$VENV" "$INGEST" --path "$path" --source "$name" --language "$lang" || echo "  ⚠ ingest failed"
}

do_python() {
    echo -e "\n🐍 ══════ Python ══════"
    dl "https://github.com/tiangolo/fastapi"       "docs/en/docs"  "FastAPI Docs"   python
    dl "https://github.com/pydantic/pydantic"       "docs"          "Pydantic Docs"  python
    dl "https://github.com/pallets/flask"            "docs"          "Flask Docs"     python
    dl "https://github.com/encode/httpx"             "docs"          "HTTPX Docs"     python
    dl "https://github.com/pytest-dev/pytest"        "doc/en"        "Pytest Docs"    python
    dl "https://github.com/sqlalchemy/sqlalchemy"    "doc/build"     "SQLAlchemy"     python
    dl "https://github.com/python-poetry/poetry"     "docs"          "Poetry Docs"    python
}

do_cpp() {
    echo -e "\n⚙️  ══════ C/C++ ══════"
    dl "https://github.com/isocpp/CppCoreGuidelines" ""             "C++ Guidelines" cpp
    dl "https://github.com/abseil/abseil-cpp"        ""              "Abseil C++"     cpp
    dl "https://github.com/fmtlib/fmt"               "doc"           "fmt lib"        cpp
    dl "https://github.com/nlohmann/json"            "docs"          "nlohmann/json"  cpp
    dl "https://github.com/google/googletest"        "docs"          "GoogleTest"     cpp
    dl "https://github.com/gabime/spdlog"            ""              "spdlog"         cpp
}

do_qt() {
    echo -e "\n🎨 ══════ Qt ══════"
    dl "https://github.com/nicktasios/qt-by-example" ""             "Qt Examples"    cpp
    dl "https://github.com/nicktasios/qt6-by-example" ""            "Qt6 Examples"   cpp
    # Qt official examples
    dl "https://github.com/qt/qtbase"                "examples"      "Qt Base Examples" cpp
}

do_algorithms() {
    echo -e "\n🧮 ══════ Algorithms ══════"
    dl "https://github.com/TheAlgorithms/Python"     ""              "Algorithms-Py"  python
    dl "https://github.com/TheAlgorithms/C-Plus-Plus" ""             "Algorithms-CPP" cpp
    dl "https://github.com/TheAlgorithms/C"          ""              "Algorithms-C"   c
}

do_rust() {
    echo -e "\n🦀 ══════ Rust ══════"
    dl "https://github.com/rust-lang/book"           "src"           "Rust Book"      rust
    dl "https://github.com/rust-lang/rust-by-example" "src"          "Rust Examples"  rust
}

case "${1:-help}" in
    python|py)      do_python ;;
    cpp|c++)        do_cpp ;;
    qt)             do_qt ;;
    algorithms|algo) do_algorithms ;;
    rust|rs)        do_rust ;;
    all)            do_python; do_cpp; do_qt; do_algorithms ;;
    *)
        echo "Скачивание и индексация внешней документации"
        echo ""
        echo "Использование: $0 <набор>"
        echo "  python       FastAPI, Pydantic, Flask, HTTPX, Pytest, SQLAlchemy"
        echo "  cpp          C++ Core Guidelines, Abseil, fmt, nlohmann/json, GoogleTest"
        echo "  qt           Qt Examples, Qt Base Examples"
        echo "  algorithms   TheAlgorithms (Python, C++, C)"
        echo "  rust         Rust Book, Rust by Example"
        echo "  all          Всё вышеперечисленное"
        ;;
esac

echo -e "\n📊 Итого в базе:"
"$VENV" "$INGEST" --stats
