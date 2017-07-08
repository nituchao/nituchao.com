---
title: "AtomicLongFieldUpdater源码分析"
date: "2017-02-23T18:27:27+08:00"
categories: ["ABC_Atomic"]
tags: ["Java", "Atomic"]
draft: false
---

## 概述

在原子变量相关类中，`AtomicIntegerFieldUpdater`, `AtomicLongFieldUpdater`, `AtomicReferenceFieldUpdater`三个类是用于原子地修改对象的成员属性，它们的原理和用法类似，区别在于对Integer，Long，Reference类型的成员属性进行修改。本文重点研究AtomicLongFieldUpdater。



AtomicLongFieldUpdater的设计非常有意思。AtomicLongFieldUpdater本身是一个抽象类，只有一个受保护的构造函数，它本身不能被实例化。



AtomicLongFieldUpdater有两个私有的静态内部类`CASUpdater`和`LockedUpdater`，它们都是`AtomicLongFieldUpdater`的子类。

用户使用`AtomicLongFieldUpdater`公共静态方法`newUpdater`实例化`AtomicLongFieldUpdater`的对象，本质是上是根据条件实例化了子类`CASUpdater`或者`LockedUpdater`，然后通过子类来完成具体的工作。`CASUpdater`和`LockedUpdater`值的读取和更新最后都是使用`sun.misc.Unsafe`类的相关操作。



`CASUpdater`使用下面的方法：

```java
public native Object getLongVolatile(Object o, long offset);
public native void   putLongVolatile(Object o, long offset, long x);
```

LockedUpdater使用下面的方法：

```java
public native long    getLong(Object o, long offset);
public native void    putLong(Object o, long offset, long x);
```

为了防止操作过程中的指令重排，LockedUpdater使用synchronized进行同步。





本文基于JDK1.7.0_67

> java version "1.7.0_67"
>
> _Java™ SE Runtime Environment (build 1.7.0_67-b01)
>
> Java HotSpot™ 64-Bit Server VM (build 24.65-b04, mixed mode)



## 内部类

`AtomicLongFieldUpdater`本身是抽象类，通过两个私有的静态内部子类来完成具体的工作。

* `CASUpdater`：顾名思义，使用CAS操作对象的成员变量。
* LockedUpdater：顾名思义，在更新和读取对象的成员变量时，使用对象锁来保证同步。



## 成员变量

`AtomicLongFieldUpdater`是个抽象类，具体的业务逻辑都是交给它的子类实现的，它本身没有包含任何成员变量。



## 函数列表

`AtomicLongFieldUpdater`采用模板方法，它本身定义了一些操作过程，而其中使用的具体的方法则由各个子类实现。

