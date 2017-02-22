---
title:  "Java通过对象同步机制实现生产者消费者"
tags: ["JAVA"]
categories: ["Queue"]
date: "2016-12-27T12:54:28+08:00"
publish: true

---

每个Java类都是从Object类派生出来的，Object类原生提供了wait(),notify(),notifyAll()等方法来实现线程间的同步控制。

进一步讲，每个对象都能当做一个锁，每个对象也能当做一个条件队列，对象中的wait(), notify(), notifyAll()方法构成了内部条件队列的API，而队列正是生产者消费者模型的一个关键元素。当对象调用wait()方法时，当前线程会释放获得的对象锁，同时，当前对象会请求操作系统挂起当前线程，此时对象的对象锁就可用了，允许其他等待线程进入。当对象调用notify()或者notifyAll()方法时，当前线程也会释放获得的对象锁，同时，操作系统会结束当前线程的执行，并从阻塞在该对象上的线程列表中选择一个进行唤醒，该线程会获得对线锁并被让操作系统调度。

### 设计思想
为了设计基于Java对象同步机制的生产者消费者程序，并且是多个生产者线程VS多个消费者线程，可以从以下三点出发。

首先，我们需要有一个缓冲区来充当生产者和消费者之间交换数据的媒介，这个缓冲区可以是一个普通的列表对象，我们在该列表对象上进行生产者和消费者的互斥访问控制。本质上讲，这个缓冲器就相当于一个队列，一方面允许生产者往里面添加数据，一方面允许消费者从里面取走数据。这个列表对象非常重要，所有的wait()和notify()操作以及对象锁的控制都是针对该对象的。因此，这是一个共享对象，在各个生产者线程和消费者线程之间充当媒介。

其次，我们需要有若干个生产者线程。生产者线程要争夺缓冲区对象锁，如果未得到锁则wait()进入阻塞等待被唤醒。如果得到了对象锁，还要判断缓冲区是否已满。如果缓冲区已满，则要wait()进入阻塞等待被唤醒，并释放缓冲区对象锁。如果缓冲区未满，则可以进行生产活动，结束后释放缓冲区对象锁，并唤醒一个阻塞的线程。

最后，我们需要有若干个消费者线程。消费者线程要争夺缓冲区对象锁，如果未得到锁则wait()进行阻塞等待被唤醒。如果得到了对象锁，还要判断缓冲区里的元素是否满足自己的需要。如果缓冲区里的元素不够自己消费，则要wait()进入阻塞等待被唤醒，并释放缓冲区对象锁。如果缓冲区里的元素满足自己的需要，则进行消费操作，结束后释放缓冲区对象锁，并唤醒一个阻塞的线程。

### 代码实现
基于上面的设计，我们需要实现共享缓冲区，生产者线程，消费者线程和主程序四部分。

**共享缓冲区**

```
package com.nituchao.jvm.prosumer.objectsync;

import java.util.Date;
import java.util.LinkedList;

/**
 * 共享缓冲区
 * Created by liang on 2016/12/15.
 */
public class Buffer {
    private static final int MAX_SIZE = 100;
    private LinkedList<String> list;

    public Buffer(LinkedList<String> list) {
        this.list = list;
    }

    /**
     * 生产n个产品
     *
     * @param num
     * @throws InterruptedException
     */
    public void BufferProduce(int num) throws InterruptedException {
        synchronized (list) {
            while (list.size() + num > MAX_SIZE) {
                System.out.println("【要生产的产品数量】:" + num + "/t【库存量】:" + list.size() + "/t暂时不能执行生产任务!");

                // list进入等待状态
                list.wait();
            }

            // 生产n个产品
            for (int i = 0; i < num; i++) {
                list.add(new Date() + " : " + i);
            }

            System.out.println("【已经生产产品数】:" + num + "/t【现仓储量为】:" + list.size());

            list.notifyAll();
        }
    }

    /**
     * 消费n个产品
     *
     * @param num
     * @throws InterruptedException
     */
    public void bufferConsume(int num) throws InterruptedException {
        synchronized (list) {
            while (list.size() < num) {
                System.out.println("【要消费的产品数量】:" + num + "/t【库存量】:" + list.size() + " /t暂时不能执行消费任务!");

                // list进入等待状态
                list.wait();
            }

            // 消费n个产品
            for (int i = 0; i < num; i++) {
                list.removeFirst();
            }

            System.out.println("【已经消费产品数】:" + num + "/t【现仓储量为】:" + list.size());

            list.notifyAll();
        }
    }
}
```

**生产者线程**

