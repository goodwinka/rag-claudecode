# RAG Knowledge Base для кодинг-агентов

Локальная база знаний по программированию (C, C++, Python, Qt, алгоритмы),
подключаемая к Claude Code и другим агентам через MCP.

## Архитектура

```
  Ваш агент (Claude Code / Aider / Continue)
       │
       ├──▶ llama-swap:8080 ──▶ llama-server (ваша модель)
       │          (генерация кода)
       │
       └──▶ MCP RAG Server (mcp_rag_server.py / Docker)
                 │
                 ├── search_docs       — общий поиск
                 ├── search_api        — API справочник
                 ├── search_algorithm  — алгоритмы
                 ├── search_qt         — Qt документация
                 ├── search_technical  — форматы, сборка, протоколы
                 │
                 └── ChromaDB (.rag-knowledge-base/)
```

## Быстрый старт (без Docker)

```bash
cd rag-for-claude-code
chmod +x setup.sh download-docs.sh
./setup.sh
```

Это установит зависимости и загрузит **встроенные базы знаний**:

| Категория | Содержание |
|-----------|-----------|
| **C** | Память, указатели, строки, POSIX, сокеты, потоки, сигналы |
| **C++** | STL, умные указатели, move-семантика, шаблоны, потоки, RAII |
| **Python** | Структуры данных, asyncio, typing, тестирование, файлы |
| **Qt** | Виджеты, сигналы/слоты, Model/View, QML, сеть, рисование, SQL |
| **Алгоритмы** | Сортировки, графы, DP, деревья, хеширование, сложность |
| **Технич.** | ELF/PE форматы, CMake, Makefile, Git, протоколы, кодировки |

## Загрузка внешней документации

```bash
./download-docs.sh python      # FastAPI, Pydantic, Flask, HTTPX, Pytest
./download-docs.sh cpp          # C++ Guidelines, Abseil, fmt, GoogleTest
./download-docs.sh qt           # Qt примеры
./download-docs.sh algorithms   # TheAlgorithms (Python, C++, C)
./download-docs.sh all          # Всё
```

## Загрузка своего проекта

```bash
source .venv/bin/activate

# Код проекта
python ingest.py --path /путь/к/проекту --type code --language python

# Документация
python ingest.py --path /путь/к/docs --source "My Docs"

# Конкретный файл
python ingest.py --path ./api.md --source "API Ref" --language python

# Статистика
python ingest.py --stats

# Очистка
python ingest.py --clear
```

## Запуск в контейнере (Docker)

### Сборка образа

```bash
# CPU (по умолчанию)
docker compose build

# GPU — CUDA 12.1
docker compose build --build-arg TORCH_INDEX_URL=https://download.pytorch.org/whl/cu121

# GPU — CUDA 12.4
docker compose build --build-arg TORCH_INDEX_URL=https://download.pytorch.org/whl/cu124
```

При сборке GPU-образа также раскомментируйте `build.args` и секцию `deploy` в
`docker-compose.yml`.

### Первичная загрузка базы знаний

```bash
# Загрузить встроенные базы (knowledge/)
docker compose run --rm rag-ingest --load-all

# Загрузить внешнюю документацию из .external-docs/
docker compose run --rm rag-ingest --path /app/.external-docs --source "External"

# Статистика
docker compose run --rm rag-ingest --stats

# Очистка
docker compose run --rm rag-ingest --clear
```

При первом запуске MCP-сервера `AUTO_INGEST=true` автоматически загружает
встроенные базы знаний, если ChromaDB пуста.

### Структура томов

По умолчанию все пути — **относительно `docker-compose.yml`**:

```
rag-claudecode/
├── docker-compose.yml
├── knowledge/               → монтируется в /app/knowledge
├── .external-docs/          → монтируется в /app/.external-docs
└── .rag-knowledge-base/     → монтируется в /data/chroma_db  (создаётся автоматически)
```

---

### Режим 1: Claude Code на хосте (stdio через docker run)

```bash
claude mcp add rag-kb -- docker run --rm -i \
  -v "$(pwd)/knowledge:/app/knowledge" \
  -v "$(pwd)/.external-docs:/app/.external-docs" \
  -v "$(pwd)/.rag-knowledge-base:/data/chroma_db" \
  rag-claudecode
```

Или в `.mcp.json`:

```json
{
  "mcpServers": {
    "rag-kb": {
      "command": "docker",
      "args": [
        "run", "--rm", "-i",
        "-v", "/абсолютный/путь/knowledge:/app/knowledge",
        "-v", "/абсолютный/путь/.external-docs:/app/.external-docs",
        "-v", "/абсолютный/путь/.rag-knowledge-base:/data/chroma_db",
        "rag-claudecode"
      ]
    }
  }
}
```

---

### Режим 2: Claude Code в контейнере (HTTP/SSE через сеть)

Запустите MCP-сервер как постоянный сервис:

```bash
docker compose up -d rag-mcp
```

Добавьте контейнер с Claude Code в ту же сеть (`rag-net`) в его
`docker-compose.yml`:

