---
source: Algorithms & Data Structures
language:
category: algorithm
---

# Алгоритмы и структуры данных

## Сложность алгоритмов (Big-O)

```
O(1)       — константная: хеш-таблица lookup, доступ по индексу
O(log n)   — логарифмическая: бинарный поиск, сбалансированные деревья
O(n)       — линейная: линейный поиск, обход массива
O(n log n) — линейно-логарифмическая: merge sort, heap sort, quick sort (avg)
O(n²)      — квадратичная: bubble sort, selection sort, вложенные циклы
O(n³)      — кубическая: наивное умножение матриц, Floyd-Warshall
O(2^n)     — экспоненциальная: полный перебор подмножеств
O(n!)      — факториальная: полный перебор перестановок

Правила:
- Убирай константы: O(2n) = O(n)
- Убирай младшие слагаемые: O(n² + n) = O(n²)
- Вложенные циклы перемножаются: O(n) × O(m) = O(n·m)
- Последовательные операции складываются: O(n) + O(m) = O(n + m)
```

## Сортировки

```python
# Quick Sort — O(n log n) avg, O(n²) worst, in-place, не стабильная
def quicksort(arr, lo=0, hi=None):
    if hi is None: hi = len(arr) - 1
    if lo >= hi: return
    pivot = arr[hi]
    i = lo
    for j in range(lo, hi):
        if arr[j] <= pivot:
            arr[i], arr[j] = arr[j], arr[i]
            i += 1
    arr[i], arr[hi] = arr[hi], arr[i]
    quicksort(arr, lo, i - 1)
    quicksort(arr, i + 1, hi)
```

```python
# Merge Sort — O(n log n) всегда, стабильная, O(n) память
def merge_sort(arr):
    if len(arr) <= 1: return arr
    mid = len(arr) // 2
    left = merge_sort(arr[:mid])
    right = merge_sort(arr[mid:])
    return merge(left, right)

def merge(a, b):
    result = []
    i = j = 0
    while i < len(a) and j < len(b):
        if a[i] <= b[j]:
            result.append(a[i]); i += 1
        else:
            result.append(b[j]); j += 1
    result.extend(a[i:])
    result.extend(b[j:])
    return result
```

```c
// Heap Sort — O(n log n) всегда, in-place, не стабильная
void heapify(int arr[], int n, int i) {
    int largest = i;
    int left = 2 * i + 1, right = 2 * i + 2;
    if (left < n && arr[left] > arr[largest]) largest = left;
    if (right < n && arr[right] > arr[largest]) largest = right;
    if (largest != i) {
        int tmp = arr[i]; arr[i] = arr[largest]; arr[largest] = tmp;
        heapify(arr, n, largest);
    }
}
void heap_sort(int arr[], int n) {
    for (int i = n / 2 - 1; i >= 0; i--) heapify(arr, n, i);
    for (int i = n - 1; i > 0; i--) {
        int tmp = arr[0]; arr[0] = arr[i]; arr[i] = tmp;
        heapify(arr, i, 0);
    }
}
```

```
Сравнение сортировок:
Алгоритм       | Best     | Avg      | Worst    | Память | Стабильная
Quick Sort      | O(n lg n)| O(n lg n)| O(n²)   | O(lg n)| Нет
Merge Sort      | O(n lg n)| O(n lg n)| O(n lg n)| O(n)   | Да
Heap Sort       | O(n lg n)| O(n lg n)| O(n lg n)| O(1)   | Нет
Insertion Sort  | O(n)     | O(n²)   | O(n²)    | O(1)   | Да
Tim Sort        | O(n)     | O(n lg n)| O(n lg n)| O(n)   | Да
Counting Sort   | O(n+k)  | O(n+k)  | O(n+k)   | O(k)   | Да
Radix Sort      | O(d·n)  | O(d·n)  | O(d·n)   | O(n+k) | Да
```

## Поиск

