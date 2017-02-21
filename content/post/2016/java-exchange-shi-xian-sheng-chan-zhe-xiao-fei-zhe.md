---
title: "Java通过Exchange机制实现生产者消费者"
categories: ["生产者VS消费者"]
tags: ["JAVA"]
publish: true
date: "2016-11-26T22:17:12+08:00"
description: Java并发API提供了一个同步辅助类Exchanger，它允许在并发线程之间交换数据。对于只有一个生产者和一个消费者的场景，可以使用该辅助类来设计实现。
---

Java并发API提供了一个同步辅助类---Exchanger，它允许并发线程之间交换数据。具体来说，Exchanger类允许在两个线程之间定义同步点(Synchronization Point)。当两个线程都达到同步点时，它们交换数据结构，因此第一个线程的数据结构进入到第二个线程中，同时第二个线程的数据结构进入到第一个线程。

生产者VS消费者模型本质上就是两个线程交换数据。因此，对于只有一个生产者和一个消费者的场景，就可以使用Exchanger类。

### 设计思想
为了通过Exchanger类实现生产者VS消费者模型，我们在设计的时候需要考虑以下三点：

1, 生产者线程和消费者线程需要各自持有一个自己的缓冲区对象。

2, 生产者线程和消费者线程需要持有一个共同的Exchanger对象，通过该对象实现两个线程的同步和数据结构交换。

3, 消费者每次交换前，需要清空自己的数据结构，因为消费者不需要给生产者传递数据。


### 代码实现
基于上面的设计，分别实现了生产者线程，消费者线程，主程序。

**生产者线程**

```
package com.nituchao.jvm.prosumer.exchanger;

import java.util.List;
import java.util.concurrent.Exchanger;

/**
 * 生产者
 * Created by liang on 2016/11/26.
 */
public class BufferProducer implements Runnable {
    private List<String> buffer;
    private final Exchanger<List<String>> exchanger;

    public BufferProducer(List<String> buffer, Exchanger<List<String>> exchanger) {
        this.buffer = buffer;
        this.exchanger = exchanger;
    }

    @Override
    public void run() {
        // 循环10次数据交换
        int cycle = 1;
        for (int i = 0; i < 10; i++) {
            System.out.printf("Buffer Producer: Cycle %d\n", cycle);

            // 在每个循环中，添加10个字符串到buffer列表中
            for (int j = 0; j < 10; j++) {
                String message = "Data " + ((i * 10) + j);
                System.out.printf("Buffer Producer: %s\n", message);
                buffer.add(message);
            }

            // 调用exchange()方法与消费者进行数据交换
            try {
                buffer = exchanger.exchange(buffer);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }

            System.out.printf("Exchange ok, Cycle %d, Buffer Producer size: %d\n", cycle, buffer.size());
            cycle++;
        }
    }
}

```

**消费者线程**

```
package com.nituchao.jvm.prosumer.exchanger;

import java.util.List;
import java.util.concurrent.Exchanger;

/**
 * 消费者
 * Created by liang on 2016/11/26.
 */
public class BufferConsumer implements Runnable {
    private List<String> buffer;
    private final Exchanger<List<String>> exchanger;

    public BufferConsumer(List<String> buffer, Exchanger<List<String>> exchanger) {
        this.buffer = buffer;
        this.exchanger = exchanger;
    }

    @Override
    public void run() {
        // 循环10次交换数据
        int cycle = 1;
        for (int i = 0; i < 10; i++) {
            System.out.printf("Buffer Consumer: Cycle %d\n", cycle);

            // 在每个循环中，调用exchange()方法与生产者同步，消费数据
            try {
                buffer = exchanger.exchange(buffer);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }

            System.out.printf("Exchnage ok, Cycle %d, Buffer Consumer size: %d\n", cycle, buffer.size());
            // 消费buffer中的数据，并情况列表
            for (int j = 0; j < 10; j++) {
                String message = buffer.get(0);
                System.out.println("Buffer Consumer: " + message);
                buffer.remove(0);
            }

            cycle++;
        }
    }
}

```

**主程序**

```
package com.nituchao.jvm.prosumer.exchanger;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Exchanger;

/**
 * 主程序
 * Created by liang on 2016/11/26.
 */
public class BufferMain {
    public static void main(String[] args) {
        // 为生产者和消费者各创建一个缓冲区
        List<String> buffer1 = new ArrayList<>();
        List<String> buffer2 = new ArrayList<>();

        // 创建Exchanger对象，用来同步生产者和消费者
        Exchanger<List<String>> exchanger = new Exchanger<>();

        // 创建生产者Producer对象和消费者对象Consumer对象
        BufferProducer bufferProducer = new BufferProducer(buffer1, exchanger);
        BufferConsumer bufferConsumer = new BufferConsumer(buffer2, exchanger);

        // 创建生产者线程和消费者线程
        Thread threadProducer = new Thread(bufferProducer);
        Thread threadConsumer = new Thread(bufferConsumer);

        // 启动
        threadProducer.start();
        threadConsumer.start();
    }
}

```

