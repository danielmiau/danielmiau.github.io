# 08-JUC并发工具类实战

## 本章概述

本章是JUC高权重核心实战章节，聚焦**多线程协作同步**核心场景，主要讲解两大高频并发工具类：CountDownLatch倒计时计数器与CyclicBarrier循环栅栏。区别于锁机制保障单资源线程安全，本章工具类核心用于**控制多线程执行顺序、实现线程间协同等待、分批同步、任务汇总**。本章将从底层原理、核心方法、落地场景、实战代码、避坑方案全方位拆解，讲透两类工具类的实现差异、适用边界与生产最佳实践，帮助解决项目中多线程并行汇总、多阶段分批执行、异步任务同步等待等核心问题，为后续Semaphore、Exchanger工具类学习及高并发业务落地奠定基础。

---

# 1. `CountDownLatch` 计数器：`await()`/`countDown()` 使用场景

CountDownLatch 是JUC最常用的并发同步工具，核心作用是**实现一组线程全部执行完成后，再唤醒主线程继续执行**，主打一次性线程等待计数，是并行任务汇总、异步任务同步的首选工具。

## 1.1 `CountDownLatch` 核心原理

### 1.1.1 定义：基于AQS实现的一次性计数器

**CountDownLatch** 是一个**基于AQS共享模式实现的一次性同步计数器**，用于控制一个或多个线程，等待其他一组线程执行完毕后再继续执行。

核心特性：一次性使用、不可重置、递减计数，计数归零后无法再次使用，区别于可循环复用的CyclicBarrier，是面试和生产中高频对比考点。

### 1.1.2 核心逻辑：初始化计数器，线程执行countDown()递减计数，await()阻塞等待计数归零

CountDownLatch 的完整执行逻辑清晰固定，分为三步，是理解其使用的核心：

1. **初始化计数**：创建CountDownLatch对象时，传入指定计数器阈值N，代表需要等待的子线程任务总数；

2. **子线程递减计数**：每一个子线程执行完成后，调用`countDown()`方法，计数器数值原子性减1；

3. **主线程阻塞等待**：主线程调用`await()`方法进入阻塞状态，持续等待，直到计数器数值递减至0，所有等待线程被统一唤醒，继续执行后续业务。

### 1.1.3 底层实现：AQS共享模式、state变量表示计数

CountDownLatch 底层完全依赖 **AQS（AbstractQueuedSynchronizer）共享锁模式** 实现，核心底层逻辑：

- 将AQS的 **state变量** 作为自定义计数器，初始化时state = 传入的计数阈值；

- `countDown()` 底层调用AQS释放共享锁方法，CAS将state原子递减；

- `await()`底层调用AQS获取共享锁方法，当state > 0时，当前线程加入AQS等待队列阻塞；

- 当state递减为0时，AQS自动唤醒队列中所有阻塞的等待线程，完成同步放行。

**核心关键点**：state计数归零后，不会重置，这是CountDownLatch**不可复用**的底层根源。

## 1.2 核心方法详解

### 1.2.1 `await()` 方法：阻塞当前线程，等待计数归零

**无参阻塞方法**：调用该方法的线程会无限阻塞，直到计数器数值归0，或者线程被中断唤醒。

使用场景：确定子线程任务一定会执行完成，无需超时控制的同步场景。

异常特性：线程阻塞期间若被中断，会直接抛出 `InterruptedException` 中断异常。

### 1.2.2 `await(long timeout, TimeUnit unit)`：限时等待，超时自动唤醒

**限时阻塞方法**：阻塞当前线程，在指定时间内等待计数器归零；若超时后计数仍未归零，线程**自动唤醒、不再阻塞**，继续向下执行。

返回值为boolean类型：**true=计数归零正常唤醒，false=超时强制唤醒**。

生产核心用途：**防止子线程卡死、死循环导致主线程永久阻塞**，是生产环境必须优先使用的安全写法。

### 1.2.3 `countDown()` 方法：计数器减1，触发等待线程唤醒

每调用一次该方法，AQS中的state计数器原子性减1，无返回值。

核心执行逻辑：

- 调用后判断state是否为0；

- 若state > 0：仅计数递减，不做任何唤醒操作；

- 若state = 0：触发AQS共享锁唤醒机制，唤醒所有阻塞的等待线程。

**避坑点**：该方法必须放在子线程finally代码块中执行，保证无论任务正常结束或异常报错，计数器都会递减，避免主线程永久阻塞。

### 1.2.4 `getCount()` 方法：获取当前计数器值

实时获取当前AQS中剩余的计数器数值，用于监控任务执行进度、日志打印、异常排查。

生产场景：批量任务执行时，打印剩余未完成任务数，方便定位卡死、阻塞问题。

## 1.3 典型使用场景

### 1.3.1 主线程等待多个子线程执行完毕（并行任务汇总）

最经典场景：将一个大任务拆分为多个子任务，多线程并行执行，所有子任务执行完毕后，主线程统一汇总结果，大幅提升任务执行效率。例如文件分片解析、数据批量查询、接口并行调用。

### 1.3.2 多线程异步任务结果汇总

业务中多个无依赖的异步查询任务（如查询用户信息、订单信息、支付信息），通过多线程并行执行，全部执行完成后统一封装返回结果，减少接口响应时间。

### 1.3.3 启动类中服务初始化同步控制

项目启动时，需要并行执行配置加载、缓存预热、数据初始化等任务，通过CountDownLatch保证所有初始化任务完成后，再开启服务端口对外提供服务，避免服务启动未完成导致接口报错。

