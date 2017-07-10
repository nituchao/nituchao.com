---
title: "Java锁之Condition接口的理解"
date: "2017-02-23T18:39:27+08:00"
categories: ["ABC_Lock"]
tags: ["Java", "Lock"]
draft: false
---

## 概述

Condition是一个接口，用于定义条件变量。条件变量的实例化是通过一个Lock对象上调用newCondition()方法获取的，这样，条件变量就和一个锁对象绑定起来了。Java中的条件变量只能和锁配合使用，来控制编发程序访问竞争资源的安全。条件变量增强了juc包下基于AQS锁框架的灵活性。对比synchronized代表的监视器锁，条件变量将锁和监视器操作(await, signal, signalAll)分离开来，而且一个锁可以绑定多个条件变量，每个条件变量的实例会维护一个单独的等待队列。条件变量使得锁框架能更加精细控制线程等待与唤醒。在AbstractQueuedSynchronizer和AbstractQueuedLongSynchronizer类中分别有一个实现ConditionObject，为整个AQS框架提供条件变量的相关能力。



本文重点关注Condition接口的设计，具体实现会在AbstractQueuedSynchronizer类中进行具体分析。



本文基于JDK1.7.0_67

> java version "1.7.0_67"_
>
> _Java(TM) SE Runtime Environment (build 1.7.0_67-b01)
>
> Java HotSpot(TM) 64-Bit Server VM (build 24.65-b04, mixed mode)



## 函数列表

```java
void await() throws InterruptedException;
void awaitUninterruptibly();
long awaitNanos(long nanosTimeout) throws InterruptedException;
boolean await(long time, TimeUnit unit) throws InterruptedException;
boolean awaitUntil(Date deadline) throws InterruptedException;
void signal();
void signalAll();
```



## 重点函数分析

### signal()和signalAll()

signal()和signal()函数的字面意思很好理解，signal()负责唤醒等待队列中的一个线程，signalAll负责唤醒等待队列中的所有线程。那什么时候用signal()？什么时候用signalAll()？答案是：避免死锁的情况下，要用signalAll()，其他情况下两者可以通用，甚至signal()的效率要高一些。

参考：

1. [java Condition条件变量的通俗易懂解释、基本使用及注意点](http://www.cnblogs.com/zhjh256/p/6389168.html)
2. [怎么理解Condition](http://ifeve.com/understand-condition/)
3. [Condition-线程通信更高效的方式](http://blog.csdn.net/ghsau/article/details/7481142)