```yaml
services:
  claude-code:
    # ...
    networks:
      - rag-net

networks:
  rag-net:
    external: true   # сеть создана rag-claudecode/docker-compose.yml
```

Укажите MCP-сервер по URL в `.mcp.json` внутри контейнера:

```json
{
  "mcpServers": {
    "rag-kb": {
      "url": "http://rag-mcp:8765/sse"
    }
  }
}
```

Или через CLI:

```bash
claude mcp add --transport sse rag-kb http://rag-mcp:8765/sse
```

Проверка работоспособности:

```bash
curl http://localhost:8765/health   # с хоста
curl http://rag-mcp:8765/health     # из контейнера в той же сети
```

---

### Переменные окружения контейнера

| Переменная | По умолчанию | Описание |
|---|---|---|
| `MCP_TRANSPORT` | `stdio` | Транспорт: `stdio` или `http` |
| `MCP_HOST` | `0.0.0.0` | Адрес HTTP-сервера |
| `MCP_PORT` | `8765` | Порт HTTP-сервера |
| `AUTO_INGEST` | `true` | Загружать knowledge/ при пустой DB |

---

## Подключение к Claude Code (без Docker)

```bash
claude mcp add rag-kb -- \
  $(pwd)/.venv/bin/python $(pwd)/mcp_rag_server.py
```

Скопируйте `CLAUDE.md` в корень рабочего проекта — он содержит
инструкции для модели когда вызывать поиск.

## Подключение к другим агентам

### Aider
```bash
aider --model openai/qwen3-coder \
      --openai-api-base http://localhost:8080/v1 \
      --openai-api-key not-needed
```

### Continue (VS Code)
`.continue/config.yaml`:
```yaml
models:
  - provider: openai
    model: qwen3-coder
    apiBase: http://localhost:8080/v1
    apiKey: not-needed
mcpServers:
  - name: rag-kb
    command: /абсолютный/путь/.venv/bin/python
    args: [/абсолютный/путь/mcp_rag_server.py]
```

## Настройка llama-swap

Модель **должна поддерживать tool calling**. Рекомендуемые:

| Модель | Размер | Tool Calling |
|--------|--------|-------------|
| Qwen3 8B+ | 5-8 GB | ✅ Надёжно |
| DeepSeek-V3 7B+ | 4-7 GB | ✅ Хорошо |
| Mistral 7B+ | 4-7 GB | ✅ Хорошо |
| Llama 4 8B | 5 GB | ✅ Хорошо |

Пример `config.yaml` для llama-swap:

```yaml
models:
  "qwen3-coder":
    cmd: >
      llama-server
      --model /models/qwen3-8b-coder-q5_k_m.gguf
      --port 9001 --ctx-size 16384 --n-gpu-layers 99
    proxy: "http://127.0.0.1:9001"
```

## Переменные окружения

| Переменная | По умолчанию | Описание |
|---|---|---|
| `RAG_DB_PATH` | `~/.rag-knowledge-base/chroma_db` | Путь к ChromaDB |
| `RAG_COLLECTION` | `programming_docs` | Имя коллекции |
| `RAG_TOP_K` | `10` | Кол-во результатов |
| `RAG_MAX_DISTANCE` | `1.5` | Порог релевантности |
| `RAG_CHUNK_SIZE` | `1200` | Размер чанка |
| `RAG_CHUNK_OVERLAP` | `150` | Перекрытие чанков |
| `MCP_TRANSPORT` | `stdio` | Транспорт: `stdio` или `http` |
| `MCP_HOST` | `0.0.0.0` | Адрес прослушивания HTTP-сервера |
| `MCP_PORT` | `8765` | Порт HTTP-сервера |

## Автообновление (cron)

```bash
# Каждый час переиндексировать проект
0 * * * * cd /path/to/rag && .venv/bin/python ingest.py --path /my/project --type code --language python
```

## Структура

```
rag-for-claude-code/
├── mcp_rag_server.py          # MCP-сервер (17 инструментов)
├── ingest.py                  # Загрузка документации
├── setup.sh                   # Установка (без Docker)
├── download-docs.sh           # Скачивание внешних доков
├── Dockerfile                 # Образ контейнера
├── docker-compose.yml         # Сервисы с монтированием томов
├── entrypoint.sh              # Точка входа контейнера
├── CLAUDE.md                  # Инструкции для модели
├── requirements.txt
├── knowledge/                 # Встроенные базы знаний (том: /app/knowledge)
│   ├── c/                     # C: память, POSIX, сокеты
│   ├── cpp/                   # C++: STL, шаблоны, RAII
│   ├── algorithms/            # Алгоритмы и структуры данных
│   ├── qt/                    # Qt: виджеты, MVC, QML, сеть
│   └── technical/             # Форматы, сборка, протоколы
├── .external-docs/            # Внешняя документация (том: /app/.external-docs)
└── .rag-knowledge-base/       # ChromaDB данные (том: /data/chroma_db)
```
