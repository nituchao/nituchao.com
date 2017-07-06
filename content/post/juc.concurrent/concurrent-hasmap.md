---
title: "ConcurrentHashMap源码分析"
date: "2017-02-23T18:27:27+08:00"
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

ConcurrentHashMap使用了不同于传统集合的快速失败迭代器的另一种迭代方式，我们称为**弱一致迭代器**。在这种迭代方式中，当iterator被创建后集合再发生改变就不再是抛出 ConcurrentModificationException，取而代之的是在改变时new新的数据从而不影响原有的数 据，iterator完成后再将头指针替换为新的数据，这样iterator线程可以使用原来老的数据，而写线程也可以并发的完成改变，更重要的，这保证了多个线程并发执行的连续性和扩展性，是性能提升的关键。

HashIterator通过调用advance()遍历底层数组。在遍历过程中，如果已经遍历的数组上的内容变化了，迭代器不会抛出ConcurrentModificationException异常。如果未遍历的数组上的内容发生了变化，则有可能反映到迭代过程中。这就是ConcurrentHashMap迭代器若一致性的表现。



`HashIterator`是个抽象类，它的子类有`EntryIterator`，`KeyIterator`和`ValueIterator`。从名字上可以看出来，HashIterator为ConcurrentHashMap的遍历提供了键、值、HashEntry等不同维度的迭代器。



`EntryIterator`、`KeyIterator`、`ValueIterator`事实上是为`EntrySet`、`KeySet`、`Values`提供迭代服务。而所有的迭代操作在本质上都是调用HashIterator里的相关实现（如：nextEntry()，hasNext()，remove()等）。

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
  * Segment数组从后往前，找到第一个table数组不为null的Segment
  * 将nextSegmentIndex指向该Segment
  * 将nextTableIndex指向该table
  * 将currentTable指向该table
  * 将nextEntry指向该table中的第一个HashEntry元素
  * lastReturned在这里还没有初始化，只有在遍历(调用nextEntry())是才赋值
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

  /**
  * 获取当前nextEntry指向的HashEntry。
  * 修改lastReturned为nextEntry当前指向的HashEntry。
  * 调用advance()，向前寻找第一个table数组不为null的Segment
  */
  final HashEntry<K,V> nextEntry() {
    HashEntry<K,V> e = nextEntry;
    if (e == null)
      throw new NoSuchElementException();
    lastReturned = e; // cannot assign until after null check
    if ((nextEntry = e.next) == null)
      advance();
    return e;
  }

  // 根据nextEntry是否为空，判断是否还有下一个元素供遍历
  public final boolean hasNext() { return nextEntry != null; }
  
  // 根据nextEntry是否为空，判断是否还有下一个元素供遍历
  public final boolean hasMoreElements() { return nextEntry != null; }

  /**
  * 调用ConcurrentHashMap的remove方法，按key移除元素。
  * 将lastReturned置为空。
  * 此时nextEntry
  */
  public final void remove() {
    if (lastReturned == null)
      throw new IllegalStateException();
    ConcurrentHashMap.this.remove(lastReturned.key);
    lastReturned = null;
  }
}
```



### EntryIterator

继承自`HashIterator`，并实现了Iterator接口，用于HashEntry的迭代遍历。EntryIterator重写了next方法，返回了一个WriteThroughEntry对象，该对象继承自AbstractMap.SimpleEntry，本质上是个Map.Entry。

EntryIterator将在ConcurrentHashMap.EntrySet中起作用，为EntrySet类型提供迭代能力。

```java
final class EntryIterator 
  		extends HashIterator 
  		implements Iterator<Entry<K,V>> {
  	public Map.Entry<K,V> next() {
      HashEntry<K,V> e = super.nextEntry();
      return new WriteThroughEntry(e.key, e.value);
	}
}
```



### KeyIterator

继承自`HashIterator`，并实现了Iterator接口，用于HashEntry的key的迭代遍历。KeyIterator重写了next方法，返回了当前HashEntry的key值。

KeyIterator将在ConcurrentHashMap.KeySet中起作用，为KeySet类型提供迭代能力。

```java
final class KeyIterator 
  		extends HashIterator
        implements Iterator<K>, Enumeration<K> {
  public final K next()        { return super.nextEntry().key; }
  public final K nextElement() { return super.nextEntry().key; }
}
```



### ValueIterator

继承自HashIterator，并实现了Iterator接口，用于HashEntry的值的迭代遍历。ValueIterator重写了next方法，返回了当前HashEntry的值。

ValueIterator将在ConcurrentHashMap.Values中起作用，为Values类型提供迭代能力。

```java
final class ValueIterator
  extends HashIterator
  implements Iterator<V>, Enumeration<V> {
  public final V next()        { return super.nextEntry().value; }
  public final V nextElement() { return super.nextEntry().value; }
}
```



### WriteThroughEntry

`WriteThroughEntry`里只有一个public方法setValue，将值写入map中。注意由于并发情况，可能不会是实时修改数据，故不能用于跟踪数据。该方法可以用于遍历时修改数据。

```java
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