### 1.3.4 单元测试中异步任务等待

Junit单元测试中，主线程执行速度快于子线程，会导致测试提前结束、无法捕获异步任务结果，通过CountDownLatch阻塞主线程，保证异步任务执行完成后再校验测试结果。

## 1.4 实战代码示例与避坑指南

### 1.4.1 并行任务执行与结果汇总代码示例

```java

import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * CountDownLatch 并行任务汇总实战
 * 场景：开启5个线程并行执行任务，主线程等待全部完成后汇总结果
 */
public class CountDownLatchTaskDemo {
    // 定义计数器：需要等待5个子线程任务完成
    private static final CountDownLatch LATCH = new CountDownLatch(5);
    // 固定线程池，匹配任务数量
    private static final ExecutorService POOL = Executors.newFixedThreadPool(5);

    public static void main(String[] args) throws InterruptedException {
        System.out.println("主线程：开始执行批量任务");

        // 提交5个并行任务
        for (int i = 1; i <= 5; i++) {
            int taskId = i;
            POOL.execute(() -> {
                try {
                    // 模拟子线程业务执行
                    System.out.println("子线程" + taskId + "：执行任务中...");
                    Thread.sleep(1000);
                    System.out.println("子线程" + taskId + "：任务执行完成");
                } catch (InterruptedException e) {
                    e.printStackTrace();
                } finally {
                    // 【核心】无论任务是否异常，都递减计数器，防止主线程阻塞
                    LATCH.countDown();
                }
            });
        }

        // 主线程阻塞，等待所有子任务完成
        LATCH.await();
        System.out.println("主线程：所有子任务执行完毕，开始汇总结果！");
        POOL.shutdown();
    }
}

```

### 1.4.2 超时等待的处理方式

生产环境**禁止使用无参await()**，避免子线程异常卡死导致主线程永久阻塞，必须使用限时等待方案，超时自动放行并做异常兜底。

```java

import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

/**
 * CountDownLatch 超时等待实战（生产推荐写法）
 */
public class CountDownLatchTimeoutDemo {
    private static final CountDownLatch LATCH = new CountDownLatch(2);

    public static void main(String[] args) throws InterruptedException {
        // 模拟耗时卡死的子线程
        new Thread(() -> {
            try {
                // 模拟任务卡死，耗时5秒
                Thread.sleep(5000);
            } catch (InterruptedException e) {
                e.printStackTrace();
            } finally {
                LATCH.countDown();
            }
        }).start();

        new Thread(() -> LATCH.countDown()).start();

        // 限时等待2秒，超时自动唤醒
        boolean success = LATCH.await(2, TimeUnit.SECONDS);
        if (success) {
            System.out.println("任务全部执行完成");
        } else {
            System.out.println("任务执行超时，剩余未完成计数：" + LATCH.getCount());
            // 超时兜底处理：日志告警、重试、降级
        }
    }
}

```

### 1.4.3 计数器无法重置、不可复用的特性说明

**核心特性（高频面试题）**：CountDownLatch 计数器归零后，**无法重置、不可二次复用**。

底层原因：AQS的state变量递减至0后，不会自动恢复初始值，再次调用await()会直接放行，无法实现新一轮等待。

避坑方案：若需要多轮循环同步任务，禁止使用CountDownLatch，必须使用**CyclicBarrier循环栅栏**。

常见报错场景：循环中重复使用同一个CountDownLatch对象，导致第二轮等待直接失效，线程无序执行。

---

# 2. `CyclicBarrier` 循环栅栏：`await()` 方法与循环特性

CyclicBarrier 是可循环复用的线程同步栅栏，主打**多线程分批同步、多轮重复执行**，解决CountDownLatch不可复用、仅支持单次同步的短板，适用于多阶段、多批次的并行同步任务。

## 2.1 `CyclicBarrier` 核心原理

### 2.1.1 定义：可循环复用的线程屏障，基于ReentrantLock与Condition实现

**CyclicBarrier（循环栅栏）** 是一个**可重复使用的多线程同步工具**，用于让一组线程到达同步屏障点后统一阻塞，等待所有线程全部抵达后，再统一批量放行。

与CountDownLatch基于AQS不同，CyclicBarrier 底层基于 **ReentrantLock + Condition条件队列** 实现，具备自动重置、循环复用的核心能力。

### 2.1.2 核心逻辑：指定数量线程到达屏障点后，统一放行，支持重置复用

CyclicBarrier 完整执行逻辑：

1. 初始化栅栏阈值（parties）：指定每批需要同步的线程数量；

2. 每个线程执行到同步点时调用await()，进入Condition条件队列阻塞；

3. 当阻塞线程数量等于阈值时，所有线程统一被唤醒，批量放行执行后续任务；

4. 本轮放行完成后，栅栏**自动重置计数**，开启下一轮等待，实现循环复用。

### 2.1.3 底层实现：锁+条件队列维护等待线程，count变量计数

核心底层结构：

- **ReentrantLock**：保证线程计数操作的原子性，防止并发计数错乱；

- **Condition**：维护阻塞等待的线程队列，统一批量唤醒；

- **count变量**：当前等待未凑齐的线程数，每来一个线程count-1；

- **parties变量**：固定栅栏阈值，每轮同步的线程总数，用于自动重置；

- **generation**：轮次标记，区分每一轮栅栏任务，处理中断、超时异常。

## 2.2 核心方法详解

### 2.2.1 `await()` 方法：线程到达屏障点，阻塞等待其他线程

线程调用该方法表示**当前线程已到达同步屏障点**，主动阻塞，等待剩余线程抵达。

