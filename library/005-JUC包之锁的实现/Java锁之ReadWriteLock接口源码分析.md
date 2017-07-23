---
"title": "Java锁之ReadWriteLock接口源码分析",
"date": "2017-02-23T18:39:27+08:00",
"categories": ["ABC_Lock"],
"tags": ["Java", "Lock"]
---

## 概述

为了提高性能，Java提供了读写锁，在读的地方使用读锁，在写的地方使用写锁，灵活控制。如果没有写锁的情况下，读是无阻塞的，在一定程度上提高了程序的执行效率。读锁本质上是一种共享锁，写锁本质上是一种互斥锁。Java通过ReadWriteLock接口声明了读写锁的相关操作，通过该接口用户可以同时获取一个读锁实例和写锁实例。ReentrantReadWriteLock是ReadWriteLock的唯一实现，该类通过静态内部类的方式实现了ReadLock和WriteLock，并且根据需要提供了公平锁(FairSync)和非公平所(NonfairSync)的实现。



本文重点关注ReadWriteLock接口的设计，具体实现会在ReentrantReadWriteLock类中进行具体分析。



本文基于JDK1.7.0_67

> java version "1.7.0_67"_
>
> _Java(TM) SE Runtime Environment (build 1.7.0_67-b01)
>
> Java HotSpot(TM) 64-Bit Server VM (build 24.65-b04, mixed mode)



## 函数列表

```java
Lock readLock();
Lock writeLock();
```



## 重点函数分析

### readLock

返回一个读锁。读锁本质上是一个共享锁。在Java的实现中，共享锁通过计数器实现，区分公平锁和非公平锁。



### writeLock

返回一个写锁。写锁本质上是一个独占锁。在Java的实现中，区分公平锁和非公平锁。