```java
// 受保护的无操作构造函数，供子类使用
protected AtomicLongFieldUpdater()
// 为对象创建并返回一个具有给定字段的更新器。
public static <U> AtomicLongFieldUpdater<U> newUpdater(Class<U> tclass, String fieldName)
// 以原子方式设置当前值为update。
// 如果当前值等于expect，并设置成功，返回true
// 如果当前值不等于expect，则设置失败，返回false
// CASUpdater的实现该不阻塞
// LockedUpdater的实现通过synchronized进行同步，会阻塞
public abstract boolean compareAndSet(T obj, long expect, long update)
// 以原子方式设置当前值为update。
// 如果当前值等于expect，并设置成功，返回true
// 如果当前值不等于expect，则设置失败，返回false
// CASUpdater的实现该不阻塞
// LockedUpdater的实现通过synchronized进行同步，会阻塞
// 该过程不保证volatile成员的happens-before语义顺序
public abstract boolean weakCompareAndSet(T obj, long expect, long update)
// 以原子方式设置当前值为newValue
// CASUpdater的实现使用Unsafe类的putLongVolatile进行操作，具有原子性
// LockedUpdater的实现使用synchronizde和Unsafe类的putLong进行操作，具有原子性
public abstract void set(T obj, long newValue)
// 以原子方式设置当前值为newValue
// CASUpdater的实现使用Unsafe类的putOrderedLong进行操作，所以本身具有原子性
// LockedUpdater的实现使用synchronizde和Unsafe类的putLong进行操作，具有原子性
// 优先保证对值的修改，而不保证可见性
public abstract void lazySet(T obj, long newValue)
// 以原子方式获取当前值
// CASUpdater的实现使用Unsafe类的getLongVolatile进行操作，所以本身具有原子性
// LockedUpdater的实现使用synchronizde和Unsafe类的getLong进行操作，具有原子性
public abstract long get(T obj)
// 以原子方式设置当前值为newValue，并返回更新前的值
// CASUpdater的实现使用Unsafe类的compareAndSwapLong进行操作，所以本身具有原子性
// LockedUpdater的实现使用synchronizde和Unsafe类的putLong进行操作，具有原子性
// 操作过程中使用自旋方式，直到操作成功
public long getAndSet(T obj, long newValue)
// 以原子方式将当前值加1，并返回更新前的值
// CASUpdater的实现使用Unsafe类的compareAndSwapLong进行操作，所以本身具有原子性
// LockedUpdater的实现使用synchronizde和Unsafe类的putLong进行操作，具有原子性
// 操作过程中使用自旋方式，直到操作成功
public long getAndIncrement(T obj)
// 以原子方式将当前值减1，并返回更新前的值
// CASUpdater的实现使用Unsafe类的compareAndSwapLong进行操作，所以本身具有原子性
// LockedUpdater的实现使用synchronizde和Unsafe类的putLong进行操作，具有原子性
// 操作过程中使用自旋方式，直到操作成功
public long getAndDecrement(T obj)
// 以原子方式将当前值加上给定值delta，并返回更新前的值
// CASUpdater的实现使用Unsafe类的compareAndSwapLong进行操作，所以本身具有原子性
// LockedUpdater的实现使用synchronizde和Unsafe类的putLong进行操作，具有原子性
// 操作过程中使用自旋方式，直到操作成功
public long getAndAdd(T obj, long delta)
// 以原子方式将当前值加1，并返回更新后的值
// CASUpdater的实现使用Unsafe类的compareAndSwapLong进行操作，所以本身具有原子性
// LockedUpdater的实现使用synchronizde和Unsafe类的putLong进行操作，具有原子性
// 操作过程中使用自旋方式，直到操作成功
public long incrementAndGet(T obj)
// 以原子方式将当前值减1，并返回更新前的值
// CASUpdater的实现使用Unsafe类的compareAndSwapLong进行操作，所以本身具有原子性
// LockedUpdater的实现使用synchronizde和Unsafe类的putLong进行操作，具有原子性
// 操作过程中使用自旋方式，直到操作成功
public long decrementAndGet(T obj)
// 以原子方式将当前值加上给定值delta，并返回更新后的值
// CASUpdater的实现使用Unsafe类的compareAndSwapLong进行操作，所以本身具有原子性
// LockedUpdater的实现使用synchronizde和Unsafe类的putLong进行操作，具有原子性
// 操作过程中使用自旋方式，直到操作成功
public long addAndGet(T obj, long delta)
```

## 重点函数分析

### newUpdater

为对象创建并返回一个具有给定字段的更新器实例。由于要操作long型数据，因此要根据虚拟机是否支持原子化更新long来创建对于的子类。当虚拟机支持原子化更新long时，创建CASUpdater实例。否则，创LockedUpdater实例，32位虚拟机不支持对long的原子化更新，因此，只能使用对象锁来保证原子操作。

```java
public static <U> AtomicLongFieldUpdater<U> newUpdater(Class<U> tclass, String fieldName) {
    Class<?> caller = Reflection.getCallerClass();
    if (AtomicLong.VM_SUPPORTS_LONG_CAS)
      	return new CASUpdater<U>(tclass, fieldName, caller);
    else
      	return new LockedUpdater<U>(tclass, fieldName, caller);
}
```



### AtomicLongFieldUpdater

受保护的无操作构造函数，供子类实现。无论是`CASUpdater`还是`LockedUpdater`，都包含了下面四个成员变量，它们构造函数的实现也是一样的，我们只分析其中CASUpdater的实现。

