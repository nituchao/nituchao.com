---
title: "CopyOnWriteArraySet源码分析"
date: "2017-02-23T18:25:27+08:00"
categories: ["Concurrent"]
tags: ["Java", "Concurrent"]
draft: false
---

## 概要

`CopyOnWriteArraySet`是线程安全的无序集合，可以将它理解成线程安全的HashSet。有意思的是，`CopyOnWriteArraySet`和HashSet虽然都继承于共同的父类AbstractSet；但是，HashSet是通过"散列表(HashSet)"实现的，而CopyConWriteArraySet则是通过"动态数组(CopyOnWriteArrayList)"实现的，并不是散列表。