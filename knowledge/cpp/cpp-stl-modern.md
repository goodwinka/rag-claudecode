---
source: C++ Modern Reference
language: cpp
category: reference
---

# C++ — STL контейнеры и итераторы

## Последовательные контейнеры

```cpp
#include <vector>
#include <deque>
#include <list>
#include <forward_list>
#include <array>
#include <string>

// vector — динамический массив (основной выбор)
std::vector<int> v = {1, 2, 3};
v.push_back(4);
v.emplace_back(5);           // конструирует на месте (эффективнее)
v.insert(v.begin() + 1, 10); // вставка по позиции — O(n)!
v.erase(v.begin() + 1);      // удаление — O(n)!
v.reserve(100);               // выделить память заранее
v.shrink_to_fit();            // освободить лишнюю память
v.resize(10, 0);              // изменить размер
v.data();                     // указатель на массив (C совместимость)
// Инвалидация итераторов: push_back, insert, erase, resize, reserve

// deque — двусторонняя очередь
std::deque<int> dq;
dq.push_front(1);  // O(1)
dq.push_back(2);   // O(1)
dq.pop_front();    // O(1)
// Быстрый random access, но элементы не в непрерывной памяти

// list — двусвязный список
std::list<int> lst = {3, 1, 4, 1, 5};
lst.sort();           // собственная сортировка (merge sort) — O(n log n)
lst.unique();         // удаляет смежные дубликаты (после sort!)
lst.merge(other);     // слияние двух отсортированных списков
lst.splice(pos, other); // перемещение элементов — O(1)
// Вставка/удаление O(1), но нет random access

// array — фиксированный размер, на стеке
std::array<int, 5> arr = {1, 2, 3, 4, 5};
arr.size();       // constexpr — известен в compile time
arr.fill(0);
```

## Ассоциативные контейнеры

```cpp
#include <map>
#include <set>
#include <unordered_map>
#include <unordered_set>

// map — отсортированный (красно-чёрное дерево)
std::map<std::string, int> m;
m["key"] = 42;                // создаёт элемент если нет!
m.insert({"key2", 100});      // не перезаписывает
m.insert_or_assign("key", 50); // C++17 — перезаписывает
m.emplace("key3", 200);

// Поиск (НЕ используй operator[] для проверки!)
auto it = m.find("key");
if (it != m.end()) {
    std::cout << it->second;
}
m.contains("key");  // C++20 — проще

// try_emplace (C++17) — не двигает аргументы если ключ есть
m.try_emplace("key4", "expensive_value");

// unordered_map — хеш-таблица, O(1) поиск
std::unordered_map<std::string, int> um;
// Требует: std::hash<Key> и operator==
// Пользовательский хеш:
struct MyHash {
    size_t operator()(const MyType &t) const { /*...*/ }
};
std::unordered_map<MyType, int, MyHash> custom;

// set — множество уникальных элементов
std::set<int> s = {3, 1, 4, 1, 5};  // {1, 3, 4, 5}
s.insert(2);
auto [it, inserted] = s.insert(3);  // structured bindings C++17
s.count(3);    // 0 или 1
s.contains(3); // C++20

// multimap / multiset — допускают дубликаты ключей
std::multimap<std::string, int> mm;
mm.insert({"a", 1});
mm.insert({"a", 2});  // оба сохранятся
auto range = mm.equal_range("a");  // итераторы [begin, end)
```

## Умные указатели

```cpp
#include <memory>

// unique_ptr — эксклюзивное владение (ОСНОВНОЙ ВЫБОР)
auto ptr = std::make_unique<MyClass>(args...);
ptr->method();
MyClass *raw = ptr.get();       // сырой указатель (не владеет)
MyClass *released = ptr.release(); // передать владение (вы обязаны удалить)
ptr.reset();                    // удалить объект
ptr.reset(new MyClass());       // заменить объект

// Перемещение (нельзя копировать!)
auto ptr2 = std::move(ptr);    // ptr теперь nullptr

// unique_ptr для массивов
auto arr = std::make_unique<int[]>(100);
arr[0] = 42;

// Кастомный deleter
auto file = std::unique_ptr<FILE, decltype(&fclose)>(
    fopen("f.txt", "r"), &fclose
);

// shared_ptr — разделяемое владение (с подсчётом ссылок)
auto sp = std::make_shared<MyClass>(args...);
auto sp2 = sp;                  // ref_count = 2
sp.use_count();                 // 2
sp.reset();                     // ref_count = 1
// Объект удалится когда use_count == 0

// ⚠️ ЦИКЛИЧЕСКИЕ ССЫЛКИ — утечка!
struct Node {
    std::shared_ptr<Node> next;  // ❌ цикл = утечка
};

// weak_ptr — разрывает циклы
struct Node {
    std::weak_ptr<Node> parent;  // ✅ не увеличивает счётчик
    std::shared_ptr<Node> child;
};
// Использование weak_ptr:
if (auto locked = wp.lock()) {  // -> shared_ptr или nullptr
    locked->method();
}
wp.expired();  // true если объект удалён

// ⚠️ НЕ создавать shared_ptr из сырого указателя дважды!
MyClass *raw = new MyClass();
std::shared_ptr<MyClass> sp1(raw);
std::shared_ptr<MyClass> sp2(raw);  // ❌ double free!
// Используйте enable_shared_from_this
```

## Move-семантика и perfect forwarding

