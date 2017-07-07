---
title: "Java锁之Unsafe类的理解"
date: "2017-02-23T18:29:27+08:00"
categories: ["Acorn_Lock"]
tags: ["Java", "Lock"]
draft: false
---

## 一言

`sun.misc.Unsafe`类是超越Java的存在，它违反了Java在内存管理上的设计初衷，却又是Java很多重要特性与功能得以实现的基础，它使Java的安全性受到威胁，却有使Java在很多方面的性能得到提升，它是魔鬼与天使的混合体。



## 概述

Java是一个安全的开发工具，它阻止开发人员犯很低级的错误，而大部分的错误都是基于内存管理的。Unsafe类突破了Java原生的内存管理体制，使用Unsafe类可以在系统内存的任意地址进行读写数据，而这些操作对于普通用户来说是非常危险的，Unsafe的操作粒度不是类，而是数据和地址。



从另一方讲，Java正被广泛应用于游戏服务器和高频率的交易应用。这些之所以能够实现主要归功于Java提供的这个非常便利的类`sun.mics.Unsafe`。Unsafe类为了速度，在Java严格的安全标准方法做了一些妥协。



Java在JUC包中提供了对`sun.misc.Unsafe`类的封装实现，这就是`java.util.concurrent.LockSupport`。



## 重要函数

`sun.mics.Unsafe`一共提供了106个函数，这些函数涵盖了以下五个方面的功能：

1. 对变量和数组内容的原子访问，自定义内存屏障
2. 对序列化的支持
3. 自定义内存管理/高效的内存布局
4. 与原生代码和其他JVM进行互操作
5. 对高级锁的支持



### 获取实例

`sun.misc.Unsafe`只有一个无参的私有构造函数，要想实例化`sun.misc.Unsafe`可以调用`getUnsafe()`方法。

```java
@CallerSensitive
public static Unsafe getUnsafe() {
  Class var0 = Reflection.getCallerClass();
  if(var0.getClassLoader() != null) {
    throw new SecurityException("Unsafe");
  } else {
    return theUnsafe;
  }
}
```

出于安全考虑，Unsafe类只能被系统类加载器实例化，否则会抛出`SecurityException`异常。



### 内存操作

#### 获取成员变量偏移量

```java
public native long objectFieldOffset(Field field); 
```

`sun.misc.Unsafe`的操作对象是内存数据，获取指定成员变量的内存地址是对其进行操作的第一步。

 `objectFieldOffset`是一个本地函数，返回指定静态field的内存地址偏移量，`Unsafe`类的其他方法中这个值是被用作一个访问特定field的一个方式。这个值对于给定的field是唯一的，并且后续对该方法的调用都返回相同的值。

`objectFieldOffset`获取到的是内存偏移量，并不是真正的内存指针地址，Unsafe类提供了`getAddress`函数将该偏移量转换为真正的内存指针地址，有了该内存指针地址，就可以直接操作内存数据的读写了。



#### 操作成员变量数据

有了`objectFieldOffset`获取到的内存偏移量，就可以使用Unsafe类对该内存位置的数据进行读写。Unsafe类提供了对所有Java基本数据类型（byte, short, int, long, float, double）和对象类型的读写，这些方法都是本地函数（另外有一些对本地函数进行封装的读写函数，已经被标识为弃用）。

```java
// var1: 对象引用
// var2: 内存偏移量，通过objectFieldOffset获取
public native int getInt(Object var1, long var2);
// var1: 对象引用
// var2: 内存偏移量，通过objectFieldOffset获取
// var4: 新的数据值
public native void putInt(Object var1, long var2, int var4);
public native Object getObject(Object var1, long var2);
public native void putObject(Object var1, long var2, Object var4);
public native boolean getBoolean(Object var1, long var2);
public native void putBoolean(Object var1, long var2, boolean var4);
public native byte getByte(Object var1, long var2);
public native void putByte(Object var1, long var2, byte var4);
public native short getShort(Object var1, long var2);
public native void putShort(Object var1, long var2, short var4);
public native char getChar(Object var1, long var2);
public native void putChar(Object var1, long var2, char var4);
public native long getLong(Object var1, long var2);
public native void putLong(Object var1, long var2, long var4);
public native float getFloat(Object var1, long var2);
public native void putFloat(Object var1, long var2, float var4);
public native double getDouble(Object var1, long var2);
public native void putDouble(Object var1, long var2, double var4);

public native byte getByte(long var1);
public native void putByte(long var1, byte var3);
public native short getShort(long var1);
public native void putShort(long var1, short var3);
public native char getChar(long var1);
public native void putChar(long var1, char var3);
public native int getInt(long var1);
public native void putInt(long var1, int var3);
public native long getLong(long var1);
public native void putLong(long var1, long var3);
public native float getFloat(long var1);
public native void putFloat(long var1, float var3);
public native double getDouble(long var1);
public native void putDouble(long var1, double var3);
```



