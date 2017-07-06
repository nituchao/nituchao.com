---
title: "ConcurrentHashMap源码分析"
date: "2017-02-23T18:26:27+08:00"
categories: ["Concurrent"]
tags: ["Java", "Concurrent"]
draft: false
---

## 一言

ConcurrentHashMap是线程安全的、高效的哈希表。默认支持16个并发级别，并发级别在初始化后不能扩展。

## 概述

**HashMap**是非线程安全的哈希表，常用于单线程程序中。

**Hashtable**是线程安全的哈希表，它是通过synchronized来保证线程安全的；多线程通过同一个“对象的同步锁”来实现并发控制。Hashtable在线程竞争激烈时，效率比较低(此时建议使用ConcurrentHashMap)！因为当一个线程访问Hashtable的同步方法时，其它线程就访问Hashtable的同步方法时，可能会进入阻塞状态。

**ConcurrentHashMap**是线程安全的哈希表，它是通过“锁分段”来保证线程安全的。ConcurrentHashMap将哈希表分成许多片段(Segment)，每一个片段除了保存哈希表之外，本质上也是一个“可重入的互斥锁”(ReentrantLock)。多线程对同一个片段的访问，是互斥的；但是，对于不同片段的访问，却是可以同步进行的。



## ConcurrentHashMap数据结构

要想搞清ConcurrentHashMap，必须先弄清楚它的数据结构：

`图`

**说明:**

1. ConcurrentHashMap继承于AbstractMap抽象类。
2. Setment是ConcurrentHashMap的内部类，它就是ConcurrentHashMap中的"锁分段"对应的数据结构。ConcurrentHashMap与Segment是组合关系，1个ConcurrentHashMap对象包含若干个Segment对象。在代码中，这表现为ConcurrentHashMap类中存在"Segment数组"成员。
3. Segment类继承于ReentrantLock类，所以Segment本质上是一个可重入的互斥锁。
4. HashEntry也是ConcurrentHashMap的内部类，是单向链表节点，存储着key-value键值对。Segment与HashEntry是组合关系，Segment类中存在“HashEntry数组”成员，“HashEntry数组”中的每个HashEntry就是一个单向链表。

对于多线程访问对一个“哈希表对象”竞争资源，Hashtable是通过一把锁来控制并发；而ConcurrentHashMap则是将哈希表分成许多片段，对于每一个片段分别通过一个互斥锁来控制并发。ConcurrentHashMap对并发的控制更加细腻，它也更加适应于高并发场景！



## ConcurrentHashMap常量定义

```java
// 默认初始容量(HashEntry的个数)
static final int DEFAULT_INITIAL_CAPACITY = 16;
// 默认负载因子
static final float DEFAULT_LOAD_FACTOR = 0.75f;
// 默认并发级别
static final int DEFAULT_CONCURRENCY_LEVEL = 16;
// 最大容量(HashEntry的个数)
static final int MAXIMUM_CAPACITY = 1 << 30;
// 每个段(Segment)中HashEntry数组(table)的最小容量
// 设置最小为2，是为了防止构造完成后立即resize
static final int MIN_SEGMENT_TABLE_CAPACITY = 2;
// 段的最大个数
static final int MAX_SEGMENTS = 1 << 16; // slightly conservative
// 在计算size时，先尝试不获取段锁计算，最多尝试RETRIES_BEFORE_LOCK次。
// 如果重试超过RETRIES_BEFORE_LOCK次，则获取段锁后进行计算。
static final int RETRIES_BEFORE_LOCK = 2;

```



## ConcurrentHashMap成员变量

```java
// 制造一个随机值，使得在计算key的hash值时不容易出现冲突。
// 该值通过sun.misc.Hashing.randomHashSeed(instance)生成。
private transient final int hashSeed = randomHashSeed(this);
// 段segment的掩码，用于计算key所在segments索引值。
final int segmentMask;
// 段segment的偏移，用于计算key所在segments索引值。
final int segmentShift;
// 段segment数组，其内部是由HashEntry数组实现。
final Segment<K,V>[] segments;
// 键集合，键不能重复
transient Set<K> keySet;
// 值集合，值可以重复
transient Collection<V> values;
// 元素HashEntry集合
transient Set<Map.Entry<K,V>> entrySet;
```



