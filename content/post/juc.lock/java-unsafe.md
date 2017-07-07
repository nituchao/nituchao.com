---
title: "Java锁之Unsafe类的理解"
date: "2017-02-23T18:39:27+08:00"
categories: ["ABC_Lock"]
tags: ["Java", "Lock"]
draft: false
---

## 一言

`sun.misc.Unsafe`类是超越Java的存在，它违反了Java在内存管理上的设计初衷，却又是Java很多重要特性与功能得以实现的基础，它使Java的安全性受到威胁，却有使Java在很多方面的性能得到提升，它是魔鬼与天使的混合体。



## 概述

Java是一个安全的开发工具，它阻止开发人员犯很低级的错误，而大部分的错误都是基于内存管理的。Unsafe类突破了Java原生的内存管理体制，使用Unsafe类可以在系统内存的任意地址进行读写数据，而这些操作对于普通用户来说是非常危险的，Unsafe的操作粒度不是类，而是数据和地址。



从另一方讲，Java正被广泛应用于游戏服务器和高频率的交易应用。这些之所以能够实现主要归功于Java提供的这个非常便利的类`sun.mics.Unsafe`。Unsafe类为了速度，在Java严格的安全标准方法做了一些妥协。



Java在JUC包中提供了对`sun.misc.Unsafe`类的封装实现，这就是`java.util.concurrent.LockSupport`。



本文基于JDK1.7.0_67

> java version "1.7.0_67"_
>
> _Java(TM) SE Runtime Environment (build 1.7.0_67-b01)
>
> Java HotSpot(TM) 64-Bit Server VM (build 24.65-b04, mixed mode)



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

出于安全考虑，Unsafe类只能被系统类加载器实例化，否则会抛出`SecurityException`异常。普通用户如果想实例化`sun.misc.Unsafe`类的对象，需要通过类反射机制或者修改Java的安全策略。



### 内存操作

#### 获取成员变量偏移量

```java
// 返回对象中指定静态成员变量的内存偏移量(相对于类存储)
public native long staticFieldOffset(Field f);

// 返回对象中指定成员变量的内存偏移量(相对于对象实例)
public native long objectFieldOffset(Field f);

// 返回对象中指定成员变量
public native Object staticFieldBase(Field f);
```

`sun.misc.Unsafe`的操作对象是内存数据，获取指定成员变量的内存地址是对其进行操作的第一步。

 `objectFieldOffset`是一个本地函数，返回指定静态field的内存地址偏移量，`Unsafe`类的其他方法中这个值是被用作一个访问特定field的一个方式。这个值对于给定的field是唯一的，并且后续对该方法的调用都返回相同的值。

`objectFieldOffset`获取到的是内存偏移量，并不是真正的内存指针地址，Unsafe类提供了`getAddress`函数将该偏移量转换为真正的内存指针地址，有了该内存指针地址，就可以直接操作内存数据的读写了。



#### 操作成员变量数据

有了`objectFieldOffset`获取到的内存偏移量，就可以使用Unsafe类对该内存位置的数据进行读写。Unsafe类提供了对所有Java基本数据类型（byte, short, int, long, float, double）和对象类型的读写，这些方法都是本地函数（另外有一些对本地函数进行封装的读写函数，已经被标识为弃用）。



这些操作可以从另一个层面理解为`sun.misc.Unsafe`对序列化和反序列化的支持。



