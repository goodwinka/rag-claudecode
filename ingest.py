#!/usr/bin/env python3
"""
Загрузка документации в базу знаний RAG.

  python ingest.py --load-all              # загрузить все встроенные базы
  python ingest.py --load-category c       # только С
  python ingest.py --load-category qt      # только Qt
  python ingest.py --path ./docs           # свои файлы
  python ingest.py --path ./src --type code --language python
  python ingest.py --stats
  python ingest.py --clear
"""

import argparse
import hashlib
import json
import os
import re
import sys
from pathlib import Path

import chromadb
from chromadb.config import Settings
from chromadb.utils.embedding_functions import SentenceTransformerEmbeddingFunction

# ─── Конфиг ──────────────────────────────────────────────────────

SCRIPT_DIR_CFG = Path(__file__).resolve().parent
DB_PATH = os.environ.get(
    "RAG_DB_PATH",
    str(SCRIPT_DIR_CFG / "chroma_db")
)
COLLECTION_NAME = os.environ.get("RAG_COLLECTION", "programming_docs")
CHUNK_SIZE = int(os.environ.get("RAG_CHUNK_SIZE", "1200"))
CHUNK_OVERLAP = int(os.environ.get("RAG_CHUNK_OVERLAP", "150"))

# ─── GPU/CPU эмбеддинги ───────────────────────────────────────────

def get_embedding_function():
    """Создаёт функцию эмбеддингов с GPU если доступно."""
    device = "cpu"
    try:
        import torch
        if torch.cuda.is_available():
            device = "cuda"
            gpu_name = torch.cuda.get_device_name(0)
            print(f"  🎮 GPU: {gpu_name}")
        elif hasattr(torch.backends, "mps") and torch.backends.mps.is_available():
            device = "mps"
            print("  🎮 GPU: Apple MPS")
        else:
            print("  💻 GPU недоступен, используется CPU")
    except ImportError:
        pass

    model = os.environ.get("RAG_EMBED_MODEL", "all-MiniLM-L6-v2")
    return SentenceTransformerEmbeddingFunction(
        model_name=model,
        device=device,
        normalize_embeddings=True,
    )

SCRIPT_DIR = SCRIPT_DIR_CFG
KNOWLEDGE_DIR = SCRIPT_DIR / "knowledge"

CODE_EXT = {
    ".py": "python", ".pyw": "python",
    ".c": "c", ".h": "c",
    ".cpp": "cpp", ".cxx": "cpp", ".cc": "cpp",
    ".hpp": "cpp", ".hxx": "cpp", ".hh": "cpp",
    ".js": "javascript", ".mjs": "javascript",
    ".ts": "typescript", ".tsx": "typescript", ".jsx": "javascript",
    ".rs": "rust", ".go": "go", ".rb": "ruby",
    ".java": "java", ".kt": "kotlin", ".swift": "swift",
    ".cs": "csharp", ".php": "php", ".lua": "lua",
    ".sh": "bash", ".bash": "bash", ".zsh": "bash",
    ".sql": "sql", ".qml": "qml",
}
DOC_EXT = {".md", ".rst", ".txt", ".html", ".htm", ".adoc"}
SKIP_DIRS = {
    "node_modules", ".git", "__pycache__", ".venv", "venv",
    ".tox", ".mypy_cache", ".pytest_cache", "dist", "build",
    ".next", ".nuxt", "coverage", ".cache", "vendor", "target",
}

# ─── Чанкинг ─────────────────────────────────────────────────────