## ConcurrentHashMap内部类

### Holder

静态内部类，存放一些在虚拟机启动后才能初始化的值。

1. 容量阈值，初始化hashSeed的时候会用到该值。

```java
static final boolean ALTERNATIVE_HASHING;
```



2. static静态块

```java
static {
  // 获取系统变量jdk.map.althashing.threshold
  // 通过系统变量jdk.map.althashing.threshold来初始化threshold
  String altThreshold = java.security.AccessController.doPrivileged(
    new sun.security.action.GetPropertyAction(
      "jdk.map.althashing.threshold"));

  int threshold;
  try {
    threshold = (null != altThreshold)
      ? Integer.parseInt(altThreshold)
      : Integer.MAX_VALUE;

    // disable alternative hashing if -1
    if (threshold == -1) {
      threshold = Integer.MAX_VALUE;
    }

    if (threshold < 0) {
      throw new IllegalArgumentException("value must be positive integer.");
    }
  } catch(IllegalArgumentException failed) {
    throw new Error("Illegal value for 'jdk.map.althashing.threshold'", failed);
  }
  // 根据系统变量jdk.map.althashing.threshold来初始化ALTERNATIVE_HASHING
  ALTERNATIVE_HASHING = threshold <= MAXIMUM_CAPACITY;
}
```



`Holder`类是用来辅助生成hashSeed的。

`jdk.map.althashing.threshold` —> `Holder.ALTERNATIVE_HASHING` —> `hashSeed`。

```java
private static int randomHashSeed(ConcurrentHashMap instance) {
  if (sun.misc.VM.isBooted() && Holder.ALTERNATIVE_HASHING) {
    return sun.misc.Hashing.randomHashSeed(instance);
  }

  return 0;
}
```



### HashEntry

ConcurrentHashMap中的末端数据结构，用于存储键值信息。

```java
static final class HashEntry<K,V> {
  // hash和key都是final，保证了读操作时不用加锁。
  final int hash;
  final K key;
  // value设置成volatile，为了确保读操作能够看到最新的值。
  volatile V value;
  // 不再用final关键字，采用unsafe操作保证并发安全。
  volatile HashEntry<K,V> next;

  HashEntry(int hash, K key, V value, HashEntry<K,V> next) {
    this.hash = hash;
    this.key = key;
    this.value = value;
    this.next = next;
  }

  final void setNext(HashEntry<K,V> n) {
    UNSAFE.putOrderedObject(this, nextOffset, n);
  }

  // Unsafe mechanics
  static final sun.misc.Unsafe UNSAFE;
  static final long nextOffset;
  static {
    try {
      UNSAFE = sun.misc.Unsafe.getUnsafe();
      Class k = HashEntry.class;
      nextOffset = UNSAFE.objectFieldOffset
        (k.getDeclaredField("next"));
    } catch (Exception e) {
      throw new Error(e);
    }
  }
}
```

**说明:**

1. HashEntry是个final类。在插入新的HashEntry节点时，只能采用头插法，因为HashEntry的next节点也是final的不可修改。final修饰的HashEntry可以提高并发性，读操作时不用加锁。
2. HashEntry在设置next节点时，使用UNSAFE类保证线程安全。

### Segment

Segment是ConcurrentHashMap的内部类，继承ReentrantLock，实现了Serializable接口。操作基本上都在Segment上，Segment中的table是一个HashEntry数组，数据就存放到这个数组中。看到这里对比下HashMap的存储结构，就大概能明白。具体方法在接下来的ConcurrentHashMap的具体方法中讲解。

```java
static final class Segment<K,V> extends ReentrantLock implements Serializable {
  private static final long serialVersionUID = 2249069246763182397L;

  static final int MAX_SCAN_RETRIES =
    Runtime.getRuntime().availableProcessors() > 1 ? 64 : 1;

  transient volatile HashEntry<K,V>[] table;
  
  transient int count;
  
  transient int modCount;

  transient int threshold;
  
  final float loadFactor;

  Segment(float lf, int threshold, HashEntry<K,V>[] tab);

  final V put(K key, int hash, V value, boolean onlyIfAbsent)

  private void rehash(HashEntry<K,V> node);

  private HashEntry<K,V> scanAndLockForPut(K key, int hash, V value);

  private void scanAndLock(Object key, int hash);

  final V remove(Object key, int hash, Object value);

  final boolean replace(K key, int hash, V oldValue, V newValue);
  final V replace(K key, int hash, V value);

  final void clear();
}
```



