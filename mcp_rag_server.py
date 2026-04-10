#!/usr/bin/env python3
"""
MCP-сервер для RAG-поиска по базе знаний программирования.
Поддерживает: C, C++, Python, Qt, алгоритмы, техническая документация.
"""

import asyncio
import json
import os
import sys
from pathlib import Path
from typing import Any

from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import Tool, TextContent

import chromadb
from chromadb.config import Settings
from chromadb.utils.embedding_functions import SentenceTransformerEmbeddingFunction

# ─── Конфигурация ────────────────────────────────────────────────

_SCRIPT_DIR = Path(__file__).resolve().parent
DB_PATH = os.environ.get(
    "RAG_DB_PATH",
    str(_SCRIPT_DIR / "chroma_db")
)
COLLECTION_NAME = os.environ.get("RAG_COLLECTION", "programming_docs")
TOP_K = int(os.environ.get("RAG_TOP_K", "10"))
MAX_DISTANCE = float(os.environ.get("RAG_MAX_DISTANCE", "1.5"))

VALID_LANGUAGES = [
    "c", "cpp", "python", "javascript", "typescript", "rust", "go",
    "java", "kotlin", "swift", "csharp", "php", "ruby", "lua",
    "bash", "sql", "qml",
]
VALID_CATEGORIES = [
    "stdlib", "framework", "algorithm", "data-structure", "pattern",
    "file-format", "build-system", "project-structure", "networking",
    "concurrency", "memory", "security", "testing", "qt", "gui",
    "system", "reference", "tutorial", "cheatsheet",
    "math", "radar", "simulation", "3d",
    "database", "devops", "ml",
    "fpga", "geo", "space",
]

_embedding_function = None


def _enable_offline_if_cached(model_name: str) -> None:
    """Включает оффлайн-режим HF Hub если модель есть в локальном кэше.

    Проверяет файловую систему напрямую — без сетевых вызовов.
    Поддерживает оба варианта кэша: HF Hub и sentence-transformers.
    """
    model_id = model_name if "/" in model_name else f"sentence-transformers/{model_name}"

    # 1. HF Hub cache: $HUGGINGFACE_HUB_CACHE или $HF_HOME/hub или ~/.cache/huggingface/hub
    hf_hub_cache = Path(
        os.environ.get("HUGGINGFACE_HUB_CACHE")
        or os.path.join(
            os.environ.get("HF_HOME", str(Path.home() / ".cache" / "huggingface")), "hub"
        )
    )
    snapshots_dir = hf_hub_cache / ("models--" + model_id.replace("/", "--")) / "snapshots"
    hf_cached = snapshots_dir.exists() and any(snapshots_dir.iterdir())

    # 2. Sentence-transformers legacy cache: ~/.cache/torch/sentence_transformers/
    st_cache = Path.home() / ".cache" / "torch" / "sentence_transformers" / model_id.replace("/", "_")

    if hf_cached or st_cache.exists():
        os.environ.setdefault("HF_HUB_OFFLINE", "1")
        os.environ.setdefault("TRANSFORMERS_OFFLINE", "1")


def _get_embedding_function():
    """Создаёт и кеширует функцию эмбеддингов с GPU если доступно."""
    global _embedding_function
    if _embedding_function is not None:
        return _embedding_function
    device = "cpu"
    try:
        import torch
        if torch.cuda.is_available():
            device = "cuda"
        elif hasattr(torch.backends, "mps") and torch.backends.mps.is_available():
            device = "mps"
    except ImportError:
        pass
    model = os.environ.get("RAG_EMBED_MODEL", "all-MiniLM-L6-v2")
    _enable_offline_if_cached(model)
    _embedding_function = SentenceTransformerEmbeddingFunction(
        model_name=model,
        device=device,
        normalize_embeddings=True,
    )
    return _embedding_function

# ─── Инициализация ───────────────────────────────────────────────

app = Server("rag-knowledge-base")

_client = None
_collection = None

