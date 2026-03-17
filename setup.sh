#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"

echo "═══════════════════════════════════════════════════"
echo "  RAG Knowledge Base для кодинг-агентов — Setup"
echo "═══════════════════════════════════════════════════"

# 1. Python venv
echo -e "\n📦 [1/4] Виртуальное окружение..."
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
fi
source "$VENV_DIR/bin/activate"
pip install -q --upgrade pip
pip install -q -r "$SCRIPT_DIR/requirements.txt"
echo "  ✓ Зависимости установлены"

# 2. Установка PyTorch с GPU поддержкой
echo -e "\n🎮 [2/4] PyTorch (GPU оптимизация эмбеддингов)..."
if nvidia-smi &>/dev/null; then
    CUDA_VER=$(nvidia-smi | grep -oP 'CUDA Version: \K[0-9]+\.[0-9]+' | head -1)
    CUDA_TAG="cu$(echo $CUDA_VER | tr -d '.')"
    # Определяем ближайший поддерживаемый тег
    case "$CUDA_TAG" in
        cu126|cu125|cu124|cu123|cu122|cu121) ;;
        cu120|cu119|cu118) CUDA_TAG="cu118" ;;
        *) CUDA_TAG="cu121" ;;
    esac
    echo "  GPU найден, устанавливаем torch для CUDA $CUDA_VER (индекс: $CUDA_TAG)..."
    pip install -q torch --index-url "https://download.pytorch.org/whl/$CUDA_TAG" || \
        pip install -q torch --index-url https://download.pytorch.org/whl/cu121
    echo "  ✓ PyTorch с CUDA установлен"
elif python3 -c "import platform; exit(0 if platform.processor() == 'arm' and platform.system() == 'Darwin' else 1)" 2>/dev/null; then
    echo "  Apple Silicon — используем MPS..."
    pip install -q torch
    echo "  ✓ PyTorch с MPS"
else
    echo "  GPU не найден, устанавливаем CPU-only torch..."
    pip install -q torch --index-url https://download.pytorch.org/whl/cpu
    echo "  ✓ PyTorch CPU"
fi

# 3. Загрузка встроенных баз знаний
echo -e "\n📚 [3/4] Загрузка встроенных баз знаний..."
python "$SCRIPT_DIR/ingest.py" --load-all

# 4. Статистика
echo -e "\n📊 [4/4] Статистика:"
python "$SCRIPT_DIR/ingest.py" --stats

echo -e "\n═══════════════════════════════════════════════════"
echo "  ✅ Готово!"
echo "═══════════════════════════════════════════════════"
echo ""
echo "Подключение к Claude Code:"
echo "  claude mcp add rag-kb -- $VENV_DIR/bin/python $SCRIPT_DIR/mcp_rag_server.py"
echo ""
echo "Загрузить внешнюю документацию:"
echo "  ./download-docs.sh python       # FastAPI, Flask, Pydantic..."
echo "  ./download-docs.sh cpp          # C++ Guidelines, fmt, googletest..."
echo "  ./download-docs.sh qt           # Qt Base, QML, Qt6 Examples"
echo "  ./download-docs.sh networking   # TCP/IP, HTTP, DNS, сокеты"
echo "  ./download-docs.sh math         # SciPy, SymPy, CGAL, геометрия"
echo "  ./download-docs.sh radar        # DSP, SDR, радарные алгоритмы"
echo "  ./download-docs.sh simulation   # Box2D, Bullet, Taichi"
echo "  ./download-docs.sh 3d           # OpenGL, Vulkan, PBR, glTF"
echo "  ./download-docs.sh all          # Всё вышеперечисленное"
echo ""
echo "Загрузить свой проект:"
echo "  source .venv/bin/activate"
echo "  python ingest.py --path /путь/к/проекту --type code --language python"
echo ""