ConcurrentHashMap的KeySet类型用于定义按Key进行遍历的相关操作。其中，iterator()会实例化一个KeyIterator()，进而提供相关的迭代操作。其他的方法，则是通过ConcurrentHashMap的原生方法实现。

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

ConcurrentHashMap的EntrySet类型用于定义按Entry进行遍历的相关操作。其中，iterator()会实例化一个EntryIterator()，进而提供相关的迭代操作。其他的方法，则是通过ConcurrentHashMap的原生方法实现。

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

ConcurrentHashMap的Values类型用于定义按Value进行遍历的相关操作。其中，iterator()会实例化一个ValueIterator()，进而提供相关的迭代操作。其他的方法，则是通过ConcurrentHashMap的原生方法实现。

由于ConcurrentHashMap的值可以重复，因此Values类型继承自AbstractCollection，而不是集合Set。

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



## ConcurrentHashMap重点函数

### 构造函数

ConcurrentHashMap有五个构造函数，重点分析下面这个构造函数。

ConcurrentHashMap初始化是通过initialCapacity，loadFactor，concurrentLevel等参数来初始化Segment数组，段偏移量segmentShift，段掩码segmentMask和每个segment里的HashEntry数组。

```java
public ConcurrentHashMap(int initialCapacity, float loadFactor, int concurrencyLevel) {
  // 参数检查
  if (!(loadFactor > 0) || initialCapacity < 0 || concurrencyLevel <= 0)
    throw new IllegalArgumentException();
  // 并发级别不能超过段的最大数量
  if (concurrencyLevel > MAX_SEGMENTS)
    concurrencyLevel = MAX_SEGMENTS;
  // Find power-of-two sizes best matching arguments
  int sshift = 0;
  int ssize = 1;
  while (ssize < concurrencyLevel) {
    ++sshift;
    ssize <<= 1;
  }
  this.segmentShift = 32 - sshift;
  this.segmentMask = ssize - 1;
  if (initialCapacity > MAXIMUM_CAPACITY)
    initialCapacity = MAXIMUM_CAPACITY;
  int c = initialCapacity / ssize;
  if (c * ssize < initialCapacity)
    ++c;
  int cap = MIN_SEGMENT_TABLE_CAPACITY;
  while (cap < c)
    cap <<= 1;
  // create segments and segments[0]
  Segment<K,V> s0 =
    new Segment<K,V>(loadFactor, (int)(cap * loadFactor),
                     (HashEntry<K,V>[])new HashEntry[cap]);
  Segment<K,V>[] ss = (Segment<K,V>[])new Segment[ssize];
  UNSAFE.putOrderedObject(ss, SBASE, s0); // ordered write of segments[0]
  this.segments = ss;
}
```

**segments数组的长度ssize通过concurrencyLevel计算得出。**为了能通过按位与的哈希算法来定位segments数组的索引，必须保证segments数组的长度是2的N次方（power-of-two size），所以必须计算出一个是大于或等于concurrencyLevel的最小的2的N次方值来作为segments数组的长度。假如concurrencyLevel等于14，15或16，ssize都会等于16，即容器里锁的个数也是16。注意concurrencyLevel的最大大小是65535，意味着segments数组的长度最大为65536，对应的二进制是16位，对应全局常量MAX_SEGMENTS = 1 << 16。

