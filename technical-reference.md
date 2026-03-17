---
source: Technical Reference
language:
category: system
---

# Техническая информация

## Структуры файловых форматов

### ELF (Executable and Linkable Format) — Linux/Unix

```
Структура ELF файла:
┌───────────────────┐
│ ELF Header        │ — магическое число 0x7F454C46, класс, endian, ABI
│  e_type           │   ET_EXEC=исполняемый, ET_DYN=shared, ET_REL=.o
│  e_machine        │   EM_X86_64, EM_AARCH64, EM_RISCV
│  e_entry          │   точка входа (адрес main/start)
│  e_phoff          │   смещение Program Headers
│  e_shoff          │   смещение Section Headers
├───────────────────┤
│ Program Headers   │ — для загрузчика (runtime view)
│  PT_LOAD          │   сегменты для загрузки в память
│  PT_DYNAMIC       │   информация для динамического линковщика
│  PT_INTERP        │   путь к интерпретатору (/lib64/ld-linux-x86-64.so.2)
├───────────────────┤
│ Sections          │ — для линковщика (link-time view)
│  .text            │   исполняемый код
│  .data            │   инициализированные глобальные данные
│  .bss             │   неинициализированные данные (нули)
│  .rodata          │   константы (строковые литералы и т.д.)
│  .symtab          │   таблица символов
│  .strtab          │   таблица строк
│  .rel.text        │   релокации для .text
│  .debug_*         │   отладочная информация (DWARF)
│  .got / .plt      │   глобальная таблица смещений / PLT
├───────────────────┤
│ Section Headers   │ — описание секций
└───────────────────┘

Утилиты: readelf -h file, objdump -d file, nm file, ldd file
```

### PE (Portable Executable) — Windows

```
┌───────────────────┐
│ DOS Header        │ — "MZ" сигнатура, e_lfanew указывает на PE Header
│ DOS Stub          │ — "This program cannot be run in DOS mode."
├───────────────────┤
│ PE Signature      │ — "PE\0\0"
│ COFF File Header  │ — Machine, NumberOfSections, TimeDateStamp
│ Optional Header   │ — AddressOfEntryPoint, ImageBase, SectionAlignment
│   Data Directories│   Import Table, Export Table, Resource Table, etc.
├───────────────────┤
│ Section Table     │
│  .text            │   код
│  .rdata           │   read-only данные, import/export таблицы
│  .data            │   читаемые/записываемые данные
│  .rsrc            │   ресурсы (иконки, диалоги, версия)
│  .reloc           │   базовые релокации
└───────────────────┘

Расширения: .exe, .dll, .sys, .ocx
Утилиты: dumpbin /headers file.exe (MSVC), objdump -p file.exe
```

### PNG формат

```
Сигнатура: 89 50 4E 47 0D 0A 1A 0A (8 байт)

Чанки (каждый = Length + Type + Data + CRC32):
  IHDR — обязательный первый: width, height, bit_depth, color_type
         color_type: 0=grayscale, 2=RGB, 3=palette, 4=gray+alpha, 6=RGBA
  PLTE — палитра (для color_type=3)
  IDAT — сжатые данные изображения (zlib/deflate)
  IEND — обязательный последний (пустой)

  Вспомогательные:
  tEXt — текстовые метаданные (ключ-значение)
  tIME — время последней модификации
  gAMA — гамма
  pHYs — физический размер пикселя

Чтение: libpng (C), Pillow (Python), stb_image.h (C, header-only)
```

### JSON / YAML / TOML

```
JSON:
  Типы: object{}, array[], string"", number, true, false, null
  Ограничения: нет комментариев, нет trailing запятых
  Парсеры: json (Python), nlohmann/json (C++), serde_json (Rust)
  MIME: application/json

YAML:
  Отступы для вложенности (пробелы, НЕ табы)
  Типы: map, sequence, scalar
  Якоря: &name и *name (ссылки)
  Многострочные строки: | (сохраняет переносы), > (складывает)
  ОСТОРОЖНО: "Norway problem" (NO → false), "1.0" может стать float
  Парсеры: PyYAML, ruamel.yaml (Python), yaml-cpp (C++)

TOML:
  [section] и key = "value"
  Типы: string, integer, float, bool, datetime, array, table
  Встроенные таблицы: [servers.alpha]
  Используется: Cargo.toml (Rust), pyproject.toml (Python)
  Парсеры: tomllib (Python 3.11+ stdlib), toml++ (C++)
```

