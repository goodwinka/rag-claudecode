FROM python:3.11-slim

WORKDIR /app

# Системные зависимости
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    && rm -rf /var/lib/apt/lists/*

# ── PyTorch ──────────────────────────────────────────────────────────────────
# Передайте TORCH_INDEX_URL при сборке для выбора варианта:
#   CPU (по умолчанию):
#     docker build .
#   CUDA 12.1:
#     docker build --build-arg TORCH_INDEX_URL=https://download.pytorch.org/whl/cu121 .
#   CUDA 12.4:
#     docker build --build-arg TORCH_INDEX_URL=https://download.pytorch.org/whl/cu124 .
ARG TORCH_INDEX_URL=https://download.pytorch.org/whl/cpu
RUN pip install --no-cache-dir torch --index-url ${TORCH_INDEX_URL}

# Python зависимости
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Предварительная загрузка модели эмбеддингов в образ
RUN python -c "from sentence_transformers import SentenceTransformer; SentenceTransformer('all-MiniLM-L6-v2')"

# Код сервера
COPY mcp_rag_server.py ingest.py ./

# Встроенные базы знаний (могут быть переопределены монтированием)
COPY knowledge/ knowledge/

# Точки монтирования:
#   /data/chroma_db      — ChromaDB (персистентная)
#   /app/.external-docs  — скачанная внешняя документация

ENV RAG_DB_PATH=/data/chroma_db
ENV RAG_COLLECTION=programming_docs
ENV RAG_TOP_K=10
ENV RAG_MAX_DISTANCE=1.5
ENV RAG_CHUNK_SIZE=1200
ENV RAG_CHUNK_OVERLAP=150
# Транспорт: stdio (по умолчанию) | http
ENV MCP_TRANSPORT=stdio
ENV MCP_HOST=0.0.0.0
ENV MCP_PORT=8765

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["mcp"]