当等待线程数凑齐阈值后，全部线程统一唤醒；若线程被中断，直接抛出异常，本轮栅栏失效。

### 2.2.2 `await(long timeout, TimeUnit unit)`：限时等待，超时抛出异常

限时阻塞等待，若指定时间内未凑齐线程数量，直接抛出 **TimeoutException** 超时异常，同时本轮栅栏标记为破损，不再复用。

生产用途：防止线程缺失导致整批任务永久阻塞，提升任务容错性。

### 2.2.3 `reset()` 方法：重置屏障，开启新一轮等待

手动重置栅栏状态，清空当前等待队列、恢复计数阈值，强制开启新一轮同步。

注意：重置时若有正在等待的线程，会直接抛出异常，慎用在任务执行中。

### 2.2.4 `getNumberWaiting()`/`getParties()`：获取等待线程数与屏障阈值

- **getParties()**：获取栅栏固定的同步线程阈值，初始化后固定不变；

- **getNumberWaiting()**：获取当前正在阻塞等待的线程数量，用于任务进度监控、异常排查。

## 2.3 典型使用场景

### 2.3.1 多阶段并行任务（多轮线程同步执行）

适用于任务分多阶段执行，每一轮都需要所有线程同步完成后，再进入下一阶段。例如数据清洗→数据计算→数据入库，三阶段分批同步执行。

### 2.3.2 大数据多线程分片处理，汇总阶段同步

大数据场景分片处理数据，每批分片数据处理完成后，统一汇总统计，再处理下一批数据，保证分批数据的完整性。

### 2.3.3 多线程分批执行，每批同步控制

海量任务分批并行执行，比如1000条数据，每10条为一批，每批线程全部执行完成后，再执行下一批，避免瞬间并发过高压垮服务。

### 2.3.4 循环任务中多线程协作

定时任务、轮询任务中，重复执行多线程同步逻辑，利用CyclicBarrier可循环特性，无需重复创建同步工具对象。

## 2.4 实战代码示例与避坑指南

### 2.4.1 多阶段并行任务代码示例

```java

import java.util.concurrent.CyclicBarrier;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * CyclicBarrier 多阶段循环同步实战
 * 场景：4个线程，分3轮同步执行任务，每轮全部到达屏障后统一放行
 */
public class CyclicBarrierStageDemo {
    // 初始化栅栏：每批4个线程同步
    private static final CyclicBarrier BARRIER = new CyclicBarrier(4);
    private static final ExecutorService POOL = Executors.newFixedThreadPool(4);

    public static void main(String[] args) {
        // 循环3轮执行同步任务
        for (int round = 1; round <= 3; round++) {
            System.out.println("===== 开始第" + round + "轮任务 =====");
            for (int i = 1; i <= 4; i++) {
                int threadId = i;
                POOL.execute(() -> {
                    try {
                        System.out.println("线程" + threadId + "：完成第" + round + "轮前置任务，等待其他线程");
                        // 到达屏障点，阻塞等待
                        BARRIER.await();
                        // 所有线程到达后统一执行后续任务
                        System.out.println("线程" + threadId + "：第" + round + "轮全部线程就绪，执行后置任务");
                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                });
            }
            // 等待本轮任务全部完成，进入下一轮
            try {
                Thread.sleep(2000);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        }
        POOL.shutdown();
    }
}

```

### 2.4.2 屏障触发时的回调任务（Runnable barrierAction）

CyclicBarrier 支持传入回调任务，**每轮线程凑齐、屏障放行前，优先执行回调任务**，常用于每轮任务的汇总、统计、日志打印，是生产高频用法。

```java

import java.util.concurrent.CyclicBarrier;
import java.util.concurrent.Executors;
import java.util.concurrent.ExecutorService;

public class CyclicBarrierCallbackDemo {
    // 带回调任务的栅栏：凑齐线程后优先执行汇总任务
    private static final CyclicBarrier BARRIER = new CyclicBarrier(4, () -> {
        System.out.println("【回调汇总任务】本轮所有线程执行完毕，统一汇总数据");
    });
    private static final ExecutorService POOL = Executors.newFixedThreadPool(4);

    public static void main(String[] args) {
        for (int i = 1; i <= 4; i++) {
            int id = i;
            POOL.execute(() -> {
                try {
                    System.out.println("线程" + id + "：任务执行完成，等待屏障放行");
                    BARRIER.await();
                } catch (Exception e) {
                    e.printStackTrace();
                }
            });
        }
        POOL.shutdown();
    }
}

```

### 2.4.3 线程中断、超时异常处理

CyclicBarrier 容错性较弱，存在两大核心异常场景，生产必须处理：

1. **线程中断异常**：任意等待线程被中断，本轮栅栏直接破损，所有等待线程抛出异常，无法继续复用；

2. **超时异常**：限时等待超时，栅栏破损，剩余等待线程全部抛出异常。

解决方案：捕获异常后，手动调用`reset()`重置栅栏，恢复复用能力，或终止本轮任务执行降级逻辑。

### 2.4.4 循环复用特性的使用注意事项

核心避坑要点（面试高频）：

- CyclicBarrier 自动重置仅在**正常凑齐线程、正常放行**时生效；异常中断、超时会导致栅栏破损，无法自动重置；

- 线程数量必须匹配栅栏阈值，否则会出现线程永久阻塞或任务错乱；

- 多轮任务执行时，避免部分线程执行过快、跳过屏障点，导致计数错乱；

- 对比总结：CountDownLatch 单次不可复用、基于AQS；CyclicBarrier 循环可复用、基于锁+条件队列。