def get_collection():
    global _client, _collection
    if _collection is not None:
        try:
            _collection.count()
            return _collection
        except Exception:
            _collection = None
            _client = None

    _client = chromadb.PersistentClient(
        path=DB_PATH,
        settings=Settings(anonymized_telemetry=False)
    )
    _collection = _client.get_or_create_collection(
        name=COLLECTION_NAME,
        metadata={"hnsw:space": "cosine"},
        embedding_function=_get_embedding_function(),
    )
    return _collection


async def _query_collection(collection, **kwargs) -> dict:
    """Запускает блокирующий chromadb.query() в thread pool.

    Необходимо, так как chromadb >= 0.5 использует внутренний httpx-клиент
    для общения с embedded-сервером. Вызов синхронного httpx из async-
    контекста конфликтует с event loop и приводит к
    RuntimeError: cannot send a request as the client has been closed.

    Автоматически снимает where=None (chromadb трактует его как фильтр по
    null-метаданным, а не как «без фильтра») и делает повторный запрос без
    where при InternalError «Error finding id» (категория отсутствует в БД).
    """
    # Не передавать where=None — в ряде версий chromadb это не «без фильтра»
    if kwargs.get("where") is None:
        kwargs.pop("where", None)

    try:
        return await asyncio.to_thread(collection.query, **kwargs)
    except Exception as e:
        if "Error finding id" in str(e) and "where" in kwargs:
            # Категория не представлена в БД — повторяем без фильтра
            kw = {k: v for k, v in kwargs.items() if k != "where"}
            return await asyncio.to_thread(collection.query, **kw)
        raise


async def _get_collection_async() -> Any:
    """Возвращает коллекцию, инициализируя её в thread pool при необходимости."""
    return await asyncio.to_thread(get_collection)


def format_results(results, query: str, show_source: bool = True) -> str:
    """Форматировать результаты поиска."""
    if not results["documents"] or not results["documents"][0]:
        return f"По запросу «{query}» ничего не найдено в базе знаний."

    parts = [f"# Результаты: {query}\n"]
    seen = set()

    for doc, meta, dist in zip(
        results["documents"][0],
        results["metadatas"][0],
        results["distances"][0]
    ):
        if dist > MAX_DISTANCE:
            continue

        # Дедупликация
        doc_hash = hash(doc[:200])
        if doc_hash in seen:
            continue
        seen.add(doc_hash)

        source = meta.get("source", "")
        lang = meta.get("language", "")
        category = meta.get("category", "")
        relevance = max(0, round((1 - dist) * 100, 1))

        header = f"## [{source}]" if show_source else "##"
        tags = []
        if lang:
            tags.append(lang)
        if category:
            tags.append(category)
        tag_str = f" ({', '.join(tags)})" if tags else ""

        parts.append(f"{header}{tag_str} — {relevance}%")
        parts.append(doc)
        parts.append("---\n")

    if len(parts) <= 1:
        return f"По запросу «{query}» нет достаточно релевантных результатов."

    return "\n".join(parts)


# ─── Определение инструментов ────────────────────────────────────

