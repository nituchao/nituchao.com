---
"title": "Java锁之Lock框架概述",
"date": "2017-02-23T18:28:27+08:00",
"categories": ["ABC_Lock"],
"tags": ["Java", "Lock"]
---

在Java中关于锁有两个体系，一个是synchronized代表的对象监视器同步锁，一个是以AQS为基础的锁框架，该框架位于java.uti.concurrent包下。



本文基于JDK1.7.0_67

> java version "1.7.0_67"_
>
> _Java(TM) SE Runtime Environment (build 1.7.0_67-b01)
>
> Java HotSpot(TM) 64-Bit Server VM (build 24.65-b04, mixed mode)





## AQS框架原理![AQS框架图](file:////Users/liang/Library/Group%20Containers/UBF8T346G9.Office/msoclip1/01/65CCEB69-4317-8645-9279-F8AA33DAD044.png)



## JUC包中的锁

相比同步锁，JUC包中的锁的功能更加强大，它为锁提供了一个框架，该框架允许更灵活地使用锁，只是它的用法更难罢了。

JUC包中的锁，包括：

* Lock接口
* ReadWriteLock接口
* Condition接口
* ReentrantLock独占锁
* ReentrantReadWriteLock读写锁
* CountDownLatch
* CyclicBarrier
* Semaphore
* AbstractOwnableSynchronizer抽象类
* AbstractQueuedSynchronizer抽象类
* AbstractQueuedLongSynchronizer抽象类
