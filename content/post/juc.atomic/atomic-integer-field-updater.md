---
title: "AtomicIntegerFieldUpdater源码分析"
date: "2017-02-23T18:27:26+08:00"
categories: ["ABC_Atomic"]
tags: ["Java", "Atomic"]
draft: false
---

## 概述

在原子变量相关类中，`AtomicIntegerFieldUpdater`, `AtomicLongFieldUpdater`, `AtomicReferenceFieldUpdater`三个类是用于原子地修改对象的成员属性，它们的原理和用法类似，区别在于对Integer，Long，Reference类型的成员属性进行修改。本文重点研究`AtomicIntegerFieldUpdater`。



AtomicIntegerFieldUpdater的设计非常有意思。AtomicIntegerFieldUpdater本身是一个抽象类，只有一个受保护的构造函数，它本身不能被实例化。在AtomicIntegerFieldUpdater中定义了一些基本的模板方法，然后通过一个静态内部子类AtomicIntegerFieldUpdaterImpl来实现具体的操作。AtomicIntegerFieldUpdaterImpl中的相关操作也都是基于Unsafe类来实现的。



本文基于JDK1.7.0_67

> java version "1.7.0_67"
>
> _Java™ SE Runtime Environment (build 1.7.0_67-b01)
>
> Java HotSpot™ 64-Bit Server VM (build 24.65-b04, mixed mode)



## 内部类

AtomicIntegerFieldUpdater本身是一个抽象类，通过一个静态内部子类来实现相关的操作。

```java
private static class AtomicIntegerFieldUpdaterImpl<T> extends AtomicIntegerFieldUpdater<T>
```



### 成员变量

`AtomicIntegerFieldUpdater`是个抽象类，具体的业务逻辑都是交给它的子类实现的，它本身没有包含任何成员变量。



## 函数列表

```java
// 受保护的无操作构造函数，供子类使用
protected AtomicIntegerFieldUpdater()
// 为对象创建并返回一个具有给定字段的更新器。
public static <U> AtomicIntegerFieldUpdater<U> newUpdater(Class<U> tclass, String fieldName)
// 以原子方式设置当前值为update
// 如果当前值等于expect，并设置成功，返回true
// 如果当前值不等于expect，则设置失败，返回false
// 该过程通过CAS实现，不阻塞
public abstract boolean compareAndSet(T obj, int expect, int update)
// 以原子方式设置当前值为update
// 如果当前值等于expect，并设置成功，返回true
// 如果当前值不等于expect，则设置失败，返回false
// 该过程通过CAS实现，不阻塞
// 该过程不保证volatile成员的happens-before语义顺序
public abstract boolean weakCompareAndSet(T obj, int expect, int update)
// 以原子方式设置当前值为newValue
// 使用Unsafe类的putIntVolatile进行操作，具有原子性
public abstract void set(T obj, int newValue)
// 以原子方式设置当前值为newValue
// 使用Unsafe类的putOrderedInt进行操作，所以本身具有原子性
public abstract void lazySet(T obj, int newValue)
// 以原子方式获取当前值
// 使用Unsafe类的getIntVolatile进行操作，所以本身具有原子性
public abstract int get(T obj)
// 以原子方式设置当前值为newValue，并返回更新前的值
// 使用Unsafe类的compareAndSwapInt进行操作，所以本身具有原子性
// 操作过程中使用自旋方式，直到操作成功
public int getAndSet(T obj, int newValue)
// 以原子方式将当前值加1，并返回更新前的值
// 使用Unsafe类的compareAndSwapInt进行操作，所以本身具有原子性
// 操作过程中使用自旋方式，直到操作成功
public int getAndIncrement(T obj)
// 以原子方式将当前值减1，并返回更新前的值
// 使用Unsafe类的compareAndSwapInt进行操作，所以本身具有原子性
// 操作过程中使用自旋方式，直到操作成功
public int getAndDecrement(T obj)
// 以原子方式将当前值加上给定值delta，并返回更新前的值
// 使用Unsafe类的compareAndSwapInt进行操作，所以本身具有原子性
// 操作过程中使用自旋方式，直到操作成功
public int getAndAdd(T obj, int delta)
// 以原子方式将当前值加1，并返回更新后的值
// 使用Unsafe类的compareAndSwapInt进行操作，所以本身具有原子性
// 操作过程中使用自旋方式，直到操作成功
public int incrementAndGet(T obj)
// 以原子方式将当前值减1，并返回更新前的值
// 使用Unsafe类的compareAndSwapInt进行操作，所以本身具有原子性
// 操作过程中使用自旋方式，直到操作成功
public int decrementAndGet(T obj)
// 以原子方式将当前值加上给定值delta，并返回更新后的值
// 使用Unsafe类的compareAndSwapInt进行操作，所以本身具有原子性
// 操作过程中使用自旋方式，直到操作成功
public int addAndGet(T obj, int delta)
```



## 重点函数分析

### newUpdater

为对象创建并返回一个具有给定字段的更新器实例。在该方法中，直接构造一个AtomicIntegerFieldUpdaterImpl实例。

```java
public static <U> AtomicIntegerFieldUpdater<U> newUpdater(Class<U> tclass, String fieldName) {
        return new AtomicIntegerFieldUpdaterImpl<U>(tclass, fieldName, Reflection.getCallerClass());
    }
```



### AtomicIntegerFieldUpdater

