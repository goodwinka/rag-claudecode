#!/bin/bash
set -e

CMD="${1:-mcp}"

if [ "$CMD" = "mcp" ]; then
    # Автоматически загрузить встроенные базы знаний при первом запуске
    if [ "${AUTO_INGEST:-true}" = "true" ]; then
        if [ ! -d "$RAG_DB_PATH" ] || [ -z "$(ls -A "$RAG_DB_PATH" 2>/dev/null)" ]; then
            echo "[entrypoint] База знаний пуста — запускаем первичную загрузку..." >&2
            python ingest.py --load-all
        fi
    fi
    exec python mcp_rag_server.py

elif [ "$CMD" = "ingest" ]; then
    shift
    exec python ingest.py "$@"

else
    exec "$@"
fi