```java
// o: 对象引用
// offset: 内存偏移量，通过objectFieldOffset获取
public native int getInt(Object o, long offset);
// o: 对象引用
// offset: 内存偏移量，通过objectFieldOffset获取
// x: 新的数据值
public native void putInt(Object o, long offset, int x);
public native Object getObject(Object o, long offset);
public native void putObject(Object o, long offset, Object x);
public native boolean getBoolean(Object o, long offset);
public native void    putBoolean(Object o, long offset, boolean x);
public native byte    getByte(Object o, long offset);
public native void    putByte(Object o, long offset, byte x);
public native short   getShort(Object o, long offset);
public native void    putShort(Object o, long offset, short x);
public native char    getChar(Object o, long offset);
public native void    putChar(Object o, long offset, char x);
public native long    getLong(Object o, long offset);
public native void    putLong(Object o, long offset, long x);
public native float   getFloat(Object o, long offset);
public native void    putFloat(Object o, long offset, float x);
public native double  getDouble(Object o, long offset);
public native void    putDouble(Object o, long offset, double x);

// 获取obj对象中offset地址对应的object型field的值为指定值。
// getObject(Object, long)的volatile版
public native Object getObjectVolatile(Object o, long offset);
// 设置obj对象中offset偏移地址对应的object型field的值为指定值。
// putObject(Object, long, Object)的volatile版
public native void    putObjectVolatile(Object o, long offset, Object x);
public native int     getIntVolatile(Object o, long offset);
public native void    putIntVolatile(Object o, long offset, int x);
public native boolean getBooleanVolatile(Object o, long offset);
public native void    putBooleanVolatile(Object o, long offset, boolean x);
public native byte    getByteVolatile(Object o, long offset);
public native void    putByteVolatile(Object o, long offset, byte x);
public native short   getShortVolatile(Object o, long offset);
public native void    putShortVolatile(Object o, long offset, short x);
public native char    getCharVolatile(Object o, long offset);
public native void    putCharVolatile(Object o, long offset, char x);
public native long    getLongVolatile(Object o, long offset);
public native void    putLongVolatile(Object o, long offset, long x);
public native float   getFloatVolatile(Object o, long offset);
public native void    putFloatVolatile(Object o, long offset, float x);
public native double  getDoubleVolatile(Object o, long offset);
public native void    putDoubleVolatile(Object o, long offset, double x);

// 设置obj对象中offset偏移地址对应的object型field的值为指定值。这是一个有序或者 
// 有延迟的<code>putObjectVolatile</cdoe>方法，并且不保证值的改变被其他线程立 
// 即看到。只有在field被<code>volatile</code>修饰并且期望被意外修改的时候 
// 使用才有用。 
// 这个方法在对低延迟代码是很有用的，它能够实现非堵塞的写入，这些写入不会被Java的JIT重新排序指令
// (instruction reordering)，这样它使用快速的存储-存储(store-store) barrier, 而不是较慢
// 的存储-加载(store-load) barrier, 后者总是用在volatile的写操作上，这种性能提升是有代价的，
// 虽然便宜，也就是写后结果并不会被其他线程看到，甚至是自己的线程，通常是几纳秒后被其他线程看到，
// 这个时间比较短，所以代价可以忍受。类似Unsafe.putOrderedObject还有unsafe.putOrderedLong
// 等方法，unsafe.putOrderedLong比使用 volatile long要快3倍左右。.
public native void    putOrderedObject(Object o, long offset, Object x);
public native void    putOrderedInt(Object o, long offset, int x);
public native void    putOrderedLong(Object o, long offset, long x);
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

// 返回一个内存指针占用的字节数(bytes)
public native int addressSize();
// 返回一个内存页占用的字节数(bytes)
public native int pageSize();

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



### 数组操作

Unsafe类中有很多以BASE_OFFSET结尾的常量，比如ARRAY_INT_BASE_OFFSET，ARRAY_BYTE_BASE_OFFSET等，这些常量值是通过arrayBaseOffset方法得到的。arrayBaseOffset方法是一个本地方法，可以获取数组第一个元素的偏移地址。



Unsafe类中还有很多以INDEX_SCALE结尾的常量，比如 ARRAY_INT_INDEX_SCALE ， ARRAY_BYTE_INDEX_SCALE等，这些常量值是通过arrayIndexScale方法得到的。arrayIndexScale方法也是一个本地方法，可以获取数组的转换因子，也就是数组中元素的增量地址。



将arrayBaseOffset与arrayIndexScale配合使用，可以定位数组中每个元素在内存中的位置。

```java
// 返回给定数组的第一个元素的内存偏移量
public native int arrayBaseOffset(Class arrayClass);
// 返回给定数组的转换因子，也就是数组中元素的增量地址
public native int arrayIndexScale(Class arrayClass);
```



### 原子操作

`sun.misc.Unsafe`类提供了CAS原子操作，能够实现高性能的线程安全的无锁数据结构。`sun.misc.Unsafe`类的CAS操作是`java.util.concurrent`包的基础，`LockSupport`，`AbstractQueuedSynchronized`，`AtomicInteger`等原子变量和锁框架都基于CAS操作实现的。



由于CAS操作在执行时当前线程不会被阻塞，所以通常使用自旋锁循环执行，直到操作成功时，表示获取到锁。

```java
// 当Java对象o的域偏移offset上的值为excepted时，原子地修改为x。
// 如果修改成功，返回true。否则，返回false。
// 操作过程中线程不会阻塞。
public final native boolean compareAndSwapObject(Object o, long offset,
                                                 Object expected,
                                                 Object x);
