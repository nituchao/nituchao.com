---
"title": "AtomicStampedReference源码分析",
"date": "2017-02-23T18:30:27+08:00",
"categories": ["ABC_Atomic"],
"tags": ["Java", "Atomic"]
---

## 概述

在原子变量相关类中，AtomicReference, AtomicStampedReference, AtomicMarkableReference三个类是对于引用类型的操作，其原理和用法类似。

`AtomicStampedReference`是带了整型版本号(int stamp)的引用型原子变量，每次执行CAS操作时需要对比版本，如果版本满足要求，则操作成功，否则操作失败，用于防止CAS操作的ABA问题。本文重点分析`AtomicStampedReference`。



`AtomicMarkableReference`则是带了布尔型标记位(Boolean mark)的引用型原子量，每次执行CAS操作是需要对比该标记位，如果标记满足要求，则操作成功，否则操作失败。



Java原子变量的实现依赖于`sun.misc.Unsafe`的CAS操作和volatile的内存可见性语义。



本文基于JDK1.7.0_67

> java version "1.7.0_67"_
>
> _Java(TM) SE Runtime Environment (build 1.7.0_67-b01)
>
> Java HotSpot(TM) 64-Bit Server VM (build 24.65-b04, mixed mode)



### 内部类

`AtomicStampedReference`是带整形版本号的原子引用类型，为了同时兼顾引用值和版本号，它定义了一个静态内部类`Pair`，`AtomicStampedReference`的相关操作都是对`Pair`内成员的操作。

```java
private static class Pair<T> {
    final T reference;
    final int stamp;
    private Pair(T reference, int stamp) {
        this.reference = reference;
        this.stamp = stamp;
    }
    static <T> Pair<T> of(T reference, int stamp) {
      	return new Pair<T>(reference, stamp);
    }
}
```



## 成员变量

`AtomicStampedReference`除了常规的`sun.misc.Unsafe`实例和`pairOffset`内存偏移量外，声明了一个`volatile`的`Pair<T>`成员，用于同时维护引用值和版本号。

```java
// 成员变量unsafe是原子变量相关操作的基础
// 原子变量的修改操作最终有sun.misc.Unsafe类的CAS操作实现
private static final sun.misc.Unsafe UNSAFE = Unsafe.getUnsafe();
// 成员变量value的内存偏移值
private static final long pairOffset = objectFieldOffset(UNSAFE, "pair", AtomicStampedReference.class);
// 用volatile的内存语义保证可见性
// 保存引用值和版本号
private volatile Pair<V> pair;

// 获取指定域的内存偏移量
static long objectFieldOffset(sun.misc.Unsafe UNSAFE,
                              String field, Class<?> klazz) {
    try {
        return UNSAFE.objectFieldOffset(klazz.getDeclaredField(field));
    } catch (NoSuchFieldException e) {
        // Convert Exception to corresponding Error
        NoSuchFieldError error = new NoSuchFieldError(field);
        error.initCause(e);
        throw error;
    }
}
```



## 函数列表

由于`AtomicStampedReference`要同时维护引用值和版本号，因此很多操作变得复杂。

```java
// 构造函数，初始化引用和版本号
public AtomicStampedReference(V initialRef, int initialStamp)
// 以原子方式获取当前引用值
public V getReference()
// 以原子方式获取当前版本号
public int getStamp()
// 以原子方式获取当前引用值和版本号
public V get(int[] stampHolder)
// 以原子的方式同时更新引用值和版本号
// 当期望引用值不等于当前引用值时，操作失败，返回false
// 当期望版本号不等于当前版本号时，操作失败，返回false
// 在期望引用值和期望版本号同时等于当前值的前提下
// 当新的引用值和新的版本号同时等于当前值时，不更新，直接返回true
// 当新的引用值和新的版本号不同时等于当前值时，同时设置新的引用值和新的版本号，返回true
// 该过程不保证volatile成员的happens-before语义顺序
public boolean weakCompareAndSet(V  expectedReference,
                                 V  newReference,
                                 int expectedStamp,
                                 int newStamp)
// 以原子的方式同时更新引用值和版本号
// 当期望引用值不等于当前引用值时，操作失败，返回false
// 当期望版本号不等于当前版本号时，操作失败，返回false
// 在期望引用值和期望版本号同时等于当前值的前提下
// 当新的引用值和新的版本号同时等于当前值时，不更新，直接返回true
// 当新的引用值和新的版本号不同时等于当前值时，同时设置新的引用值和新的版本号，返回true
public boolean compareAndSet(V   expectedReference,
                             V   newReference,
                             int expectedStamp,
                             int newStamp)
// 以原子方式设置引用的当前值为新值newReference
// 同时，以原子方式设置版本号的当前值为新值newStamp
// 新引用值和新版本号只要有一个跟当前值不一样，就进行更新
public void set(V newReference, int newStamp)
// 以原子方式设置版本号为新的值
// 前提：引用值保持不变
// 当期望的引用值与当前引用值不相同时，操作失败，返回fasle
// 当期望的引用值与当前引用值相同时，操作成功，返回true
public boolean attemptStamp(V expectedReference, int newStamp)
// 使用`sun.misc.Unsafe`类原子地交换两个对象
private boolean casPair(Pair<V> cmp, Pair<V> val)
```



