---
title: "CopyOnWriteArraySet源码分析"
date: "2017-02-23T18:25:27+08:00"
categories: ["Concurrent"]
tags: ["Java", "Concurrent"]
draft: false
---

## 一句话

`CopyOnWriteArraySet`是线程安全的无序集合，它是通过聚合了一个`CopyOnWriteArray`成员变量来实现的。



## 概要

`CopyOnWriteArraySet`是线程安全的无序集合，可以将它理解成线程安全的HashSet。有意思的是，`CopyOnWriteArraySet`和HashSet虽然都继承于共同的父类AbstractSet；但是，HashSet是通过"散列表(HashSet)"实现的，而CopyConWriteArraySet则是通过"动态数组(CopyOnWriteArrayList)"实现的，并不是散列表。



`CopyOnWriteArraySet`具有以下特性：

1. 它最适合于具有以下特征的应用程序：Set 大小通常保持很小，只读操作远多于可变操作，需要在遍历期间防止线程间的冲突。
2. 它是线程安全的。它的线程安全通过volatile、互斥锁来实现。
3. 因为通常需要复制整个基础数组，所以可变操作（add()、set() 和 remove() 等等）的开销很大。
4. 迭代器支持hasNext(), next()等不可变操作，但不支持可变 remove()等 操作。
5. 使用迭代器进行遍历的速度很快，并且不会与其他线程发生冲突。在构造迭代器时，迭代器依赖于不变的数组快照。



## CopyOnWriteArraySet原理

CopyOnWriteArraySet的数据结构，如下图所示：

`图`



**说明**

1. CopyOnWriteArraySet继承于AbstractSet，这就意味着它是一个集合。
2. CopyOnWriteArraySet聚合了一个CopyOnWriteArrayList对象，它是通过CopyOnWriteArrayList实现的。而CopyOnWriteArrayList本质是个动态数组队列，所以CopyOnWriteArraySet相当于通过动态数组实现的"集合"！
3. CopyOnWriteArraySet不允许有重复元素。因此，CopyOnWriteArrayList额外提供了addIfAbsent()和addAllAbsent()这两个添加元素的API，通过这些API来添加元素时，只有当元素不存在时才执行添加操作。
4. CopyOnWriteArraySet的"线程安全"机制是通过volatile和互斥锁来实现的。而它本身没有volatile变量和互斥锁，都是借由CopyOnWriteArrayList实现。



## CopyOnWriteArraySet函数列表

```java
// 创建一个空 set。
CopyOnWriteArraySet()
// 创建一个包含指定 collection 所有元素的 set。
CopyOnWriteArraySet(Collection<? extends E> c)

// 如果指定元素并不存在于此 set 中，则添加它。
boolean add(E e)
// 如果此 set 中没有指定 collection 中的所有元素，则将它们都添加到此 set 中。
boolean addAll(Collection<? extends E> c)
// 移除此 set 中的所有元素。
void clear()
// 如果此 set 包含指定元素，则返回 true。
boolean contains(Object o)
// 如果此 set 包含指定 collection 的所有元素，则返回 true。
boolean containsAll(Collection<?> c)
// 比较指定对象与此 set 的相等性。
boolean equals(Object o)
// 如果此 set 不包含任何元素，则返回 true。
boolean isEmpty()
// 返回按照元素添加顺序在此 set 中包含的元素上进行迭代的迭代器。
Iterator<E> iterator()
// 如果指定元素存在于此 set 中，则将其移除。
boolean remove(Object o)
// 移除此 set 中包含在指定 collection 中的所有元素。
boolean removeAll(Collection<?> c)
// 仅保留此 set 中那些包含在指定 collection 中的元素。
boolean retainAll(Collection<?> c)
// 返回此 set 中的元素数目。
int size()
// 返回一个包含此 set 所有元素的数组。
Object[] toArray()
// 返回一个包含此 set 所有元素的数组；返回数组的运行时类型是指定数组的类型。
<T> T[] toArray(T[] a)
```



## CopyOnWriteArraySet成员变量

CopyOnWriteArraySet只有下面一个成员变量

```java
private final CopyOnWriteArrayList<E> al;
```

**说明:**

1. 成员变量al是`final`类型的，通过构造函数进行初始化后将不能再修改。
2. 成员变量al里的`添加/修改/删除`操作都是通过互斥锁和volatile变量来保证现场安全的，因此，成员变量al不再用`volatile`修饰，也不再额外声明可重入锁lock。



## CopyOnWriteArraySet重点函数

### 构造函数

```java
public CopyOnWriteArraySet() {
        al = new CopyOnWriteArrayList<E>();
}
public CopyOnWriteArraySet(Collection<? extends E> c) {
        al = new CopyOnWriteArrayList<E>();
        al.addAllAbsent(c);
}
```

CopyOnWriteArraySet允许初始化一个空的集合，也允许通过复制一个集合里的元素来进行初始化。本质上将，CopyOnWriteArraySet的初始化是通过初始化成员变量CopyOnWriteArrayList al来实现的。



### 添加

```java
public boolean add(E e) {
        return al.addIfAbsent(e);
}

public boolean addAll(Collection<? extends E> c) {
        return al.addAllAbsent(c) > 0;
}
```

CopyOnWriteArraySet不允许重复元素。因此，添加操作都是调用CopyOnWriteArrayList的`addIfAbsent`方法或者`addAllAbsent`方法实现的。