// 当Java对象o的域偏移offset上的值为int型的excepted时，原子地修改为x。
// 如果修改成功，返回true。否则，返回false。
// 操作过程中线程不会阻塞。
public final native boolean compareAndSwapInt(Object o, long offset,
                                              int expected,
                                              int x);
// 当Java对象o的域偏移offset上的值为int型的excepted时，原子地修改为x。
// 如果修改成功，返回true。否则，返回false。
// 操作过程中线程不会阻塞。
public final native boolean compareAndSwapLong(Object o, long offset,
                                               long expected,
                                               long x);
```



### 监视器锁

`synchronized`是JVM最早提供的锁，称为监视器锁，也称对象锁。获得锁的过程称为monitorEnter，释放锁的过程称为monitorExit，锁的信息保存在对象头里，同步语句会在编译成字节码后转换成监视器语法(monitorEnter和monitorExit)。`sun.misc.Unsafe`类提供了监视器的相关操作。

```java
// 锁住对象
public native void monitorEnter(Object o);
// 尝试锁住对象
public native boolean tryMonitorEnter(Object o);
// 解锁对象
public native void monitorExit(Object o);
```



### 线程控制

在实现`java.util.concurrent.AbstractQueued`类，并基于AQS实现整个JUC锁框架的过程中，一方面需要使用`sun.misc.Unsafe`类的CAS操作进行锁的获取(标记位state的修改)，另一方在获取锁失败时要把当前线程放入等待队列，并阻塞当前线程。阻塞当前的线程的方法也是`sun.misc.Unsafe`类提供的。



```java
// 阻塞当前线程。
// 直到通过unpark方法解除阻塞，或者线程被中断，或者指定的超时时间到期
// isAbsolute参数是指明时间是绝对的，还是相对的
// time单位是纳秒，如果为0则表示长期阻塞
public native void park(boolean isAbsolute, long time);
// 解除指定线程的阻塞状态。
public native void unpark(Object thread);
```

park方法的两个参数里并没有指定要阻塞的线程引用，JVM怎么知道要将哪个线程阻塞？而unpark方法又是如何将一个线程的阻塞状态解除的呢？要真正理解park和unpark的工作原理，需要深入到HotSpot的源码。



简单的讲，park和unpark本质上是通过HotSpot里的一个volatile共享变量(volatile int _counter)来通信的，当park时，这个变量设置为0，当unpark时，这个变量设置为1。



由此，我们发现使用park和unpark来对线程进行同步控制非常灵活，unpark甚至可以在park之前调用。park/unpark模型真正实现了线程之间的同步，Java线程之间不再需要一个Object(synchronized代表的对象锁，用对象头存储锁信息)或者其他变量来存储状态(AQS中的state变量)来存储状态，不再需要关心对方的状态。



对比Java5中提供的wait/notify/notifyAll同步体系。wait/notify机制有个很蛋疼的地方是，比如线程B要用notify通知线程A，那么线程B要确保线程A已经在wait调用上等待了，否则线程A可能永远都在等待。编程的时候就会很蛋疼。



unpark函数为线程提供“许可(permit)”，线程调用park函数则等待“许可”。这个有点像信号量，但是这个“许可”是不能叠加的，“许可”是一次性的。



比如线程B连续调用了三次unpark函数，当线程A调用park函数就使用掉这个“许可”，如果线程A再次调用park，则进入等待状态。



在HotSpot的实现里，每个Java线程都有一个Parker实例，Parker类的定义如下：

```c++
class Parker : public os::PlatformParker {  
private:  
  volatile int _counter ;  
  ...  
public:  
  void park(bool isAbsolute, jlong time);  
  void unpark();  
  ...  
}  
class PlatformParker : public CHeapObj<mtInternal> {  
  protected:  
    pthread_mutex_t _mutex [1] ;  
    pthread_cond_t  _cond  [1] ;  
    ...  
}  
```



### 异常处理

`sun.misc.Unsafe`类还提供了抛出异常的能力。

```java
// 在不通知验证器(verifier)的情况下，抛出异常。
public native void throwException(Throwable ee);
```



### 对象增强

`sun.misc.Unsafe`类还提供了一些对类和对象进行操作的函数。通过这些函数，用户可以在绕过虚拟机的情况下进行类的加载、初始化，或者对对象进行实例化。

```java
// 让虚拟机在不进行安全检查的情况下定义一个类。
// 默认情况下，该类的类加载器和保护域来自调用类。
public native Class defineClass(String name, byte[] b, int off, int len,
                                ClassLoader loader,
                                ProtectionDomain protectionDomain);
