FROM python:3.11-slim

WORKDIR /app

# Системные зависимости
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    && rm -rf /var/lib/apt/lists/*

# PyTorch CPU (без CUDA — меньший размер образа)
# Для GPU: замените на --index-url https://download.pytorch.org/whl/cu121
RUN pip install --no-cache-dir torch --index-url https://download.pytorch.org/whl/cpu

# Python зависимости
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Предварительная загрузка модели эмбеддингов в образ
RUN python -c "from sentence_transformers import SentenceTransformer; SentenceTransformer('all-MiniLM-L6-v2')"

# Код сервера
COPY mcp_rag_server.py ingest.py ./

# Встроенные базы знаний (могут быть переопределены монтированием)
COPY knowledge/ knowledge/

# Точки монтирования внешних данных
# /data/chroma_db   — база ChromaDB (персистентная)
# /app/.external-docs — скачанная внешняя документация

ENV RAG_DB_PATH=/data/chroma_db
ENV RAG_COLLECTION=programming_docs
ENV RAG_TOP_K=10
ENV RAG_MAX_DISTANCE=1.5
ENV RAG_CHUNK_SIZE=1200
ENV RAG_CHUNK_OVERLAP=150

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["mcp"]
