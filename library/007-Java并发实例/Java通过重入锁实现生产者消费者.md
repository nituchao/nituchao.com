---
"title": "Java通过重入锁实现生产者消费者",
"categories": ["Queue"],
"tags": ["JAVA", "QUEUE"],
"date": "2016-12-27T16:12:12+08:00"

---

ReentrantLock是一个可重入的互斥锁，又被称为"独占锁"，ReentrantLock锁在同一个时间点只能被一个线程锁持有，而可重入的意思是，ReentrantLock可以被单个线程多次获取，ReentrantLock的性能并不高，优点是比价灵活。ReentrantLock比Synchronized关键词更加灵活，并且能支持条件变量，后面我还会单独介绍使用条件变量实现生产者消费者模型的方法。

### 设计思想
本文希望同ReentrantLock来实现一个共享缓冲区，生产者线程和消费者线程通过该共享缓冲区来实现相关的生产和消费操作，每个线程对共享缓冲区的访问是互斥的。

另外，由于共享缓冲区是有空间限制的，生产者在生产前要判断共享缓冲区空间是否充足。消费者在消费前要判断共享缓冲区内的元素是否足够消费。

### 代码实现
根据上面的设计思想，我们需要实现共享缓冲区，生产者线程，消费者线程，主程序等四个部分。

**共享缓冲区**
```
package com.nituchao.jvm.prosumer.reentrant;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReentrantLock;

/**
 * 共享缓冲区
 * Created by liang on 2016/12/30.
 */
public class Buffer {
    private final List<String> list;
    private int MAX_SIZE = 10;
    private final Lock lock;

    public Buffer() {
        this.list = new ArrayList<String>();
        this.lock = new ReentrantLock();
    }

    /**
     * 生产num个元素
     *
     * @param num
     * @return
     */
    public boolean bufferProduct(int num) {
        boolean result = true;
        try {
            lock.lock();

            // 检查缓冲区是否能够容纳要生产的元素
            if (list.size() + num <= MAX_SIZE) {
                // 开始生产
                for (int i = 0; i < num; i++) {
                    list.add(0, Thread.currentThread().getName() + ":" + (i + 1));
                }

                result = true;

                System.out.printf("Thread %s: Buffer Product succ, num is %d, buffer size is %d\n", Thread.currentThread().getName(), num, list.size());
            } else {
                result = false;

                System.out.printf("Thread %s: Buffer Product succ, num is %d, buffer size is %d\n", Thread.currentThread().getName(), num, list.size());
            }
        } catch (Exception e) {
            e.printStackTrace();
            result = false;
        } finally {
            lock.unlock();
        }

        return result;
    }

    /**
     * 消费num个元素
     *
     * @param num
     * @return
     */
    public boolean bufferConsume(int num) {
        boolean result = false;
        try {
            lock.lock();

            // 检查缓冲区是否有足够的元素供消费
            if (list.size() >= num) {
                // 开始消费
                for (int i = 0; i < num; i++) {
                    list.remove(0);
                }

                result = true;

                System.out.printf("Thread: %s, Buffer Consume succ, num is %d, buffer size is %d\n", Thread.currentThread().getName(), num, list.size());
            } else {
                result = false;

                System.out.printf("Thread: %s, Buffer Consume fail, num is %d, buffer size is %d\n", Thread.currentThread().getName(), num, list.size());
            }
        } catch (Exception e) {
            e.printStackTrace();
            result = false;
        } finally {
            lock.unlock();
        }

        return result;
    }
}
```

**生产者线程**
```
package com.nituchao.jvm.prosumer.reentrant;

import java.util.Random;
import java.util.concurrent.TimeUnit;

/**
 * 生产者线程
 * Created by liang on 2016/12/30.
 */
public class BufferProducer implements Runnable {
    private int num;
    private Buffer buffer;

    public BufferProducer(Buffer buffer, int num) {
        this.num = num;
        this.buffer = buffer;
    }

    @Override
    public void run() {
        // 生产num个元素，如果生产失败，则休眠一段时间重新生产
        while (!buffer.bufferProduct(num)) {
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
package com.nituchao.jvm.prosumer.reentrant;

import java.util.Random;
import java.util.concurrent.TimeUnit;

/**
 * 消费者线程
 * Created by liang on 2016/12/30.
 */
public class BufferConsumer implements Runnable {
    private int num;
    private Buffer buffer;

    public BufferConsumer(Buffer buffer, int num) {
        this.num = num;
        this.buffer = buffer;
    }

    @Override
    public void run() {
        // 消费num个产品，如果消费失败，则休眠一段时间再重新消费
        while (!buffer.bufferConsume(num)) {
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
package com.nituchao.jvm.prosumer.reentrant;

/**
 * 主程序
 * Created by liang on 2016/12/30.
 */
public class BufferMain {

    public static void main(String[] args) {
        int num = 10;
        // 实例化Buffer
        Buffer buffer = new Buffer();

        // 实例化生产者和消费者线程集合
        Thread[] threadProducers = new Thread[num];
        Thread[] threadConsumers = new Thread[num];

        // 实例化生产者和消费者线程
        for (int i = 0; i < num; i++) {
            Thread threadProducer = new Thread(new BufferProducer(buffer, i + 1));
            Thread threadConsumer = new Thread(new BufferConsumer(buffer, i + 1));

            threadProducers[i] = threadProducer;
            threadConsumers[i] = threadConsumer;
        }

        // 启动生产者和消费者线程
        for (int i = 0; i < num; i++) {
            threadConsumers[i].start();

            threadProducers[i].start();
        }
    }
}

```

