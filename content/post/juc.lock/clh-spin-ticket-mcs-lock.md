---
title: "Java锁之自旋锁的原理"
date: "2017-02-23T18:29:27+08:00"
categories: ["ABC_Lock"]
tags: ["Java", "Lock"]
draft: false
---

## 概述

锁作为数据同步工具，Java提供了两种实现：synchronized和AQS，这两种锁的实现根本不同，但是在加锁和解锁的过程中，也有很多共同点。它们在进行加锁/解锁时或多或少的用到自旋锁的设计思想。对于这几种自旋锁设计思想的研究，可以帮助我们更好的理解Java的Lock框架。



## SPIN锁

Spin锁即自旋锁。自旋锁是采用让当前线程不停地在循环体内`检测并设置临界资源的状态`，直到状态满足条件并设置为指定的新状态。`检测并设置临界资源`操作必须是原子的，这样即使多个线程在给定时间自旋，也只有一个线程可获得该锁。

自旋锁的优点之一是自旋的线程不会被阻塞，一直处于活跃状态，对于锁保护的临界区较小的情况下，自旋获取锁和释放锁的成本都比较低，时间比较短。

### Java中的自旋锁

在JAVA中，我们可以使用原子变量和Unsafe类的CAS操作来实现自旋锁：

```java
public class SpinLock {
  private AtomicReference<Thread> atomic = new AtomicReference<Thread>();
  
  public void lock() {
    Thread currentThread = Thread.currentThread();
    
    // 如果锁未被占用，则设置当前线程为锁的拥有者。
    while(!atomic.compareAndSet(null, currentThread)) {}
  }
  
  public void unlock() {
    Thread currentThread = Thread.currentThread();
    // 只有锁的拥有者能释放锁
    atomic.compareAndSet(currentThread, null);
  }
}
```



#### 缺点

1. CAS操作需要硬件的配合；

2. 保证各个CPU的缓存（L1、L2、L3、跨CPU Socket、主存）的数据一致性，通讯开销很大，在多处理器系统上更严重；

3. 没法保证公平性，不保证等待进程/线程按照FIFO顺序获得锁。

   ​

### Linux中的自旋锁

自旋锁在Linux内核中广泛使用。在Linux操作系统中，自旋锁是一个互斥设备，它只有两个值`锁定`和`解锁`。

由于操作系统和CPU直接打交道，自旋锁又可分为在单核处理器上和多核处理器上。

#### 单核处理器

用在单核处理器上，有可分为两种：

1. 系统不支持内核抢占

   此时自旋锁什么也不做，确实也不需要做什么，因为单核处理器只有一个线程在执行，又不支持内核抢占，因此资源不可能会被其他的线程访问到。

2. 系统支持内核抢占

   这种情况下，自旋锁加锁仅仅是禁止了内核抢占，解锁则是启用了内核抢占。

在上述两种情况下，在获取自旋锁后可能会发生中断，若中断处理程序去访问自旋锁所保护的资源，则会发生死锁。因此，linux内核又提供了spin_lock_irq()和spin_lock_irqsave()，这两个函数会在获取自旋锁的同时（同时禁止内核抢占），禁止本地外部可屏蔽中断，从而保证自旋锁的原子操作。



#### 多核处理器

多核处理器意味着有多个线程可以同时在不同的处理器上并行执行。

举个例子：

四核处理器，若A处理器上的线程1获取了锁,B、C两个处理器恰好这个时候也要访问这个锁保护的资源，因此他俩CPU就一直自旋忙等待。D并不需要这个资源，因此它可以正常处理其他事情。

自旋锁的几个特点：

1.被自旋锁保护的临界区代码执行时不能睡眠。单核处理器下，获取到锁的线程睡眠，若恰好此时CPU调度的另一个执行线程也需要获取这个锁，则会造成死锁；多核处理器下，若想获取锁的线程在同一个处理器下，同样会造成死锁，若位于另外的处理器，则会长时间占用CPU等待睡眠的线程释放锁，从而浪费CPU资源。

2.被自旋锁保护的临界区代码执行时不能被其他中断打断。

3.被自旋锁保护的临界区代码在执行时，内核不能被抢占。