```
package com.nituchao.jvm.prosumer.objectsync;

/**
 * 生产者线程
 * Created by liang on 2016/12/30.
 */
public class BufferProducer implements Runnable {
    private Buffer buffer;
    private int num;

    public BufferProducer(Buffer buffer, int num) {
        this.buffer = buffer;
        this.num = num;
    }

    @Override
    public void run() {
        try {
            buffer.BufferProduce(num);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
```

**消费者线程**

```
package com.nituchao.jvm.prosumer.objectsync;

/**
 * 消费者线程
 * Created by liang on 2016/12/30.
 */
public class BufferConsumer implements Runnable {
    private Buffer buffer;
    private int num;

    public BufferConsumer(Buffer buffer, int num) {
        this.buffer = buffer;
        this.num = num;
    }

    @Override
    public void run() {
        try {
            buffer.bufferConsume(num);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
```

**主程序**

```
package com.nituchao.jvm.prosumer.objectsync;

import java.util.LinkedList;

/**
 * 主程序
 * Created by liang on 2016/12/30.
 */
public class BufferMain {
    public static void main(String[] args) {
        int num = 10;
        LinkedList<String> list = new LinkedList<>();
        Thread[] threadProducers = new Thread[num];
        Thread[] threadConsumers = new Thread[num];
        Buffer buffer = new Buffer(list);

        for (int i = 0; i < num; i++) {
            Thread threadTmp = new Thread(new BufferProducer(buffer, 10 + i));
            threadProducers[i] = threadTmp;
        }

        for (int i = 0; i < num; i++) {
            Thread threadTmp = new Thread(new BufferConsumer(buffer, 10 + i));
            threadConsumers[i] = threadTmp;
        }

        for (int i = 0; i < num; i++) {
            threadProducers[i].start();
            threadConsumers[i].start();
        }

        System.out.printf("list size is [%d].\n", list.size());
    }
}

```

### 运行结果

```
【要消费的产品数量】:10/t【库存量】:0 /t暂时不能执行消费任务!
【要消费的产品数量】:12/t【库存量】:0 /t暂时不能执行消费任务!
【要消费的产品数量】:13/t【库存量】:0 /t暂时不能执行消费任务!
list size is [0].
【已经生产产品数】:12/t【现仓储量为】:12
【已经消费产品数】:11/t【现仓储量为】:1
【已经生产产品数】:11/t【现仓储量为】:12
【已经生产产品数】:10/t【现仓储量为】:22
【已经消费产品数】:13/t【现仓储量为】:9
【要消费的产品数量】:12/t【库存量】:9 /t暂时不能执行消费任务!
【要消费的产品数量】:10/t【库存量】:9 /t暂时不能执行消费任务!
【要消费的产品数量】:19/t【库存量】:9 /t暂时不能执行消费任务!
【已经生产产品数】:19/t【现仓储量为】:28
【已经消费产品数】:18/t【现仓储量为】:10
【已经生产产品数】:18/t【现仓储量为】:28
【已经消费产品数】:17/t【现仓储量为】:11
【已经生产产品数】:17/t【现仓储量为】:28
【已经消费产品数】:16/t【现仓储量为】:12
【已经生产产品数】:16/t【现仓储量为】:28
【已经消费产品数】:15/t【现仓储量为】:13
【已经生产产品数】:15/t【现仓储量为】:28
【已经消费产品数】:14/t【现仓储量为】:14
【已经生产产品数】:14/t【现仓储量为】:28
【已经生产产品数】:13/t【现仓储量为】:41
【已经消费产品数】:19/t【现仓储量为】:22
【已经消费产品数】:10/t【现仓储量为】:12
【已经消费产品数】:12/t【现仓储量为】:0

Process finished with exit code 0
```

### 工作原理

共享缓冲区是此程序的核心，它里面内聚了一个普通的列表list。

在生产产品时，首先通过synchronized关键字获取列表list的对象锁，然后进行业务判断，如果当前集合的剩余空间无法容纳要生产的元素，则调用list.wait()，进入等待状态，并释放list对象锁，使其他线程有机会获取对象锁。如果可以生产，则进行相关操作，最后通过调用list.notifyAll()来唤醒等待状态中的线程，并释放list对象锁。

在消费产品时，首先通过synchronized关键字获取列表list的对象锁，然后进行业务判断，如果当前集合中没有足够的元素供消费，则调用list.wait()，进入等待状态，并释放list对象锁，使其他线程有机会获取对象锁。如果可以消费，则进行相关操作，最后通过调用list.notifyAll()来唤醒等待状态中的线程，并释放对象锁。

由于缓冲池实现了共享数据结构的访问和同步，因此生产者线程和消费者线程的实现就相对简单，只是调用共享缓冲池的生产方法和消费方法。

使用对象锁实现生产者消费者的另一个关键点在于，生产者和消费者要使用同一个共享缓冲池对象，即buffer对象。
