---
title: "Java通过信号量机制实现生产者消费者"
categories: ["Queue"]
tags: ["JAVA"]
publish: true
date: "2016-12-27T16:12:12+08:00"
description: 
---

信号量是一种计数器，用来保护一个或者多个共享资源的访问。Java提供了Semaphore类来实现信号量机制。

如果线程要访问一个共享资源，它必须先获得信号量。如果信号量的内部计数器大于0，信号量将减1，然后允许访问这个共享资源。计数器大于0意味着有可以使用的资源，因此线程将被允许使用其中一个资源。

否则，如果信号量的计数器等于0，信号量将会把线程置入休眠直至计数器大于0.计数器等于0的时候意味着所有的共享资源已经被其他线程使用了，所以需要访问这个共享资源的线程必须等待。

当线程使用完某个共享资源时，信号量必须被释放，以便其他线程能够访问共享资源。释放操作将使信号量的内部计数器增加1。

### 设计思想

为了使用信号量机制来实现生产者VS消费者模型，我们需要实例化一个二进制信号量对象，即内部计数器只有0和1两个值。多个生产者线程和多个消费者线程竞争这个信号量来互斥访问共享缓冲区。

另外，由于共享缓冲区是有空间限制的，生产者在生产前要判断共享缓冲区空间是否充足。消费者在消费前要判断共享缓冲区内的元素是否足够消费。

### 代码实现
基于上面的设计思想，我们需要实现共享缓冲区，生产者线程，消费者线程和主程序四部分。

**共享缓冲区**

```
package com.nituchao.jvm.prosumer.semaphore;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Semaphore;

/**
 * 缓冲区
 * Created by liang on 2016/12/29.
 */
public class Buffer {
    private int MAX_SIZE = 100;
    private final List<String> list;
    private final Semaphore semaphore;

    public Buffer() {
        this.list = new ArrayList<>();
        this.semaphore = new Semaphore(1);
    }

    /**
     * 生产Buffer元素
     *
     * @param num
     */
    public boolean BufferProduct(int num) {
        boolean result = true;

        try {
            // 获取信号量
            semaphore.acquire();

            // 如果缓冲区能够容纳要生成的元素，允许生产
            if (list.size() + num <= MAX_SIZE) {
                // 开始生产
                for (int i = 1; i <= num; i++) {
                    list.add(0, Thread.currentThread().getName() + " : " + i);
                }

                result = true;

                System.out.printf("Thread %s: Buffer Product succ, num is %d, buffer size is %d\n", Thread.currentThread().getName(), num, list.size());
            } else {
                // 缓冲区无法容纳要生成的元素，禁止生产
                result = false;

                System.out.printf("Thread %s: Buffer Product fail, num is %d, buffer size is %d\n", Thread.currentThread().getName(), num, list.size());
            }
        } catch (InterruptedException e) {
            e.printStackTrace();
        } finally {
            semaphore.release();
        }

        return result;
    }

    /**
     * 消费Buffer元素
     *
     * @param num
     * @return
     */
    public boolean BufferConsume(int num) {
        boolean result = true;

        try {
            // 获取信号量
            semaphore.acquire();

            // 如果缓冲区中有足够的元素消费，允许消费
            if (list.size() - num >= 0) {
                // 开始消费
                for (int i = 1; i <= num; i++) {
                    String element = list.remove(0);
                }

                result = true;

                System.out.printf("Thread: %s, Buffer Consume succ, num is %d, buffer size is %d\n", Thread.currentThread().getName(), num, list.size());
            } else {
                // 缓冲取没有足够的元素供消费，禁止消费
                result = false;

                System.out.printf("Thread: %s, Buffer Consume fail, num is %d, buffer size is %d\n", Thread.currentThread().getName(), num, list.size());
            }
        } catch (InterruptedException e) {
            e.printStackTrace();
        } finally {
            semaphore.release();
        }

        return result;
    }
}

```

**生产者线程**

```
package com.nituchao.jvm.prosumer.semaphore;

import java.util.Random;
import java.util.concurrent.TimeUnit;

/**
 * 生产者线程
 * Created by liang on 2016/12/29.
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
        while (!buffer.BufferProduct(num)) {
            try {
                TimeUnit.MILLISECONDS.sleep(new Random(1000).nextInt());
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        }
    }
}


```

**消费者线程**

```
package com.nituchao.jvm.prosumer.semaphore;

import java.util.Random;
import java.util.concurrent.TimeUnit;

/**
 * 消费者线程
 * Created by liang on 2016/12/29.
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
        while (!buffer.BufferConsume(num)) {
            try {
                TimeUnit.MILLISECONDS.sleep(new Random(1000).nextInt());
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        }
    }
}

```

**主程序**