## 重点函数分析

### AtomicStampedReference

```java
public AtomicStampedReference(V initialRef, int initialStamp) {
  	pair = Pair.of(initialRef, initialStamp);
}
```

构造函数，根据指定的引用值和版本号，构造一个Pair对象，并将该对象赋值给成员变量`pair`。

由于成员变量`pair`被volatile修饰，并且这里只有一个单操作的赋值语句，因此是可以保证原子性的。



### get

```java
public V get(int[] stampHolder) {
    Pair<V> pair = this.pair;
    stampHolder[0] = pair.stamp;
    return pair.reference;
}
```

真个函数很有意思，同时获取引用值和版本号。由于Java程序只能有一个返回值，该函数通过一个数组参数`int[] stampHolder`来返回版本号，而通过`return`语句返回引用值。



### set

```java
public void set(V newReference, int newStamp) {
	Pair<V> current = pair;
	if (newReference != current.reference || newStamp != current.stamp)
		this.pair = Pair.of(newReference, newStamp);
}
```

只要新的引用值和新的版本号，有一个与当前值不一样的，就同时修改引用值和版本号。



### compareAndSet

```java
public boolean compareAndSet(V   expectedReference,
                             V   newReference,
                             int expectedStamp,
                             int newStamp) {
 	Pair<V> current = pair;
 	return
 		expectedReference == current.reference &&
 		expectedStamp == current.stamp &&
 		((newReference == current.reference &&
 		  newStamp == current.stamp) ||
 		  casPair(current, Pair.of(newReference, newStamp)));
 }
```

以原子的方式同时更新引用值和版本号。

当期望引用值不等于当前引用值时，操作失败，返回false。

当期望版本号不等于当前版本号时，操作失败，返回false。

在期望引用值和期望版本号同时等于当前值的前提下，当新的引用值和新的版本号同时等于当前值时，不更新，直接返回true。由于要修改的内容与原内容完全一致，这种处理可以避免一次内存操作，效率较高。

当新的引用值和新的版本号不同时等于当前值时，同时设置新的引用值和新的版本号，返回true



### weakCompareAndSet

```java
public boolean weakCompareAndSet(V   expectedReference,
                                 V   newReference,
                                 int expectedStamp,
                                 int newStamp) {
  	return compareAndSet(expectedReference, newReference,
                       	 expectedStamp, newStamp);
}
```

以原子的方式同时更新引用值和版本号。该是通过调用CompareAndSet实现的。JDK文档中说，weakCompareAndSet在更新变量时并不创建任何`happens-before`顺序，因此即使要修改的值是volatile的，也不保证对该变量的读写操作的顺序（一般来讲，volatile的内存语义保证`happens-before`顺序）。



### attemptStamp

```java
public boolean attemptStamp(V expectedReference, int newStamp) {
  	Pair<V> current = pair;
  	return
    	expectedReference == current.reference &&
    	(newStamp == current.stamp ||
     	 casPair(current, Pair.of(expectedReference, newStamp)));
}
```

修改指定引用值的版本号。

当期望的引用值与当前引用值不相同时，操作失败，返回fasle。
当期望的引用值与当前引用值相同时，操作成功，返回true。



### casPair

```java
private boolean casPair(Pair<V> cmp, Pair<V> val) {
  	return UNSAFE.compareAndSwapObject(this, pairOffset, cmp, val);
}
```

使用`sun.misc.Unsafe`类原子地交换两个对象。
