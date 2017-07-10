---
title: "Java锁之AbstractOwnableSynchronizer抽象类的理解"
date: "2017-02-23T18:39:27+08:00"
categories: ["ABC_Lock"]
tags: ["Java", "Lock"]
draft: false
---

## 概述

在JUC包中实现的同步器锁分为独占锁(如ReentrantLock、WriteLock)和共享锁(ReadLock)。共享锁本质上是通过对volatile修饰的计数器state进行维护而实现的。独占锁则是通过在同步器中设置独占线程来实现的。在JUC包中AbstractOwnableSynchronizer是个抽象类，它维护了一个Thread类型的成员变量，标识当前独占同步器的线程引用。AbstractOwnableSynchronizer的子类是大名鼎鼎的AbstractQueuedSynchronizer和AbstractQueuedLongSynchronizer，这两个子类是实现JUC包下锁框架的基础。



本文重点研究AbstractOwnerSynchronizer抽象类的设计，具体实现会在AbstractQueuedSynchronizer类中进行分析。



本文基于JDK1.7.0_67

> java version "1.7.0_67"_
>
> _Java(TM) SE Runtime Environment (build 1.7.0_67-b01)
>
> Java HotSpot(TM) 64-Bit Server VM (build 24.65-b04, mixed mode)



## 成员变量

在AbstractOwnableSynchronizer类中只有一个成员变量exclusiveOwnerThread，该变量记录当前独占同步器的那个线程。

```java
private transient Thread exclusiveOwnerThread;
```



## 函数列表

```java
// 空实现的构造函数，供子类实现
protected AbstractOwnableSynchronizer();
// 设置同步器的独占线程
protected final void setExclusiveOwnerThread(Thread t);
// 获取同步器的独占线程
protected final Thread getExclusiveOwnerThread();
```
