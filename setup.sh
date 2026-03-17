#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"

echo "═══════════════════════════════════════════════════"
echo "  RAG Knowledge Base для кодинг-агентов — Setup"
echo "═══════════════════════════════════════════════════"

# 1. Python venv
echo -e "\n📦 [1/3] Виртуальное окружение..."
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
fi
source "$VENV_DIR/bin/activate"
pip install -q --upgrade pip
pip install -q -r "$SCRIPT_DIR/requirements.txt"
echo "  ✓ Зависимости установлены"

# 2. Загрузка встроенных баз знаний
echo -e "\n📚 [2/3] Загрузка встроенных баз знаний..."
python "$SCRIPT_DIR/ingest.py" --load-all

# 3. Статистика
echo -e "\n📊 [3/3] Статистика:"
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
echo "  ./download-docs.sh cpp          # cppreference, boost..."
echo "  ./download-docs.sh qt           # Qt docs"
echo "  ./download-docs.sh all"
echo ""
echo "Загрузить свой проект:"
echo "  source .venv/bin/activate"
echo "  python ingest.py --path /путь/к/проекту --type code --language python"
echo ""