public native Class defineClass(String name, byte[] b, int off, int len);

// 在不调用构造函数的情况下，实例化类Class的一个对象
// 如果累Class还没有加载到JVM，则进行加载
public native Object allocateInstance(Class cls)
        throws InstantiationException;

// 定义一个匿名类，该类将不被classloader，或系统目录感知
public native Class defineAnonymousClass(Class hostClass, byte[] data, Object[] cpPatches);

// 确保指定的类已经被初始化(加载到JVM)
public native void ensureClassInitialized(Class c);
```



## 实例分析

本节记录了一些使用`sun.misc.Unsafe`的实例，并对这些实例进行分析。



### 实例化私有类

很多类为了封装的需要将构造函数声明成私有的，防止被实例化。在`sun.misc.Unsafe`类面前，这中做法不堪一击。`allocateInstance`方法可以在不调用构造函数的情况下，直接实例化类的一个对象。

```java
import sun.misc.Unsafe;

import java.lang.reflect.Field;

public class UnsafeUser {
    public static void main(String[] args) throws Exception {
        // 由于安全限制，只有系统class loader才能使用getUnsafe()方法
        // 普通用户只能通过反射实例化Unsafe
        Field field = Unsafe.class.getDeclaredField("theUnsafe");
        field.setAccessible(true);
        Unsafe unsafe = (Unsafe) field.get(null);

        // 实例化User，不调用构造函数
        User user = (User) unsafe.allocateInstance(User.class);
        user.setName("liang");
        System.out.println(user.getName());
    }
}

class User {
    private String name;
    private User() {}
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
}

// 执行后输出
liang
```



###  操作对象内存

```java
import sun.misc.Unsafe;

import java.lang.reflect.Field;

public class UnsafeUser {

    public static void main(String[] args) throws Exception {
        // 由于安全限制，只有系统classloader才能使用getUnsafe()方法
        // 普通用户只能通过反射实例化Unsafe
        Field field = Unsafe.class.getDeclaredField("theUnsafe");
        field.setAccessible(true);
        Unsafe unsafe = (Unsafe) field.get(null);

        // 实例化User，不调用构造函数
        User user = (User) unsafe.allocateInstance(User.class);
        user.setName("liang");
        user.setAge(28);

        // 输出user对象中各个成员遍历的内存偏移值
        for (Field f : user.getClass().getDeclaredFields()) {
            System.out.println(f.getName() + " 对应的内存偏移地址: " + unsafe.objectFieldOffset(f));
        }

        System.out.println("---------------------");

      	// 获取age内存偏移量
        long ageOffset = 
          unsafe.objectFieldOffset(user.getClass().getDeclaredField("age"));
       	// // 获取name内存偏移量
        long nameOffset = 
          unsafe.objectFieldOffset(user.getClass().getDeclaredField("name"));

        // 修改age值
        unsafe.putInt(user, ageOffset, 29);
        // 修改name值
        unsafe.putObject(user, nameOffset, "zhang liang");

        System.out.println("age: " + user.getAge());
        System.out.println("name: " + user.getName());
    }
}

class User {
    private int age;
    private String name;
    private User() {}
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    public int getAge() { return age; }
    public void setAge(int age) { this.age = age; }
}

// 执行后输出：
age 对应的内存偏移地址: 12
name 对应的内存偏移地址: 16
---------------------
age: 29
name: zhang liang
```



### 创建超大数组

Java中数组的最大长度为Integer.MAX_VALUE，正常情况下如果想创建一个大于Integer.MAX_VALUE的数组是做不到的，但是Unsafe可以，通过对内存进行直接分配实现。

```java
public class BigArray {
    public static void main(String[] arg) throws Exception {

        // 由于安全限制，只有系统classloader才能使用getUnsafe()方法
        // 普通用户只能通过反射实例化Unsafe
        Field field = Unsafe.class.getDeclaredField("theUnsafe");
        field.setAccessible(true);
        Unsafe unsafe = (Unsafe) field.get(null);

        //只要内存够大，可以把这个调大，大于Integer.MAX_VALUE
        long size = (long) Integer.MAX_VALUE * 2;
        long addr = unsafe.allocateMemory(size);
        System.out.println("unsafe address :" + addr);

        for (int i = 0; i < size; i++) {
            unsafe.putByte(addr + i, (byte) 6);
            if (unsafe.getByte(addr + i) != 6) {
                System.out.println("failed at offset");
            }
        }
    }
}

