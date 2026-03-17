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
       └──▶ MCP RAG Server (mcp_rag_server.py)
                 │
                 ├── search_docs       — общий поиск
                 ├── search_api        — API справочник
                 ├── search_algorithm  — алгоритмы
                 ├── search_qt         — Qt документация
                 ├── search_technical  — форматы, сборка, протоколы
                 │
                 └── ChromaDB (~/.rag-knowledge-base/)
```

## Быстрый старт

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

## Подключение к Claude Code

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

## Автообновление (cron)

```bash
# Каждый час переиндексировать проект
0 * * * * cd /path/to/rag && .venv/bin/python ingest.py --path /my/project --type code --language python
```

## Структура

```
rag-for-claude-code/
├── mcp_rag_server.py          # MCP-сервер (7 инструментов)
├── ingest.py                  # Загрузка документации
├── setup.sh                   # Установка
├── download-docs.sh           # Скачивание внешних доков
├── CLAUDE.md                  # Инструкции для модели
├── requirements.txt
├── knowledge/                 # Встроенные базы знаний
│   ├── c/                     # C: память, POSIX, сокеты
│   ├── cpp/                   # C++: STL, шаблоны, RAII
│   ├── python/                # Python: stdlib, async, typing
│   ├── qt/                    # Qt: виджеты, MVC, QML, сеть
│   ├── algorithms/            # Алгоритмы и структуры данных
│   └── technical/             # Форматы, сборка, протоколы
└── .external-docs/            # Скачанная внешняя документация
```