#### 自旋锁函数

```c
// 最基本得自旋锁函数，它不失效本地中断。
void spin_lock(spinlock_t *lock);
// 在获得自旋锁之前禁用硬中断（只在本地处理器上），而先前的中断状态保存在flags中
void spin_lock_irqsave(spinlock_t *lock, unsigned long flags);
// 在获得自旋锁之前禁用硬中断（只在本地处理器上），不保存中断状态
void spin_lockirq(spinlock_t *lock);
// 在获得锁前禁用软中断，保持硬中断打开状态
void spin_lock_bh(spinlock_t *lock);
```



## TICKET锁

Ticket锁即排队自旋锁，Ticket锁是为了解决上面自旋锁的公平性问题，类似于现实中海底捞的排队叫号：锁拥有一个服务号，表示正在服务的线程，还有一个排队号；每个线程尝试获取锁之前先拿一个排队号，然后不断轮训锁的当前服务号是否是自己的排队号，如果是，则表示自己拥有了锁，不是则继续轮训。



当前线程释放锁时，将服务号加1，这样下一个线程看到这个变化，就退出自旋，表示获取到锁。

### Java中的自旋锁

在JAVA中，我们可以使用原子变量和Unsafe类的CAS操作来实现Ticket自旋锁：

```java
public class TicketLock {
   private AtomicInteger serviceNum = new AtomicInteger(); // 服务号
   private AtomicInteger ticketNum = new AtomicInteger(); // 排队号

   public int lock() {
         // 首先原子性地获得一个排队号
         int myTicketNum = ticketNum.getAndIncrement();

         // 只要当前服务号不是自己的就不断轮询
       	while (serviceNum.get() != myTicketNum) {}

       	return myTicketNum;
    }

    public void unlock(int myTicket) {
        // 只有当前线程拥有者才能释放锁
        int next = myTicket + 1;
        serviceNum.compareAndSet(myTicket, next);
    }
}
```



#### 缺点

Ticket Lock 虽然解决了公平性的问题，但是多处理器系统上，每个进程/线程占用的处理器都在读写同一个变量`serviceNum` ，每次读写操作都必须在多个处理器缓存之间进行缓存同步，这会导致繁重的系统总线和内存的流量，大大降低系统整体的性能。



### Linux中的排队自旋锁

排队自旋锁(FIFO Ticket Spinlock)是Linux内核2.6.25版本引入的一种新型自旋锁，它解决了传统自旋锁由于无序竞争导致的"公平性"问题。但是由于排队自旋锁在一个共享变量上“自旋”，因此在锁竞争激烈的多核或 NUMA 系统上导致性能低下。



## MCS锁

MCS自旋锁是一种基于链表的高性能、可扩展的自旋锁。申请线程之在本地变量上自旋，直接前驱负责通知其结束自旋，从而极大地减少了不必要的处理器缓存同步的次数，降低了总线和内存的开销。



MCS锁的设计目标如下：

1. 保证自旋锁申请者以先进先出的顺序获取锁（FIFO Ordering）。
2. 只在本地可访问的标志变量上自旋。
3. 在处理器个数较少的系统中或锁竞争并不激烈的情况下，保持较高性能。
4. 自旋锁的空间复杂度（即锁数据结构和锁操作所需的空间开销）为常数。
5. 在没有处理器缓存一致性协议保证的系统中也能很好地工作。



### Java中的MCS锁

在JAVA中，我们可以使用原子变量和Unsafe类的CAS操作来实现MCS自旋锁：

