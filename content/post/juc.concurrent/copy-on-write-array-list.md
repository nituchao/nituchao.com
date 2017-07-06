---
title: "CopyOnWriteArrayList源码分析"
date: "2017-02-23T18:25:27+08:00"
categories: ["Concurrent"]
tags: ["Java", "Concurrent"]
draft: false
---


## 概述
CopyOnWriteArrayList相当于线程安全的ArrayList。和ArrayList一样，它是个可变数组；但是和ArrayList不同的是，它具有以下特性：
1. 它最适合于具有以下特征的应用程序：List大小通常保持很小，只读操作远多于可变操作，需要在遍历期间防止线程间的冲突。
2. 它是线程安全的。它的线程安全表现在两个方面，修改时使用锁进行同步，读取时使用数据快照。
3. 因为通常要复制整个基础数组，所以可变操作（add()、set()和remove()等操作）的开销很大。
4. 迭代器支持hasNext()、next等不可变操作，但不支持可变remove()等操作。
5. 使用迭代器进行遍历的速度很快，并且不会与其他线程发生冲突。在构造迭代器时，迭代器依赖于不变的数组快照。



## CopyOnWriteArrayList原理和数据结构

CopyOnWriteArrayList的数据结构，如下图所示：

**CopyOnWriteArrayList UML图**


说明：
1. CopyOnWriteArrayList实现了List接口，因此可以认为它是一个有序的集合。
2. CopyOnWriteArrayList实现了RandomAccess接口，因此可以认为它的元素可以随机访问。
3. CopyOnWriteArrayList包含一个可重入锁Lock。每一个CopyOnWriteArrayList都和一个互斥锁lock绑定，通过lock，实现了对CopyOnWriteArrayList的互斥访问。
4. CopyOnWriteArrayList包含了成员array数组，这说明CopyOnWriteArrayList本质上通过数组实现的。而且，可存储的元素个数没有上限。

下面从"动态数组"和"线程安全"两个方面进一步对CopyOnWriteArrayList的原理进行说明。
1. **CopyOnWriteArrayList的"动态数组"机制** 

   它内部有个"volatile数组"(array)来保持数据。在"添加/修改/删除"数据时，都会新建一个数组，并将更新后的数据拷贝到新建的数组中，最后再将该数组赋值给"volatile数组"。这就是它叫做CopyOnWriteArrayList的原因！

   CopyOnWriteArrayList就是通过这种方式实现的动态数组；不过正由于它在"添加/修改/删除"数据时，都会新建数组，所以涉及到修改数据的操作，CopyOnWriteArrayList效率很低。但是单单只是进行遍历的话，效率比较高。

2. **CopyOnWriteArrayList的"线程安全"机制** 

 是通过volatile和互斥锁来实现的。
 a. CopyOnWriteArrayList是通过"volatile数组"来保存数据的。

 一个线程读取volatile数组时，总能看到其他线程对该volatile变量最后的写入。就这样，通过volatile提供了"读取到的数据总是最新的"这个机制的保证。
 b. CopyOnWriteArrayList通过互斥锁来保护数据。

 在"添加/修改/删除"数据时，会先"获取互斥锁"，在修改完毕后，先将数据更新到"volatile数组"中，然后再"释放互斥锁"；这样，就达到了保护数据的目的。



## CopyOnWriteArrayList成员变量

```java
/** 可重入锁，对数组进行添加/修改/删除操作时，通过lock来进行同步操作 */
transient final ReentrantLock lock = new ReentrantLock();

/** 数组，保存数据的地方。对数组array的操作都要通过getArray和setArray进行操作 */
private volatile transient Object[] array;
```



## CopyOnWriteArrayList函数列表

