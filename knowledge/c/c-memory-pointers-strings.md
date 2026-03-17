---
source: C Memory & Pointers
language: c
category: reference
---

# C — Управление памятью и указатели

## malloc / calloc / realloc / free

```c
#include <stdlib.h>

// malloc — неинициализированная память
int *arr = (int *)malloc(100 * sizeof(int));
if (arr == NULL) { /* обработка ошибки */ }

// calloc — инициализация нулями
int *arr2 = (int *)calloc(100, sizeof(int));

// realloc — изменение размера (может переместить блок!)
int *tmp = (int *)realloc(arr, 200 * sizeof(int));
if (tmp == NULL) {
    free(arr); // ВАЖНО: arr всё ещё валиден если realloc вернул NULL
} else {
    arr = tmp;  // arr может измениться!
}

// free — освобождение
free(arr);
arr = NULL;  // ВСЕГДА обнулять после free
```

## Частые ошибки с памятью

```c
// ❌ Use after free
free(ptr);
ptr->field = 5;  // UNDEFINED BEHAVIOR

// ❌ Double free
free(ptr);
free(ptr);  // UNDEFINED BEHAVIOR

// ❌ Утечка при realloc
ptr = realloc(ptr, new_size);  // если NULL — утечка старого ptr

// ❌ Чтение неинициализированной памяти (malloc)
int *p = malloc(sizeof(int));
printf("%d", *p);  // UB — мусор

// ✅ Правильный паттерн realloc
void *tmp = realloc(ptr, new_size);
if (tmp) { ptr = tmp; } else { /* ошибка, ptr по-прежнему валиден */ }
```

## Указатели — основы

```c
int x = 42;
int *p = &x;       // p хранит адрес x
int val = *p;       // val = 42 (разыменование)
*p = 100;           // x теперь 100

// Указатель на указатель
int **pp = &p;
**pp = 200;         // x теперь 200

// Указатель на функцию
int (*func_ptr)(int, int) = &add;
int result = func_ptr(2, 3);

// typedef для указателей на функции
typedef int (*BinaryOp)(int, int);
BinaryOp op = &add;

// Массив указателей на функции
BinaryOp ops[] = {&add, &sub, &mul};
ops[0](2, 3);  // вызов add

// void* — универсальный указатель
void *generic = malloc(100);
int *ip = (int *)generic;
// Нельзя разыменовывать void* напрямую
// Нельзя делать арифметику с void* (не стандарт)

// const и указатели
const int *p1;        // указатель на const int (значение нельзя менять)
int *const p2 = &x;   // const указатель (адрес нельзя менять)
const int *const p3 = &x; // оба нельзя
```

## Арифметика указателей

```c
int arr[5] = {10, 20, 30, 40, 50};
int *p = arr;       // p указывает на arr[0]

p + 1;              // адрес arr[1] (сдвиг на sizeof(int))
*(p + 2);           // значение arr[2] = 30
p[3];               // то же что *(p + 3) = 40

// Разность указателей
ptrdiff_t diff = &arr[4] - &arr[1];  // 3 (элемента, не байта!)

// ВАЖНО: арифметика только в пределах одного массива
// Сравнение указателей на разные объекты — UB (кроме == и !=)
```

## Динамические массивы (growable array)

```c
typedef struct {
    int *data;
    size_t size;
    size_t capacity;
} DynArray;

DynArray da_create(size_t initial_cap) {
    DynArray da = {
        .data = malloc(initial_cap * sizeof(int)),
        .size = 0,
        .capacity = initial_cap
    };
    return da;
}

int da_push(DynArray *da, int value) {
    if (da->size >= da->capacity) {
        size_t new_cap = da->capacity * 2;
        int *tmp = realloc(da->data, new_cap * sizeof(int));
        if (!tmp) return -1;  // ошибка
        da->data = tmp;
        da->capacity = new_cap;
    }
    da->data[da->size++] = value;
    return 0;
}

void da_free(DynArray *da) {
    free(da->data);
    da->data = NULL;
    da->size = da->capacity = 0;
}
```

## Строки в C

