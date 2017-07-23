---
"title": "AtomicReference源码分析",
"date": "2017-02-23T18:30:27+08:00",
"categories": ["ABC_Atomic"],
"tags": ["Java", "Atomic"]
---

## 概述

在原子变量相关类中，AtomicReference, AtomicStampedReference, AtomicMarkableReference三个类是对于引用类型的操作，其原理和用法类似。

`AtomicStampedReference`是带了整型版本号(int stamp)的引用型原子变量，每次执行CAS操作时需要对比版本，如果版本满足要求，则操作成功，否则操作失败，用于防止CAS操作的ABA问题。



`AtomicMarkableReference`则是带了布尔型标记位(Boolean mark)的引用型原子量，每次执行CAS操作是需要对比该标记位，如果标记满足要求，则操作成功，否则操作失败。



Java原子变量的实现依赖于`sun.misc.Unsafe`的CAS操作和volatile的内存可见性语义。





本文基于JDK1.7.0_67

> java version "1.7.0_67"_
>
> _Java(TM) SE Runtime Environment (build 1.7.0_67-b01)
>
> Java HotSpot(TM) 64-Bit Server VM (build 24.65-b04, mixed mode)



## 成员变量

`AtomicReference`通过泛型`T`来声明成员值的类型，表示这是对引用类型的操作。

```java
// 成员变量unsafe是原子变量相关操作的基础
// 原子变量的修改操作最终有sun.misc.Unsafe类的CAS操作实现
private static final Unsafe unsafe = Unsafe.getUnsafe();
// 成员变量value的内存偏移值，在静态代码块中初始化
private static final long valueOffset;
// 通过volatile关键字保证可见性，用于保存值
private volatile V value;

static {
  try {
    valueOffset = unsafe.objectFieldOffset
      (AtomicReference.class.getDeclaredField("value"));
  } catch (Exception ex) { throw new Error(ex); }
}
```





## 函数列表

```java
// 构造函数，初始化值为null
public AtomicReference()
// 构造函数，指定初始化值
public AtomicReference(V initialValue)
// 以原子方式获取当前值
public final V get()
// 以原子方式设置当前值为新的值newValue
public final void set(V newValue)
// 以原子方式设置当前值为新的值newValue
// 优先保证修改操作，而不保证volatile的可见性语义
// 效率较高
public final void lazySet(V newValue)
// 以原子方式设置当前值为update
// 如果当前值等于except，则设置成功，返回true
// 如果当前值不等于except，则设置失败，返回fase
// 该过程不阻塞
public final boolean compareAndSet(V expect, V update)
// 以原子方式设置当前值为update
// 如果当前值等于except，则设置成功，返回true
// 如果当前值不等于except，则设置失败，返回fase
// 该过程不阻塞
// 该过程不保证volatile成员的happens-before语义顺序
public final boolean weakCompareAndSet(V expect, V update)
// 以原子方式设置当前值为update
// 返回更新前的值
public final V getAndSet(V newValue)
// 返回当前值的string表达式
public String toString()
```



## 重点函数分析

### set(V newValue)

以原子方式设置当前值为newValue，因为set方法只是一个单操作的赋值语句，因此是原子的。加上volatile的内存可见性保证，Set是原子操作无疑。



### lazySet(V newValue)

简单点说，lazySet优先保证数据的修改操作，而降低对可见性的要求。

lazySet是使用Unsafe.putOrderedObject方法，这个方法在对低延迟代码是很有用的，它能够实现非堵塞的写入，这些写入不会被Java的JIT重新排序指令([instruction reordering](http://stackoverflow.com/questions/14321212/java-instruction-reordering-cache-in-threads))，这样它使用快速的存储-存储(store-store) barrier, 而不是较慢的存储-加载(store-load) barrier, 后者总是用在volatile的写操作上，这种性能提升是有代价的，虽然便宜，也就是写后结果并不会被其他线程看到，甚至是自己的线程，通常是几纳秒后被其他线程看到，这个时间比较短，所以代价可以忍受。

类似Unsafe.putOrderedObject还有unsafe.putOrderedLong等方法，unsafe.putOrderedLong比使用 volatile long要快3倍左右。



## compareAndSet(V expect,V update)

以原子方式设置当前值为update。如果当前值等于expect，并设置成功，返回true。如果当前值不等于expect，则设置失败，返回false。该过程不阻塞。由于是使用了`sun.misc.Unsafe`的CAS操作实现，它是原子操作无疑。

_*set和compareAndSet都是原子操作，只是他们的目的不同，set只是单纯想设置一个新的值。而compareAndSet则是希望在满足一定条件的情况下(当前值等于except)再设置新的值。*



## weakCompareAndSet(V expect,V update)

以原子方式设置当前值为update。它的实现与compareAndSet完全一致。JDK文档中说，weakCompareAndSet在更新变量时并不创建任何`happens-before`顺序，因此即使要修改的值是volatile的，也不保证对该变量的读写操作的顺序（一般来讲，volatile的内存语义保证`happens-before`顺序）。





参考:

1. [Java.Util.Concurrent.Atomic.AtomicMarkableReference Class](https://developer.xamarin.com/api/type/Java.Util.Concurrent.Atomic.AtomicMarkableReference/)