### HashIterator

`HashIterator`是个抽象类，它的子类有`EntryIterator`，`KeyIterator`和`ValueIterator`。从名字上可以看出来，HashIterator为ConcurrentHashMap的遍历提供了键、值、HashEntry等不同维度的迭代器。

```java
abstract class HashIterator {
  int nextSegmentIndex;
  int nextTableIndex;
  HashEntry<K,V>[] currentTable;
  HashEntry<K, V> nextEntry;
  HashEntry<K, V> lastReturned;

  HashIterator() {
    // 从segment的segment.length - 1开始向前遍历。
    nextSegmentIndex = segments.length - 1;
    nextTableIndex = -1;
    advance();
  }

  /**
  * Set nextEntry to first node of next non-empty table
  * (in backwards order, to simplify checks).
  */
  final void advance() {
    for (;;) {
      if (nextTableIndex >= 0) {
        if ((nextEntry = entryAt(currentTable, nextTableIndex--)) != null)
          break;
      }
      else if (nextSegmentIndex >= 0) {
        Segment<K,V> seg = segmentAt(segments, nextSegmentIndex--);
        if (seg != null && (currentTable = seg.table) != null)
          nextTableIndex = currentTable.length - 1;
      }
      else
        break;
    }
  }

  final HashEntry<K,V> nextEntry() {
    HashEntry<K,V> e = nextEntry;
    if (e == null)
      throw new NoSuchElementException();
    lastReturned = e; // cannot assign until after null check
    if ((nextEntry = e.next) == null)
      advance();
    return e;
  }

  public final boolean hasNext() { return nextEntry != null; }
  public final boolean hasMoreElements() { return nextEntry != null; }

  public final void remove() {
    if (lastReturned == null)
      throw new IllegalStateException();
    ConcurrentHashMap.this.remove(lastReturned.key);
    lastReturned = null;
  }
}
```



### EntryIterator

```java
final class EntryIterator extends HashIterator implements Iterator<Entry<K,V>>
{
  	public Map.Entry<K,V> next() {
      HashEntry<K,V> e = super.nextEntry();
      return new WriteThroughEntry(e.key, e.value);
	}
}
```



### KeyIterator

```java
final class KeyIterator 
  		extends HashIterator
        implements Iterator<K>, Enumeration<K>
{
  public final K next()        { return super.nextEntry().key; }
  public final K nextElement() { return super.nextEntry().key; }
}
```



### ValueIterator

```java
final class ValueIterator
  extends HashIterator
  implements Iterator<V>, Enumeration<V>
{
  public final V next()        { return super.nextEntry().value; }
  public final V nextElement() { return super.nextEntry().value; }
}
```



### WriteThroughEntry

`WriteThroughEntry`里只有一个public方法setValue，将值写入map中。注意由于并发情况，可能不会是实时修改数据，故不能用于跟踪数据。该方法可以用于遍历时修改数据。

```
final class WriteThroughEntry extends AbstractMap.SimpleEntry<K,V> {
  
  WriteThroughEntry(K k, V v) {
  	super(k,v);
  }

  public V setValue(V value) {
    if (value == null) throw new NullPointerException();
    V v = super.setValue(value);
    ConcurrentHashMap.this.put(getKey(), value);
    return v;
  }
}
```



### KeySet

```java
final class KeySet extends AbstractSet<K> {
  public Iterator<K> iterator() {
  	return new KeyIterator();
  }
  public int size() {
  	return ConcurrentHashMap.this.size();
  }
  public boolean isEmpty() {
  	return ConcurrentHashMap.this.isEmpty();
  }
  public boolean contains(Object o) {
  	return ConcurrentHashMap.this.containsKey(o);
  }
  public boolean remove(Object o) {
  	return ConcurrentHashMap.this.remove(o) != null;
  }
  public void clear() {
  	ConcurrentHashMap.this.clear();
  }
}
```