---

# 3. `Semaphore` 信号量：`acquire()`/`release()` 控制并发数

Semaphore（信号量）是JUC中**用于控制并发线程数量、实现资源限流**的核心工具类，核心作用是通过固定许可数量限制同时访问资源的线程数，实现流量削峰、资源隔离、接口限流，是线程池、连接池、分布式限流本地实现的底层核心。

## 3.1 `Semaphore` 核心原理

### 3.1.1 定义：基于AQS实现的并发资源控制器，支持公平/非公平模式

**Semaphore** 是基于AQS共享锁模式实现的**计数信号量**，本质是一个**资源配额控制器**。通过预设固定的“许可数量”，限制同一时间能够执行任务的最大线程数，超出数量的线程进入阻塞队列等待，以此实现并发限流。

Semaphore 提供两种工作模式：

- **非公平模式（默认）**：新线程优先抢占许可，不排队，吞吐量高，可能出现线程饥饿；

- **公平模式**：严格按照线程入队顺序获取许可，先来先服务，杜绝饥饿，吞吐量略低。

### 3.1.2 核心逻辑：维护许可数量，线程获取许可执行任务，执行完毕释放许可

Semaphore 完整执行逻辑极简且核心，贯穿所有使用场景：

1. **初始化配额**：创建Semaphore时指定许可数permits，代表最大并发线程数；

2. **抢占许可**：线程执行任务前调用acquire()获取许可，许可充足则直接执行，许可耗尽则阻塞等待；

3. **执行业务逻辑**：获取到许可的线程正常执行业务代码；

4. **归还许可**：任务执行完毕调用release()释放许可，许可回归资源池，唤醒阻塞等待的线程继续执行。

通俗理解：许可就是**坑位**，坑位有限，抢到就能执行，没抢到就排队。

### 3.1.3 底层实现：state变量表示许可数，共享锁模式实现资源竞争

Semaphore 底层依托AQS共享锁机制实现，核心底层逻辑：

- **state变量**：AQS的state值直接代表**剩余可用许可数量**，初始化时state = permits；

- **acquire获取**：CAS递减state，剩余许可≥0则获取成功，否则线程入AQS队列阻塞；

- **release释放**：CAS递增state，归还许可，同时唤醒队列中等待的线程；

- **共享锁特性**：支持多个线程同时获取许可、并行执行，区别于独占锁的单线程执行。

## 3.2 核心方法详解

### 3.2.1 `acquire()` 方法：获取许可，无许可则阻塞

无参核心获取方法：线程默认获取**1个许可**，成功则继续执行，无可用许可则**永久阻塞**，直到有线程释放许可或当前线程被中断。

特点：强阻塞、无超时、安全性弱，业务线程卡死会导致许可永久占用，生产不推荐单独使用。

### 3.2.2 `acquire(int permits)`：获取指定数量许可

支持一次性获取多个许可，适用于**任务资源消耗不同**的场景，例如大任务占用3个许可、小任务占用1个许可，实现精细化资源配额控制。

注意：获取许可数不能大于初始化总许可数，否则线程永久阻塞。

### 3.2.3 `tryAcquire()`/`tryAcquire(long timeout, TimeUnit unit)`：非阻塞/限时获取许可

- **tryAcquire()**：非阻塞尝试获取许可，获取成功返回true，无许可直接返回false，线程不阻塞，适合快速失败场景；

- **tryAcquire(long timeout, TimeUnit unit)**：限时尝试获取许可，指定时间内获取成功则返回true，超时直接返回false，**生产最推荐使用**，可避免线程永久阻塞。

### 3.2.4 `release()`/`release(int permits)`：释放许可，归还资源

任务执行完成后归还许可，无参默认释放1个许可，传参可释放指定数量许可，底层CAS递增AQS state值，唤醒阻塞线程。

**核心强制规范**：release() **必须放在finally代码块**，保证无论任务正常执行、异常报错，许可都能正常归还，杜绝许可泄漏。

### 3.2.5 `availablePermits()`：获取当前可用许可数

实时查询当前剩余可用的许可数量，用于监控限流状态、打印日志、动态告警、排查线程阻塞问题，是线上排查并发堆积的核心方法。

## 3.3 典型使用场景

### 3.3.1 接口限流、服务限流控制

单机接口限流核心实现方案，限制某一接口同一时间最大并行请求数，防止瞬时高并发打垮服务，实现**单机流量削峰**，配合网关限流可实现多级防护。

### 3.3.2 数据库连接池、线程池资源控制

数据库连接池核心原理就是Semaphore，固定连接数，业务线程获取连接、执行SQL、释放连接，保证数据库连接资源不被耗尽，避免Too many connections异常。

### 3.3.3 高并发场景下限制同时执行的线程数

大批量任务异步处理场景，例如批量文件解析、批量数据同步、批量消息消费，通过Semaphore限制最大并发线程数，防止瞬间创建大量线程导致OOM、CPU打满。

### 3.3.4 资源有限场景的并发访问控制

硬件资源、第三方接口、付费接口等有限资源场景，通过信号量限制并发访问，防止资源超限、接口限流封号、付费成本过高。

## 3.4 实战代码示例与避坑指南

### 3.4.1 接口限流代码示例

模拟单机接口限流，设置最大并发数为5，10个请求并发访问，超出请求排队等待，实现流量控制。