**初始化segmentShift和segmentMask。** 这两个全局变量在定位segment时的哈希算法里需要使用，sshift等于ssize从1向左移位的次数，在默认情况下concurrencyLevel等于16，1需要向左移位移动4次，所以sshift等于4。segmentShift用于定位参与hash运算的位数，segmentShift等于32减sshift，所以等于28，这里之所以用32是因为ConcurrentHashMap里的hash()方法输出的最大数是32位的，后面的测试中我们可以看到这点。segmentMask是哈希运算的掩码，等于ssize减1，即15，掩码的二进制各个位的值都是1。因为ssize的最大长度是65536，所以segmentShift最大值是16，segmentMask最大值是65535，对应的二进制是16位，每个位都是1。

**初始化每个Segment。**输入参数initialCapacity是ConcurrentHashMap的初始化容量，loadfactor是每个segment的负载因子，在构造方法里需要通过这两个参数来初始化数组中的每个segment。

**初始化每个segment里HashEntry数组的长度cap**。cap等于initialCapacity除以ssize的倍数c，如果c大于1，就会取大于等于c的2的N次方值，所以cap不是1，就是2的N次方。segment的容量threshold＝(int)cap*loadFactor，默认情况下initialCapacity等于16，loadfactor等于0.75，通过运算cap等于1，threshold等于零。



### put(K key, V value)

```java
public V put(K key, V value) {
  Segment<K,V> s;
  if (value == null)
  	throw new NullPointerException();
  int hash = hash(key);
  int j = (hash >>> segmentShift) & segmentMask;
  if ((s = (Segment<K,V>)UNSAFE.getObject          // nonvolatile; recheck
  	(segments, (j << SSHIFT) + SBASE)) == null) //  in ensureSegment
  s = ensureSegment(j);
  return s.put(key, hash, value, false);
}
```

Segment内部类中的put方法：

```
final V put(K key, int hash, V value, boolean onlyIfAbsent) {
	// tryLock(): 如果锁可用，则获取锁，并立即返回true，否则返回false。
	// scanAndLockForPut扫描指定key的节点，并获取锁，如果不存在就新建一个HashEntry。
	// 在scanAndLockForPut方法里，会循环执行MAX_SCAN_RETRIES次tryLock。
	// 如果还是没有获取到锁，则调用lock()方法使用CAS获取锁。
	// 总之，在node返回时，当前线程一定已经取到了当前segment的锁。
	HashEntry<K,V> node = tryLock() ? null : 
		scanAndLockForPut(key, hash, value);
	V oldValue;
	try {
        HashEntry<K,V>[] tab = table;
        int index = (tab.length - 1) & hash;
        HashEntry<K,V> first = entryAt(tab, index);
        for (HashEntry<K,V> e = first;;) {
        	if (e != null) {
        		K k;
        		if ((k = e.key) == key ||
        			(e.hash == hash && key.equals(k))) {
        			oldValue = e.value;
        			if (!onlyIfAbsent) {
        				e.value = value;
        				++modCount;
                  }
                  break;
              }
              e = e.next;
            }
            else {
                if (node != null)
                    node.setNext(first);
                else
                    node = new HashEntry<K,V>(hash, key, value, first);
                int c = count + 1;
                if (c > threshold && tab.length < MAXIMUM_CAPACITY)
                    rehash(node);
                else
                    setEntryAt(tab, index, node);
                ++modCount;
                count = c;
                oldValue = null;
                break;
            }
		}
    } finally {
    unlock();
    }
    return oldValue;
}
```

put操作开始，首先定位到Segment，为了线程安全，锁定当前Segment；然后在Segment里进行插入操作，首先判断是否需要扩容，然后在定位添加元素的位置放在HashEntry数组里。

扩容：在插入元素前会先判断Segment里的HashEntry数组是否超过容量（threshold），如果超过阀值，数组进行扩容。值得一提的是，Segment的扩容判断比HashMap更恰当，因为HashMap是在插入元素后判断元素是否已经到达容量的，如果到达了就进行扩容，但是很有可能扩容之后没有新元素插入，这时HashMap就进行了一次无效的扩容。

扩容的时候首先会创建一个两倍于原容量的数组，然后将原数组里的元素进行再hash后插入到新的数组里。为了高效ConcurrentHashMap不会对整个容器进行扩容，而只对某个segment进行扩容。



### get(K key)

在ConcurrentHashMap中get(K key)方法没有加锁，因此可能会读到其他线程put的新数据。这也是ConcurrentHashMap弱一致性的体现。