```java
public class MCSLock {
    public static class MCSNode {
        volatile MCSNode next;
        volatile boolean isBlock = true; // 本地自旋变量，默认是在等待锁
    }

    volatile MCSNode queue;// 指向最后一个申请锁的MCSNode
    private static final AtomicReferenceFieldUpdater UPDATER = 
      AtomicReferenceFieldUpdater.newUpdater(MCSLock.class, MCSNode.class, "queue");

    public void lock(MCSNode currentThread) {
        MCSNode predecessor = UPDATER.getAndSet(this, currentThread);// step 1
        if (predecessor != null) {
            predecessor.next = currentThread;// step 2

            while (currentThread.isBlock) {// step 3
            }
        }else { // 只有一个线程在使用锁，没有前驱来通知它，所以得自己标记自己为非阻塞
            currentThread.isBlock = false;
        }
    }

    public void unlock(MCSNode currentThread) {
        if (currentThread.isBlock) {// 锁拥有者进行释放锁才有意义
            return;
        }

        if (currentThread.next == null) {// 检查是否有人排在自己后面
            if (UPDATER.compareAndSet(this, currentThread, null)) {// step 4
                // compareAndSet返回true表示确实没有人排在自己后面
                return;
            } else {
                // 突然有人排在自己后面了，可能还不知道是谁，下面是等待后续者
                // 这里之所以要忙等是因为：step 1执行完后，step 2可能还没执行完
                while (currentThread.next == null) { // step 5
                }
            }
        }

        currentThread.next.isBlock = false;
        currentThread.next = null;// for GC
    }
}
```



###  Linux中的MCS锁

目前 Linux 内核尚未使用 MCS Spinlock。根据上节的算法描述，我们可以很容易地实现 MCS Spinlock。本文的实现针对x86 体系结构(包括 IA32 和 x86_64)。原子交换、比较-交换操作可以使用带 LOCK 前缀的 xchg(q)，cmpxchg(q)[3] 指令实现。



## CLH锁

CLH（Craig, Landin, and Hagersten）锁也是基于链表的可扩展、高性能、公平的自旋锁，申请线程旨在本地变量上自旋，它不断轮训前驱的状态，如果发现前驱释放了锁就结束自旋。



### Java中的CLH锁

在Java中CLH的应用非常广泛，比如JUC包下的锁框架AbstractQueuedSynchronized就是基于CLH实现的，并进而实现了整个Lock框架体系。



在JAVA中，我们可以使用原子变量和Unsafe类的CAS操作来实现CLH自旋锁：

```java
public class CLHLock {
    public static class CLHNode {
        private volatile boolean isLocked = true; // 默认是在等待锁
    }

    @SuppressWarnings("unused" )
    private volatile CLHNode tail ;
    private static final AtomicReferenceFieldUpdater<CLHLock, CLHNode> UPDATER = AtomicReferenceFieldUpdater
                  . newUpdater(CLHLock.class, CLHNode .class , "tail" );

    public void lock(CLHNode currentThread) {
        CLHNode preNode = UPDATER.getAndSet( this, currentThread);
        if(preNode != null) {//已有线程占用了锁，进入自旋
            while(preNode.isLocked ) {
            }
        }
    }

    public void unlock(CLHNode currentThread) {
        // 如果队列里只有当前线程，则释放对当前线程的引用（for GC）。
        if (!UPDATER .compareAndSet(this, currentThread, null)) {
            // 还有后续线程
            currentThread. isLocked = false ;// 改变状态，让后续线程结束自旋
        }
    }
}
```



## CLH锁与MCS锁的比较

下图是经典的CLH锁和MCS锁队列图示：

![CLH和MCS](http://coderbee.net/wp-content/uploads/2013/11/CLH-MCS-SpinLock.png)



差异：

1. 从代码实现来看，CLH比MCS要简单得多。
2. 从自旋的条件来看，CLH是在前驱节点的属性上自旋，而MCS是在本地属性变量上自旋。
3. 从链表队列来看，CLH的队列是隐式的，CLHNode并不实际持有下一个节点；MCS的队列是物理存在的。
4. CLH锁释放时只需要改变自己的属性，MCS锁释放则需要改变后继节点的属性。

**注意：这里实现的锁都是独占的，且不能重入的。**



参考：

1. [高性能自旋锁 MCS Spinlock 的设计与实现](https://www.ibm.com/developerworks/cn/linux/l-cn-mcsspinlock/)
2. [高效编程之互斥锁和自旋锁的一些知识](http://www.cnblogs.com/hdflzh/p/3716156.html)
3. [基于队列的锁:mcs lock简介](https://my.oschina.net/MinGKai/blog/188522)
4. [深入理解linux内核自旋锁](http://blog.csdn.net/vividonly/article/details/6594195)