在构造函数中，首先获取要更新的类的指定成员变量fieldName的访问策略(Modifier: public, private, default, protected)，然后检查调用类(caller)是否有权限访问该成员变量fieldName，如果没有权限则抛出异常。接下来，判断指定的成员变量fieldName的类型是否是long，如果不是，也抛出异常。接下来，判断当前指定的成员变量是否是volatile类型的，如果不是，也抛出异常。接下来，实例化调用者类cclass，和操作目标类tclass。最后，计算指定成员变量fieldName的内存偏移值。

```java
// 成员变量unsafe是原子变量相关操作的基础
// 原子变量的修改操作最终有sun.misc.Unsafe类的CAS操作实现
private static final Unsafe unsafe = Unsafe.getUnsafe();
// 成员变量fieldName的内存偏移值，在构造函数中初始化
private final long offset;
// 操作目标类，对该类中的fieldName字段进行更新
private final Class<T> tclass;
// 调用者类，通过反射获取
private final Class cclass;

CASUpdater(Class<T> tclass, String fieldName, Class<?> caller) {
    Field field = null;
    int modifiers = 0;
    try {
      	// 获取要更新的类的指定成员变量fieldName的访问策略
        field = tclass.getDeclaredField(fieldName);
        modifiers = field.getModifiers();
      	// 验证访问策略
        sun.reflect.misc.ReflectUtil.ensureMemberAccess(
          	caller, tclass, null, modifiers);
        sun.reflect.misc.ReflectUtil.checkPackageAccess(tclass);
    } catch (Exception ex) {
      	throw new RuntimeException(ex);
    }

  	// 当前成员变量的类型必须是long
    Class fieldt = field.getType();
    if (fieldt != long.class)
      	throw new IllegalArgumentException("Must be long type");

  	// 当前成员变量必须是volatile修饰
    if (!Modifier.isVolatile(modifiers))
      	throw new IllegalArgumentException("Must be volatile type");

  	// 设置调用者类
    this.cclass = (Modifier.isProtected(modifiers) &&
                   caller != tclass) ? caller : null;
  	// 设置操作目标类
    this.tclass = tclass;
  	// 设置成员变量的内存偏移值
    offset = unsafe.objectFieldOffset(field);
}
```



### weakCompareAndSet

以原子方式设置当前值为update。如果当前值等于expect，并设置成功，返回true。如果当前值不等于expect，则设置失败，返回false。

weakCompareAndSet是通过调用compareAndSet实现的，但是，在JDK文档中声明，weakCompareAndSet不保证volatile的happens-before内存顺序性语义，这是它们的区别。



在`AtomicLongFieldUpdater`类中，这是一个抽象方法。`CASUpdater`和`LockedUpdater`有各自的实现。

```java
public abstract boolean weakCompareAndSet(T obj, long expect, long update);
```



### compareAndSet

以原子方式设置当前值为update。如果当前值等于expect，并设置成功，返回true。如果当前值不等于expect，则设置失败，返回false。

在`AtomicLongFieldUpdater`类中，这是一个抽象方法。`CASUpdater`和`LockedUpdater`有各自的实现。

```java
public abstract boolean compareAndSet(T obj, long expect, long update);
```



#### CASUpdater的实现

当JVM支持long的原子更新时，CASUpdater选择用Unsafe类的`compareAndSwapLong`方法来直接原子地比较期望值并更新当前值。

```java
public boolean compareAndSet(T obj, long expect, long update) {
    if (obj == null || obj.getClass() != tclass || cclass != null) fullCheck(obj);
    	return unsafe.compareAndSwapLong(obj, offset, expect, update);
}

// 类型检查&访问检查
private void fullCheck(T obj) {
	if (!tclass.isInstance(obj))
    	throw new ClassCastException();
  	if (cclass != null)
    	ensureProtectedAccess(obj);
}

// 访问检查
private void ensureProtectedAccess(T obj) {
    if (cclass.isInstance(obj)) {
      	return;
    }
    throw new RuntimeException(
      	new IllegalAccessException("Class " +
            cclass.getName() +
            " can not access a protected member of class " +
            tclass.getName() +
            " using an instance of " +
            obj.getClass().getName()
            )
    );
}
```



#### LockedUpdater的实现

当JVM不支持long的原子更新时，LockedUpdater选择用synchronized对象锁来同步更新操作，其中涉及到当前值是否等于预期值expect，如果相等，则更新，并返回true，否则，不更新，返回false。

