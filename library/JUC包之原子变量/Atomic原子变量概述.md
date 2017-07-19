---
"title": "Atomic原子变量概述",
"date": "2017-02-23T18:39:27+08:00",
"categories": ["ABC_Atomic"],
"tags": ["Java", "Atomic"]
---

Java原子变量的诞生源自一个简单的需求 —— 多个线程共享某个变量或者对象时，需要对修改和读取操作进行同步。

同步包含两层含义：

1. 互斥访问
2. 可见性

通常，多线程对临界资源的互斥访问通过对象锁(synchronized关键字)保证。对象锁是一种独占锁（悲观锁），会导致其它所有需要锁的线程挂起。而可见性则由volatile的内存语义保证。



Java 1.5开始提供了原子变量和原子引用，这些类放置在`java.util.concurrent`下。大概可以归为4类：

1. 基本类型：AtomicInteger, AtomicLong, AtomicBoolean;
2. 数组类型：AtomicIntegerArray, AtomicLongArray, AtomicReferenceArray;
3. 引用类型：AtomicReference, AtomicStampedReference, AtomicMarkableReference;
4. 对象的属性修改类型：AtomicIntegerFieldUpdater, AtomicLongFieldUpdater, AtomicReferenceFieldUpdater;



Java原子变量的存在是为了对相应的数据进行原子操作。



所谓的原子操作包含下面几层含义：

1. 操作过程不会被中断。
2. 操作过程不会被阻塞。
3. 修改结果被其他线程可见。