受保护的无操作构造函数，供子类实现。AtomicIntegerFieldUpdaterImpl是唯一的子类，我们来看一下他是怎么实现的。在构造函数中，首先获取要更新的类(tclass)的指定成员变量fieldName的访问策略(Modifier: public, private, default, protected)，然后检查调用类(caller)是否有权限访问该成员变量fieldName，如果没有权限则抛出异常。接下来，判断指定的成员变量fieldName的类型是否是long，如果不是，也抛出异常。接下来，判断当前指定的成员变量是否是volatile类型的，如果不是，也抛出异常。接下来，实例化调用者类cclass，和操作目标类tclass。最后，计算指定成员变量fieldName的内存偏移值。

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

AtomicIntegerFieldUpdaterImpl(Class<T> tclass, String fieldName, Class<?> caller) {
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

  	// 当前成员变量的类型必须是int
    Class fieldt = field.getType();
    if (fieldt != int.class)
      	throw new IllegalArgumentException("Must be integer type");

  	// 当前成员变量必须是volatile修饰
    if (!Modifier.isVolatile(modifiers))
      	throw new IllegalArgumentException("Must be volatile type");
	// 设置调用者类
    this.cclass = (Modifier.isProtected(modifiers) &&
                   caller != tclass) ? caller : null;
    // 设置目标操作类
  	this.tclass = tclass;
	// 设置成员变量的内存偏移值
    offset = unsafe.objectFieldOffset(field);
}
```



### weakCompareAndSet

以原子方式设置当前值为update。如果当前值等于expect，并设置成功，返回true。如果当前值不等于expect，则设置失败，返回false。

weakCompareAndSet的实现与compareAndSet完全相同，但是，在JDK文档中声明，weakCompareAndSet不保证volatile的happens-before内存顺序性语义，这是它们的区别。



在`AtomicIntegerFieldUpdater`类中，这是一个抽象方法。具体的实现在子类AtomicIntegerFieldUpdaterImpl提供。

```java
public abstract boolean weakCompareAndSet(T obj, int expect, int update);
```

AtomicIntegerFieldUpdaterImpl中weakCompareAndSet方法的实现如下：

```java
public boolean weakCompareAndSet(T obj, int expect, int update) {
	if (obj == null || obj.getClass() != tclass || cclass != null) fullCheck(obj);
	return unsafe.compareAndSwapInt(obj, offset, expect, update);
}
```



### compareAndSet

以原子方式设置当前值为update。如果当前值等于expect，并设置成功，返回true。如果当前值不等于expect，则设置失败，返回false。

在`AtomicIntegerFieldUpdater`类中，这是一个抽象方法。具体的实现在子类AtomicIntegerFieldUpdaterImpl提供。

```java
public abstract boolean compareAndSet(T obj, int expect, int update);
```

AtomicIntegerFieldUpdaterImpl中的compareAndSet方法的实现如下：

```java
public boolean compareAndSet(T obj, int expect, int update) {
	if (obj == null || obj.getClass() != tclass || cclass != null) fullCheck(obj);
	return unsafe.compareAndSwapInt(obj, offset, expect, update);
}

private void fullCheck(T obj) {
    if (!tclass.isInstance(obj))
      	throw new ClassCastException();
    if (cclass != null)
      	ensureProtectedAccess(obj);
}

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



### get

以原子方式获取当前值。通过Unsafe的getIntVolatile保证原则性。

在`AtomicIntegerFieldUpdater`类中，这是一个抽象方法。具体的实现在子类AtomicIntegerFieldUpdaterImpl提供。

```java
public abstract int get(T obj);
```

AtomicIntegerFieldUpdaterImpl中的get方法的实现如下：

```java
public final int get(T obj) {
	if (obj == null || obj.getClass() != tclass || cclass != null) fullCheck(obj);
	return unsafe.getIntVolatile(obj, offset);
}
```



### set

以原子方式设置当前值为newValue。通过Unsafe的putIntVolatile保证原子性。

在`AtomicIntegerFieldUpdater`类中，这是一个抽象方法。具体的实现在子类AtomicIntegerFieldUpdaterImpl提供。

```java
public abstract void set(T obj, int newValue);
```

AtomicIntegerFieldUpdaterImpl中的set方法的实现如下。

```java
public void set(T obj, int newValue) {
	if (obj == null || obj.getClass() != tclass || cclass != null) fullCheck(obj);
	unsafe.putIntVolatile(obj, offset, newValue);
}
```



### lazySet

以原子方式设置当前值为newValue。与set方法的区别在于使用Unsafe类的putOreredInt保证原子性，同时该方法优先保证数据的更新，而不保证可见性，效率高。

在`AtomicIntegerFieldUpdater`类中，这是一个抽象方法。具体的实现在子类AtomicIntegerFieldUpdaterImpl提供。

```java
public abstract void lazySet(T obj, int newValue);
```

AtomicIntegerFieldUpdaterImpl中的lazySet方法的实现如下：

```java
public void lazySet(T obj, int newValue) {
  	if (obj == null || obj.getClass() != tclass || cclass != null) fullCheck(obj);
  	unsafe.putOrderedInt(obj, offset, newValue);
}
```



### getAndSet

以原子方式将当前值更新为newValue，并返回更新前的值。

在`AtomicIntegerFieldUpdater`类中，这是一个模板方法。该方法通过自旋的方式循环调用compareAndSet方法，直到操作成功。

```java
public int getAndSet(T obj, int newValue) {
  for (;;) {
    int current = get(obj);
    if (compareAndSet(obj, current, newValue))
    	return current;
  }
}
```



类似的方法还有如下几个，它们的实现大同小异，不在一一列举：

```java
public int getAndSet(T obj, int newValue)
public int getAndIncrement(T obj)
public int getAndDecrement(T obj)
public int getAndAdd(T obj, int delta)
public int incrementAndGet(T obj)
public int decrementAndGet(T obj)
public int addAndGet(T obj, int delta)
```