```java
public boolean compareAndSet(T obj, long expect, long update) {
	if (obj == null || obj.getClass() != tclass || cclass != null) fullCheck(obj);
    synchronized (this) {
        long v = unsafe.getLong(obj, offset);
        if (v != expect)
            return false;
        unsafe.putLong(obj, offset, update);
        return true;
    }
}
```



### get

以原子方式获取当前值。

在`AtomicLongFieldUpdater`类中，这是一个抽象方法。`CASUpdater`和`LockedUpdater`有各自的实现。

```java
public long get(T obj);
```



#### CASUpdater的实现

当JVM支持long的原子更新时，CASUpdater选择用Unsafe类的getLongVolatile方法来直接原子地获取当前值。

```java
public long get(T obj) {
    if (obj == null || obj.getClass() != tclass || cclass != null) fullCheck(obj);
    return unsafe.getLongVolatile(obj, offset);
}
```



#### LockedUpdater的实现

当JVM不支持long的原子更新时，LockedUpdater选择用synchronized对象锁来同步更新操作。

```java
public long get(T obj) {
    if (obj == null || obj.getClass() != tclass || cclass != null) fullCheck(obj);
    synchronized (this) {
        return unsafe.getLong(obj, offset);
    }
}
```



### set

以原子方式设置当前值为newValue。


在`AtomicLongFieldUpdater`类中，这是一个抽象方法。`CASUpdater`和`LockedUpdater`有各自的实现。

```java
public abstract void set(T obj, long newValue);
```



#### CASUpdater的实现

当JVM支持long的原子更新时，CASUpdater选择用Unsafe类的putLongVolatile方法来直接原子地更新当前值。

```java
public void set(T obj, long newValue) {
	if (obj == null || obj.getClass() != tclass || cclass != null) fullCheck(obj);
    unsafe.putLongVolatile(obj, offset, newValue);
}
```



#### LockedUpdater的实现

当JVM不支持long的原子更新时，LockedUpdater选择用synchronized对象锁来同步更新操作。

```java
public void set(T obj, long newValue) {
	if (obj == null || obj.getClass() != tclass || cclass != null) fullCheck(obj);
    synchronized (this) {
	    unsafe.putLong(obj, offset, newValue);
    }
}
```



### lazySet

以原子方式设置当前值为newValue。与set方法不同之处在于，lazySet优先保证更新数据，而不保证可见性。因此，更新效率高于set。但是，这种保证只是JDK的设计声明，在子类的实现中，要具体情况具体分析。比如LockedUpdater的lazySet就是调用set方法实现的，本质上一样。



在`AtomicLongFieldUpdater`类中，这是一个抽象方法。`CASUpdater`和`LockedUpdater`有各自的实现。

```java
public abstract void lazySet(T obj, long newValue);
```



#### CASUpdater的实现

当JVM支持long的原子更新时，CASUpdater选择用Unsafe类的putOrderedLong方法来直接原子地更新当前值。并且，该方法优先保证更新数据，而不保证可见性。效率比putLong高3倍。

```java
public void lazySet(T obj, long newValue) {
	if (obj == null || obj.getClass() != tclass || cclass != null) fullCheck(obj);
	unsafe.putOrderedLong(obj, offset, newValue);
}
```



#### LockedUpdater的实现

当JVM不支持long的原子更新时，LockedUpdater选择调用set方法进行更新，set方法则使用synchronized对象锁来同步更新操作。在LockedUpdater中set方法和lazySet方法没有区别。

```java
public void lazySet(T obj, long newValue) {
	set(obj, newValue);
}
```



### getAndSet

以原子方式设置当前值为newValue，并返回更新前的值。

这是一个模板方法，通过在自旋循环中反复调用compareAndSet方法进行操作，而compareAndSet则在不同的子类中有不同的实现。

```java
public long getAndSet(T obj, long newValue) {
  for (;;) {
    long current = get(obj);
    if (compareAndSet(obj, current, newValue))
    	return current;
  }
}
```



类似的方法还有：

```java
public long getAndIncrement(T obj)
public long getAndDecrement(T obj)
public long getAndAdd(T obj, long delta)
public long incrementAndGet(T obj)
public long decrementAndGet(T obj)
public long addAndGet(T obj, long delta)
```