```java
// 创建一个空列表，默认大小为0。
CopyOnWriteArrayList()
// 创建一个按 collection 的迭代器返回元素的顺序包含指定 collection 元素的列表。
CopyOnWriteArrayList(Collection<? extends E> c)
// 创建一个保存给定数组的副本的列表。 
CopyOnWriteArrayList(E[] toCopyIn)
// 将指定元素添加到此列表的尾部。
boolean add(E e)
// 在此列表的指定位置上插入指定元素。
void add(int index, E element)
// 按照指定 collection 的迭代器返回元素的顺序，将指定 collection 中的所有元素添加此列表的尾部。
boolean addAll(Collection<? extends E> c)
// 从指定位置开始，将指定 collection 的所有元素插入此列表。
boolean addAll(int index, Collection<? extends E> c)
// 按照指定 collection 的迭代器返回元素的顺序，将指定 collection 中尚未包含在此列表中的所有元素添加列表的尾部。
int addAllAbsent(Collection<? extends E> c)
// 添加元素（如果不存在）。
boolean addIfAbsent(E e)
// 从此列表移除所有元素。
void clear()
// 返回此列表的浅表副本。
Object clone()
// 如果此列表包含指定的元素，则返回 true。
boolean contains(Object o)
// 如果此列表包含指定 collection 的所有元素，则返回 true。
boolean containsAll(Collection<?> c)
// 比较指定对象与此列表的相等性。
boolean equals(Object o)
// 返回列表中指定位置的元素。
E get(int index)
// 返回此列表的哈希码值。
int hashCode()
// 返回第一次出现的指定元素在此列表中的索引，从 index 开始向前搜索，如果没有找到该元素，则返回 -1。
int indexOf(E e, int index)
// 返回此列表中第一次出现的指定元素的索引；如果此列表不包含该元素，则返回 -1。
int indexOf(Object o)
// 如果此列表不包含任何元素，则返回 true。
boolean isEmpty()
// 返回以恰当顺序在此列表元素上进行迭代的迭代器。
Iterator<E> iterator()
// 返回最后一次出现的指定元素在此列表中的索引，从 index 开始向后搜索，如果没有找到该元素，则返回 -1。
int lastIndexOf(E e, int index)
// 返回此列表中最后出现的指定元素的索引；如果列表不包含此元素，则返回 -1。
int lastIndexOf(Object o)
// 返回此列表元素的列表迭代器（按适当顺序）。
ListIterator<E> listIterator()
// 返回列表中元素的列表迭代器（按适当顺序），从列表的指定位置开始。
ListIterator<E> listIterator(int index)
// 移除此列表指定位置上的元素。
E remove(int index)
// 从此列表移除第一次出现的指定元素（如果存在）。
boolean remove(Object o)
// 从此列表移除所有包含在指定 collection 中的元素。
boolean removeAll(Collection<?> c)
// 只保留此列表中包含在指定 collection 中的元素。
boolean retainAll(Collection<?> c)
// 用指定的元素替代此列表指定位置上的元素。
E set(int index, E element)
// 返回此列表中的元素数。
int size()
// 返回此列表中 fromIndex（包括）和 toIndex（不包括）之间部分的视图。
List<E> subList(int fromIndex, int toIndex)
// 返回一个按恰当顺序（从第一个元素到最后一个元素）包含此列表中所有元素的数组。
Object[] toArray()
// 返回以恰当顺序（从第一个元素到最后一个元素）包含列表所有元素的数组；
// 返回数组的运行时类型是指定数组的运行时类型。
<T> T[] toArray(T[] a)
// 返回此列表的字符串表示形式。
String toString()
```



## CopyOnWriteArrayList重点函数

### 构造函数

```
// 初始化一个大小为0的对象数组
public CopyOnWriteArrayList() {
    setArray(new Object[0]);
}

// 使用一个集合里的元素来初始化一个对象数组
public CopyOnWriteArrayList(Collection<? extends E> c) {
    Object[] elements = c.toArray();
    if (elements.getClass() != Object[].class)
        elements = Arrays.copyOf(elements, elements.length, Object[].class);
    setArray(elements);
}

// 使用一个数组里元素来初始化一个对象数组
public CopyOnWriteArrayList(E[] toCopyIn) {
    setArray(Arrays.copyOf(toCopyIn, toCopyIn.length, Object[].class));
}

final Object[] getArray() {
    return array;
}

final void setArray(Object[] a) {
    array = a;
}
```

CopyOnWriteArrayList的三个构造函数都调用了setArray()，将新创建的数组赋值给CopyOnWriteArrayList的成员变量array。



### 添加

#### 直接添加

以add(E e)为例来分析`CopyOnWriteArrayList`的添加操作。

```java
public boolean add(E e) {
    final ReentrantLock lock = this.lock;
    // 获取“锁”
    lock.lock();
    try {
        // 获取原始”volatile数组“中的数据和数据长度。
        Object[] elements = getArray();
        int len = elements.length;
        // 新建一个数组newElements，并将原始数据拷贝到newElements中；
        // newElements数组的长度=“原始数组的长度”+1
        Object[] newElements = Arrays.copyOf(elements, len + 1);
        // 将“新增加的元素”保存到newElements中。
        newElements[len] = e;
        // 将newElements赋值给”volatile数组“。
        setArray(newElements);
        return true;
    } finally {
        // 释放“锁”
        lock.unlock();
    }
}
```

**说明**：

add(E e)的作用就是将数据e添加到”volatile数组“中。它的实现方式是，新建一个数组，接着将原始的”volatile数组“的数据拷贝到新数组中，然后将新增数据也添加到新数组中；最后，将新数组赋值给”volatile数组“。

在add(E e)中有两点需要关注。

1. 在”添加操作“开始前，获取独占锁(lock)，若此时有需要线程要获取锁，则必须等待；在操作完毕后，释放独占锁(lock)，此时其它线程才能获取锁。通过独占锁，来防止多线程同时修改数据！lock的定义如下：

```java
transient final ReentrantLock lock = new ReentrantLock();
```

2. 操作完毕时，会通过setArray()来更新”volatile数组“。而且，前面我们提过”即对一个volatile变量的读，总是能看到（任意线程）对这个volatile变量最后的写入“；这样，每次添加元素之后，其它线程都能看到新添加的元素。


#### 不重复添加