## Системы сборки

### CMake (C/C++)

```cmake
cmake_minimum_required(VERSION 3.20)
project(MyProject VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Опции
option(BUILD_TESTS "Build tests" ON)
option(USE_QT "Use Qt framework" OFF)

# Исходники
add_executable(myapp
    src/main.cpp
    src/utils.cpp
)

# Библиотека
add_library(mylib STATIC
    src/lib.cpp
)
target_include_directories(mylib PUBLIC include)

# Линковка
target_link_libraries(myapp PRIVATE mylib)

# Find packages
find_package(Threads REQUIRED)
target_link_libraries(myapp PRIVATE Threads::Threads)

# Qt
if(USE_QT)
    find_package(Qt6 REQUIRED COMPONENTS Widgets Network)
    target_link_libraries(myapp PRIVATE Qt6::Widgets Qt6::Network)
    set(CMAKE_AUTOMOC ON)
    set(CMAKE_AUTORCC ON)
    set(CMAKE_AUTOUIC ON)
endif()

# FetchContent — скачать зависимость
include(FetchContent)
FetchContent_Declare(fmt
    GIT_REPOSITORY https://github.com/fmtlib/fmt
    GIT_TAG 10.2.1
)
FetchContent_MakeAvailable(fmt)
target_link_libraries(myapp PRIVATE fmt::fmt)

# Тесты
if(BUILD_TESTS)
    enable_testing()
    add_executable(tests tests/test_main.cpp)
    target_link_libraries(tests PRIVATE mylib)
    add_test(NAME tests COMMAND tests)
endif()

# Install
install(TARGETS myapp DESTINATION bin)
install(TARGETS mylib DESTINATION lib)
install(DIRECTORY include/ DESTINATION include)
```

```bash
# Сборка
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTS=ON
cmake --build . -j$(nproc)
ctest --output-on-failure
cmake --install . --prefix /usr/local
```

### Makefile (основы)

```makefile
CC = gcc
CXX = g++
CFLAGS = -Wall -Wextra -O2 -std=c11
CXXFLAGS = -Wall -Wextra -O2 -std=c++20

SRCS = $(wildcard src/*.c)
OBJS = $(SRCS:src/%.c=build/%.o)
TARGET = build/myapp

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

build/%.o: src/%.c | build
	$(CC) $(CFLAGS) -c -o $@ $<

build:
	mkdir -p build

clean:
	rm -rf build

# Автоматические зависимости заголовков
-include $(OBJS:.o=.d)
build/%.o: src/%.c | build
	$(CC) $(CFLAGS) -MMD -c -o $@ $<
```

### Python проект (pyproject.toml)

```toml
[build-system]
requires = ["setuptools>=68.0", "wheel"]
build-backend = "setuptools.backends._legacy:_Backend"

[project]
name = "my-package"
version = "1.0.0"
description = "My package"
requires-python = ">=3.10"
dependencies = [
    "requests>=2.28",
    "pydantic>=2.0",
]

[project.optional-dependencies]
dev = ["pytest>=7.0", "ruff>=0.1.0", "mypy>=1.0"]

[project.scripts]
myapp = "my_package.cli:main"

[tool.pytest.ini_options]
testpaths = ["tests"]
asyncio_mode = "auto"

[tool.ruff]
target-version = "py310"
line-length = 100
select = ["E", "F", "I", "N", "W", "UP"]

[tool.mypy]
python_version = "3.10"
strict = true
```

## Структура проектов

### C/C++ проект

```
my-project/
├── CMakeLists.txt
├── README.md
├── LICENSE
├── .clang-format
├── .clang-tidy
├── include/
│   └── myproject/
│       ├── core.h
│       └── utils.h
├── src/
│   ├── main.cpp
│   ├── core.cpp
│   └── utils.cpp
├── tests/
│   ├── CMakeLists.txt
│   ├── test_core.cpp
│   └── test_utils.cpp
├── docs/
├── third_party/       # или external/
└── build/             # out-of-source build
```

### Python проект

```
my-project/
├── pyproject.toml
├── README.md
├── LICENSE
├── src/
│   └── my_package/
│       ├── __init__.py
│       ├── core.py
│       ├── models.py
│       ├── utils.py
│       └── cli.py
├── tests/
│   ├── __init__.py
│   ├── conftest.py
│   ├── test_core.py
│   └── test_models.py
├── docs/
└── .github/
    └── workflows/
        └── ci.yml
```