```java
public V get(Object key) {
    Segment<K,V> s; // manually integrate access methods to reduce overhead
    HashEntry<K,V>[] tab;
    int h = hash(key);
    long u = (((h >>> segmentShift) & segmentMask) << SSHIFT) + SBASE;
    if ((s = (Segment<K,V>)UNSAFE.getObjectVolatile(segments, u)) != null &&
        (tab = s.table) != null) {
        for (HashEntry<K,V> e = (HashEntry<K,V>) UNSAFE.getObjectVolatile
                 (tab, ((long)(((tab.length - 1) & h)) << TSHIFT) + TBASE);
             e != null; e = e.next) {
            K k;
            if ((k = e.key) == key || (e.hash == h && key.equals(k)))
                return e.value;
        }
    }
    return null;
}
```



### size()

要统计整个ConcurrentHashMap里元素的大小，就必须统计所有Segment里元素的大小后求和。Segment里的全局变量count是一个volatile变量，那么在多线程场景下，我们是不是直接把所有Segment的count相加就可以得到整个ConcurrentHashMap大小了呢？不是的，虽然相加时可以获取每个Segment的count的最新值，但是拿到之后可能累加前使用的count发生了变化，那么统计结果就不准了。所以最安全的做法，是在统计size的时候把所有Segment的put，remove和clean方法全部锁住，但是这种做法显然非常低效。

因为在累加count操作过程中，之前累加过的count发生变化的几率非常小，所以ConcurrentHashMap的做法是先尝试2次通过不锁住Segment的方式来统计各个Segment大小，如果统计的过程中，容器的count发生了变化，则再采用加锁的方式来统计所有Segment的大小。

```java
public int size() {
  // Try a few times to get accurate count. On failure due to
  // continuous async changes in table, resort to locking.
  final Segment<K,V>[] segments = this.segments;
  int size;
  boolean overflow; // true if size overflows 32 bits
  long sum;         // sum of modCounts
  long last = 0L;   // previous sum
  int retries = -1; // first iteration isn't retry
  try {
    for (;;) {
        if (retries++ == RETRIES_BEFORE_LOCK) {
            for (int j = 0; j < segments.length; ++j)
                ensureSegment(j).lock(); // force creation
        }
        sum = 0L;
        size = 0;
        overflow = false;
        for (int j = 0; j < segments.length; ++j) {
            Segment<K,V> seg = segmentAt(segments, j);
            if (seg != null) {
            sum += seg.modCount;
            int c = seg.count;
            if (c < 0 || (size += c) < 0)
            overflow = true;
            }
        }
        if (sum == last)
          break;
      	last = sum;
    }
  } finally {
      if (retries > RETRIES_BEFORE_LOCK) {
          for (int j = 0; j < segments.length; ++j)
              segmentAt(segments, j).unlock();
      }
  }
  return overflow ? Integer.MAX_VALUE : size;
}
```



### putIfAbsent(K key, V value)

```java
// 如果key在容器中不存在则将其放入其中，否则donothing.
// 返回 null,表示确实不存在，并且value被成功放入
// 返回非 null, 表示 key 存在，返回值是key在容器中的当前值 。
public V putIfAbsent(K key, V value) {
  Segment<K,V> s;
  if (value == null)
    throw new NullPointerException();
  int hash = hash(key);
  int j = (hash >>> segmentShift) & segmentMask;
  if ((s = (Segment<K,V>)UNSAFE.getObject
       (segments, (j << SSHIFT) + SBASE)) == null)
    s = ensureSegment(j);
  return s.put(key, hash, value, true);
}
```



参考：

1. [为什么ConcurrentHashMap是弱一致的](http://ifeve.com/concurrenthashmap-weakly-consistent/)
2. [JUC集合之ConcurrentHashMap](http://www.cnblogs.com/skywang12345/p/3498537.html)
3. [并发容器-ConcurrentMap](http://a-ray-of-sunshine.github.io/2016/08/01/%E5%B9%B6%E5%8F%91%E5%AE%B9%E5%99%A8-ConcurrentMap/)
4. [ConcurrentHashMap简介](http://cxis.me/2016/05/26/ConcurrentHashMap%E7%AE%80%E4%BB%8B/)