def chunk_text(text: str, size: int = CHUNK_SIZE, overlap: int = CHUNK_OVERLAP) -> list[str]:
    text = text.strip()
    if not text:
        return []
    if len(text) <= size:
        return [text]

    chunks = []
    start = 0
    while start < len(text):
        end = start + size
        if end < len(text):
            for sep in ["\n## ", "\n### ", "\n\n", "\n", ". ", " "]:
                pos = text.rfind(sep, start + size // 3, end)
                if pos != -1:
                    end = pos + len(sep)
                    break
        chunk = text[start:end].strip()
        if chunk and len(chunk) > 30:
            chunks.append(chunk)
        start = max(start + 1, end - overlap)
    return chunks


def chunk_code(text: str, lang: str, size: int = CHUNK_SIZE) -> list[str]:
    lines = text.split("\n")
    block_re = {
        "python": r"^(class |def |async def )",
        "c":      r"^(\w[\w\s\*]+\(|struct |enum |typedef |#define )",
        "cpp":    r"^(\w[\w\s\*:<>]+\(|class |struct |enum |namespace |template)",
        "javascript": r"^(function |class |const \w+ = |export |import )",
        "typescript": r"^(function |class |const \w+ = |export |import |interface |type )",
        "rust":   r"^(fn |pub fn |impl |struct |enum |trait |mod )",
        "go":     r"^(func |type |package )",
    }.get(lang, r"^(function |class |def |fn |pub |struct |enum )")

    chunks, current, cur_size = [], [], 0
    for line in lines:
        ls = len(line) + 1
        if cur_size > size // 2 and re.match(block_re, line) and current:
            chunks.append("\n".join(current))
            current, cur_size = [], 0
        current.append(line)
        cur_size += ls
        if cur_size >= size * 2:
            chunks.append("\n".join(current))
            current, cur_size = [], 0
    if current:
        chunks.append("\n".join(current))
    return [c for c in chunks if c.strip() and len(c.strip()) > 20]


# ─── Утилиты ─────────────────────────────────────────────────────

def doc_id(source: str, idx: int, content: str) -> str:
    h = hashlib.md5(content.encode()).hexdigest()[:10]
    return f"{source}::{idx}::{h}"


def detect_metadata_from_path(filepath: Path) -> dict:
    """Автоопределение метаданных из пути knowledge/<category>/<file>.md"""
    parts = filepath.resolve().parts
    meta = {"language": "", "category": "", "source": filepath.stem}

    # Определяем по расширению
    ext = filepath.suffix.lower()
    if ext in CODE_EXT:
        meta["language"] = CODE_EXT[ext]

    # Определяем из структуры knowledge/<category>/...
    try:
        knowledge_idx = parts.index("knowledge")
        if knowledge_idx + 1 < len(parts):
            cat_dir = parts[knowledge_idx + 1]
            cat_map = {
                "c": ("c", "reference"),
                "cpp": ("cpp", "reference"),
                "python": ("python", "reference"),
                "qt": ("cpp", "qt"),
                "algorithms": ("", "algorithm"),
                "technical": ("", "system"),
                "networking": ("", "networking"),
                "math": ("", "math"),
                "radar": ("", "radar"),
                "simulation": ("", "simulation"),
                "3d": ("", "3d"),
                "database": ("", "database"),
                "devops": ("", "devops"),
                "security": ("", "security"),
                "ml": ("python", "ml"),
                "fpga": ("", "fpga"),
                "geo": ("", "geo"),
                "space": ("", "space"),
            }
            if cat_dir in cat_map:
                lang, cat = cat_map[cat_dir]
                if not meta["language"]:
                    meta["language"] = lang
                meta["category"] = cat
    except ValueError:
        pass

    return meta


def parse_front_matter(text: str) -> tuple[dict, str]:
    """Извлечь YAML front matter из markdown."""
    meta = {}
    content = text
    if text.startswith("---\n"):
        end = text.find("\n---\n", 4)
        if end != -1:
            fm = text[4:end]
            content = text[end + 5:]
            for line in fm.split("\n"):
                if ":" in line:
                    k, v = line.split(":", 1)
                    meta[k.strip().lower()] = v.strip()
    return meta, content


# ─── Загрузка ─────────────────────────────────────────────────────

def ingest_file(filepath: Path, collection, source: str = "",
                language: str = "", category: str = "",
                doc_type: str = "") -> int:
    try:
        content = filepath.read_text(encoding="utf-8", errors="ignore")
    except Exception as e:
        print(f"  ✗ {filepath}: {e}")
        return 0
    if not content.strip():
        return 0

    # Автоопределение метаданных
    auto = detect_metadata_from_path(filepath)
    fm, content = parse_front_matter(content)

    source = source or fm.get("source", auto["source"])
    language = language or fm.get("language", auto["language"])
    category = category or fm.get("category", auto["category"])
    if not doc_type:
        doc_type = "code" if filepath.suffix.lower() in CODE_EXT else "doc"

    # Чанкинг
    if doc_type == "code" and language:
        chunks = chunk_code(content, language)
    else:
        chunks = chunk_text(content)

    if not chunks:
        return 0

    ids, documents, metadatas = [], [], []
    for i, chunk in enumerate(chunks):
        ids.append(doc_id(f"{source}:{filepath.name}", i, chunk))
        documents.append(chunk)
        metadatas.append({
            "source": source,
            "filename": filepath.name,
            "language": language,
            "category": category,
            "type": doc_type,
            "chunk_index": i,
        })

    # Upsert батчами по 500
    for start in range(0, len(ids), 500):
        end = start + 500
        collection.upsert(
            ids=ids[start:end],
            documents=documents[start:end],
            metadatas=metadatas[start:end],
        )
    return len(ids)


def ingest_dir(path: Path, collection, **kwargs) -> int:
    files = []
    for fp in sorted(path.rglob("*")):
        if fp.is_file() and not any(s in fp.parts for s in SKIP_DIRS):
            if fp.suffix.lower() in CODE_EXT or fp.suffix.lower() in DOC_EXT:
                files.append(fp)
    total = 0
    for fp in files:
        n = ingest_file(fp, collection, **kwargs)
        if n > 0:
            rel = fp.relative_to(path) if path.is_dir() else fp.name
            print(f"  ✓ {rel}: {n} чанков")
            total += n
    return total


def load_knowledge_category(cat: str, collection) -> int:
    cat_path = KNOWLEDGE_DIR / cat
    if not cat_path.is_dir():
        print(f"  ⚠ Категория не найдена: {cat}")
        return 0
    print(f"\n📂 Загрузка категории: {cat}")
    return ingest_dir(cat_path, collection)


def load_all_knowledge(collection) -> int:
    if not KNOWLEDGE_DIR.is_dir():
        print(f"⚠ Директория knowledge/ не найдена: {KNOWLEDGE_DIR}")
        return 0
    total = 0
    cats = sorted(d.name for d in KNOWLEDGE_DIR.iterdir() if d.is_dir())
    for cat in cats:
        total += load_knowledge_category(cat, collection)
    return total


# ─── Батчевое получение метаданных ───────────────────────────────

BATCH_SIZE = 5000

def _iter_all_metadatas(collection, total: int = 0):
    """Итерирует метаданные батчами, обходя лимит SQL переменных ChromaDB."""
    if total == 0:
        total = collection.count()
    for offset in range(0, total, BATCH_SIZE):
        batch = collection.get(
            include=["metadatas"],
            limit=BATCH_SIZE,
            offset=offset,
        )
        yield batch["metadatas"]


# ─── CLI ──────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Загрузка документации в RAG базу знаний",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--load-all", action="store_true",
                        help="Загрузить все встроенные базы знаний")
    parser.add_argument("--load-category", type=str, metavar="CAT",
                        help="Загрузить категорию: c, cpp, python, qt, algorithms, technical")
    parser.add_argument("--path", type=str, help="Путь к файлу/директории")
    parser.add_argument("--source", type=str, default="")
    parser.add_argument("--language", type=str, default="")
    parser.add_argument("--category", type=str, default="")
    parser.add_argument("--type", type=str, default="", choices=["code", "doc", ""])
    parser.add_argument("--clear", action="store_true")
    parser.add_argument("--stats", action="store_true")
    parser.add_argument("--list-categories", action="store_true")

    args = parser.parse_args()
    os.makedirs(DB_PATH, exist_ok=True)

    client = chromadb.PersistentClient(
        path=DB_PATH, settings=Settings(anonymized_telemetry=False)
    )

    if args.clear:
        try:
            client.delete_collection(COLLECTION_NAME)
            print(f"✓ Коллекция удалена.")
        except Exception:
            print("Коллекция не существует.")
        return

    ef = get_embedding_function()
    collection = client.get_or_create_collection(
        name=COLLECTION_NAME,
        metadata={"hnsw:space": "cosine"},
        embedding_function=ef,
    )

    if args.stats:
        count = collection.count()
        print(f"Документов: {count}")
        if count > 0:
            src, lngs, cats = {}, {}, {}
            for batch_meta in _iter_all_metadatas(collection, count):
                for m in batch_meta:
                    s = m.get("source", "?")
                    src[s] = src.get(s, 0) + 1
                    l = m.get("language", "")
                    if l: lngs[l] = lngs.get(l, 0) + 1
                    c = m.get("category", "")
                    if c: cats[c] = cats.get(c, 0) + 1
            print(f"\nЯзыки:")
            for l, c in sorted(lngs.items(), key=lambda x: -x[1]):
                print(f"  {l}: {c}")
            print(f"\nКатегории:")
            for c, n in sorted(cats.items(), key=lambda x: -x[1]):
                print(f"  {c}: {n}")
            print(f"\nИсточники: {len(src)}")
            for s, c in sorted(src.items()):
                print(f"  {s}: {c}")
        return

    if args.list_categories:
        if KNOWLEDGE_DIR.is_dir():
            for d in sorted(KNOWLEDGE_DIR.iterdir()):
                if d.is_dir():
                    files = list(d.rglob("*.md"))
                    print(f"  {d.name}: {len(files)} файлов")
        else:
            print("Директория knowledge/ не найдена")
        return

    total = 0
    if args.load_all:
        total += load_all_knowledge(collection)

    if args.load_category:
        total += load_knowledge_category(args.load_category, collection)

    if args.path:
        p = Path(args.path).resolve()
        if not p.exists():
            print(f"Путь не найден: {p}")
            sys.exit(1)
        print(f"\n📂 Загрузка: {p}")
        if p.is_dir():
            total += ingest_dir(p, collection,
                                source=args.source, language=args.language,
                                category=args.category, doc_type=args.type)
        else:
            total += ingest_file(p, collection,
                                 source=args.source, language=args.language,
                                 category=args.category, doc_type=args.type)

    if not any([args.load_all, args.load_category, args.path]):
        parser.print_help()
        return

    print(f"\n✅ Загружено: {total} чанков")
    print(f"📊 Всего в базе: {collection.count()}")


if __name__ == "__main__":
    main()