@app.list_tools()
async def list_tools() -> list[Tool]:
    return [
        Tool(
            name="search_docs",
            description=(
                "Семантический поиск по базе знаний программирования. "
                "Содержит: C, C++, Python, Go, Rust, TypeScript, Qt, "
                "алгоритмы, сети, математика, радар/DSP, моделирование, 3D, "
                "БД, DevOps, ML/AI, безопасность. "
                "ОБЯЗАТЕЛЬНО вызывай перед написанием кода если: "
                "1) используешь API библиотеки/фреймворка, "
                "2) не уверен в синтаксисе или сигнатуре, "
                "3) реализуешь алгоритм или структуру данных."
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "Поисковый запрос на естественном языке"
                    },
                    "language": {
                        "type": "string",
                        "description": f"Фильтр по языку: {', '.join(VALID_LANGUAGES)}",
                        "default": ""
                    },
                    "category": {
                        "type": "string",
                        "description": f"Фильтр по категории: {', '.join(VALID_CATEGORIES)}",
                        "default": ""
                    },
                    "n_results": {
                        "type": "integer",
                        "description": "Количество результатов (1-20, по умолчанию 10)",
                        "default": 10
                    }
                },
                "required": ["query"]
            }
        ),
        Tool(
            name="search_api",
            description=(
                "Поиск по API-справочникам: функции, классы, методы, сигнатуры. "
                "Используй когда нужна точная сигнатура функции или метода."
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "Имя функции/класса/метода или описание"
                    },
                    "language": {
                        "type": "string",
                        "description": "Язык программирования",
                        "default": ""
                    }
                },
                "required": ["query"]
            }
        ),
        Tool(
            name="search_algorithm",
            description=(
                "Поиск алгоритмов и структур данных: сортировка, графы, "
                "деревья, динамическое программирование, оценка сложности."
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "Описание алгоритма или задачи"
                    },
                    "language": {
                        "type": "string",
                        "description": "Язык для примеров кода",
                        "default": ""
                    }
                },
                "required": ["query"]
            }
        ),
        Tool(
            name="search_qt",
            description=(
                "Поиск по документации Qt: виджеты, сигналы/слоты, "
                "QML, модели, сеть, многопоточность, графика."
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "Запрос по Qt"
                    }
                },
                "required": ["query"]
            }
        ),
        Tool(
            name="search_technical",
            description=(
                "Поиск технической информации: форматы файлов, "
                "структуры проектов, системы сборки, сетевые протоколы."
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "Технический запрос"
                    }
                },
                "required": ["query"]
            }
        ),
        Tool(
            name="search_networking",
            description=(
                "Поиск по сетевым протоколам и программированию: "
                "TCP/IP, UDP, HTTP/2/3, QUIC, TLS, DNS, WebSocket, gRPC, "
                "MQTT, сокеты, epoll, сетевой стек, системный дизайн."
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "query": {"type": "string", "description": "Сетевой запрос"}
                },
                "required": ["query"]
            }
        ),
        Tool(
            name="search_math",
            description=(
                "Поиск по математике, линейной алгебре и геометрии: "
                "векторы, матрицы, кватернионы, численные методы, "
                "интерполяция, FFT, статистика, оптимизация."
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "query": {"type": "string", "description": "Математический запрос"}
                },
                "required": ["query"]
            }
        ),
        Tool(
            name="search_radar",
            description=(
                "Поиск по радиолокации, DSP и обработке сигналов: "
                "FFT, фильтры (FIR/IIR), радарное уравнение, CFAR, "
                "доплеровский эффект, SDR, GNU Radio, pulse compression."
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "query": {"type": "string", "description": "Запрос по радару/DSP"}
                },
                "required": ["query"]
            }
        ),
        Tool(
            name="search_simulation",
            description=(
                "Поиск по моделированию и симуляции: "
                "численное интегрирование ОДУ (RK4, Эйлер), "
                "физические движки (Box2D, Bullet), метод конечных элементов, "
                "дискретно-событийная симуляция, Taichi, Monte Carlo."
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "query": {"type": "string", "description": "Запрос по моделированию"}
                },
                "required": ["query"]
            }
        ),
        Tool(
            name="search_3d",
            description=(
                "Поиск по 3D моделированию и рендерингу: "
                "OpenGL, Vulkan, GLSL/HLSL шейдеры, ray tracing, "
                "форматы (OBJ, FBX, glTF), Assimp, GLM, BVH, "
                "трансформации, нормали, UV-маппинг, PBR."
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "query": {"type": "string", "description": "Запрос по 3D/рендерингу"}
                },
                "required": ["query"]
            }
        ),
        Tool(
            name="search_databases",
            description=(
                "Поиск по базам данных и ORM: "
                "SQL, PostgreSQL, Redis, SQLAlchemy, psycopg, "
                "индексы, транзакции, миграции, оптимизация запросов."
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "query": {"type": "string", "description": "Запрос по базам данных"}
                },
                "required": ["query"]
            }
        ),
        Tool(
            name="search_ml",
            description=(
                "Поиск по машинному обучению и AI: "
                "PyTorch, scikit-learn, Transformers, тензоры, "
                "обучение моделей, нейронные сети, NLP, autograd."
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "query": {"type": "string", "description": "Запрос по ML/AI"}
                },
                "required": ["query"]
            }
        ),
        Tool(
            name="search_fpga",
            description=(
                "Поиск по FPGA, HDL и программированию Xilinx/AMD: "
                "VHDL, Verilog, SystemVerilog, Vitis HLS (C++ → RTL), "
                "PYNQ (Python на Zynq), AXI4/AXI-Lite/AXI-Stream интерфейсы, "
                "DMA, IP cores, синтез (Yosys), симуляция (GHDL, Icarus, Verilator), "
                "тестирование (cocotb, VUnit), формальная верификация, "
                "RISC-V на FPGA (PicoRV32, VexRiscv), SDR на FPGA."
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "query": {"type": "string", "description": "Запрос по FPGA/HDL/Xilinx"}
                },
                "required": ["query"]
            }
        ),
        Tool(
            name="search_geo",
            description=(
                "Поиск по геопространственным данным и ГИС: "
                "форматы (GeoJSON, Shapefile, GeoTIFF, KML/KMZ, GPX, PMTiles, GeoParquet), "
                "GDAL, PROJ, координатные системы (WGS84, UTM, CRS), "
                "GeoPandas, Shapely, Rasterio, Fiona, PostGIS, SpatiaLite, "
                "тайлы (MapLibre, Leaflet, MVT, STAC), ДЗЗ (Sentinel, спутниковые данные), "
                "трансформации координат, анализ рельефа (DEM), картографические проекции."
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "query": {"type": "string", "description": "Запрос по ГИС/геоданным"}
                },
                "required": ["query"]
            }
        ),
        Tool(
            name="search_space",
            description=(
                "Поиск по аэрокосмическим технологиям: "
                "орбитальная механика (Kepler, Lambert, Холман, SGP4, TLE), "
                "Astropy, Poliastro, Skyfield, SpiceyPy (NAIF SPICE), "
                "CCSDS протоколы (Space Packet, TM, TC, AOS), "
                "NASA cFS, F Prime (Ingenuity), OpenMCT, "
                "автопилоты БПЛА (ArduPilot, PX4, MAVLink, MAVSDK), "
                "Луна (LOLA DEM, лунная геометрия SPICE), "
                "CFD аэродинамика (OpenFOAM, SU2), визуализация (Cesium, Rerun), "
                "наземные станции, спутниковая связь, GR Satellites."
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "query": {"type": "string", "description": "Запрос по космосу/аэрокосмосу"}
                },
                "required": ["query"]
            }
        ),
        Tool(
            name="kb_stats",
            description="Статистика базы знаний.",
            inputSchema={"type": "object", "properties": {}}
        ),
        Tool(
            name="list_sources",
            description="Список всех источников в базе знаний.",
            inputSchema={"type": "object", "properties": {}}
        ),
    ]