### EntrySet

```java
final class EntrySet extends AbstractSet<Map.Entry<K,V>> {
  public Iterator<Map.Entry<K,V>> iterator() {
  	return new EntryIterator();
  }
  public boolean contains(Object o) {
    if (!(o instanceof Map.Entry))
    	return false;
    Map.Entry<?,?> e = (Map.Entry<?,?>)o;
    V v = ConcurrentHashMap.this.get(e.getKey());
    return v != null && v.equals(e.getValue());
  }
  public boolean remove(Object o) {
  	if (!(o instanceof Map.Entry))
  		return false;
  	Map.Entry<?,?> e = (Map.Entry<?,?>)o;
  	return ConcurrentHashMap.this.remove(e.getKey(), e.getValue());
  }
  public int size() {
  	return ConcurrentHashMap.this.size();
  }
  public boolean isEmpty() {
  	return ConcurrentHashMap.this.isEmpty();
  }
  public void clear() {
  	ConcurrentHashMap.this.clear();
  }
}
```



### Values

```java
final class Values extends AbstractCollection<V> {
  public Iterator<V> iterator() {
  	return new ValueIterator();
  }
  public int size() {
  	return ConcurrentHashMap.this.size();
  }
  public boolean isEmpty() {
  	return ConcurrentHashMap.this.isEmpty();
  }
  public boolean contains(Object o) {
  	return ConcurrentHashMap.this.containsValue(o);
  }
  public void clear() {
  	ConcurrentHashMap.this.clear();
  }
}
```





## ConcurrentHashMap函数列表

```java
// 创建一个带有默认初始容量 (16)、加载因子 (0.75) 和 concurrencyLevel (16) 的新的空映射。
ConcurrentHashMap()
// 创建一个带有指定初始容量、默认加载因子 (0.75) 和 concurrencyLevel (16) 的新的空映射。
ConcurrentHashMap(int initialCapacity)
// 创建一个带有指定初始容量、加载因子和默认 concurrencyLevel (16) 的新的空映射。
ConcurrentHashMap(int initialCapacity, float loadFactor)
// 创建一个带有指定初始容量、加载因子和并发级别的新的空映射。
ConcurrentHashMap(int initialCapacity, float loadFactor, int concurrencyLevel)
// 构造一个与给定映射具有相同映射关系的新映射。
ConcurrentHashMap(Map<? extends K,? extends V> m)

// 从该映射中移除所有映射关系
void clear()
// 一种遗留方法，测试此表中是否有一些与指定值存在映射关系的键。
boolean contains(Object value)
// 测试指定对象是否为此表中的键。
boolean containsKey(Object key)
// 如果此映射将一个或多个键映射到指定值，则返回 true。
boolean containsValue(Object value)
// 返回此表中值的枚举。
Enumeration<V> elements()
// 返回此映射所包含的映射关系的 Set 视图。
Set<Map.Entry<K,V>> entrySet()
// 返回指定键所映射到的值，如果此映射不包含该键的映射关系，则返回 null。
V get(Object key)
// 如果此映射不包含键-值映射关系，则返回 true。
boolean isEmpty()
// 返回此表中键的枚举。
Enumeration<K> keys()
// 返回此映射中包含的键的 Set 视图。
Set<K> keySet()
// 将指定键映射到此表中的指定值。
V put(K key, V value)
// 将指定映射中所有映射关系复制到此映射中。
void putAll(Map<? extends K,? extends V> m)
// 如果指定键已经不再与某个值相关联，则将它与给定值关联。
V putIfAbsent(K key, V value)
// 从此映射中移除键（及其相应的值）。
V remove(Object key)
// 只有目前将键的条目映射到给定值时，才移除该键的条目。
boolean remove(Object key, Object value)
// 只有目前将键的条目映射到某一值时，才替换该键的条目。
V replace(K key, V value)
// 只有目前将键的条目映射到给定值时，才替换该键的条目。
boolean replace(K key, V oldValue, V newValue)
// 返回此映射中的键-值映射关系数。
int size()
// 返回此映射中包含的值的 Collection 视图。
Collection<V> values()
```