#### 获取内存指针地址

`objectFieldOffset`获取到的是内存偏移量，并不是真正的内存指针地址，Unsafe类提供了`getAddress`函数将该偏移量转换为真正的内存指针地址，有了该内存指针地址，就可以直接操作内存数据的读写了。



```java
// 根据给定的内存偏移量(objectFieldOffset的返回值)，获取真正的内存指针地址。
// 如果给定的内存偏移量为0或者并没有指向一个内存块，返回undefined。
// 如果返回的内存指针地址位宽小于64，用无符号整数进行扩展转换为Java long型。
public native long getAddress(long var1);
// 保存一个内存指针地址到给定的内存偏移量。
// 如过给定的内存偏移量为0或者并没有指向一个内存块，返回undefined。
public native void putAddress(long var1, long var3);
```



#### 直接分配内存空间

`sun.mics.Unsafe`类允许Java程序使用JVM堆外内存，即操作系统内存。`BufferBytes`类也可以分配JVM堆外内存，但是只能使用最大2GB的JVM堆外内存空间，而`sun.mics.Unsafe`类没有这个限制。

```java
// 分配一块大小为var1字节的JVM堆外内存。
// 新分配的内存空间中的内容处于未初始化状态。
// 新分配的内存空间的指针地址不为0，并对所有的值类型做内存对齐。
public native long allocateMemory(long var1);
// 调整JVM堆外内存空间大小。
// 参数var1是待调整的JVM堆外内存空间的指针地址。
// 参数var3是新的JVM堆外内存空间字节大小。
// 如果新空间大小var1=0，则返回指针地址为0.
public native long reallocateMemory(long var1, long var3);
// 释放指定内存指针地址的内存空间。
public native void freeMemory(long var1);
```







#### 直接操作内存类型数据

有了`addAddress`函数获取到的内存指针地址，就可以直接操作该内存指针地址处的数据了。Unsafe类提供了对所有Java基础数据类型和对象类型的直接内存操作函数。

下面提供的这些函数，都是按照数据类型对内存数据进行读写。

```java
// var1: 内存指针地址
public native byte getByte(long var1);
// var1: 内存指针地址
// var3: 新的数据值
public native void putByte(long var1, byte var3);
public native short getShort(long var1);
public native void putShort(long var1, short var3);
public native char getChar(long var1);
public native void putChar(long var1, char var3);
public native int getInt(long var1);
public native void putInt(long var1, int var3);
public native long getLong(long var1);
public native void putLong(long var1, long var3);
public native float getFloat(long var1);
public native void putFloat(long var1, float var3);
public native double getDouble(long var1);
public native void putDouble(long var1, double var3);
```



#### 直接操作内存字节数据

有了`addAddress`函数获取到的内存指针地址，就可以直接操作该内存指针地址处的数据了。Unsafe类提供了直接按照字节为单位对指定的内存指针地址进行数据操作的函数。

```java
public native void setMemory(Object o, long offset, long bytes, byte value);
public void setMemory(long address, long bytes, byte value) {
  	setMemory(null, address, bytes, value);
}
```



#### 直接复制内存数据

有了`addAddress`函数获取到的内存指针地址，还可以直接将一个内存指针地址对应的数据块拷贝到另一个内存指针地址对应的位置。

```java
public native void copyMemory(Object srcBase, long srcOffset,
                              Object destBase, long destOffset,
                              long bytes);
public void copyMemory(long srcAddress, long destAddress, long bytes) {
  	copyMemory(null, srcAddress, null, destAddress, bytes);
}
```



### 原子操作



### 监视器锁



### 线程控制



### 序列化支持











## 实战



参考:

1. [sun.misc.Unsafe的理解](http://www.cnblogs.com/chenpi/p/5389254.html)


2. [Java Magic. Part 4: sun.misc.Unsafe](http://ifeve.com/sun-misc-unsafe/)
3. [java-hidden-features](http://howtodoinjava.com/tag/java-hidden-features/)
4. [sun.misc.unsafe类的使用](http://blog.csdn.net/fenglibing/article/details/17138079)
5. [深入浅出 Java Concurrency (5): 原子操作 part 4](http://www.blogjava.net/xylz/archive/2010/07/04/325206.html)
6. [sun.misc.Unsafe的后启示录](http://www.infoq.com/cn/articles/A-Post-Apocalyptic-sun.misc.Unsafe-World)