@app.call_tool()
async def call_tool(name: str, arguments: dict[str, Any]) -> list[TextContent]:
    try:
        collection = await _get_collection_async()
        count = await asyncio.to_thread(collection.count)
        if count == 0 and name.startswith("search"):
            return [TextContent(type="text", text=(
                "⚠️ База знаний пуста!\n"
                "Запустите: python ingest.py --load-all\n"
                "Или: ./setup.sh"
            ))]

        handlers = {
            "search_docs": _search_docs,
            "search_api": _search_api,
            "search_algorithm": _search_algorithm,
            "search_qt": _search_qt,
            "search_technical": _search_technical,
            "search_networking": _search_networking,
            "search_math": _search_math,
            "search_radar": _search_radar,
            "search_simulation": _search_simulation,
            "search_3d": _search_3d,
            "search_databases": _search_databases,
            "search_ml": _search_ml,
            "search_fpga": _search_fpga,
            "search_geo": _search_geo,
            "search_space": _search_space,
            "kb_stats": _kb_stats,
            "list_sources": _list_sources,
        }
        handler = handlers.get(name)
        if not handler:
            return [TextContent(type="text", text=f"Неизвестный инструмент: {name}")]
        return await handler(arguments)
    except Exception as e:
        return [TextContent(type="text", text=f"Ошибка: {type(e).__name__}: {e}")]