```c
#include <string.h>

// strlen — длина без '\0'
size_t len = strlen("hello");  // 5

// strcpy / strncpy
char dest[20];
strcpy(dest, "hello");          // ОПАСНО если dest мал
strncpy(dest, "hello", sizeof(dest) - 1);
dest[sizeof(dest) - 1] = '\0'; // strncpy НЕ гарантирует '\0'!

// strlcpy (BSD/POSIX, безопаснее) — если доступна
// size_t strlcpy(char *dst, const char *src, size_t size);

// strcat / strncat
strcat(dest, " world");        // ОПАСНО — переполнение
strncat(dest, " world", sizeof(dest) - strlen(dest) - 1);

// strcmp
if (strcmp(s1, s2) == 0) { /* равны */ }
// strncmp — сравнение первых n символов

// snprintf — БЕЗОПАСНОЕ форматирование
char buf[256];
int n = snprintf(buf, sizeof(buf), "Name: %s, Age: %d", name, age);
// n = кол-во символов, которое БЫЛО БЫ записано (без '\0')
// если n >= sizeof(buf) — строка обрезана

// memcpy / memmove
memcpy(dest, src, n);    // НЕ для перекрывающихся областей
memmove(dest, src, n);   // безопасно для перекрытия

// memset
memset(buf, 0, sizeof(buf));  // заполнить нулями

// strchr / strrchr / strstr
char *p = strchr(str, 'x');    // первое вхождение символа
char *p2 = strrchr(str, 'x'); // последнее вхождение
char *p3 = strstr(str, "sub"); // подстрока

// strtok — ИЗМЕНЯЕТ строку, не потокобезопасна
char str[] = "a,b,c";
char *tok = strtok(str, ",");   // "a"
tok = strtok(NULL, ",");        // "b"
// strtok_r — потокобезопасная версия (POSIX)
```

## Файловый ввод-вывод

```c
#include <stdio.h>

// Открытие
FILE *f = fopen("file.txt", "r");  // "r", "w", "a", "rb", "wb", "r+"
if (!f) { perror("fopen"); return -1; }

// Чтение
char buf[256];
while (fgets(buf, sizeof(buf), f)) {  // безопасно, с '\n'
    // обработка строки
}

// fscanf
int val;
fscanf(f, "%d", &val);

// fread / fwrite — бинарный ввод-вывод
size_t nread = fread(buf, 1, sizeof(buf), f);
size_t nwritten = fwrite(buf, 1, nread, f);

// Позиционирование
fseek(f, 0, SEEK_SET);   // начало файла
fseek(f, 0, SEEK_END);   // конец
long pos = ftell(f);       // текущая позиция
rewind(f);                 // = fseek(f, 0, SEEK_SET)

// ВСЕГДА закрывать
fclose(f);

// Размер файла
fseek(f, 0, SEEK_END);
long size = ftell(f);
fseek(f, 0, SEEK_SET);  // вернуться в начало
```

## Структуры и выравнивание

```c
struct Point {
    int x;
    int y;
};

// Инициализация (C99+)
struct Point p = {.x = 10, .y = 20};

// typedef
typedef struct {
    char name[64];
    int age;
} Person;

// Гибкий член массива (C99)
typedef struct {
    size_t len;
    char data[];  // ДОЛЖЕН быть последним
} Buffer;

Buffer *buf = malloc(sizeof(Buffer) + 100);
buf->len = 100;

// offsetof — смещение поля
#include <stddef.h>
size_t off = offsetof(Person, age);

// Выравнивание: компилятор добавляет padding
struct Bad {     // 12 байт (с padding)
    char a;      // 1 байт + 3 padding
    int b;       // 4 байта
    char c;      // 1 байт + 3 padding
};
struct Good {    // 8 байт (без лишнего padding)
    int b;       // 4 байта
    char a;      // 1 байт
    char c;      // 1 байт + 2 padding
};
```

## Препроцессор

```c
// Включение заголовков
#include <stdio.h>    // системный
#include "myheader.h" // локальный

// Защита от повторного включения
#ifndef MY_HEADER_H
#define MY_HEADER_H
// содержимое
#endif

// Или (нестандартно, но поддерживается везде)
#pragma once

// Макросы
#define MAX(a, b) ((a) > (b) ? (a) : (b))  // СКОБКИ ОБЯЗАТЕЛЬНЫ
#define ARRAY_SIZE(arr) (sizeof(arr) / sizeof((arr)[0]))

// Многострочный макрос
#define SWAP(a, b) do { \
    typeof(a) _tmp = (a); \
    (a) = (b);            \
    (b) = _tmp;           \
} while (0)

// Строкификация и конкатенация
#define STR(x) #x          // STR(hello) -> "hello"
#define CONCAT(a, b) a##b  // CONCAT(foo, bar) -> foobar

// Условная компиляция
#ifdef DEBUG
    #define LOG(fmt, ...) fprintf(stderr, fmt "\n", ##__VA_ARGS__)
#else
    #define LOG(fmt, ...) ((void)0)
#endif

// _Generic (C11) — аналог перегрузки
#define print_val(x) _Generic((x), \
    int: printf("%d\n", x),        \
    float: printf("%f\n", x),      \
    char*: printf("%s\n", x)       \
)
```
