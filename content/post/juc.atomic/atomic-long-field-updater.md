---
title: "AtomicLongFieldUpdater源码分析"
date: "2017-02-23T18:27:27+08:00"
categories: ["ABC_Atomic"]
tags: ["Java", "Atomic"]
draft: false
---

## 概述

在原子变量相关类中，AtomicIntegerFieldUpdater, AtomicLongFieldUpdater, AtomicReferenceFieldUpdater三个类是用于原子地修改对象的成员属性，它们的原理和用法类似，区别在于对Integer，Long，Reference类型的成员属性进行修改。本文重点研究AtomicLongFieldUpdater。



AtomicLongFieldUpdater的设计非常有意思。AtomicLongFieldUpdater本身是一个抽象类，只有一个受保护的构造函数，它本身不能被实例化。



AtomicLongFieldUpdater有两个私有的静态内部类`CASUpdater`和`LockedUpdater`，它们都是`AtomicLongFieldUpdater`的子类。用户使用`AtomicLongFieldUpdater`公共静态方法`newUpdater`实例化`AtomicLongFieldUpdater`的对象，本质是上是根据条件实例化了子类`CASUpdater`或者`LockedUpdater`，然后通过子类来完成具体的工作。



本文基于JDK1.7.0_67

> java version "1.7.0_67"
>
> _Java™ SE Runtime Environment (build 1.7.0_67-b01)
>
> Java HotSpot™ 64-Bit Server VM (build 24.65-b04, mixed mode)



### 内部类