async def _search_docs(args: dict) -> list[TextContent]:
    query = args["query"]
    language = args.get("language", "").lower().strip()
    category = args.get("category", "").lower().strip()
    n = min(args.get("n_results", TOP_K), 20)

    where = _build_filter(language=language, category=category)
    collection = await _get_collection_async()
    results = await _query_collection(
        collection,
        query_texts=[query], n_results=n,
        where=where, include=["documents", "metadatas", "distances"]
    )
    return [TextContent(type="text", text=format_results(results, query))]


async def _search_api(args: dict) -> list[TextContent]:
    query = args["query"]
    language = args.get("language", "").lower().strip()
    where = _build_filter(language=language, category="reference")

    collection = await _get_collection_async()
    results = await _query_collection(
        collection,
        query_texts=[f"API reference: {query}"],
        n_results=TOP_K, where=where,
        include=["documents", "metadatas", "distances"]
    )
    # Если мало результатов — искать шире
    if not results["documents"][0] or len(results["documents"][0]) < 2:
        results = await _query_collection(
            collection,
            query_texts=[query], n_results=TOP_K,
            where=_build_filter(language=language),
            include=["documents", "metadatas", "distances"]
        )
    return [TextContent(type="text", text=format_results(results, query))]


async def _search_algorithm(args: dict) -> list[TextContent]:
    query = args["query"]
    language = args.get("language", "").lower().strip()

    where_filters = [
        _build_filter(category="algorithm"),
        _build_filter(category="data-structure"),
    ]

    collection = await _get_collection_async()
    all_docs, all_metas, all_dists = [], [], []
    for wf in where_filters:
        res = await _query_collection(
            collection,
            query_texts=[query], n_results=TOP_K // 2,
            where=wf, include=["documents", "metadatas", "distances"]
        )
        if res["documents"] and res["documents"][0]:
            all_docs.extend(res["documents"][0])
            all_metas.extend(res["metadatas"][0])
            all_dists.extend(res["distances"][0])

    # Также поищем по всей базе
    res2 = await _query_collection(
        collection,
        query_texts=[f"algorithm: {query}"], n_results=TOP_K // 2,
        include=["documents", "metadatas", "distances"]
    )
    if res2["documents"] and res2["documents"][0]:
        all_docs.extend(res2["documents"][0])
        all_metas.extend(res2["metadatas"][0])
        all_dists.extend(res2["distances"][0])

    combined = {"documents": [all_docs], "metadatas": [all_metas], "distances": [all_dists]}
    return [TextContent(type="text", text=format_results(combined, query))]


async def _search_qt(args: dict) -> list[TextContent]:
    query = args["query"]
    collection = await _get_collection_async()

    results = await _query_collection(
        collection,
        query_texts=[f"Qt: {query}"], n_results=TOP_K,
        where=_build_filter(category="qt"),
        include=["documents", "metadatas", "distances"]
    )
    if not results["documents"][0] or results["distances"][0][0] > 1.2:
        results = await _query_collection(
            collection,
            query_texts=[f"Qt {query}"], n_results=TOP_K,
            include=["documents", "metadatas", "distances"]
        )
    return [TextContent(type="text", text=format_results(results, query))]


async def _search_technical(args: dict) -> list[TextContent]:
    query = args["query"]
    collection = await _get_collection_async()

    tech_cats = ["file-format", "build-system", "project-structure", "system", "networking"]
    all_docs, all_metas, all_dists = [], [], []

    for cat in tech_cats:
        res = await _query_collection(
            collection,
            query_texts=[query], n_results=3,
            where=_build_filter(category=cat),
            include=["documents", "metadatas", "distances"]
        )
        if res["documents"] and res["documents"][0]:
            all_docs.extend(res["documents"][0])
            all_metas.extend(res["metadatas"][0])
            all_dists.extend(res["distances"][0])

    combined = {"documents": [all_docs], "metadatas": [all_metas], "distances": [all_dists]}
    return [TextContent(type="text", text=format_results(combined, query))]