```cpp
// rvalue reference
std::string a = "hello";
std::string b = std::move(a);  // a теперь в "moved-from" состоянии
// a ВАЛИДЕН, но содержимое не определено (обычно пуст)

// Move конструктор и оператор
class Buffer {
    int *data_;
    size_t size_;
public:
    // Move конструктор
    Buffer(Buffer &&other) noexcept
        : data_(other.data_), size_(other.size_) {
        other.data_ = nullptr;
        other.size_ = 0;
    }
    // Move оператор присваивания
    Buffer &operator=(Buffer &&other) noexcept {
        if (this != &other) {
            delete[] data_;
            data_ = other.data_;
            size_ = other.size_;
            other.data_ = nullptr;
            other.size_ = 0;
        }
        return *this;
    }
};

// Perfect forwarding
template<typename T, typename... Args>
std::unique_ptr<T> make(Args&&... args) {
    return std::unique_ptr<T>(new T(std::forward<Args>(args)...));
}
```

## Многопоточность (C++11/14/17/20)

```cpp
#include <thread>
#include <mutex>
#include <condition_variable>
#include <future>
#include <atomic>

// Потоки
std::thread t([]{ /* работа */ });
t.join();   // ждать
t.detach(); // отсоединить (ОСТОРОЖНО!)
// Если не join и не detach — std::terminate!

// Мьютексы
std::mutex mtx;
{
    std::lock_guard<std::mutex> lock(mtx);  // RAII блокировка
    // критическая секция
}  // автоматическая разблокировка

std::unique_lock<std::mutex> ulock(mtx);  // гибче: defer, try, timed
ulock.unlock();
ulock.lock();

// Для нескольких мьютексов (избежание deadlock)
std::scoped_lock lock(mtx1, mtx2);  // C++17

// Условные переменные
std::condition_variable cv;
std::unique_lock<std::mutex> lk(mtx);
cv.wait(lk, []{ return ready; });  // ждёт пока ready==true
// В другом потоке:
{
    std::lock_guard<std::mutex> lg(mtx);
    ready = true;
}
cv.notify_one();

// async / future
auto future = std::async(std::launch::async, []{
    return expensive_computation();
});
int result = future.get();  // блокирует до готовности

// atomic
std::atomic<int> counter{0};
counter.fetch_add(1);
counter.store(42);
int val = counter.load();

// shared_mutex (C++17) — read/write lock
#include <shared_mutex>
std::shared_mutex rw;
{
    std::shared_lock lock(rw);  // чтение (множество)
}
{
    std::unique_lock lock(rw);  // запись (эксклюзивно)
}
```

## Строки и string_view

```cpp
#include <string>
#include <string_view>  // C++17

std::string s = "hello";
s += " world";
s.substr(0, 5);        // "hello" (КОПИЯ!)
s.find("world");       // 6 (npos если не найдено)
s.starts_with("hel");  // C++20
s.ends_with("ld");     // C++20
s.contains("llo");     // C++23

// string_view — НЕ владеющий (без копирования)
std::string_view sv = s;  // O(1)
sv.substr(0, 5);           // O(1) — тоже string_view
// ⚠️ Не используй string_view дольше чем живёт строка!
// ⚠️ string_view может указывать на невалидную память

// Конвертация строк <-> числа
int n = std::stoi("42");
double d = std::stod("3.14");
std::string ns = std::to_string(42);

// C++17 from_chars / to_chars (без аллокаций, быстрее)
#include <charconv>
int value;
auto [ptr, ec] = std::from_chars(sv.data(), sv.data() + sv.size(), value);
if (ec == std::errc{}) { /* успех */ }
```

## Concepts и Ranges (C++20)

```cpp
#include <concepts>
#include <ranges>

// Concepts
template<typename T>
concept Numeric = std::integral<T> || std::floating_point<T>;

template<Numeric T>
T add(T a, T b) { return a + b; }

// Ranges
#include <algorithm>
#include <ranges>
namespace rv = std::ranges::views;

std::vector<int> v = {5, 3, 1, 4, 2, 8, 7, 6};

// Пайплайны (ленивые вычисления)
auto result = v
    | rv::filter([](int x) { return x > 3; })
    | rv::transform([](int x) { return x * 2; })
    | rv::take(3);

// Собрать в контейнер
std::vector<int> out(result.begin(), result.end());
// C++23: auto out = result | std::ranges::to<std::vector>();

// Алгоритмы с ranges
std::ranges::sort(v);
auto it = std::ranges::find(v, 42);
bool all_pos = std::ranges::all_of(v, [](int x) { return x > 0; });
```

## std::optional, std::variant, std::any (C++17)

```cpp
#include <optional>
#include <variant>

// optional — может содержать или нет значение
std::optional<int> find(const std::string &key) {
    if (/*found*/) return 42;
    return std::nullopt;
}
auto val = find("key");
if (val) { use(*val); }
int x = val.value_or(0);  // значение по умолчанию

// variant — типобезопасный union
std::variant<int, double, std::string> v;
v = 42;
v = "hello"s;
// Доступ:
if (std::holds_alternative<int>(v)) {
    int i = std::get<int>(v);
}
// visit — паттерн visitor
std::visit([](auto &val) { std::cout << val; }, v);

// Overloaded pattern для visit
template<class... Ts> struct overloaded : Ts... { using Ts::operator()...; };
std::visit(overloaded{
    [](int i)    { std::cout << "int: " << i; },
    [](double d) { std::cout << "dbl: " << d; },
    [](const std::string &s) { std::cout << "str: " << s; },
}, v);

// std::expected (C++23) — результат или ошибка
#include <expected>
std::expected<int, std::string> parse(const std::string &s) {
    try { return std::stoi(s); }
    catch (...) { return std::unexpected("parse error"); }
}
```