### 运行结果
```
Connected to the target VM, address: '127.0.0.1:53178', transport: 'socket'
Thread: Thread-1, Buffer Consume fail, num is 1, buffer size is 0
Thread Thread-0: Buffer Product succ, num is 1, buffer size is 1
Thread: Thread-3, Buffer Consume fail, num is 2, buffer size is 1
Thread Thread-2: Buffer Product succ, num is 2, buffer size is 3
Thread: Thread-3, Buffer Consume succ, num is 2, buffer size is 1
Thread: Thread-5, Buffer Consume fail, num is 3, buffer size is 1
Thread: Thread-5, Buffer Consume fail, num is 3, buffer size is 1
Thread: Thread-5, Buffer Consume fail, num is 3, buffer size is 1
Thread Thread-4: Buffer Product succ, num is 3, buffer size is 4
Thread: Thread-7, Buffer Consume succ, num is 4, buffer size is 0
Thread Thread-6: Buffer Product succ, num is 4, buffer size is 4
Thread: Thread-9, Buffer Consume fail, num is 5, buffer size is 4
Thread: Thread-9, Buffer Consume fail, num is 5, buffer size is 4
Thread: Thread-9, Buffer Consume fail, num is 5, buffer size is 4
Thread Thread-8: Buffer Product succ, num is 5, buffer size is 9
Thread: Thread-11, Buffer Consume succ, num is 6, buffer size is 3
Thread Thread-10: Buffer Product succ, num is 6, buffer size is 9
Thread: Thread-13, Buffer Consume succ, num is 7, buffer size is 2
Thread Thread-12: Buffer Product succ, num is 7, buffer size is 9
Thread: Thread-15, Buffer Consume succ, num is 8, buffer size is 1
Thread Thread-14: Buffer Product succ, num is 8, buffer size is 9
Thread: Thread-17, Buffer Consume succ, num is 9, buffer size is 0
Thread Thread-16: Buffer Product succ, num is 9, buffer size is 9
Thread: Thread-19, Buffer Consume fail, num is 10, buffer size is 9
Thread: Thread-19, Buffer Consume fail, num is 10, buffer size is 9
Thread: Thread-19, Buffer Consume fail, num is 10, buffer size is 9
Thread: Thread-19, Buffer Consume fail, num is 10, buffer size is 9
Thread: Thread-19, Buffer Consume fail, num is 10, buffer size is 9
Thread Thread-18: Buffer Product succ, num is 10, buffer size is 9
Thread: Thread-1, Buffer Consume succ, num is 1, buffer size is 8
Thread: Thread-5, Buffer Consume succ, num is 3, buffer size is 5
Thread: Thread-9, Buffer Consume succ, num is 5, buffer size is 0
Thread: Thread-19, Buffer Consume fail, num is 10, buffer size is 0
Thread: Thread-19, Buffer Consume fail, num is 10, buffer size is 0
Thread: Thread-19, Buffer Consume fail, num is 10, buffer size is 0
Thread: Thread-19, Buffer Consume fail, num is 10, buffer size is 0
Thread: Thread-19, Buffer Consume fail, num is 10, buffer size is 0
Disconnected from the target VM, address: '127.0.0.1:53178', transport: 'socket'
Thread: Thread-19, Buffer Consume fail, num is 10, buffer size is 0
Thread Thread-18: Buffer Product succ, num is 10, buffer size is 10
Thread: Thread-19, Buffer Consume succ, num is 10, buffer size is 0

Process finished with exit code 0

```

### 工作原理
主程序首先实例化一个共享缓冲区对象buffer，然后将该共享缓冲区对象buffer作为构造参数生成若干个生产者线程，和若干个消费者线程。

生产者线程调用共享缓冲区的bufferProduce(num)方法生产元素，在生产前要先获取锁(lock.lock()方法)，并判断当前共享缓冲区是否能够容纳所有元素，如果不能容纳，则直接返回false，并释放锁。如果可以容纳，则进行生产活动，返回true，并释放锁。生产者线程在一个while循环里判断，如果生产失败(返回false)，则等待一段时间，重新开始执行生产操作。如果生产成功，则结束当前线程。

消费者线程调用共享缓冲区的bufferConsume(num)方法消费元素，在生产前要先获取锁(lock.lock()方法)，并判断当前共享缓冲区是否有足够的元素供消费，如果元素数量不够，则直接返回false，并释放锁。如果元素足够，则进行消费活动，返回true，并释放锁。消费者线程在一个while循环里判断，如果消费失败(返回false)，则等待一段时间，重新开始执行消费操作。如果消费成功，则结束当前线程。