// 运行结果
unsafe address :4754382848
```



### 线程挂起与恢复

将一个线程进行挂起是通过park方法实现的，调用 park后，线程将一直阻塞直到超时或者中断等条件出现。unpark可以终止一个挂起的线程，使其恢复正常。



整个并发框架中对线程的挂起操作被封装在 LockSupport类中，LockSupport类中有各种版本pack方法，但最终都调用了Unsafe.park()方法。

```java
import sun.misc.Unsafe;

import java.lang.reflect.Field;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.locks.LockSupport;

public class Lock {
    public static void main(String[] args) throws Exception {

        // 由于安全限制，只有系统classloader才能使用getUnsafe()方法
        // 普通用户只能通过反射实例化Unsafe
        Field field = Unsafe.class.getDeclaredField("theUnsafe");
        field.setAccessible(true);
        Unsafe unsafe = (Unsafe) field.get(null);

        WaitThread waitThread = new WaitThread(unsafe);
        waitThread.start();
        WorkThread workThread = new WorkThread(unsafe, waitThread);
        workThread.start();

        workThread.join();

        System.out.println("the end.");
    }
}

/**
 * 工作线程
 */
class WorkThread extends Thread {
    private Thread waitThread;
    private Unsafe unsafe;

    public WorkThread(Unsafe unsafe, Thread waitThread) {
        this.waitThread = waitThread;
        this.unsafe = unsafe;
    }

    public void run() {
        int i = 0;
        while (true) {
            if (i == 5) {
                System.out.println("WorkThread is now to wake WaitThread");
                unsafe.unpark(waitThread);

                break;
            }

            System.out.println("WorkThread is now working for " + (++i) + " s");

            try {
                TimeUnit.SECONDS.sleep(1);
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
    }
}

class WaitThread extends Thread {
    private Unsafe unsafe;

    public WaitThread(Unsafe unsafe) {
        this.unsafe = unsafe;
    }
  
    public void run() {
        System.out.println("Wait Thread is now going to block!");
        unsafe.park(false, 0);
        System.out.println("WaitThread is now awake");
    }
}

// 执行结果
Wait Thread is now going to block!
WorkThread is now working for 1 s
WorkThread is now working for 2 s
WorkThread is now working for 3 s
WorkThread is now working for 4 s
WorkThread is now working for 5 s
WorkThread is now to wake WaitThread
WaitThread is now awake
the end.
```





参考:

1. [sun.misc.Unsafe基于JDK7的源码](http://hg.openjdk.java.net/jdk7/jdk7/jdk/file/9b8c96f96a0f/src/share/classes/sun/misc/Unsafe.java)

2. [sun.misc.Unsafe的理解](http://www.cnblogs.com/chenpi/p/5389254.html)


2. [Java Magic. Part 4: sun.misc.Unsafe](http://ifeve.com/sun-misc-unsafe/)
3. [java-hidden-features](http://howtodoinjava.com/tag/java-hidden-features/)
4. [sun.misc.unsafe类的使用](http://blog.csdn.net/fenglibing/article/details/17138079)
5. [深入浅出 Java Concurrency (5): 原子操作 part 4](http://www.blogjava.net/xylz/archive/2010/07/04/325206.html)
6. [sun.misc.Unsafe的后启示录](http://www.infoq.com/cn/articles/A-Post-Apocalyptic-sun.misc.Unsafe-World)
7. [JAVA并发编程学习笔记之Unsafe类](http://blog.csdn.net/aesop_wubo/article/details/7537278)
8. [sun.misc.Unsafe源码解析](http://blog.csdn.net/dfdsggdgg/article/details/51538601)
9. [sun.misc.Unsafe的各种神技](http://blog.csdn.net/dfdsggdgg/article/details/51543545)
10. [Java的LockSupport.park()实现分析](http://blog.csdn.net/hengyunabc/article/details/28126139)