```
package com.nituchao.jvm.prosumer.semaphore;

/**
 * 主程序
 * Created by liang on 2016/12/29.
 */
public class BufferMain {

    public static void main(String[] args) {
        int num = 10;

        // 初始化Buffer对象
        Buffer buffer = new Buffer();

        // 实例化num个生产者和消费者线程
        Thread[] threadProducers = new Thread[num];
        Thread[] threadConsumers = new Thread[num];

        for (int i = 0; i < num; i++) {
            threadProducers[i] = new Thread(new BufferProducer(buffer, i + 1));
            threadConsumers[i] = new Thread(new BufferConsumer(buffer, i + 1));
        }

        // 分别启动生产者和消费者线程
        for (int i = 0; i < num; i++) {
            // 故意先开始消费
            threadConsumers[i].start();

            // 故意后开始生产
            threadProducers[i].start();
        }
    }
}

```

### 运行结果

```
Connected to the target VM, address: '127.0.0.1:61012', transport: 'socket'
Thread: Thread-1, Buffer Consume fail, num is 1, buffer size is 0
Thread Thread-0: Buffer Product succ, num is 1, buffer size is 1
Thread: Thread-3, Buffer Consume fail, num is 2, buffer size is 1
Thread Thread-2: Buffer Product succ, num is 2, buffer size is 3
Thread: Thread-5, Buffer Consume succ, num is 3, buffer size is 0
Thread Thread-4: Buffer Product succ, num is 3, buffer size is 3
Thread: Thread-7, Buffer Consume fail, num is 4, buffer size is 3
Thread: Thread-7, Buffer Consume fail, num is 4, buffer size is 3
Thread: Thread-7, Buffer Consume fail, num is 4, buffer size is 3
Thread: Thread-7, Buffer Consume fail, num is 4, buffer size is 3
Thread: Thread-7, Buffer Consume fail, num is 4, buffer size is 3
Thread: Thread-7, Buffer Consume fail, num is 4, buffer size is 3
Thread Thread-6: Buffer Product succ, num is 4, buffer size is 7
Thread: Thread-9, Buffer Consume succ, num is 5, buffer size is 2
Thread Thread-8: Buffer Product succ, num is 5, buffer size is 7
Thread: Thread-11, Buffer Consume succ, num is 6, buffer size is 1
Thread Thread-10: Buffer Product succ, num is 6, buffer size is 7
Thread: Thread-13, Buffer Consume succ, num is 7, buffer size is 0
Thread Thread-12: Buffer Product succ, num is 7, buffer size is 7
Thread: Thread-15, Buffer Consume fail, num is 8, buffer size is 7
Thread: Thread-15, Buffer Consume fail, num is 8, buffer size is 7
Thread: Thread-15, Buffer Consume fail, num is 8, buffer size is 7
Thread: Thread-15, Buffer Consume fail, num is 8, buffer size is 7
Thread: Thread-15, Buffer Consume fail, num is 8, buffer size is 7
Thread Thread-14: Buffer Product succ, num is 8, buffer size is 15
Thread: Thread-17, Buffer Consume succ, num is 9, buffer size is 6
Thread Thread-16: Buffer Product succ, num is 9, buffer size is 15
Thread: Thread-19, Buffer Consume succ, num is 10, buffer size is 5
Thread Thread-18: Buffer Product succ, num is 10, buffer size is 15
Thread: Thread-3, Buffer Consume succ, num is 2, buffer size is 13
Thread: Thread-1, Buffer Consume succ, num is 1, buffer size is 12
Thread: Thread-7, Buffer Consume succ, num is 4, buffer size is 8
Thread: Thread-15, Buffer Consume succ, num is 8, buffer size is 0
Disconnected from the target VM, address: '127.0.0.1:61012', transport: 'socket'

Process finished with exit code 0
```

### 工作原理
主程序首先实例化一个二进制信号量对象semaphore，指定该信号量内部计数器只有0和1，这样可以保证同一时间只有一个线程能够访问共享缓冲区。这样一来，共享缓冲区buffer本质上就成为一个队列。

主程序实例化num个生产者线程和num个消费者线程。

生产者线程负责向缓冲区里生产元素，每个生产者生产的数量都各不相同，从而能更好的观察效果。生产者首先会去尝试获取信号量(acquire)，然后检查当前共享缓冲区是否有足够空间容纳自己可生产的元素。如果有，则进行生产，如果没有，则不进行生产。最后，释放信号量(release)并把生产的结果返回(boolen)。生产者线程如果发现自己生产失败，则会随机休眠一段时间再重复上面的操作，直到生产操作成功。

消费者线程负责从缓冲区里消费元素，每个消费者消费的数量都各不相同，从而能更好的观察效果。消费者首先回去尝试获取信号量(acquire)，然后检查当前共享缓冲区中是否有足够的元素供自己消费。如果有，则进行消费，如果没有，则不进行消费。最后，释放信号量(release)并把消费的结果返回(boolean)。消费者线程如果发现自己消费失败，则会随机休眠一段时间再重复上面的操作，直到消费操作成功。

生产者线程和消费者线程访问是信号量是公平竞争，第一个获取信号量的线程将能够访问临界区，其余的线程将被信号量阻塞，直到信号量被释放。一旦信号量被释放，被被阻塞的线程就可以重新竞争信号量并访问临界区。