```java
import java.util.concurrent.Semaphore;
import java.util.concurrent.Executors;
import java.util.concurrent.ExecutorService;

/**
 * Semaphore 单机接口限流实战
 * 最大并发5个线程，模拟10个并发请求
 */
public class SemaphoreLimitDemo {
    // 初始化信号量：最大许可数5，代表最大并发5
    private static final Semaphore SEMAPHORE = new Semaphore(5);
    // 模拟请求线程池
    private static final ExecutorService POOL = Executors.newFixedThreadPool(10);

    public static void main(String[] args) {
        // 模拟10个并发请求
        for (int i = 1; i <= 10; i++) {
            int reqId = i;
            POOL.execute(() -> {
                try {
                    // 获取许可：获取失败则阻塞等待
                    SEMAPHORE.acquire();
                    System.out.println("请求" + reqId + " 获取资源成功，执行业务逻辑");
                    // 模拟业务耗时
                    Thread.sleep(1000);
                } catch (InterruptedException e) {
                    e.printStackTrace();
                } finally {
                    // 【核心】finally释放许可，防止许可泄漏
                    SEMAPHORE.release();
                    System.out.println("请求" + reqId + " 释放资源，当前剩余许可：" + SEMAPHORE.availablePermits());
                }
            });
        }
        POOL.shutdown();
    }
}

```

### 3.4.2 公平/非公平模式对比与选型

通过构造方法 `new Semaphore(permits, fair)` 指定模式：

```java
// 非公平模式（默认）：吞吐量高，可能线程饥饿
Semaphore nonFairSemaphore = new Semaphore(5);
// 公平模式：先来先服务，杜绝饥饿，吞吐量略低
Semaphore fairSemaphore = new Semaphore(5, true);

```

**生产选型规则**：

- 追求高吞吐、无严格顺序要求 → **非公平模式**（默认）；

- 任务优先级一致、需要杜绝线程饥饿、保证公平性 → **公平模式**。

### 3.4.3 许可泄漏问题（release()必须在finally中调用）

**许可泄漏是Semaphore最严重的生产BUG**：线程获取许可后，业务代码抛出异常、直接return，未执行release()，会导致许可永久无法归还，可用许可数持续减少，最终并发越来越低、服务彻底卡死。

**强制避坑方案**：所有acquire()获取许可的代码，**release()必须无条件写入finally**，保证100%归还。

### 3.4.4 动态调整许可数的注意事项

Semaphore **不支持动态修改初始化许可数**，底层permits为固定值。若需要动态扩容、缩容限流并发数，只能新建Semaphore对象替换旧对象。

避坑点：禁止通过频繁创建对象调整并发数，会导致队列线程错乱、许可混乱，动态限流建议使用Guava RateLimiter替代。

# 4. `Exchanger` 交换器：线程间数据交换场景

Exchanger 是JUC中冷门但专用的线程工具类，核心作用是**实现两个线程之间的数据双向交换**，仅支持两两配对、成对交换，适用于点对点线程数据交互、数据校验、生产者消费者直连场景。

## 4.1 `Exchanger` 核心原理

### 4.1.1 定义：用于两个线程间数据交换的工具类，基于Lock+Condition实现

**Exchanger（数据交换器）** 是一个专门用于**成对线程数据交换**的同步工具，允许两个线程在同步点交换数据，一个线程的数据作为另一个线程的返回值，实现双向数据传递。

区别于其他JUC工具类：Exchanger **不基于AQS**，底层基于 **ReentrantLock + Condition** 实现线程阻塞与唤醒。

### 4.1.2 核心逻辑：线程调用exchange()方法阻塞，等待配对线程到达，交换数据后同时放行

Exchanger 核心配对交换逻辑：

1. 线程A调用exchange(dataA)，携带数据进入方法，无配对线程则阻塞；

2. 线程B调用exchange(dataB)，携带数据到达交换点；

3. 两线程成功配对，自动交换数据：线程A获取dataB，线程B获取dataA；

4. 数据交换完成，两个线程同时放行，继续执行后续业务。

### 4.1.3 底层实现：slot数组存储等待线程，配对成功后交换数据

Exchanger 底层采用**slot插槽数组**实现高效配对，核心机制：

- 单个slot插槽存储等待线程的引用、携带数据、线程信息；

- 第一个到达的线程占用slot，阻塞等待；

- 第二个到达的线程匹配slot中的等待线程，完成数据交换，清空slot；

- 多线程场景下通过多slot减少竞争，提升交换吞吐量。

## 4.2 核心方法详解

### 4.2.1 `exchange(V x)`：阻塞式数据交换

核心无参阻塞方法：线程携带数据x进入交换队列，等待配对线程。若无配对线程，线程**永久阻塞**，直到配对线程到达或线程被中断。

返回值为配对线程传递过来的数据，实现双向交换。

### 4.2.2 `exchange(V x, long timeout, TimeUnit unit)`：限时数据交换

限时阻塞交换，指定时间内未匹配到配对线程，直接抛出**TimeoutException**超时异常，避免线程永久阻塞，是生产推荐写法。

### 4.2.3 交换器的线程配对机制

Exchanger 严格遵循**一对一配对机制**：

- 严格两两配对，不支持三个及以上线程同时交换；

- 先到先配对，空闲slot匹配等待线程；

- 单线程调用exchange()必然阻塞，无自愈能力。

## 4.3 典型使用场景

### 4.3.1 生产者-消费者模式中数据直接交换

极简生产者消费者模型，无需队列中转，生产者线程生成数据、消费者线程消费数据，通过Exchanger直接交换，减少中间容器开销。

### 4.3.2 两个线程间双向数据传递

两个独立线程需要双向通信场景，如线程A传递参数给线程B，线程B返回计算结果给线程A，实现闭环数据交互。