async def _search_networking(args: dict) -> list[TextContent]:
    query = args["query"]
    collection = await _get_collection_async()
    results = await _query_collection(
        collection,
        query_texts=[f"network protocol: {query}"], n_results=TOP_K,
        where=_build_filter(category="networking"),
        include=["documents", "metadatas", "distances"]
    )
    if not results["documents"][0] or results["distances"][0][0] > 1.2:
        results = await _query_collection(
            collection,
            query_texts=[query], n_results=TOP_K,
            include=["documents", "metadatas", "distances"]
        )
    return [TextContent(type="text", text=format_results(results, query))]


async def _search_math(args: dict) -> list[TextContent]:
    query = args["query"]
    collection = await _get_collection_async()
    results = await _query_collection(
        collection,
        query_texts=[f"mathematics geometry: {query}"], n_results=TOP_K,
        where=_build_filter(category="math"),
        include=["documents", "metadatas", "distances"]
    )
    if not results["documents"][0] or results["distances"][0][0] > 1.2:
        results = await _query_collection(
            collection,
            query_texts=[query], n_results=TOP_K,
            include=["documents", "metadatas", "distances"]
        )
    return [TextContent(type="text", text=format_results(results, query))]


async def _search_radar(args: dict) -> list[TextContent]:
    query = args["query"]
    collection = await _get_collection_async()
    # Ищем по radar + signal processing
    all_docs, all_metas, all_dists = [], [], []
    for cat in ["radar", "signal-processing"]:
        res = await _query_collection(
            collection,
            query_texts=[f"radar signal processing DSP: {query}"],
            n_results=TOP_K // 2,
            where=_build_filter(category=cat),
            include=["documents", "metadatas", "distances"]
        )
        if res["documents"] and res["documents"][0]:
            all_docs.extend(res["documents"][0])
            all_metas.extend(res["metadatas"][0])
            all_dists.extend(res["distances"][0])
    if not all_docs:
        res = await _query_collection(
            collection,
            query_texts=[query], n_results=TOP_K,
            include=["documents", "metadatas", "distances"]
        )
        all_docs = res["documents"][0]
        all_metas = res["metadatas"][0]
        all_dists = res["distances"][0]
    combined = {"documents": [all_docs], "metadatas": [all_metas], "distances": [all_dists]}
    return [TextContent(type="text", text=format_results(combined, query))]


async def _search_simulation(args: dict) -> list[TextContent]:
    query = args["query"]
    collection = await _get_collection_async()
    results = await _query_collection(
        collection,
        query_texts=[f"simulation modeling physics: {query}"], n_results=TOP_K,
        where=_build_filter(category="simulation"),
        include=["documents", "metadatas", "distances"]
    )
    if not results["documents"][0] or results["distances"][0][0] > 1.2:
        results = await _query_collection(
            collection,
            query_texts=[query], n_results=TOP_K,
            include=["documents", "metadatas", "distances"]
        )
    return [TextContent(type="text", text=format_results(results, query))]


async def _search_3d(args: dict) -> list[TextContent]:
    query = args["query"]
    collection = await _get_collection_async()
    results = await _query_collection(
        collection,
        query_texts=[f"3D rendering graphics: {query}"], n_results=TOP_K,
        where=_build_filter(category="3d"),
        include=["documents", "metadatas", "distances"]
    )
    if not results["documents"][0] or results["distances"][0][0] > 1.2:
        results = await _query_collection(
            collection,
            query_texts=[query], n_results=TOP_K,
            include=["documents", "metadatas", "distances"]
        )
    return [TextContent(type="text", text=format_results(results, query))]


async def _search_databases(args: dict) -> list[TextContent]:
    query = args["query"]
    collection = await _get_collection_async()
    results = await _query_collection(
        collection,
        query_texts=[f"database SQL: {query}"], n_results=TOP_K,
        where=_build_filter(category="database"),
        include=["documents", "metadatas", "distances"]
    )
    if not results["documents"][0] or results["distances"][0][0] > 1.2:
        results = await _query_collection(
            collection,
            query_texts=[query], n_results=TOP_K,
            include=["documents", "metadatas", "distances"]
        )
    return [TextContent(type="text", text=format_results(results, query))]