### 运行结果
运行上面的主程序，得到的输出信息如下:

```
Connected to the target VM, address: '127.0.0.1:55618', transport: 'socket'
Buffer Producer: Cycle 1
Buffer Consumer: Cycle 1
Buffer Producer: Data 0
Buffer Producer: Data 1
Buffer Producer: Data 2
Buffer Producer: Data 3
Buffer Producer: Data 4
Buffer Producer: Data 5
Buffer Producer: Data 6
Buffer Producer: Data 7
Buffer Producer: Data 8
Buffer Producer: Data 9
Exchange ok, Cycle 1, Buffer Producer size: 0
Buffer Producer: Cycle 2
Exchnage ok, Cycle 1, Buffer Consumer size: 10
Buffer Producer: Data 10
Buffer Consumer: Data 0
Buffer Producer: Data 11
Buffer Consumer: Data 1
Buffer Producer: Data 12
Buffer Consumer: Data 2
Buffer Producer: Data 13
Buffer Consumer: Data 3
Buffer Producer: Data 14
Buffer Consumer: Data 4
Buffer Producer: Data 15
Buffer Consumer: Data 5
Buffer Producer: Data 16
Buffer Consumer: Data 6
Buffer Producer: Data 17
Buffer Consumer: Data 7
Buffer Producer: Data 18
Buffer Consumer: Data 8
Buffer Producer: Data 19
Buffer Consumer: Data 9
Buffer Consumer: Cycle 2
Exchnage ok, Cycle 2, Buffer Consumer size: 10
Exchange ok, Cycle 2, Buffer Producer size: 0
Buffer Producer: Cycle 3
Buffer Consumer: Data 10
Buffer Producer: Data 20
Buffer Consumer: Data 11
Buffer Producer: Data 21
Buffer Consumer: Data 12
Buffer Producer: Data 22
Buffer Consumer: Data 13
Buffer Consumer: Data 14
Buffer Consumer: Data 15
Buffer Producer: Data 23
Buffer Producer: Data 24
Buffer Consumer: Data 16
Buffer Producer: Data 25
Buffer Consumer: Data 17
Buffer Producer: Data 26
Buffer Producer: Data 27
Buffer Consumer: Data 18
Buffer Producer: Data 28
Buffer Producer: Data 29
Buffer Consumer: Data 19
Buffer Consumer: Cycle 3
Exchnage ok, Cycle 3, Buffer Consumer size: 10
Exchange ok, Cycle 3, Buffer Producer size: 0
Buffer Producer: Cycle 4
Buffer Consumer: Data 20
Buffer Producer: Data 30
Buffer Consumer: Data 21
Buffer Producer: Data 31
Buffer Consumer: Data 22
Buffer Producer: Data 32
Buffer Consumer: Data 23
Buffer Producer: Data 33
Buffer Consumer: Data 24
Buffer Producer: Data 34
Buffer Producer: Data 35
Buffer Producer: Data 36
Buffer Producer: Data 37
Buffer Consumer: Data 25
Buffer Producer: Data 38
Buffer Consumer: Data 26
Buffer Producer: Data 39
Buffer Consumer: Data 27
Buffer Consumer: Data 28
Buffer Consumer: Data 29
Buffer Consumer: Cycle 4
Exchnage ok, Cycle 4, Buffer Consumer size: 10
Buffer Consumer: Data 30
Buffer Consumer: Data 31
Exchange ok, Cycle 4, Buffer Producer size: 0
Buffer Producer: Cycle 5
Buffer Producer: Data 40
Buffer Producer: Data 41
Buffer Producer: Data 42
Buffer Producer: Data 43
Buffer Producer: Data 44
Buffer Consumer: Data 32
Buffer Producer: Data 45
Buffer Producer: Data 46
Buffer Producer: Data 47
Buffer Producer: Data 48
Buffer Producer: Data 49
Buffer Consumer: Data 33
Buffer Consumer: Data 34
Buffer Consumer: Data 35
Buffer Consumer: Data 36
Buffer Consumer: Data 37
Buffer Consumer: Data 38
Buffer Consumer: Data 39
Buffer Consumer: Cycle 5
Exchnage ok, Cycle 5, Buffer Consumer size: 10
Exchange ok, Cycle 5, Buffer Producer size: 0
Buffer Producer: Cycle 6
Buffer Consumer: Data 40
Buffer Consumer: Data 41
Buffer Consumer: Data 42
Buffer Consumer: Data 43
Buffer Producer: Data 50
Buffer Consumer: Data 44
Buffer Producer: Data 51
Buffer Consumer: Data 45
Buffer Producer: Data 52
Buffer Consumer: Data 46
Buffer Producer: Data 53
Buffer Consumer: Data 47
Buffer Producer: Data 54
Buffer Producer: Data 55
Buffer Consumer: Data 48
Buffer Producer: Data 56
Buffer Producer: Data 57
Buffer Producer: Data 58
Buffer Consumer: Data 49
Buffer Consumer: Cycle 6
Buffer Producer: Data 59
Exchange ok, Cycle 6, Buffer Producer size: 0
Buffer Producer: Cycle 7
Exchnage ok, Cycle 6, Buffer Consumer size: 10
Buffer Producer: Data 60
Buffer Consumer: Data 50
Buffer Consumer: Data 51
Buffer Consumer: Data 52
Buffer Producer: Data 61
Buffer Consumer: Data 53
Buffer Producer: Data 62
Buffer Consumer: Data 54
Buffer Producer: Data 63
Buffer Consumer: Data 55
Buffer Consumer: Data 56
Buffer Consumer: Data 57
Buffer Producer: Data 64
Buffer Consumer: Data 58
Buffer Producer: Data 65
Buffer Consumer: Data 59
Buffer Consumer: Cycle 7
Buffer Producer: Data 66
Buffer Producer: Data 67
Buffer Producer: Data 68
Buffer Producer: Data 69
Exchange ok, Cycle 7, Buffer Producer size: 0
Buffer Producer: Cycle 8
Exchnage ok, Cycle 7, Buffer Consumer size: 10
Buffer Consumer: Data 60
Buffer Producer: Data 70
Buffer Consumer: Data 61
Buffer Producer: Data 71
Buffer Consumer: Data 62
Buffer Consumer: Data 63
Buffer Producer: Data 72
Buffer Consumer: Data 64
Buffer Producer: Data 73
Buffer Consumer: Data 65
Buffer Producer: Data 74
Buffer Consumer: Data 66
Buffer Producer: Data 75
Buffer Consumer: Data 67
Buffer Producer: Data 76
Buffer Consumer: Data 68
Buffer Producer: Data 77
Buffer Consumer: Data 69
Buffer Producer: Data 78
Buffer Consumer: Cycle 8
Buffer Producer: Data 79
Exchange ok, Cycle 8, Buffer Producer size: 0
Buffer Producer: Cycle 9
Buffer Producer: Data 80
Exchnage ok, Cycle 8, Buffer Consumer size: 10
Buffer Consumer: Data 70
Buffer Consumer: Data 71
Buffer Consumer: Data 72
Buffer Consumer: Data 73
Buffer Producer: Data 81
Buffer Consumer: Data 74
Buffer Producer: Data 82
Buffer Consumer: Data 75
Buffer Producer: Data 83
Buffer Consumer: Data 76
Buffer Producer: Data 84
Buffer Consumer: Data 77
Buffer Producer: Data 85
Buffer Consumer: Data 78
Buffer Producer: Data 86
Buffer Consumer: Data 79
Buffer Producer: Data 87
Buffer Consumer: Cycle 9
Buffer Producer: Data 88
Buffer Producer: Data 89
Exchange ok, Cycle 9, Buffer Producer size: 0
Buffer Producer: Cycle 10
Buffer Producer: Data 90
Exchnage ok, Cycle 9, Buffer Consumer size: 10
Buffer Producer: Data 91
Buffer Consumer: Data 80
Buffer Producer: Data 92
Buffer Consumer: Data 81
Buffer Producer: Data 93
Buffer Consumer: Data 82
Buffer Producer: Data 94
Buffer Consumer: Data 83
Buffer Producer: Data 95
Buffer Producer: Data 96
Buffer Producer: Data 97
Buffer Producer: Data 98
Buffer Producer: Data 99
Buffer Consumer: Data 84
Buffer Consumer: Data 85
Buffer Consumer: Data 86
Buffer Consumer: Data 87
Buffer Consumer: Data 88
Buffer Consumer: Data 89
Buffer Consumer: Cycle 10
Exchnage ok, Cycle 10, Buffer Consumer size: 10
Exchange ok, Cycle 10, Buffer Producer size: 0
Buffer Consumer: Data 90
Buffer Consumer: Data 91
Buffer Consumer: Data 92
Buffer Consumer: Data 93
Buffer Consumer: Data 94
Buffer Consumer: Data 95
Buffer Consumer: Data 96
Buffer Consumer: Data 97
Buffer Consumer: Data 98
Buffer Consumer: Data 99
Disconnected from the target VM, address: '127.0.0.1:55618', transport: 'socket'

Process finished with exit code 0

```

### 工作原理
消费者先创建一个空的缓存区，然后通过调用Exchanger与生产者同步来获得可以消费的数据。生产者从一个空的缓存列表开始执行，它创建了10个字符串，然后存储在这个缓存中，并且使用exchanger对象与消费者同步。两者共享一个exchanger对象。

在这个同步点上，两个线程(生产者和消费者)都在Exchanger里，它们交换数据结构，当消费者从exchange()方法返回的时候，它的缓存列表有10个字符串。当生产者从exchange()返回的时候，它的缓存列表是空的。这个操作将循环执行10次。