### 4.3.3 数据校验场景（如线程间数据比对）

双线程并行计算同一数据，通过Exchanger交换结果，相互比对校验，保证计算结果准确性，用于金融、结算等高精度校验场景。

## 4.4 实战代码示例与避坑指南

### 4.4.1 线程间数据交换代码示例

```java
import java.util.concurrent.Exchanger;

/**
 * Exchanger 双线程数据双向交换实战
 */
public class ExchangerDemo {
    // 创建数据交换器
    private static final Exchanger<String> EXCHANGER = new Exchanger<>();

    public static void main(String[] args) {
        // 线程A：发送数据A，接收线程B的数据
        new Thread(() -> {
            try {
                String sendData = "线程A传输的数据";
                System.out.println("线程A：准备交换数据，发送：" + sendData);
                // 阻塞等待配对，接收对方数据
                String receiveData = EXCHANGER.exchange(sendData);
                System.out.println("线程A：接收配对数据：" + receiveData);
            } catch (Exception e) {
                e.printStackTrace();
            }
        }, "A").start();

        // 线程B：发送数据B，接收线程A的数据
        new Thread(() -> {
            try {
                String sendData = "线程B传输的数据";
                System.out.println("线程B：准备交换数据，发送：" + sendData);
                String receiveData = EXCHANGER.exchange(sendData);
                System.out.println("线程B：接收配对数据：" + receiveData);
            } catch (Exception e) {
                e.printStackTrace();
            }
        }, "B").start();
    }
}

```

### 4.4.2 超时等待的处理方式

生产禁止使用无参exchange()，防止单线程异常缺失导致另一个线程永久阻塞，必须使用限时交换并捕获超时异常。

```java
import java.util.concurrent.Exchanger;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

public class ExchangerTimeoutDemo {
    private static final Exchanger<String> EXCHANGER = new Exchanger<>();

    public static void main(String[] args) {
        // 仅启动单个线程，模拟配对线程缺失
        new Thread(() -> {
            try {
                // 限时2秒等待配对，超时抛出异常
                String data = EXCHANGER.exchange("测试数据", 2, TimeUnit.SECONDS);
                System.out.println("交换成功：" + data);
            } catch (TimeoutException e) {
                System.out.println("数据交换超时，无配对线程，执行降级逻辑");
            } catch (Exception e) {
                e.printStackTrace();
            }
        }).start();
    }
}

```

### 4.4.3 多线程环境下的使用限制（仅支持两两配对）

**核心避坑点（高频面试坑）**：Exchanger **仅支持两个线程配对交换**，不支持多线程批量交换。

若同时开启3个及以上线程调用exchange()，会出现随机两两配对、剩余线程阻塞的混乱情况，业务完全不可控。

解决方案：多线程数据交互场景，禁止使用Exchanger，改用队列、CountDownLatch、自定义消息总线实现。

---

# 5. 工具类对比：`CountDownLatch` vs `CyclicBarrier`

CountDownLatch与CyclicBarrier是面试和开发中最容易混淆的两大线程同步工具，二者均可实现“多线程等待、统一放行”，但在复用性、底层原理、触发逻辑、适用场景上有本质区别，本节全方位拆解对比，明确选型标准。

## 5.1 核心特性对比

### 5.1.1 复用性对比：一次性vs可循环复用

**CountDownLatch：一次性不可复用**

CountDownLatch的计数器一旦归零，生命周期直接结束，无法重置、无法二次使用。底层AQS的state变量归零后不会自动恢复初始值，再次调用`await()`会直接放行，无法实现新一轮的线程等待同步。每一次新的同步任务，都需要重新创建CountDownLatch对象。

**CyclicBarrier：支持循环复用**

CyclicBarrier在每一轮线程凑齐、屏障放行完成后，会**自动重置计数**，恢复初始阈值，可直接开启下一轮同步等待，无需新建对象，天然支持多轮、多阶段循环任务，这是其核心优势。

### 5.1.2 触发时机对比：等待任务执行完毕vs等待线程到达屏障

**CountDownLatch：基于任务完成计数，等待任务执行完毕**

核心触发逻辑：**以任务结果为维度**。初始化设定任务总数，子线程执行完业务任务后手动调用`countDown()`标记任务完成，主线程等待所有任务标记完成后放行。关注的是「所有任务是否执行结束」，线程执行时长、到达顺序无要求。

**CyclicBarrier：基于线程到达计数，等待线程到达屏障**

核心触发逻辑：**以线程到达状态为维度**。初始化设定线程阈值，所有线程执行到指定同步点（屏障点）调用`await()`阻塞，等待**所有线程全部到达屏障**后统一放行。关注的是「所有线程是否抵达同步位置」，用于保证多线程执行进度对齐。

### 5.1.3 底层实现对比：AQS共享模式vs ReentrantLock+Condition

**CountDownLatch 底层原理**：

基于 **AQS共享锁模式** 实现，通过AQS的state变量作为计数器，依托AQS原生的队列阻塞、共享唤醒机制，无额外锁对象，底层更轻量化、执行效率更高。

**CyclicBarrier 底层原理**：

不依赖AQS，基于 **ReentrantLock + Condition条件队列** 实现，通过独占锁保证计数原子性，通过Condition队列管理阻塞线程，支持手动重置、屏障回调、异常标记，功能更丰富，但底层开销略高于CountDownLatch。

### 5.1.4 适用场景对比：单次汇总vs多阶段同步

**CountDownLatch 适配场景**：单次、一次性的任务汇总同步，无多轮执行需求。典型场景：接口多任务并行查询、启动初始化一次性加载、单元测试异步等待。