async def _search_ml(args: dict) -> list[TextContent]:
    query = args["query"]
    collection = await _get_collection_async()
    results = await _query_collection(
        collection,
        query_texts=[f"machine learning neural network: {query}"], n_results=TOP_K,
        where=_build_filter(category="ml"),
        include=["documents", "metadatas", "distances"]
    )
    if not results["documents"][0] or results["distances"][0][0] > 1.2:
        results = await _query_collection(
            collection,
            query_texts=[query], n_results=TOP_K,
            include=["documents", "metadatas", "distances"]
        )
    return [TextContent(type="text", text=format_results(results, query))]


async def _search_fpga(args: dict) -> list[TextContent]:
    query = args["query"]
    collection = await _get_collection_async()
    results = await _query_collection(
        collection,
        query_texts=[f"FPGA HDL VHDL Verilog Xilinx: {query}"], n_results=TOP_K,
        where=_build_filter(category="fpga"),
        include=["documents", "metadatas", "distances"]
    )
    if not results["documents"][0] or results["distances"][0][0] > 1.2:
        results = await _query_collection(
            collection,
            query_texts=[query], n_results=TOP_K,
            include=["documents", "metadatas", "distances"]
        )
    return [TextContent(type="text", text=format_results(results, query))]


async def _search_geo(args: dict) -> list[TextContent]:
    query = args["query"]
    collection = await _get_collection_async()
    all_docs, all_metas, all_dists = [], [], []
    for cat in ["geo", "file-format"]:
        res = await _query_collection(
            collection,
            query_texts=[f"GIS geospatial geodata: {query}"], n_results=TOP_K // 2,
            where=_build_filter(category=cat),
            include=["documents", "metadatas", "distances"]
        )
        if res["documents"] and res["documents"][0]:
            all_docs.extend(res["documents"][0])
            all_metas.extend(res["metadatas"][0])
            all_dists.extend(res["distances"][0])
    if not all_docs:
        res = await _query_collection(
            collection,
            query_texts=[query], n_results=TOP_K,
            include=["documents", "metadatas", "distances"]
        )
        all_docs = res["documents"][0]
        all_metas = res["metadatas"][0]
        all_dists = res["distances"][0]
    combined = {"documents": [all_docs], "metadatas": [all_metas], "distances": [all_dists]}
    return [TextContent(type="text", text=format_results(combined, query))]


async def _search_space(args: dict) -> list[TextContent]:
    query = args["query"]
    collection = await _get_collection_async()
    results = await _query_collection(
        collection,
        query_texts=[f"aerospace orbital space satellite: {query}"], n_results=TOP_K,
        where=_build_filter(category="space"),
        include=["documents", "metadatas", "distances"]
    )
    if not results["documents"][0] or results["distances"][0][0] > 1.2:
        results = await _query_collection(
            collection,
            query_texts=[query], n_results=TOP_K,
            include=["documents", "metadatas", "distances"]
        )
    return [TextContent(type="text", text=format_results(results, query))]


# ─── Батчевое получение метаданных ───────────────────────────────

_BATCH_SIZE = 5000

async def _iter_metadatas_async(collection, total: int = 0):
    """Итерирует метаданные батчами в thread pool, обходя лимит SQL переменных ChromaDB."""
    if total == 0:
        total = await asyncio.to_thread(collection.count)
    for offset in range(0, total, _BATCH_SIZE):
        batch = await asyncio.to_thread(
            collection.get,
            include=["metadatas"],
            limit=_BATCH_SIZE,
            offset=offset,
        )
        yield batch["metadatas"]


