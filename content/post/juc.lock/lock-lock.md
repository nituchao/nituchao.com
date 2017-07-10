---
title: "Java锁之Lock接口的理解"
date: "2017-02-23T18:39:27+08:00"
categories: ["ABC_Lock"]
tags: ["Java", "Lock"]
draft: false
---

## 概述

在JUC包中，Lock接口定义了一个锁应该拥有基本操作。Lock接口的实现类非常多，既有共享锁，也有独占锁，甚至在ConcurrentHashMap等并发集合里的Segment结构本质上也是锁的实现。另外，Lock接口还组合了一个Condition类型的条件变量，用于提供更加灵活、高效的控制操作。



本文重点关注Lock接口的设计，具体实现会在各个实现类中进行具体分析。



本文基于JDK1.7.0_67

> java version "1.7.0_67"_
>
> _Java(TM) SE Runtime Environment (build 1.7.0_67-b01)
>
> Java HotSpot(TM) 64-Bit Server VM (build 24.65-b04, mixed mode)



### 函数列表

```java
// 获取锁
// 如果获取失败，则进入阻塞队列
// 忽略了中断，在成功获取锁之后，再根据中断标识处理中断，即selfInterrupt中断自己
void lock();
// 获取锁
// 如果获取失败，则进入阻塞队列
// 在锁获取过程中不处理中断状态，而是直接抛出中断异常，由上层调用者处理中断。
void lockInterruptibly() throws InterruptedException;
// 尝试获取锁
// 获取成功，返回true
// 获取失败，返回fasle
// 不阻塞
boolean tryLock();
// 尝试获取锁
// 获取成功，返回true
// 获取失败，返回false
// 该操作必须在time时间内完成
boolean tryLock(long time, TimeUnit unit) throws InterruptedException;
// 释放锁
void unlock();
// 创建一个条件变量，用于更加精细地控制同步过程
Condition newCondition();
```