```python
# Бинарный поиск — O(log n), массив ОТСОРТИРОВАН
def binary_search(arr, target):
    lo, hi = 0, len(arr) - 1
    while lo <= hi:
        mid = lo + (hi - lo) // 2  # избежать overflow
        if arr[mid] == target:
            return mid
        elif arr[mid] < target:
            lo = mid + 1
        else:
            hi = mid - 1
    return -1

# bisect — стандартная библиотека Python
import bisect
bisect.bisect_left(arr, x)   # индекс для вставки (первая позиция)
bisect.bisect_right(arr, x)  # индекс для вставки (после дубликатов)
bisect.insort(arr, x)        # вставка с сохранением сортировки

# Бинарный поиск по ответу (шаблон)
def can_solve(param, limit):
    """Можно ли решить задачу с данным param?"""
    ...

lo, hi = min_possible, max_possible
while lo < hi:
    mid = lo + (hi - lo) // 2
    if can_solve(mid, limit):
        hi = mid       # ищем минимальный param
    else:
        lo = mid + 1
answer = lo
```

## Графы

```python
from collections import defaultdict, deque
import heapq

# Представление графа
graph = defaultdict(list)  # список смежности
graph[u].append((v, weight))

# BFS — поиск в ширину — O(V + E)
def bfs(graph, start):
    visited = {start}
    queue = deque([start])
    order = []
    while queue:
        node = queue.popleft()
        order.append(node)
        for neighbor in graph[node]:
            if neighbor not in visited:
                visited.add(neighbor)
                queue.append(neighbor)
    return order

# BFS — кратчайший путь (невзвешенный граф)
def shortest_path(graph, start, end):
    queue = deque([(start, [start])])
    visited = {start}
    while queue:
        node, path = queue.popleft()
        if node == end:
            return path
        for neighbor in graph[node]:
            if neighbor not in visited:
                visited.add(neighbor)
                queue.append((neighbor, path + [neighbor]))
    return None

# DFS — поиск в глубину — O(V + E)
def dfs(graph, start):
    visited = set()
    order = []
    def _dfs(node):
        visited.add(node)
        order.append(node)
        for neighbor in graph[node]:
            if neighbor not in visited:
                _dfs(neighbor)
    _dfs(start)
    return order

# Dijkstra — кратчайший путь (взвешенный, неотрицательные веса) — O((V+E) log V)
def dijkstra(graph, start):
    dist = {start: 0}
    heap = [(0, start)]
    while heap:
        d, u = heapq.heappop(heap)
        if d > dist.get(u, float('inf')):
            continue
        for v, w in graph[u]:
            nd = d + w
            if nd < dist.get(v, float('inf')):
                dist[v] = nd
                heapq.heappush(heap, (nd, v))
    return dist

# Топологическая сортировка — O(V + E)
# Для DAG (ориентированный ациклический граф)
def topo_sort(graph, num_nodes):
    in_degree = [0] * num_nodes
    for u in graph:
        for v in graph[u]:
            in_degree[v] += 1
    queue = deque(v for v in range(num_nodes) if in_degree[v] == 0)
    order = []
    while queue:
        u = queue.popleft()
        order.append(u)
        for v in graph[u]:
            in_degree[v] -= 1
            if in_degree[v] == 0:
                queue.append(v)
    return order if len(order) == num_nodes else None  # None = цикл

# Union-Find (Disjoint Set) — для компонент связности
class UnionFind:
    def __init__(self, n):
        self.parent = list(range(n))
        self.rank = [0] * n

    def find(self, x):
        if self.parent[x] != x:
            self.parent[x] = self.find(self.parent[x])  # сжатие пути
        return self.parent[x]

    def union(self, x, y):
        px, py = self.find(x), self.find(y)
        if px == py: return False
        if self.rank[px] < self.rank[py]: px, py = py, px
        self.parent[py] = px
        if self.rank[px] == self.rank[py]: self.rank[px] += 1
        return True
```

## Динамическое программирование