由于CopyOnWriteArraySet是通过聚合了一个CopyOnWriteArrayList实现的，而CopyOnWriteArraySet是不包含重复元素的，因此CopyOnWriteArrayList提供了一个不添加重复元素的方法`addIfAbsent`，该方法每次从头遍历数组，如果发现元素已经存在，则直接返回false，如果遍历后待添加元素不存在，则添加到新数组的末尾，然后将新数组设置为成员数组。

```java
public boolean addIfAbsent(E e) {
        final ReentrantLock lock = this.lock;
        lock.lock();
        try {
            // Copy while checking if already present.
            // This wins in the most common case where it is not present
            Object[] elements = getArray();
            int len = elements.length;
            Object[] newElements = new Object[len + 1];
            for (int i = 0; i < len; ++i) {
                if (eq(e, elements[i]))
                    return false; // exit, throwing away copy
                else
                    newElements[i] = elements[i];
            }
            newElements[len] = e;
            setArray(newElements);
            return true;
        } finally {
            lock.unlock();
        }
    }
```

有在检查待添加元素是否已经存在时要从头遍历数组，因此随着元素个数递增，该方法的效率线性下降。



### 获取

以get(int index)为例，来对`CopyOnWriteArrayList`的删除操作进行说明。

```java
public E get(int index) {
    return get(getArray(), index);
}

private E get(Object[] a, int index) {
    return (E) a[index];
}
```

**说明:**

get(int index)的实现非常简单，就是返回"volatile数组"中的第index个元素。读取元素的过程不需要加锁，是读取时array的镜像。



### 删除

以remove(int index)为例，来说明`CopyOnWriteArrayList`的删除操作。

```java
public E remove(int index) {
    final ReentrantLock lock = this.lock;
    // 获取“锁”
    lock.lock();
    try {
        // 获取原始”volatile数组“中的数据和数据长度。
        Object[] elements = getArray();
        int len = elements.length;
        // 获取elements数组中的第index个数据。
        E oldValue = get(elements, index);
        int numMoved = len - index - 1;
        // 如果被删除的是最后一个元素，则直接通过Arrays.copyOf()进行处理，而不需要新建数组。
        // 否则，新建数组，然后将”volatile数组中被删除元素之外的其它元素“拷贝到新数组中。
        // 最后，将新数组赋值给”volatile数组“。
        if (numMoved == 0)
            setArray(Arrays.copyOf(elements, len - 1));
        else {
            Object[] newElements = new Object[len - 1];
            System.arraycopy(elements, 0, newElements, 0, index);
            System.arraycopy(elements, index + 1, newElements, index,
                             numMoved);
            setArray(newElements);
        }
        return oldValue;
    } finally {
        // 释放“锁”
        lock.unlock();
    }
}
```

**说明**：

remove(int index)的作用就是将”volatile数组“中第index个元素删除。

***它的实现方式是，如果被删除的是最后一个元素，则直接通过Arrays.copyOf()进行处理，而不需要新建数组。***否则，新建数组，然后将”volatile数组中被删除元素之外的其它元素“拷贝到新数组中。最后，将新数组赋值给”volatile数组“。
和add(E e)一样，remove(int index)也是”在操作之前，获取独占锁；操作完成之后，释放独占是“；并且”在操作完成时，会通过将数据更新到volatile数组中“。

remove操作没有检查index的合法性，有可能会抛出IndexOutOfBoundsExceptions



### 遍历

以`iterator()`为例，来说明`CopyOnWriteArrayList`的遍历操作。

```java
public Iterator<E> iterator() {
  return new COWIterator<E> (getArray(), 0);
}

private static class COWIterator<E> implements ListIterator<E> {
    private final Object[] snapshot;
    private int cursor;

    private COWIterator(Object[] elements, int initialCursor) {
        cursor = initialCursor;
        snapshot = elements;
    }

    public boolean hasNext() {
        return cursor < snapshot.length;
    }

    public boolean hasPrevious() {
        return cursor > 0;
    }

    // 获取下一个元素
    @SuppressWarnings("unchecked")
    public E next() {
        if (!hasNext())
            throw new NoSuchElementException();
        return (E) snapshot[cursor++];
    }

    // 获取上一个元素
    @SuppressWarnings("unchecked")
    public E previous() {
        if (!hasPrevious())
            throw new NoSuchElementException();
        return (E) snapshot[--cursor];
    }

    public int nextIndex() {
        return cursor;
    }

    public int previousIndex() {
        return cursor-1;
    }

    public void remove() {
        throw new UnsupportedOperationException();
    }

    public void set(E e) {
        throw new UnsupportedOperationException();
    }

    public void add(E e) {
        throw new UnsupportedOperationException();
    }
}
```

**说明**：



COWIterator不支持修改元素的操作。例如，对于`remove()`,`set()`,`add()`等操作，`COWIterator`都会抛出异常！
另外，需要提到的一点是，CopyOnWriteArrayList返回迭代器不会抛出`ConcurrentModificationException`异常，即它不是fail-fast机制的！



参考：

[Java多线程系列之CopyOnWriteArrayList](http://www.cnblogs.com/skywang12345/p/3498483.html)