**CyclicBarrier 适配场景**：多阶段、多轮次、需要进度对齐的同步任务。典型场景：分批数据处理、多阶段任务执行、集群节点同步、循环批量任务。

## 5.2 场景选型对比

### 5.2.1 主线程等待多个任务执行完毕：优先CountDownLatch

当业务需求为：拆分大任务为多个子任务，多线程并行执行，**所有子任务执行完成后，主线程统一汇总结果、结束流程**，优先使用CountDownLatch。

该场景核心诉求是「任务收尾汇总」，无需线程进度对齐、无需重复执行，CountDownLatch轻量化、简单高效，无需多余重置逻辑，是最优选择。

### 5.2.2 多线程分阶段同步执行：优先CyclicBarrier

当业务需求为：多线程并行执行，**必须保证所有线程完成当前阶段，再统一进入下一阶段**，例如：数据读取→数据清洗→数据计算→数据入库四阶段同步执行，必须使用CyclicBarrier。

该场景核心诉求是「线程进度对齐、阶段同步」，CountDownLatch无法实现单线程多阶段等待，仅CyclicBarrier支持屏障卡点同步。

### 5.2.3 多轮同步场景：必须使用CyclicBarrier

所有需要**循环多轮执行同步任务**的场景，必须使用CyclicBarrier。CountDownLatch单次执行后失效，若强行循环创建对象，会导致代码冗余、对象频繁创建GC、逻辑复杂，而CyclicBarrier天然支持循环复用，代码简洁、性能更优。

## 5.3 代码实现对比示例

### 5.3.1 相同场景下两种工具类的不同实现

场景需求：开启3个线程执行任务，等待所有线程任务完成后，主线程打印汇总日志，分别用两种工具类实现，直观对比差异。

**1. CountDownLatch 实现（单次任务汇总）**

```java
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * CountDownLatch 任务汇总实现
 * 特点：任务驱动、一次性执行、需手动countDown
 */
public class CountDownLatchCompareDemo {
    private static final CountDownLatch LATCH = new CountDownLatch(3);
    private static final ExecutorService POOL = Executors.newFixedThreadPool(3);

    public static void main(String[] args) throws InterruptedException {
        for (int i = 1; i <= 3; i++) {
            int taskId = i;
            POOL.execute(() -> {
                try {
                    System.out.println("任务" + taskId + "执行完成");
                    Thread.sleep(500);
                } catch (InterruptedException e) {
                    e.printStackTrace();
                } finally {
                    // 手动标记任务完成，计数器递减
                    LATCH.countDown();
                }
            });
        }
        // 主线程等待所有任务完成
        LATCH.await();
        System.out.println("CountDownLatch：所有任务汇总完成");
        POOL.shutdown();
    }
}

```

**2. CyclicBarrier 实现（线程屏障对齐）**

```java
import java.util.concurrent.CyclicBarrier;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * CyclicBarrier 任务同步实现
 * 特点：线程驱动、屏障对齐、自动重置
 */
public class CyclicBarrierCompareDemo {
    // 3个线程到达屏障后放行，附带汇总回调
    private static final CyclicBarrier BARRIER = new CyclicBarrier(3, () -> {
        System.out.println("CyclicBarrier：所有线程抵达屏障，汇总完成");
    });
    private static final ExecutorService POOL = Executors.newFixedThreadPool(3);

    public static void main(String[] args) {
        for (int i = 1; i <= 3; i++) {
            int taskId = i;
            POOL.execute(() -> {
                try {
                    System.out.println("线程" + taskId + "执行完毕，等待屏障对齐");
                    // 线程到达同步点，阻塞等待其他线程
                    BARRIER.await();
                } catch (Exception e) {
                    e.printStackTrace();
                }
            });
        }
        POOL.shutdown();
    }
}

```

### 5.3.2 性能对比与选型建议

**性能对比**

- **低并发单次任务**：CountDownLatch 性能略优，底层基于AQS共享锁，无多余锁机制与回调逻辑，开销更低；

- **多轮循环任务**：CyclicBarrier 性能远超CountDownLatch，无需频繁创建、销毁对象，减少GC开销与对象初始化损耗；

- **高并发分段任务**：两者性能差距极小，性能不再是核心选型指标，优先看业务场景。

**最终选型总结（面试/生产通用）**

1. 仅需要**单次任务汇总、主线程等待子线程** → 必选 CountDownLatch；

2. 需要**多阶段、多轮次线程进度对齐** → 必选 CyclicBarrier；

3. 需要**任务完成回调汇总** → 优先 CyclicBarrier 内置回调；

4. 简单轻量同步、追求极致性能 → 优先 CountDownLatch。

---

# 6. 工具类在实际项目中的应用场景

## 6.1 大数据/批量处理场景

### 6.1.1 CountDownLatch：多线程分片处理，主线程等待汇总

**业务场景**：大数据量批量导入、批量数据校验、文件分片解析、数据库批量查询。单线程处理海量数据效率极低，通过CountDownLatch实现数据分片、多线程并行处理，所有分片任务执行完毕后，主线程统一汇总处理结果、统计成功/失败数量、生成最终报表。

**核心价值**：将串行任务改为并行任务，大幅缩短批量任务执行时长，同时保证任务完整性，避免主线程提前结束导致数据丢失。

### 6.1.2 CyclicBarrier：多阶段数据处理，每阶段同步执行

**业务场景**：数据清洗流水线任务，分为「数据读取→格式校验→脏数据过滤→数据转换→入库存储」多个阶段。要求所有分片数据完成当前阶段后，统一进入下一阶段，避免部分数据超前执行、部分数据滞后导致的数据错乱。

