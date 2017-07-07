---
title: "AtomicLong源码分析"
date: "2017-02-23T18:30:28+08:00"
categories: ["ABC_Atomic"]
tags: ["Java", "Lock"]
draft: false
---

## 概述

在原子变量相关类中，AtomicBoolean, AtomicInteger, AtomicLong三个类是对于基本数据类型的操作，其原理和用法类似，区别在于Boolean, Integer, Long分别是8位，32位，64位的类型，本文重点研究AtomicLong。



Boolean类型数据长度为8位，Integer类型数据是32位，在当前32位操作系统或者64位操作中都能够直接对其进行原子修改和读取。而Long类型数据是64位，在32位JVM上会当做两个分离的32位来进行操作，所以本身不具备原子性。



还好我们现在的JDK基本都已经更新到64位，对long型数据的直接修改不存在原子性问题，但是当出现运算操作(比如++, —等)时还是会出现性问题，AtomicLong的目的是实现Long类型数据的各种原子操作。



Java原子变量的实现依赖于`sun.misc.Unsafe`的CAS操作和volatile的内存可见性语义。





本文基于JDK1.7.0_67

>java version "1.7.0_67"_
>
>_Java(TM) SE Runtime Environment (build 1.7.0_67-b01)
>
>Java HotSpot(TM) 64-Bit Server VM (build 24.65-b04, mixed mode)



## 成员变量

```java
// 成员变量unsafe是原子变量相关操作的基础
// 原子变量的修改操作最终有sun.misc.Unsafe类的CAS操作实现
private static final Unsafe unsafe = Unsafe.getUnsafe();
// 成员变量value的内存偏移值，在静态代码块中初始化
private static final long valueOffset;
// 通过volatile关键字保证可见性，用于保存值
private volatile long value;

static {
  try {
    valueOffset = unsafe.objectFieldOffset
      	(AtomicLong.class.getDeclaredField("value"));
  } catch (Exception ex) { throw new Error(ex); }
}
```



## 函数列表

```java
// 构造函数，初始化值为0
public AtomicLong()
// 构造函数，指定初始化值
public AtomicLong(long initialValue)
// 以原子方式获取当前值
public final long get()
// 以原子方式设置当前值为newValue
// 赋值语句是单操作，所以本身具有原子性
public final void set(long newValue)
// 最后设置为给定值。延时设置变量值，这个等价于set()方法，
// 但是由于字段是volatile类型的，因此此字段的修改会比普通字段
//（非volatile字段）有稍微的性能延时（尽管可以忽略），所以如果
// 不是想立即读取设置的新值，允许在“后台”修改值，那么此方法就很
// 有用。如果还是难以理解，这里就类似于启动一个后台线程如执行修
// 改新值的任务，原线程就不等待修改结果立即返回。
public final void lazySet(long newValue)
// 以原子方式设置当前值为newValue，并返回旧值
public final long getAndSet(long newValue)
// 以原子方式设置当前值为update。
// 如果当前值等于expect，并设置成功，返回true
// 如果当前值不等于expect，则设置失败，返回false
// 该过程不阻塞
public final boolean compareAndSet(long expect, long update)
// 同compareAndSet
public final boolean weakCompareAndSet(long expect, long update)
// 以原子的方式将当前值加1
// 该过程以自旋锁的形似循环执行，直到操作成功
// 该过程不会阻塞
// 返回更新前的值
public final long getAndIncrement()
// 以原子的方式将当前值减1
// 该过程以自旋的形式循环执行，直到操作成功
// 该过程不会阻塞
// 返回更新前的值
public final long getAndDecrement()
// 以原子方式将原值加上给定的delta
// 该过程以自旋的形式循环执行，直到操作成功
// 该过程不会阻塞
// 返回更新前的值
public final long getAndAdd(long delta)
// 以原子方式将原值加1
// 该过程会议自旋的形式循环执行，直到操作成功
// 该过程不会阻塞
// 返回更新后的值
public final long incrementAndGet()
// 以原子方式将原值减1
// 该过程会议自旋的形式循环执行，直到操作成功
// 该过程不会阻塞
// 返回更新后的值
public final long decrementAndGet()
// 以原子方式将原值加上给定的delta
// 该过程以自旋的形式循环执行，直到操作成功
// 该过程不会阻塞
// 返回更新后的值
public final long addAndGet(long delta)
// 将当前值使用Long的静态方法转换成String类型，并返回
public String toString()
// 将当前值使用强制类型转换成int类型，并返回
public int intValue()
// 直接返回当前值
public long longValue()
// 将当前值使用强制类型转换成float类型，并返回
public float floatValue()
// 将当前值使用强制类型转换成double类型，并返回
public double doubleValue()
```



## 重点函数分析

### set(long newValue)

以原子方式设置当前值为newValue，因为set方法只是一个但操作的赋值语句，因此是原子的。加上volatile的内存可见性保证，Set是原子操作无疑。



### lazySet(long newValue)

简单点说，lazySet优先保证数据的修改操作，而降低对可见性的要求。

lazySet是使用Unsafe.putOrderedObject方法，这个方法在对低延迟代码是很有用的，它能够实现非堵塞的写入，这些写入不会被Java的JIT重新排序指令([instruction reordering](http://stackoverflow.com/questions/14321212/java-instruction-reordering-cache-in-threads))，这样它使用快速的存储-存储(store-store) barrier, 而不是较慢的存储-加载(store-load) barrier, 后者总是用在volatile的写操作上，这种性能提升是有代价的，虽然便宜，也就是写后结果并不会被其他线程看到，甚至是自己的线程，通常是几纳秒后被其他线程看到，这个时间比较短，所以代价可以忍受。

类似Unsafe.putOrderedObject还有unsafe.putOrderedLong等方法，unsafe.putOrderedLong比使用 volatile long要快3倍左右。



## compareAndSet(long expect, long update)

以原子方式设置当前值为update。如果当前值等于expect，并设置成功，返回true。如果当前值不等于expect，则设置失败，返回false。该过程不阻塞。由于是使用了`sun.misc.Unsafe`的CAS操作实现，它是原子操作无疑。

__set和compareAndSet都是原子操作，只是他们的目的不同，set只是单纯想设置一个新的值。而compareAndSet则是希望在满足一定条件的情况下(当前值等于except)再设置新的值。_



## weakCompareAndSet(long expect, long update)

以原子方式设置当前值为update。它的实现与compareAndSet完全一致。JDK文档中说，weakCompareAndSet在更新变量时并不创建任何`happens-before`顺序，因此即使要修改的值是volatile的，也不保证对该变量的读写操作的顺序（一般来讲，volatile的内存语义保证`happens-before`顺序）。



参考：

1. [Java并发——原子变量和原子操作](http://www.cnblogs.com/timlearn/p/4127616.html)


2. [AtomicInteger lazySet vs set](https://stackoverflow.com/questions/1468007/atomicinteger-lazyset-vs-set)
3. [Java Atomic Variable set() vs compareAndSet()](https://stackoverflow.com/questions/19238594/java-atomic-variable-set-vs-compareandset)