### Qt проект

```
my-qt-app/
├── CMakeLists.txt
├── src/
│   ├── main.cpp
│   ├── mainwindow.h
│   ├── mainwindow.cpp
│   ├── mainwindow.ui     # Qt Designer form
│   ├── models/
│   │   ├── datamodel.h
│   │   └── datamodel.cpp
│   └── widgets/
│       ├── customwidget.h
│       └── customwidget.cpp
├── qml/                   # для Qt Quick
│   ├── main.qml
│   └── components/
├── resources/
│   ├── resources.qrc
│   ├── icons/
│   └── translations/
│       ├── app_ru.ts
│       └── app_en.ts
└── tests/
```

## Сетевые протоколы

### HTTP

```
Методы: GET (идемпотентный), POST, PUT (идемпотентный), 
        DELETE (идемпотентный), PATCH, HEAD, OPTIONS

Коды ответов:
  1xx — информационные
  2xx — успех: 200 OK, 201 Created, 204 No Content
  3xx — перенаправление: 301 Moved, 304 Not Modified
  4xx — ошибка клиента: 400 Bad Request, 401 Unauthorized, 
        403 Forbidden, 404 Not Found, 429 Too Many Requests
  5xx — ошибка сервера: 500 Internal, 502 Bad Gateway, 503 Unavailable

Заголовки:
  Content-Type: application/json; charset=utf-8
  Authorization: Bearer <token>
  Cache-Control: no-cache, max-age=3600
  Accept: application/json
  Content-Length: 1234
```

### TCP/IP стек

```
Уровень приложения: HTTP, HTTPS, FTP, SSH, DNS, SMTP
Транспортный:       TCP (надёжный, порядок), UDP (быстрый, без гарантий)
Сетевой:            IP (v4/v6), ICMP, ARP
Канальный:          Ethernet, WiFi (802.11)

TCP 3-way handshake: SYN → SYN-ACK → ACK
TCP порт: 16 бит (0-65535), well-known: 0-1023
  22=SSH, 53=DNS, 80=HTTP, 443=HTTPS, 3306=MySQL, 5432=PostgreSQL

Размеры:
  IPv4 адрес: 32 бита (4 байта)
  IPv6 адрес: 128 бит (16 байт)
  MAC адрес: 48 бит (6 байт)
  MTU Ethernet: 1500 байт
  MSS TCP: ~1460 байт (MTU - IP header - TCP header)
```

## Кодировки

```
ASCII: 7 бит, 128 символов (0-127)
Latin-1 (ISO-8859-1): 8 бит, 256 символов
Windows-1251: кириллица
UTF-8: переменная длина (1-4 байта)
  0xxxxxxx           — 1 байт (ASCII совместимо)
  110xxxxx 10xxxxxx  — 2 байта
  1110xxxx 10xxxxxx 10xxxxxx — 3 байта
  11110xxx 10xxxxxx 10xxxxxx 10xxxxxx — 4 байта

UTF-16: 2 или 4 байта
  BOM (Byte Order Mark): 0xFEFF (big-endian), 0xFFFE (little-endian)
UTF-32: всегда 4 байта

Правила:
- Всегда явно указывай кодировку при работе с файлами
- Внутреннее представление: UTF-8 или UTF-32
- В C: char = байт (не символ!), для Unicode: wchar_t или uint32_t
- В C++: std::u8string (C++20), std::u32string
- В Python: str всегда Unicode, bytes для бинарных данных
```

## Git

```bash
# Основные команды
git init / git clone url
git status / git diff / git log --oneline --graph
git add -p                   # интерактивное добавление
git commit -m "message"
git push origin branch
git pull --rebase origin main

# Ветки
git branch feature
git switch feature           # (новое) вместо checkout
git switch -c feature        # создать и переключиться
git merge feature
git rebase main              # перебазирование на main

# Отмена
git restore file.txt         # откатить файл
git restore --staged file    # убрать из staging
git reset --soft HEAD~1      # отменить коммит (сохранить изменения)
git reset --hard HEAD~1      # отменить коммит (удалить изменения!)
git revert HEAD              # создать обратный коммит

# Stash
git stash push -m "wip"
git stash pop
git stash list

# Интерактивный rebase
git rebase -i HEAD~3         # squash, edit, reorder последние 3 коммита

# .gitignore
build/
*.o
*.pyc
__pycache__/
.env
node_modules/
.vscode/
```