async def _kb_stats(args: dict) -> list[TextContent]:
    collection = await _get_collection_async()
    count = await asyncio.to_thread(collection.count)
    if count == 0:
        return [TextContent(type="text", text="База знаний пуста.")]

    sources, languages, categories = {}, {}, {}
    async for batch_meta in _iter_metadatas_async(collection, count):
        for m in batch_meta:
            s = m.get("source", "?")
            sources[s] = sources.get(s, 0) + 1
            l = m.get("language", "")
            if l:
                languages[l] = languages.get(l, 0) + 1
            c = m.get("category", "")
            if c:
                categories[c] = categories.get(c, 0) + 1

    lines = [
        f"# Статистика базы знаний\n",
        f"Всего чанков: **{count}**\n",
        f"## Языки",
    ]
    for l, c in sorted(languages.items(), key=lambda x: -x[1]):
        lines.append(f"- {l}: {c}")

    lines.append(f"\n## Категории")
    for c, n in sorted(categories.items(), key=lambda x: -x[1]):
        lines.append(f"- {c}: {n}")

    lines.append(f"\n## Источники ({len(sources)})")
    for s, c in sorted(sources.items()):
        lines.append(f"- {s}: {c}")

    return [TextContent(type="text", text="\n".join(lines))]


async def _list_sources(args: dict) -> list[TextContent]:
    collection = await _get_collection_async()
    count = await asyncio.to_thread(collection.count)
    if count == 0:
        return [TextContent(type="text", text="База знаний пуста.")]

    sources = {}
    async for batch_meta in _iter_metadatas_async(collection, count):
        for m in batch_meta:
            key = m.get("source", "?")
            if key not in sources:
                sources[key] = {"count": 0, "lang": set(), "cat": set()}
            sources[key]["count"] += 1
            if m.get("language"):
                sources[key]["lang"].add(m["language"])
            if m.get("category"):
                sources[key]["cat"].add(m["category"])

    lines = ["# Источники в базе знаний\n"]
    for s, info in sorted(sources.items()):
        langs = ", ".join(sorted(info["lang"])) or "—"
        cats = ", ".join(sorted(info["cat"])) or "—"
        lines.append(f"- **{s}** — {info['count']} чанков | {langs} | {cats}")

    return [TextContent(type="text", text="\n".join(lines))]


def _build_filter(language: str = "", category: str = "") -> dict | None:
    conditions = []
    if language:
        conditions.append({"language": language})
    if category:
        conditions.append({"category": category})

    if len(conditions) == 0:
        return None
    elif len(conditions) == 1:
        return conditions[0]
    else:
        return {"$and": conditions}


# ─── Запуск ──────────────────────────────────────────────────────

async def _run_http_server() -> None:
    """HTTP/SSE транспорт — для подключения из другого контейнера."""
    try:
        from mcp.server.sse import SseServerTransport
        from starlette.applications import Starlette
        from starlette.requests import Request
        from starlette.responses import JSONResponse, Response
        from starlette.routing import Mount, Route
        import uvicorn
    except ImportError as exc:
        print(f"HTTP транспорт требует starlette и uvicorn: {exc}", file=sys.stderr)
        sys.exit(1)

    host = os.environ.get("MCP_HOST", "0.0.0.0")
    port = int(os.environ.get("MCP_PORT", "8765"))

    sse = SseServerTransport("/messages/")

    async def handle_sse(request: Request):
        async with sse.connect_sse(
            request.scope, request.receive, request._send
        ) as streams:
            await app.run(streams[0], streams[1], app.create_initialization_options())
        return Response()

    async def health(request: Request):
        return JSONResponse({"status": "ok"})

    starlette_app = Starlette(
        routes=[
            Route("/health", endpoint=health),
            Route("/sse", endpoint=handle_sse),
            Mount("/messages/", app=sse.handle_post_message),
        ]
    )

    print(f"MCP RAG сервер (HTTP): http://{host}:{port}/sse", file=sys.stderr)
    config = uvicorn.Config(starlette_app, host=host, port=port, log_level="warning")
    server = uvicorn.Server(config)
    await server.serve()


async def main():
    # Прогреваем коллекцию и embedding-модель до старта сервера.
    # Это гарантирует, что httpx-клиент chromadb и загрузка модели
    # происходят в thread pool и не конфликтуют с event loop MCP.
    await asyncio.to_thread(get_collection)

    transport = os.environ.get("MCP_TRANSPORT", "stdio").lower()
    if transport == "http":
        await _run_http_server()
    else:
        async with stdio_server() as (read_stream, write_stream):
            await app.run(read_stream, write_stream, app.create_initialization_options())

if __name__ == "__main__":
    asyncio.run(main())