```python
# Шаблон DP:
# 1. Определить состояние: dp[i] = что?
# 2. Определить переход: dp[i] = f(dp[j], ...)
# 3. Базовый случай: dp[0] = ?
# 4. Порядок вычисления: снизу вверх или мемоизация

# Рюкзак 0/1 — O(n·W)
def knapsack(weights, values, capacity):
    n = len(weights)
    dp = [[0] * (capacity + 1) for _ in range(n + 1)]
    for i in range(1, n + 1):
        for w in range(capacity + 1):
            dp[i][w] = dp[i-1][w]  # не берём предмет
            if weights[i-1] <= w:
                dp[i][w] = max(dp[i][w],
                    dp[i-1][w - weights[i-1]] + values[i-1])
    return dp[n][capacity]

# Оптимизация памяти (одномерный dp)
def knapsack_opt(weights, values, capacity):
    dp = [0] * (capacity + 1)
    for i in range(len(weights)):
        for w in range(capacity, weights[i] - 1, -1):  # ОБРАТНЫЙ порядок!
            dp[w] = max(dp[w], dp[w - weights[i]] + values[i])
    return dp[capacity]

# Longest Common Subsequence — O(n·m)
def lcs(s1, s2):
    n, m = len(s1), len(s2)
    dp = [[0] * (m + 1) for _ in range(n + 1)]
    for i in range(1, n + 1):
        for j in range(1, m + 1):
            if s1[i-1] == s2[j-1]:
                dp[i][j] = dp[i-1][j-1] + 1
            else:
                dp[i][j] = max(dp[i-1][j], dp[i][j-1])
    return dp[n][m]

# Мемоизация (сверху вниз)
from functools import lru_cache

@lru_cache(maxsize=None)
def fib(n):
    if n < 2: return n
    return fib(n - 1) + fib(n - 2)

# Для классов и изменяемых аргументов
import functools
def memoize(func):
    cache = {}
    @functools.wraps(func)
    def wrapper(*args):
        if args not in cache:
            cache[args] = func(*args)
        return cache[args]
    return wrapper
```

## Деревья

```python
# Бинарное дерево поиска
class TreeNode:
    def __init__(self, val, left=None, right=None):
        self.val = val
        self.left = left
        self.right = right

# Обходы
def inorder(node):    # левый, корень, правый — отсортированный порядок
    if not node: return
    yield from inorder(node.left)
    yield node.val
    yield from inorder(node.right)

def preorder(node):   # корень, левый, правый
    if not node: return
    yield node.val
    yield from preorder(node.left)
    yield from preorder(node.right)

def level_order(root):  # BFS по уровням
    if not root: return []
    result, queue = [], deque([root])
    while queue:
        level = []
        for _ in range(len(queue)):
            node = queue.popleft()
            level.append(node.val)
            if node.left: queue.append(node.left)
            if node.right: queue.append(node.right)
        result.append(level)
    return result

# Trie (префиксное дерево) — для строк
class TrieNode:
    def __init__(self):
        self.children = {}
        self.is_end = False

class Trie:
    def __init__(self):
        self.root = TrieNode()

    def insert(self, word):
        node = self.root
        for ch in word:
            if ch not in node.children:
                node.children[ch] = TrieNode()
            node = node.children[ch]
        node.is_end = True

    def search(self, word):
        node = self._find(word)
        return node is not None and node.is_end

    def starts_with(self, prefix):
        return self._find(prefix) is not None

    def _find(self, prefix):
        node = self.root
        for ch in prefix:
            if ch not in node.children: return None
            node = node.children[ch]
        return node
```

## Хеширование и вероятностные структуры

```python
# Bloom Filter — проверка принадлежности (может давать false positive)
import mmh3  # murmurhash3

class BloomFilter:
    def __init__(self, size, num_hashes):
        self.size = size
        self.num_hashes = num_hashes
        self.bits = [False] * size

    def add(self, item):
        for i in range(self.num_hashes):
            idx = mmh3.hash(str(item), i) % self.size
            self.bits[idx] = True

    def might_contain(self, item):
        return all(
            self.bits[mmh3.hash(str(item), i) % self.size]
            for i in range(self.num_hashes)
        )

# Rolling hash (Rabin-Karp) — поиск подстроки O(n+m)
def rabin_karp(text, pattern):
    base, mod = 256, 10**9 + 7
    n, m = len(text), len(pattern)
    if m > n: return -1
    
    p_hash = t_hash = 0
    power = pow(base, m - 1, mod)
    
    for i in range(m):
        p_hash = (p_hash * base + ord(pattern[i])) % mod
        t_hash = (t_hash * base + ord(text[i])) % mod
    
    for i in range(n - m + 1):
        if p_hash == t_hash and text[i:i+m] == pattern:
            return i
        if i + m < n:
            t_hash = (t_hash - ord(text[i]) * power) * base + ord(text[i + m])
            t_hash %= mod
    return -1
```
