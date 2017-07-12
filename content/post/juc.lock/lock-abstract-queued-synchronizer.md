---
title: "Java锁之AQS抽象类源码分析"
date: "2017-02-23T18:39:27+08:00"
categories: ["ABC_Lock"]
tags: ["Java", "Lock"]
draft: false
---

## 概述

队列同步器AbstractQueuedSynchronizer（以下简称AQS），是用来构建锁或者其他同步组件的基础框架。它使用一个int成员变量来表示同步状态（重入次数，共享状态等），通过CAS操作对同步状态进行修改，确保状态的改变是安全的。通过内置的FIFO(First In First Out)队列来完成资源获取的排队工作。在AQS里有两个队列，分别是维护Sync Queue和Condition Queue，两个队列的节点都是AQS的静态内部类Node。Sync Queue在独占模式和共享模式中均会使用到，本质上是一个存放Node的CLH队列（主要特点是, 队列中总有一个 dummy 节点, 后继节点获取锁的条件由前继节点决定, 前继节点在释放 lock 时会唤醒sleep中的后继节点），维护的是等待获取锁的线程信息。Condition Queue在独占模式中才会用到，当用户使用条件变量进行线程同步时，维护的是等待条件变量的线程信息。



通过AQS实现的锁分独占锁(ReentrantLock，WriteLock，Segment等)和共享锁(ReadLock)，使用一个volatile修饰的int类型的变量state来表示当前同步块的状态。state在AQS中功能强大，即可以用来表示同步器的加锁状态，也可以用来表示重入锁的重入次数(tryAcquire)，还可以用来标识读锁和写锁的加锁状态。



在AQS的基础上，JUC包实现了如下几类锁：
1，公平锁和非公平所

2，可重入锁

3，独占锁和共享锁

以上三类锁并不是独立的，可以有多种组合。

1，ReentrantLock：可重入锁，公平锁|非公平锁，独占锁。

2，ReentrantReadWriteLock：可重入锁，公平锁|非公平锁，独占锁|共享锁。



另外，除了上面列举的ReentrantLock和ReentrantReadWriteLock外，下面几个类也是依靠AQS实现的。

1，CountDownLatch

2，CyclicBarrier

3，Semaphore

4，Segment



AQS主要包含下面几个特点，是我们理解AQS框架的关键：

1，内部含有两条队列（Sync Queue，Condition Queue）。

2，AQS内部定义获取锁（acquire），释放锁（release）的主逻辑，子类实现相应的模板方法。

3，支持共享和独占两种模式（共享模式时只用Sync Queue，独占时只用Sync Queue，但如果涉及条件变量Condition，则还有Condition Queue）。

4，支持不响应中断获取独占锁（acquire），响应中断获取独占锁（acquireInterruptibly），超时获取独占锁（tryAcquireNanos）；不响应中断获取共享锁（acquireShared），响应中断获取共享锁（acquireSharedInterruptibly），超时获取共享锁（tryAcquireSharedNanos）；

5，在子类的tryAcquire，tryAcquireShared中实现公平和非公平的区分。



本文重点介绍AbstractQueuedSynchronizer的设计，其实现待到具体的子类再做分析。



本文基于JDK1.7.0_67

> java version "1.7.0_67"_
>
> _Java(TM) SE Runtime Environment (build 1.7.0_67-b01)
>
> Java HotSpot(TM) 64-Bit Server VM (build 24.65-b04, mixed mode)



## 内部类

### Node

Node是AbstractQueuedSynchronizer的静态内部类，文章概述里，我们说在AQS中有两类等待队列(Sync Queue和Condition Queue)，Node就是等待队列的节点类。AQS的等待队列是"CLH"锁队列的变种。"CLH"锁是一种自旋锁，在AQS中

#### 成员变量

```java
// 标识节点是否是 共享的节点(这样的节点只存在于 Sync Queue 里面)
static final Node SHARED = new Node();
// 标识节点是 独占模式
static final Node EXCLUSIVE = null;
// 代表线程已经被取消
static final int CANCELLED =  1;
// 代表后续节点需要唤醒
static final int SIGNAL    = -1;
// 代表线程在condition queue中，等待某一条件
static final int CONDITION = -2;
// 代表后续结点会传播唤醒的操作，共享模式下起作用
static final int PROPAGATE = -3;
// 当前节点的状态
volatile int waitStatus;
// 当前节点的上一个节点
volatile Node prev;
// 当前节点的下一个节点
volatile Node next;
// 当前节点代表的线程
volatile Thread thread;
// 这个节点等待的模式(共享模式和独占模式)
Node nextWaiter;
```



#### 函数列表

```java
// 空制造函数
Node();
// 构造函数，初始化nextWaiter
// addWaiter使用
Node(Thread thread, Node mode);
// 构造函数，初始化waitStatus
// Condition使用
Node(Thread thread, int waitStatus);
// 如果当前节点的等待模式(nextWaiter)是共享模式，返回true
final boolean isShared();
// 返回当前节点的上一个节点
final Node predecessor() throws NullPointerException;
```



### ConditionObject



参考：

- [Java 并发编程的艺术](http://download.csdn.net/detail/u011898232/9548575)
- [Java Magic. Part 4: sun.misc.Unsafe](http://ifeve.com/sun-misc-unsafe/)
- [Java里的CompareAndSet(CAS)](http://www.blogjava.net/mstar/archive/2013/04/24/398351.html)
- [ReentrantLock的lock-unlock流程详解](http://blog.csdn.net/luonanqin/article/details/41871909)
- [深入JVM锁机制2-Lock](http://blog.csdn.net/chen77716/article/details/6641477)
- [深度解析Java 8：JDK1.8 AbstractQueuedSynchronizer的实现分析（上）](http://www.infoq.com/cn/articles/jdk1.8-abstractqueuedsynchronizer)
- [AbstractQueuedSynchronizer源码分析](https://www.cnblogs.com/zhanjindong/p/java-concurrent-package-aqs-AbstractQueuedSynchronizer.html)
- [聊聊并发（十二）—AQS分析](https://my.oschina.net/xianggao/blog/532709)
- [AbstractQueuedSynchronizer (AQS)](http://www.javarticles.com/2012/10/abstractqueuedsynchronizer-aqs.html)
- [并发编程实践二：AbstractQueuedSynchronizer](http://blog.csdn.net/tomato__/article/details/24774465)