**核心价值**：实现多线程任务**阶段强同步**，保证批量数据处理的有序性与完整性，适用于数据流水线、ETL分批处理场景。

### 6.1.3 Semaphore：控制并发分片任务数，避免数据库压力过大

**业务场景**：大数据分片入库、批量更新数据库场景。若无并发控制，大量线程同时操作数据库，会瞬间打满数据库连接池、触发数据库锁等待、导致接口超时、服务雪崩。通过Semaphore限制同时操作数据库的线程数量。

**核心价值**：**流量削峰、资源限流**，在保证批量处理效率的同时，保护数据库、缓存等核心资源，避免瞬时并发过高导致服务异常。

## 6.2 服务启动与初始化场景

### 6.2.1 CountDownLatch：启动时等待多个依赖服务初始化完成

**业务场景**：SpringBoot项目启动阶段，需要并行执行多项初始化任务：缓存预热、配置文件加载、字典数据加载、第三方客户端初始化、定时任务注册。

通过CountDownLatch开启多线程并行初始化，主线程等待所有初始化任务完成后，再开启服务端口、注册注册中心，对外提供服务。避免服务启动完成但内部资源未初始化完毕，导致接口报错。

### 6.2.2 CyclicBarrier：集群节点同步启动

**业务场景**：分布式集群服务启动、分布式任务节点初始化。要求集群内所有节点全部启动完成、初始化就绪后，再统一开启任务调度、数据同步功能，避免部分节点未启动导致的集群数据不一致。

**核心价值**：实现集群节点**启动进度对齐**，保证集群服务状态统一，适用于分布式定时任务、分布式数据同步场景。

## 6.3 限流与资源控制场景

### 6.3.1 Semaphore：接口限流、第三方服务调用并发控制

**接口限流**：单机接口瞬时高并发场景，通过Semaphore设置接口最大并行请求数，超出请求阻塞或快速失败，实现单机限流，防止流量打垮业务服务。

**第三方调用限流**：调用付费第三方接口、有QPS限制的外部服务时，通过Semaphore固定并发数，避免调用超限被封号、产生高额费用。

### 6.3.2 Semaphore：数据库/文件句柄等有限资源的并发访问控制

数据库连接、文件读写句柄、网络端口等资源都是**有限稀缺资源**，无限制并发访问会导致资源耗尽、连接超时、文件占用异常。

通过Semaphore控制资源并发占用数，实现资源的有序竞争、合理复用，是连接池、资源池的底层核心实现原理。

## 6.4 生产环境避坑与最佳实践

### 6.4.1 CountDownLatch：计数器归零后不可复用，避免重复使用

**生产坑点**：重复使用同一个CountDownLatch对象执行多轮任务，第一轮计数归零后，第二轮await()直接放行，无法实现等待逻辑，导致任务并发错乱、数据异常。

**最佳实践**：单次任务单次创建，多轮循环任务直接使用CyclicBarrier，禁止复用CountDownLatch；必须复用场景，手动new新对象替换旧对象。

### 6.4.2 CyclicBarrier：处理线程中断、超时异常，避免屏障永久阻塞

**生产坑点**：CyclicBarrier存在线程中断、超时异常时，会标记屏障破损，剩余等待线程全部抛出异常，若未捕获处理，会导致任务中断、线程卡死、资源泄漏。

**最佳实践**：

- 优先使用限时await()，避免永久阻塞；

- 全局捕获异常，出现破损后手动调用reset()重置屏障；

- 异常场景执行降级兜底逻辑，保证任务不中断。

### 6.4.3 Semaphore：许可必须成对获取释放，避免泄漏导致资源耗尽

**生产核心致命坑点**：线程acquire获取许可后，业务代码抛出异常、提前return，未执行release释放许可，导致**许可泄漏**。可用许可数持续减少，最大并发不断降低，最终无可用许可，服务彻底卡死。

**最佳实践**：

- 所有许可获取逻辑，release()必须写入finally代码块，无条件释放；

- 业务复杂场景使用tryAcquire限时获取，避免永久阻塞；

- 禁止手动超额释放许可，避免并发失控。

### 6.4.4 工具类异常处理与监控（如计数、许可数监控）

**通用最佳实践**：

1. **超时兜底**：所有阻塞方法优先使用限时重载方法，杜绝线程永久阻塞；

2. **状态监控**：定时打印监控指标：CountDownLatch剩余计数、CyclicBarrier等待线程数、Semaphore可用许可数，实时发现任务堆积、线程阻塞问题；

3. **异常捕获**：统一捕获InterruptedException、TimeoutException，做日志告警、任务重试、降级处理；

4. **资源回收**：任务执行完毕后，及时销毁工具类、关闭线程池，避免内存泄漏。

---

# 本章总结

本章完成了JUC并发工具类的**对比复盘与生产落地闭环**，首先从复用性、触发时机、底层实现、适用场景四个核心维度，彻底区分了CountDownLatch与CyclicBarrier的核心差异，通过同款场景代码对比明确了精准选型规则；其次结合大数据批量处理、服务启动初始化、接口限流、稀缺资源控制四大高频业务场景，落地了三大核心工具类的实战用法，打通理论与业务的壁垒；最后汇总生产环境核心避坑点与标准化最佳实践，解决了工具复用异常、许可泄漏、线程阻塞、任务错乱等线上高频问题。至此，JUC四大线程协作工具类知识体系完全闭环，后续将为线程池原理、并发容器等高阶并发内容学习奠定坚实基础。