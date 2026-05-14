# 06-AQS与Lock体系核心原理

## 本章概述

本章是Java多线程与JUC并发体系的**核心基石章节**，属于高阶面试与生产调优重难点。此前学习的synchronized、volatile属于底层语法级并发机制，而本章讲解的AQS（抽象队列同步器）是JUC包下所有锁与并发工具的**统一底层框架**。本章将从AQS的定义、设计思想、核心组件、队列机制、独占与共享锁原理逐层拆解，彻底讲透state状态变量、同步队列、条件队列的底层流转逻辑，厘清独占锁与共享锁的核心差异与适用场景。学好本章内容，能够彻底看懂ReentrantLock、读写锁、CountDownLatch、Semaphore等所有JUC工具类的底层实现，为后续并发源码阅读、锁性能调优、并发问题排查提供核心理论支撑。

---

# 1. AQS（AbstractQueuedSynchronizer）框架概述

AQS 全称 AbstractQueuedSynchronizer（抽象队列同步器），是 JDK1.5 随 JUC 包推出的**并发同步统一底层框架**，解决了传统同步机制代码冗余、实现混乱、无法复用的问题，是现代Java并发编程的核心底层支撑。

## 1.1 AQS的定义与核心地位

### 1.1.1 AQS：Java并发工具类的底层核心框架

AQS 是一个**抽象类**，位于 `java.util.concurrent.locks` 包下，是整个 JUC 并发体系的顶层基石。几乎所有的并发锁、同步工具类，底层全部基于 AQS 实现，包括但不限于：ReentrantLock、ReentrantReadWriteLock、CountDownLatch、Semaphore、CyclicBarrier 等。

如果说 volatile、synchronized 是 JVM 底层的原生锁机制，那么 **AQS 就是Java代码层面统一的同步调度框架**，所有显式锁和同步器的排队、阻塞、唤醒、资源抢占逻辑，全部由 AQS 统一实现。

### 1.1.2 AQS的核心设计思想：模板方法模式实现同步器

AQS 核心采用 **模板方法设计模式**，将同步逻辑分为「通用底层逻辑」和「自定义上层逻辑」两部分，实现极致复用：

1. **AQS统一封装通用逻辑**：线程入队、出队、自旋、阻塞、唤醒、队列维护、CAS重试、中断处理等所有通用、复杂的排队同步逻辑，由AQS底层固定实现，无需开发者重复编写；

2. **子类重写自定义逻辑**：AQS提供空的模板方法，子类根据自身锁特性（独占/共享、公平/非公平、可重入/不可重入）重写少量方法，即可快速实现一个同步器。

简单理解：**AQS搭好并发同步的骨架，不同锁和同步器只需要填充自己的业务规则**，极大降低了并发组件的开发复杂度。

### 1.1.3 AQS的适用场景：锁、同步器、并发工具类的通用底层

AQS 不直接面向业务开发使用，而是作为**底层通用基础设施**，支撑三类核心场景：

- **锁实现**：独占锁、共享锁、读写锁等各类自定义锁的底层实现；

- **线程同步器**：控制多线程并发执行节奏，如倒计时等待、栅栏等待、信号量限流；

- **并发工具底层**：所有JUC高级并发类的统一底层依赖。

## 1.2 AQS的设计目标与核心优势

### 1.2.1 统一同步机制：为不同同步场景提供通用底层实现

在AQS出现之前，Java并发同步逻辑混乱，不同同步组件拥有各自的实现方式，没有统一规范，维护成本高、BUG多。

AQS 的核心设计目标就是**统一所有并发同步的底层模型**，将线程排队、阻塞、唤醒、资源竞争的通用逻辑标准化，让所有锁和同步器基于同一套底层机制运行，保证并发逻辑的稳定性和统一性。

### 1.2.2 减少重复实现：JUC中大部分工具类均基于AQS实现

AQS 将复杂的并发队列调度、线程状态管理、CAS竞争、阻塞唤醒逻辑全部封装，开发者无需关心底层线程调度细节，仅需重写少量核心方法即可实现功能强大的同步组件。

这也是 JUC 包工具类简洁、高效、稳定的核心原因，**90%的JUC并发组件底层均依赖AQS**，彻底避免了重复造轮子。

### 1.2.3 高性能并发：基于CAS与CLH队列实现无阻塞同步

相比于 synchronized 重量级锁依赖操作系统阻塞、上下文切换开销大的问题，AQS 采用 **CAS自旋 + CLH队列 + 懒阻塞** 的混合模式，性能大幅优化：

- 轻度竞争：基于CAS无锁自旋尝试获取资源，不阻塞线程，无上下文切换开销；

- 重度竞争：线程入队排队，阻塞闲置线程，避免CPU空转；

- 精准唤醒：仅唤醒后继有效线程，不会批量唤醒无效线程，减少竞争开销。

整体并发吞吐量、线程调度精细度远优于传统同步机制，是高并发场景高性能锁的核心保障。

---

# 2. AQS的核心组件：state状态变量、等待队列、条件队列

AQS 的整套并发机制，完全依赖三大核心组件支撑：**state同步状态变量、同步等待队列、Condition条件队列**。三者各司其职，分别负责资源状态记录、线程排队调度、条件阻塞唤醒，构成AQS完整的并发调度体系。

## 2.1 state状态变量

### 2.1.1 state的定义：volatile修饰的同步状态标识

AQS 内部维护一个核心成员变量：`private volatile int state`，是整个AQS框架的**资源状态核心标识**。

变量被 **volatile** 修饰，保证多线程间的可见性与有序性，所有线程对资源的抢占、释放、等待，全部通过修改、读取 state 值实现，是AQS资源竞争的唯一核心依据。

### 2.1.2 state的作用：表示锁的持有状态、资源可用数量

state 是一个通用状态字段，不同同步器对 state 的解读不同，核心作用分为两类：

1. **独占锁场景（ReentrantLock）**：表示锁的持有状态和重入次数
            

    - state = 0：锁空闲、无线程持有；

    - state > 0：锁被占用，数值代表**锁重入次数**；

2. **共享锁场景（CountDownLatch/Semaphore）**：表示剩余可用资源数量
           

    - CountDownLatch：state代表剩余倒数次数；

    - Semaphore：state代表剩余可用信号量、可并发线程数。

**核心结论**：state 本质是一个**通用资源计数器**，语义由子类同步器自定义定义。

### 2.1.3 state的操作：getState()/setState()/compareAndSetState()

AQS 禁止子类直接操作 state 变量，封装了三套核心方法，保证线程安全：

- **getState()**：获取当前最新的同步状态值，volatile保证读取可见性；

- **setState(int newState)**：直接设置状态值，适合线程安全、无竞争的场景；

- **compareAndSetState(int expect, int update)**：**CAS无锁更新**，核心方法，基于内存地址对比替换，保证高并发下状态修改的原子性，是AQS高性能的核心支撑。

## 2.2 等待队列（同步队列）

### 2.2.1 等待队列的结构：双向链表CLH队列

AQS 内部维护一个 **CLH双向阻塞队列**，即同步等待队列，用于存放所有抢占资源失败、需要排队等待的线程。

队列核心特性：

- 底层数据结构：**双向链表**，拥有 head 头节点、tail 尾节点；

- 入队：竞争资源失败的线程，封装为Node节点，从尾部入队；

- 出队：资源释放后，从头部唤醒后继节点线程；

- 全程基于CAS实现队列修改，无锁操作，并发安全。

CLH队列的核心价值：**将并发竞争失败的线程有序排队，避免无序抢占CPU，大幅提升并发稳定性**。

### 2.2.2 队列节点Node的结构：prev/next/thread/waitStatus

队列中的每一个线程都会被封装为一个 **Node节点**，核心属性如下：

- **thread**：当前封装的等待线程对象；

- **prev**：前驱节点引用，用于双向链表回溯；

- **next**：后继节点引用，用于向后唤醒线程；

- **waitStatus**：节点等待状态，控制线程阻塞、唤醒、取消
            

    - 0：初始状态；

    - -1(SIGNAL)：后继节点需要被唤醒；

    - -2(CONDITION)：节点在条件队列等待；

    - 1(CANCELLED)：线程等待超时/中断，取消等待。

### 2.2.3 线程入队与出队流程：自旋等待、前驱节点唤醒

**线程入队流程**：

1. 线程尝试抢占资源失败；

2. 封装为Node节点，通过CAS自旋尝试追加到队列尾部；

3. 成功入队后，检测前驱节点状态；

4. 前驱节点为有效等待状态，当前线程阻塞，释放CPU资源。

**线程出队唤醒流程**：

1. 持有资源的线程释放锁/资源；

2. 唤醒head节点的直接后继节点；

3. 被唤醒的线程重新CAS抢占资源；

4. 抢占成功则清空节点、出队执行业务逻辑，失败则继续阻塞等待。

## 2.3 条件队列（Condition队列）

### 2.3.1 条件队列的定义：等待特定条件的线程单向链表

同步队列是所有线程统一排队的公共队列，而 **Condition条件队列** 是AQS提供的、用于等待「特定业务条件」的私有队列，对应 `Lock.newCondition()` 实现。

条件队列底层是**单向链表**，专门存放调用 `await()` 方法、等待特定条件满足的线程。线程在条件队列中处于阻塞状态，不会参与锁竞争，直到条件满足被唤醒。

### 2.3.2 条件队列与等待队列的关系：等待-条件-唤醒流转

两个队列的线程可相互流转，是生产者消费者模型、线程精准唤醒的核心基础：

1. 线程持有锁，执行业务逻辑，发现条件不满足，调用 **await()**；

2. 线程释放锁，从同步队列移出，进入**条件队列**阻塞等待；

3. 其他线程执行业务，唤醒条件，调用 **signal()**；

4. 等待线程从条件队列移出，重新加入**同步队列**排队抢锁；

5. 抢到锁后继续执行业务逻辑。

**核心区别**：同步队列是抢锁排队，条件队列是等条件排队。

### 2.3.3 条件队列的节点复用机制

AQS 为了节省内存、提升性能，**同步队列和条件队列复用同一套Node节点对象**，无需创建新对象：

- 线程进入条件队列：修改node的waitStatus为CONDITION，脱离双向同步队列，加入单向条件队列；

- 线程被唤醒：节点重新修改状态，重置链表指针，重新加入同步队列竞争锁；

全程节点复用，避免频繁创建销毁对象，极大提升高并发场景性能。

---

# 3. 独占锁与共享锁的实现原理

AQS 框架核心支持两类锁机制：**独占锁（排他锁）**与**共享锁**，JUC所有锁和同步器都基于这两种模式实现。二者的state解读、队列调度、唤醒机制完全不同，是区分不同并发工具的核心依据。

## 3.1 独占锁（Exclusive）实现原理

### 3.1.1 独占锁的定义：同一时间仅允许一个线程持有锁

**独占锁**又称排他锁，核心特性：同一时刻，**有且仅有一个线程可以持有锁、占用资源**，其他所有竞争线程必须进入同步队列阻塞等待。

典型实现：**ReentrantLock**、synchronized底层互斥机制。适用于资源互斥操作、数据修改、事务更新等场景，保证操作原子性。

### 3.1.2 核心流程：acquire()获取锁 → 成功执行/失败入队 → release()释放锁

**独占锁获取流程（acquire）**：

1. 调用模板方法 `tryAcquire()` 尝试独占获取锁；

2. 获取成功（state修改成功）：直接执行业务代码；

3. 获取失败：线程封装为Node入队，自旋尝试重试，最终阻塞；

4. 等待前驱节点释放资源，被唤醒后重新竞争锁。

**独占锁释放流程（release）**：

1. 线程执行完毕，调用 `tryRelease()` 释放锁资源；

2. 清空state状态（重入锁逐层递减）；

3. 唤醒同步队列中的**下一个后继线程**；

4. 后继线程开始竞争锁资源。

### 3.1.3 模板方法：tryAcquire()/tryRelease()自定义实现

AQS模板方法设计模式的核心体现：AQS仅定义流程，不定义具体抢占规则，由子类重写实现个性化逻辑：

- **tryAcquire()**：尝试获取独占锁，子类可实现可重入、公平/非公平、超时等逻辑；

- **tryRelease()**：尝试释放独占锁，子类实现重入次数递减、资源清空逻辑。

例如 ReentrantLock 通过重写这两个方法，实现了**可重入、公平/非公平**的独占锁特性。

## 3.2 共享锁（Shared）实现原理

### 3.2.1 共享锁的定义：同一时间允许多个线程持有锁

**共享锁**核心特性：同一时刻**允许多个线程同时持有锁、占用资源**，线程之间共享资源，互不排斥，适用于读多写少、限流、等待放行场景。

典型实现：ReentrantReadWriteLock读锁、CountDownLatch、Semaphore。

### 3.2.2 核心流程：acquireShared()获取锁 → 成功执行/失败入队 → releaseShared()释放锁

**共享锁获取流程（acquireShared）**：

1. 调用 `tryAcquireShared()` 尝试获取共享资源；

2. 返回正数：获取资源成功，允许并发执行；

3. 返回负数：资源不足，线程入队阻塞等待；

4. 多个线程可同时获取资源，无需互斥排队。

**共享锁释放流程（releaseShared）**：

1. 线程释放共享资源，调用 `tryReleaseShared()` 归还资源；

2. 更新state资源计数；

3. **传播唤醒**：成功释放后，持续唤醒后续排队的共享线程，最大化并发吞吐量。

### 3.2.3 模板方法：tryAcquireShared()/tryReleaseShared()自定义实现

- **tryAcquireShared()**：尝试获取共享资源，返回值区分结果：负数失败、0成功无剩余资源、正数成功且有剩余资源；

- **tryReleaseShared()**：尝试释放共享资源，更新state计数器，实现多线程资源归还。

不同工具类通过重写方法实现不同逻辑：CountDownLatch递减state、Semaphore递减许可数、读写锁读锁共享计数。

## 3.3 独占锁与共享锁的对比与适用场景

### 3.3.1 实现方式与state状态的不同用法

|对比维度|独占锁（Exclusive）|共享锁（Shared）|
|---|---|---|
|state含义|锁持有状态、重入次数|剩余可用资源数量|
|并发权限|同一时间仅一个线程持有|同一时间多个线程同时持有|
|获取方法|acquire / tryAcquire|acquireShared / tryAcquireShared|
|释放方法|release / tryRelease|releaseShared / tryReleaseShared|
### 3.3.2 等待队列唤醒机制的差异

- **独占锁唤醒**：每次释放锁，**仅唤醒一个后继线程**，保证独占排他性，避免多线程竞争；

- **共享锁唤醒**：支持**传播式唤醒**，一个线程释放资源后，会持续唤醒后续所有可执行的共享线程，最大化并发性能。

### 3.3.3 典型应用场景：独占锁（ReentrantLock）/共享锁（CountDownLatch）

**独占锁适用场景**：

- 数据更新、修改、写入操作；

- 事务操作、库存扣减、金额变更；

- 需要保证操作原子性、数据一致性的场景；

- 典型组件：ReentrantLock。

**共享锁适用场景**：

- 多读少写场景，读操作共享并发；

- 多线程等待统一放行（CountDownLatch）；

- 接口限流、资源配额控制（Semaphore）；

- 典型组件：读写锁、CountDownLatch、Semaphore。

---

# 4. `ReentrantLock` 可重入锁原理

ReentrantLock 是 JDK1.5 推出的、**基于AQS独占模式实现的显式可重入锁**，也是生产环境替代 synchronized 的核心锁组件。相较于原生隐式锁，ReentrantLock 具备更高的灵活性、可定制性与可控性，是高并发业务开发的首选独占锁。

## 4.1 ReentrantLock概述与使用方式

### 4.1.1 ReentrantLock：基于AQS实现的可重入显式锁

**ReentrantLock（可重入锁）** 是 Java 显式锁的核心实现，底层完全基于 AQS 独占锁模板实现。其核心特性为**可重入**：同一线程可多次获取同一把锁，避免自身阻塞死锁，同时支持手动加锁、手动解锁、超时抢锁、可中断抢锁、公平/非公平模式切换等高级特性。

ReentrantLock 内部通过内部类 **Sync、NonfairSync、FairSync** 继承AQS，重写独占锁核心模板方法，实现个性化的锁抢占、释放、重入逻辑，是AQS模板方法模式的经典落地案例。

### 4.1.2 与synchronized的对比：显式锁的灵活性优势

synchronized 是 JVM 原生隐式锁，依赖虚拟机底层实现，功能固定、灵活性差；ReentrantLock 是代码层面实现的显式锁，具备极强的可定制性，核心对比如下：

- **锁类型**：synchronized 为隐式锁，自动加锁解锁；ReentrantLock 为显式锁，手动控制加锁解锁

- **可重入性**：两者均支持可重入

- **锁模式**：synchronized 仅支持非公平锁；ReentrantLock 支持公平/非公平锁切换

- **高级特性**：synchronized 无超时、无中断、无尝试抢锁；ReentrantLock 支持 tryLock 超时抢锁、可中断抢锁、Condition精准唤醒

- **性能**：JDK1.6后synchronized优化偏向锁、轻量级锁，性能基本持平ReentrantLock；高并发竞争场景下ReentrantLock性能更稳定

- **适用场景**：简单同步场景用synchronized；复杂并发、精细化控制场景用ReentrantLock

### 4.1.3 核心使用方式：lock()/unlock()/tryLock()

ReentrantLock 提供三类核心加锁API，适配不同并发场景，以下为可直接运行的标准使用示例：

```java
import java.util.concurrent.locks.ReentrantLock;

/**
 * ReentrantLock 核心使用示例
 * 规范：lock必须在try外，unlock必须在finally中，避免锁泄露
 */
public class ReentrantLockDemo {
    // 创建非公平可重入锁（默认）
    private static final ReentrantLock LOCK = new ReentrantLock();

    public static void main(String[] args) {
        // 1. 基础lock()阻塞加锁：抢不到锁一直阻塞
        baseLockTest();

        // 2. tryLock()尝试加锁：非阻塞，抢不到直接返回false
        tryLockTest();

        // 3. tryLock超时加锁：指定时间内尝试抢锁
        tryLockTimeOutTest();
    }

    /**
     * 基础阻塞锁：一直等待获取锁
     */
    private static void baseLockTest() {
        LOCK.lock();
        try {
            // 同步业务逻辑
            System.out.println("获取锁成功，执行业务逻辑");
        } finally {
            // 必须finally解锁，防止异常导致锁无法释放
            LOCK.unlock();
        }
    }

    /**
     * 非阻塞尝试锁：抢锁失败立即返回，不阻塞线程
     */
    private static void tryLockTest() {
        if (LOCK.tryLock()) {
            try {
                System.out.println("尝试抢锁成功");
            } finally {
                LOCK.unlock();
            }
        } else {
            System.out.println("尝试抢锁失败，不阻塞线程");
        }
    }

    /**
     * 超时尝试锁：指定时间内自旋抢锁，超时失败
     */
    private static void tryLockTimeOutTest() {
        try {
            // 3秒内尝试获取锁
            if (LOCK.tryLock(3, java.util.concurrent.TimeUnit.SECONDS)) {
                try {
                    System.out.println("超时抢锁成功");
                } finally {
                    LOCK.unlock();
                }
            } else {
                System.out.println("3秒抢锁超时，放弃抢锁");
            }
        } catch (InterruptedException e) {
            System.out.println("抢锁线程被中断");
            Thread.currentThread().interrupt();
        }
    }
}

```

**生产强制规范**：**unlock()必须放在finally代码块中**，防止业务异常导致锁未释放，引发全局死锁、线程卡死问题。

## 4.2 可重入性的底层实现

可重入性是 ReentrantLock 的核心特性，底层完全依托 AQS 的 **state状态变量** 和 **持有线程记录** 实现，彻底解决同一线程多次加锁导致的自我阻塞问题。

### 4.2.1 state变量的作用：记录锁的重入次数

在 ReentrantLock 独占锁场景中，AQS 的 state 变量不再是简单的有无锁标识，而是**记录当前线程的锁重入次数**：

- **state = 0**：锁空闲，无任何线程持有；

- **state > 0**：锁被占用，数值代表当前线程的重入次数；

- 每重入加锁一次，state + 1；每解锁一次，state - 1；

- 只有 state 递减至 0 时，锁才真正释放，其他线程才可竞争。

### 4.2.2 线程持有锁的判断：判断当前线程是否为锁持有者

ReentrantLock 内部单独维护变量 `exclusiveOwnerThread`，用于**记录当前持有锁的线程**，这是实现可重入的核心判断依据：

1. 线程尝试获取锁时，先判断 state 是否为 0；

2. 若 state != 0，判断当前线程是否等于 exclusiveOwnerThread；

3. 若是当前持有线程，直接放行，实现重入；

4. 若不是当前线程，进入队列阻塞排队。

该机制保证：**持有锁的线程可以无限次重复加锁，不会自我阻塞**。

### 4.2.3 重入次数的自增与释放时的递减

**重入加锁流程**：当前线程已持有锁，再次调用 lock()，不竞争、不阻塞，直接将 state 数值 +1，重入次数累加。

**重入释放流程**：线程每次调用 unlock()，state 数值 -1；

- state > 0：锁未完全释放，依然被当前线程持有，其他线程无法竞争；

- state = 0：清空持有线程标识，锁完全释放，唤醒队列中后继线程竞争锁。

**生产避坑**：重入加锁多少次，就必须解锁多少次，否则 state 无法归零，会导致**锁泄露、永久死锁**。

## 4.3 公平锁与非公平锁实现

ReentrantLock 最核心的差异化特性：支持**公平锁、非公平锁**两种模式，两种模式底层均基于AQS实现，仅抢锁逻辑不同，默认使用非公平锁。

### 4.3.1 非公平锁：抢占式获取，可能导致线程饿死

**非公平锁（默认模式）**：线程抢锁不遵循排队顺序，**新线程优先抢占锁**，不区分队列等待线程。

**底层逻辑**：线程获取锁时，先直接CAS尝试修改state抢锁，抢锁成功直接执行；失败才进入队列排队。

**优缺点**：

- 优点：减少线程阻塞、唤醒开销，吞吐量高、性能极好；

- 缺点：老线程可能持续被新线程抢占，长期抢不到锁，引发**线程饥饿问题**。

### 4.3.2 公平锁：严格按照队列顺序获取锁

**公平锁**：严格遵循 **先来先服务** 原则，线程抢锁必须排队，不允许插队。

**底层逻辑**：线程抢锁前，先判断AQS同步队列是否存在等待线程；若队列有线程排队，当前新线程直接入队，不尝试CAS抢占，保证排队顺序绝对公平。

**优缺点**：

- 优点：线程有序执行，无线程饥饿问题，并发稳定性高；

- 缺点：大量线程需要入队阻塞、唤醒，上下文切换频繁，吞吐量低于非公平锁。

**创建方式**：`new ReentrantLock(true)` 开启公平锁模式。

### 4.3.3 公平/非公平锁的性能对比与适用场景

| 对比维度   | 非公平锁（默认）                     | 公平锁                                     |
| ---------- | ------------------------------------ | ------------------------------------------ |
| 抢锁规则   | 新线程优先抢占，支持插队             | 严格队列顺序，禁止插队                     |
| 性能吞吐量 | 极高，减少阻塞唤醒开销               | 较低，线程调度开销大                       |
| 线程饥饿   | 存在                                 | 无                                         |
| 适用场景   | 高并发、追求吞吐量、不关注线程公平性 | 任务优先级一致、禁止线程饿死、追求并发稳定 |

**生产最佳实践**：90%场景使用默认非公平锁；仅在线程任务优先级均等、长期运行的定时任务场景，开启公平锁。

---

# 5.`ReentrantReadWriteLock` 读写锁原理

ReentrantLock 是**独占锁**，同一时间仅一个线程执行，所有读写操作互斥，在读多写少场景下性能极差。为优化读多写少并发场景，JDK提供了 **ReentrantReadWriteLock 可重入读写锁**，基于AQS同时实现独占+共享模式，做到读共享、写独占，大幅提升高并发读场景吞吐量。

## 5.1 ReentrantReadWriteLock概述

### 5.1.1 读写锁的核心设计：读共享、写独占

ReentrantReadWriteLock 核心设计思想：**读写分离、区分对待读写操作**，内部包含两把锁：

- **读锁（共享锁）**：基于AQS共享模式实现，多线程可同时加读锁、并发读取数据；

- **写锁（独占锁）**：基于AQS独占模式实现，同一时间仅一个线程加写锁，独占修改数据。

**四大互斥规则（核心）**：

1. **读与读：共享不互斥**，多线程同时读；

2. **读与写：互斥阻塞**，读时不能写、写时不能读；

3. **写与写：互斥阻塞**，写操作独占资源；

4. 完美适配读多写少场景，兼顾并发安全与性能。

### 5.1.2 适用场景：读多写少的高并发场景

读写锁专门解决 **读多写少、读取频繁、修改极少** 的高并发业务场景，典型落地场景：

- 本地缓存、配置信息、字典数据的查询与更新；

- 商品详情、静态数据、基础数据高并发查询；

- 统计数据、日志数据读取，低频更新场景。

此类场景若使用普通独占锁，所有读操作串行执行，会产生严重的性能瓶颈，读写锁可将并发吞吐量提升数十倍。

### 5.1.3 读锁与写锁的关系：互斥性分析

读写锁的互斥本质是**保证数据可见性与一致性**，避免脏读、幻读：

- 已有读锁：新的读锁可直接获取，新的写锁必须阻塞等待所有读锁释放；

- 已有写锁：新的读锁、新的写锁全部阻塞，保证写操作独占执行；

- 无任何锁：读写锁均可正常获取。

## 5.2 state变量的高/低位拆分设计

ReentrantReadWriteLock 同时存在读锁、写锁，需要同时记录两种锁的持有次数，因此对AQS的32位int类型state变量做了**高低位拆分**设计，用一个变量维护两种锁状态，极致节省内存。

### 5.2.1 state的16位高：读锁持有次数

AQS 的 state 是 32位 int 类型，**高16位**专门用于记录**读锁的总持有次数**（所有线程的读锁累计次数）。

每当一个线程获取读锁，高16位数值+1；释放读锁，高16位数值-1；高16位为0代表当前无读锁。

### 5.2.2 state的16位低：写锁重入次数

state 的 **低16位**专门用于记录**当前线程写锁的重入次数**。

写锁是独占锁，同一时间仅一个线程持有，低16位数值代表该线程的写锁重入次数，为0代表无写锁持有。

### 5.2.3 高低位拆分的实现逻辑与计算方式

读写锁通过位运算实现高低位拆分读取与修改，核心常量与计算逻辑：

```java
// 读写锁核心位运算常量
// 偏移量16
static final int SHARED_SHIFT   = 16;
// 读锁掩码：高16位
static final int SHARED_UNIT    = (1 << SHARED_SHIFT);
// 写锁掩码：低16位
static final int EXCLUSIVE_MASK = (1 << SHARED_SHIFT) - 1;

/** 获取读锁次数：无符号右移16位，取出高16位数值  */
static int sharedCount(int c)    { return c >>> SHARED_SHIFT; }
/** 获取写锁次数：与低16位掩码与运算，取出低16位数值  */
static int exclusiveCount(int c) { return c & EXCLUSIVE_MASK; }

```

**核心原理**：通过位运算隔离高低位，一个32位state变量同时维护读写两把锁的状态，无需额外定义变量，设计极其精巧。

## 5.3 读锁与写锁的获取与释放流程

### 5.3.1 写锁获取：独占模式，读锁/写锁互斥

写锁基于AQS独占模式实现，获取流程：

1. 获取state高低位数值，判断当前是否存在读锁或写锁；

2. **存在读锁（高16位>0）**：直接阻塞，读写互斥；

3. **存在其他线程写锁（低16位>0且非当前线程）**：阻塞排队；

4. **当前线程持有写锁**：写锁重入，低16位计数+1；

5. **无任何锁**：CAS修改state，占用写锁，低16位置1。

写锁释放：逐层递减低16位重入次数，次数归零后完全释放锁，唤醒后续排队线程。

### 5.3.2 读锁获取：共享模式，与读锁共享、与写锁互斥

读锁基于AQS共享模式实现，获取流程：

1. 判断当前是否存在写锁（低16位>0）；

2. **存在写锁且非当前线程持有**：读锁阻塞，读写互斥；

3. **无写锁**：CAS修改state高16位，读锁计数+1，直接获取共享读锁；

4. 多线程可同时获取读锁，实现并发读取。

读锁释放：递减state高16位计数，所有读锁释放完毕后，唤醒等待的写锁线程。

### 5.3.3 写锁降级：写锁转为读锁的实现机制

**锁降级**是读写锁的核心高级特性：**允许写锁降级为读锁，不允许读锁升级为写锁**。

**降级流程**：线程持有写锁 → 获取读锁 → 释放写锁，最终线程仅持有读锁，完成锁降级。

**为什么只允许降级、不允许升级**：

- 读锁升级：多个线程同时持有读锁，若全部尝试升级写锁，会导致**循环死锁**；

- 写锁降级：当前线程独占资源，降级读锁不会产生并发冲突，安全可控。

**降级价值**：保证数据一致性，避免释放写锁后、获取读锁前的数据被其他线程修改，实现数据无缝读取。

## 5.4 读写锁的性能优势与注意事项

### 5.4.1 读多写少场景下的性能提升

普通 ReentrantLock 所有读写操作串行执行，读操作越多，性能瓶颈越明显；而读写锁通过**读共享机制**，支持海量读线程并发执行，仅写操作串行。

在读多写少场景中，并发吞吐量可提升**数倍至数十倍**，是高并发查询业务的最优锁方案。

### 5.4.2 写锁饥饿问题与解决方案

读写锁默认存在**写锁饥饿问题**：海量读线程持续抢占读锁，导致写锁线程持续阻塞，永远无法获取锁。

**解决方案**：

- 使用 **公平模式读写锁**：new ReentrantReadWriteLock(true)；

- 公平模式下，读锁线程会礼让队列中等待的写锁线程，优先放行写锁，彻底解决饥饿问题。

### 5.4.3 锁降级的使用规范与限制

**使用规范**：

1. 锁降级必须遵循：**先拿读锁、再放写锁**，保证降级过程数据不被篡改；

2. 降级后仅持有读锁，只能读取数据，无法修改数据；

3. 禁止读锁升级，避免全局死锁。

**适用场景**：修改数据后需要立即读取最新数据，且无需再次修改的场景，通过锁降级保证数据一致性。

---

# 6. `ReadWriteLock` 的读写分离场景

普通独占锁（synchronized、ReentrantLock）存在致命短板：无论读操作还是写操作，全部串行互斥执行。在互联网绝大多数**读多写少**业务场景中，大量无害的并发读操作被强行阻塞，造成严重的性能浪费。ReadWriteLock读写锁通过读写分离设计，完美解决该问题，是高并发读场景的核心优化方案。

## 6.1 读写分离的核心思想

### 6.1.1 读操作共享、写操作互斥，提升并发读性能

读写分离的核心设计理念：**区分读写操作的并发特性，差异化加锁**，最大化并发吞吐量，核心规则如下：

- **读与读共享**：读操作属于线程安全的只读操作，无数据修改风险，允许多个线程同时持有读锁并发读取，无阻塞、无互斥；

- **读与写互斥**：写操作会修改数据，为了避免脏读、数据不一致，读锁和写锁互相阻塞；

- **写与写互斥**：多线程同时修改数据会引发覆盖错乱，写锁保持独占互斥特性。

该机制在保证**线程安全、数据一致性**的前提下，彻底释放读操作的并发能力，大幅提升系统吞吐量。

### 6.1.2 典型业务场景：缓存、配置中心、读多写少数据

读写锁专属适配**读多写少、读取频繁、更新低频**的业务场景，生产高频落地场景如下：

1. **本地缓存场景**：系统启动加载热点数据，海量请求并发查询缓存，定时/手动少量更新缓存；

2. **配置中心场景**：系统配置、字典参数、白名单配置，全局高频读取，运维低频更新；

3. **基础数据场景**：商品基础信息、类目数据、地区数据、静态文案，读多写极少；

4. **统计数据场景**：日访问量、热度统计、榜单数据，高频查询、定时聚合更新。

以上场景若使用普通独占锁，会出现严重的读阻塞性能瓶颈，读写锁是最优解。

### 6.1.3 读写分离与普通独占锁的性能对比

我们从并发能力、阻塞范围、吞吐量、适用场景四个维度，对比读写锁与普通独占锁的核心差异：

| 对比维度   | 普通独占锁（ReentrantLock/synchronized） | 读写锁（ReentrantReadWriteLock） |
| ---------- | ---------------------------------------- | -------------------------------- |
| 并发规则   | 读写全部互斥，所有操作串行执行           | 读共享、写互斥，读并行、写串行   |
| 阻塞范围   | 任意操作都会阻塞其他所有线程             | 仅写操作阻塞读写，读操作不阻塞读 |
| 并发吞吐量 | 低，读多场景性能极差                     | 极高，完美适配高并发读场景       |
| 锁开销     | 小，逻辑简单                             | 略大，需维护双锁状态             |
| 适用场景   | 读写均衡、写多场景、数据强一致场景       | 读多写少、高频查询、低频更新场景 |

## 6.2 读写锁的典型业务实现

### 6.2.1 缓存读写场景：读锁读取缓存、写锁更新缓存

本地缓存是读写锁最经典的落地场景，通过读锁共享查询、写锁独占更新，实现高并发安全读写，以下为生产可直接复用的完整代码：

```java
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.locks.ReentrantReadWriteLock;

/**
 * 基于读写锁实现的本地缓存工具类
 * 读锁共享：海量请求并发查缓存，无阻塞
 * 写锁独占：更新缓存时互斥，防止数据覆盖错乱
 */
public class LocalCacheWithReadWriteLock {
    // 缓存存储容器
    private static final Map<String, Object> CACHE_MAP = new ConcurrentHashMap<>();
    // 读写锁对象
    private static final ReentrantReadWriteLock RW_LOCK = new ReentrantReadWriteLock();
    // 读锁
    private static final ReentrantReadWriteLock.ReadLock READ_LOCK = RW_LOCK.readLock();
    // 写锁
    private static final ReentrantReadWriteLock.WriteLock WRITE_LOCK = RW_LOCK.writeLock();

    /**
     * 读取缓存：加读锁，共享并发
     */
    public static Object getCache(String key) {
        READ_LOCK.lock();
        try {
            // 多线程可同时进入读取，无性能阻塞
            return CACHE_MAP.get(key);
        } finally {
            // 释放读锁
            READ_LOCK.unlock();
        }
    }

    /**
     * 更新缓存：加写锁，独占互斥
     */
    public static void setCache(String key, Object value) {
        WRITE_LOCK.lock();
        try {
            // 写操作独占，防止并发覆盖
            CACHE_MAP.put(key, value);
        } finally {
            WRITE_LOCK.unlock();
        }
    }

    /**
     * 删除缓存：加写锁
     */
    public static void removeCache(String key) {
        WRITE_LOCK.lock();
        try {
            CACHE_MAP.remove(key);
        } finally {
            WRITE_LOCK.unlock();
        }
    }
}

```

### 6.2.2 配置更新场景：读锁读取配置、写锁更新配置

系统全局配置、字典数据具备**全局读取、极少更新**的特性，适配读写锁架构，保证配置读取高性能、更新数据强一致：

```java
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.locks.ReentrantReadWriteLock;

/**
 * 系统配置读写工具类
 * 高频读取配置，低频更新配置
 */
public class SystemConfigManager {
    // 全局配置容器
    private static final Map<String, String> CONFIG = new HashMap<>();
    private static final ReentrantReadWriteLock RW_LOCK = new ReentrantReadWriteLock();
    private static final ReentrantReadWriteLock.ReadLock READ_LOCK = RW_LOCK.readLock();
    private static final ReentrantReadWriteLock.WriteLock WRITE_LOCK = RW_LOCK.writeLock();

    /**
     * 获取系统配置：共享读
     */
    public static String getConfig(String key) {
        READ_LOCK.lock();
        try {
            return CONFIG.get(key);
        } finally {
            READ_LOCK.unlock();
        }
    }

    /**
     * 更新系统配置：独占写
     */
    public static void updateConfig(String key, String value) {
        WRITE_LOCK.lock();
        try {
            // 模拟数据库更新后，更新本地缓存配置
            CONFIG.put(key, value);
        } finally {
            WRITE_LOCK.unlock();
        }
    }
}

```

### 6.2.3 高并发统计场景：读锁读取统计数据、写锁更新数据

网站访问量、接口调用次数、商品热度等统计数据，需要**高频查询展示、定时聚合更新**，使用读写锁可大幅提升查询并发量，同时保证更新数据安全：

```java
import java.util.concurrent.locks.ReentrantReadWriteLock;

/**
 * 业务统计数据管理器
 * 高频读、低频聚合更新
 */
public class BusinessStatistic {
    // 访问次数统计
    private static long visitCount = 0L;
    private static final ReentrantReadWriteLock RW_LOCK = new ReentrantReadWriteLock();
    private static final ReentrantReadWriteLock.ReadLock READ_LOCK = RW_LOCK.readLock();
    private static final ReentrantReadWriteLock.WriteLock WRITE_LOCK = RW_LOCK.writeLock();

    /**
     * 查询统计数据：高并发读
     */
    public static long getVisitCount() {
        READ_LOCK.lock();
        try {
            return visitCount;
        } finally {
            READ_LOCK.unlock();
        }
    }

    /**
     * 更新统计数据：独占写
     */
    public static void addVisitCount(long num) {
        WRITE_LOCK.lock();
        try {
            visitCount += num;
        } finally {
            WRITE_LOCK.unlock();
        }
    }
}

```

## 6.3 读写锁的避坑指南

### 6.3.1 避免读锁升级为写锁：导致死锁风险

**核心禁忌**：读写锁**不支持读锁升级为写锁**，绝对禁止在持有读锁的情况下，再次尝试获取写锁。

**死锁原理**：

1. 多个线程同时持有读锁；

2. 任意一个线程尝试升级写锁，会因为其他线程持有读锁而阻塞；

3. 其他读线程也可能尝试升级写锁，互相等待对方释放读锁；

4. 所有线程全部阻塞，形成**永久死锁**。

**生产规范**：如需修改数据，必须**先释放读锁，再获取写锁**；仅允许**写锁降级为读锁**。

### 6.3.2 写锁饥饿问题的处理

**问题现象**：非公平读写锁下，海量读线程持续抢占读锁，导致少量写锁线程持续排队、长期无法获取锁，引发**写锁饥饿**，数据长期无法更新。

**解决方案**：

1. **开启公平锁模式**：通过 `new ReentrantReadWriteLock(true)` 创建公平读写锁；

2. 公平锁机制下，队列中存在等待的写线程时，新的读线程会主动礼让，优先唤醒写线程，彻底解决饥饿问题；

3. 缺点：会轻微降低读并发吞吐量，适合读写差距不是极端悬殊的场景。

### 6.3.3 读写锁与synchronized的选型建议

结合业务场景，给出生产环境**精准选型规则**：

- **优先使用synchronized**：代码简短、同步代码块极小、读写均衡、低并发场景，无需引入复杂锁机制；

- **优先使用ReentrantLock**：需要公平锁、超时抢锁、可中断抢锁、简单互斥并发场景；

- **优先使用ReentrantReadWriteLock**：明确读多写少、高并发查询、低频更新的业务场景；

- **绝对禁用场景**：写多读少场景禁止使用读写锁，会因为写互斥特性导致性能倒退。

---

# 7. `Condition` 条件队列的实现与使用

Java 原生的 `wait()/notify()` 等待通知机制存在极大局限性：仅支持单条件等待、随机唤醒线程，无法实现精准控制。JUC 基于AQS提供的 **Condition条件队列**，彻底解决传统等待通知机制的短板，支持多条件、精准唤醒、可中断、超时等待，是实现精准线程调度、生产者消费者模型的核心组件。

## 7.1 Condition接口概述

### 7.1.1 Condition：基于Lock的等待-通知机制实现

**Condition** 是 JUC 提供的条件等待接口，依托 Lock 显式锁实现，是**替代Object.wait/notify的高级等待通知组件**。

核心定位：在显式锁加锁的代码块中，让线程基于特定业务条件阻塞等待，当条件满足时，精准唤醒等待线程，实现线程间的精准通信与调度。

### 7.1.2 与Object的wait()/notify()对比：多条件队列支持

Condition 是对原生等待通知机制的全方位升级，核心差异如下：

| 对比维度 | Object.wait()/notify()                          | Condition.await()/signal()        |
| -------- | ----------------------------------------------- | --------------------------------- |
| 依赖锁   | 依赖synchronized隐式锁                          | 依赖Lock显式锁（ReentrantLock等） |
| 条件队列 | 单个锁仅支持**一个等待队列**                    | 单个锁支持**多个独立条件队列**    |
| 唤醒机制 | notify随机唤醒、notifyAll全部唤醒，无法精准控制 | 精准唤醒指定条件下的等待线程      |
| 功能支持 | 不支持超时、不可控                              | 支持超时等待、可中断等待          |
| 适用场景 | 简单单条件线程等待                              | 复杂多条件、精准线程调度场景      |

### 7.1.3 核心方法：await()/signal()/signalAll()

Condition 核心三大方法，对应线程等待与唤醒完整逻辑：

- **await()**：当前线程释放锁，进入当前条件队列阻塞等待，等待被其他线程唤醒；

- **signal()**：唤醒当前条件队列中的**一个**等待线程，线程唤醒后重新竞争锁；

- **signalAll()**：唤醒当前条件队列中的**所有**等待线程，全部重新竞争锁。

**强制规范**：Condition 所有方法**必须在持有Lock锁的代码块中执行**，否则直接抛出异常。

## 7.2 Condition的底层实现原理

### 7.2.1 条件队列的结构：单向链表Node节点

每个 Condition 对象内部维护一个**独立的单向条件队列**，队列节点依然复用AQS的Node节点：

- 节点状态 waitStatus = -2（CONDITION），标识节点处于条件等待状态；

- 条件队列仅使用 next 指针构建单向链表，无需 prev 前驱指针；

- 与AQS同步双向队列相互独立，节点可双向流转。

### 7.2.2 await()方法流程：释放锁 → 加入条件队列等待 → 被唤醒后重新竞争锁

await() 是线程等待的核心方法，完整底层流转步骤：

1. **封装节点入队**：将当前线程封装为Node节点，加入Condition单向条件队列；

2. **完全释放锁**：线程主动释放当前持有的Lock锁，清空state状态，允许其他线程竞争锁；

3. **阻塞等待**：线程自旋判断等待状态，最终阻塞挂起，放弃CPU执行权；

4. **等待被唤醒**：等待其他线程执行 signal() 唤醒当前节点；

5. **重新竞争锁**：被唤醒后，节点从条件队列移除，转入AQS同步队列，重新自旋竞争锁；

6. **恢复执行**：成功获取锁后，线程退出await方法，继续执行业务逻辑。

### 7.2.3 signal()方法流程：从条件队列唤醒节点 → 加入等待队列竞争锁

signal() 精准唤醒条件队列线程，完整流程：

1. **校验锁状态**：校验当前线程是否持有锁，无锁直接抛异常；

2. **取出等待节点**：从Condition条件队列头部取出第一个有效等待节点；

3. **修改节点状态**：将节点状态从CONDITION修改为SIGNAL，退出条件等待状态；

4. **转入同步队列**：将该节点加入AQS同步阻塞队列；

5. **唤醒线程**：唤醒该节点绑定的线程，让其开始自旋竞争锁资源。

## 7.3 Condition的多条件队列优势

### 7.3.1 支持多个独立的等待条件，实现精准唤醒

Condition 最大的核心优势：**同一个Lock锁，可以创建多个独立的Condition条件队列**。

原生 wait/notify 机制中，所有等待线程都在同一个队列，唤醒只能随机或全部唤醒，无法区分业务条件；而 Condition 可以根据不同业务场景，拆分不同等待队列，**精准唤醒对应条件的线程**，互不干扰、极大提升并发效率。

### 7.3.2 生产者-消费者模型中多条件的使用场景

多条件队列最经典落地场景：**多条件生产者消费者模型**，拆分两个独立条件：

- **非满条件**：队列满时，生产者线程等待；队列有空位时唤醒生产者；

- **非空条件**：队列空时，消费者线程等待；队列有数据时唤醒消费者；

通过双条件精准唤醒，彻底解决传统模型的虚假唤醒、无效唤醒、性能浪费问题。

### 7.3.3 代码示例：基于Condition的多条件生产者-消费者模型

以下为生产可用、无虚假唤醒、线程安全的**多条件生产者消费者完整实现**：

```java
import java.util.ArrayDeque;
import java.util.Queue;
import java.util.concurrent.locks.Condition;
import java.util.concurrent.locks.ReentrantLock;

/**
 * 基于Condition多条件实现生产者消费者模型
 * 精准唤醒：生产者唤醒生产者、消费者唤醒消费者
 * 彻底解决notify无效唤醒问题
 */
public class ConditionProducerConsumer {
    // 队列最大容量
    private static final int MAX_SIZE = 10;
    // 消息队列
    private final Queue<Integer> queue = new ArrayDeque<>();
    // 显式锁
    private final ReentrantLock lock = new ReentrantLock();
    // 条件1：队列非满条件，控制生产者等待/唤醒
    private final Condition notFull = lock.newCondition();
    // 条件2：队列非空条件，控制消费者等待/唤醒
    private final Condition notEmpty = lock.newCondition();

    /**
     * 生产者生产数据
     */
    public void produce(Integer num) throws InterruptedException {
        lock.lock();
        try {
            // 队列满，生产者等待（while防止虚假唤醒）
            while (queue.size() == MAX_SIZE) {
                notFull.await();
            }
            // 生产数据
            queue.offer(num);
            System.out.println(Thread.currentThread().getName() + " 生产数据：" + num + "，当前队列大小：" + queue.size());
            // 精准唤醒消费者：队列已有数据，唤醒等待的消费者
            notEmpty.signal();
        } finally {
            lock.unlock();
        }
    }

    /**
     * 消费者消费数据
     */
    public void consume() throws InterruptedException {
        lock.lock();
        try {
            // 队列空，消费者等待
            while (queue.isEmpty()) {
                notEmpty.await();
            }
            // 消费数据
            Integer num = queue.poll();
            System.out.println(Thread.currentThread().getName() + " 消费数据：" + num + "，当前队列大小：" + queue.size());
            // 精准唤醒生产者：队列有空位，唤醒等待的生产者
            notFull.signal();
        } finally {
            lock.unlock();
        }
    }

    // 测试运行
    public static void main(String[] args) {
        ConditionProducerConsumer model = new ConditionProducerConsumer();

        // 生产者线程
        new Thread(() -> {
            for (int i = 1; i <= 20; i++) {
                try {
                    model.produce(i);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                }
            }
        }, "生产者线程").start();

        // 消费者线程
        new Thread(() -> {
            for (int i = 1; i <= 20; i++) {
                try {
                    model.consume();
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                }
            }
        }, "消费者线程").start();
    }
}

```

**核心优势总结**：

- 精准唤醒：生产者只唤醒消费者、消费者只唤醒生产者，无无效唤醒；

- while循环判断条件，彻底规避线程虚假唤醒BUG；

- 多条件队列隔离，逻辑清晰、并发性能远超原生wait/notify。

---

# 8. `Lock` 接口的核心方法：`lock()`/`unlock()`/`tryLock()`

**Lock接口**是JUC显式锁的顶层接口，所有基于AQS实现的锁（ReentrantLock、ReentrantReadWriteLock）都直接或间接实现该接口。Lock接口定义了一整套标准化的加锁、解锁、尝试抢锁、可中断抢锁方法，相较于synchronized固定的隐式锁逻辑，提供了精细化、可定制、高灵活的锁控制能力。

## 8.1 `lock()` 方法：阻塞式获取锁

### 8.1.1 方法定义与作用：获取锁，失败则阻塞

`void lock()` 是Lock接口最基础的阻塞式加锁方法，核心作用：**尝试获取锁资源，获取成功直接执行业务逻辑，获取失败则永久阻塞当前线程，直至成功抢到锁**。

该方法无返回值、不响应超时，线程一旦抢锁失败，会进入AQS同步队列自旋+阻塞休眠，全程挂起等待，直到持有锁的线程释放锁后被唤醒竞争资源，是生产中最常用的加锁方式。

### 8.1.2 底层流程：调用AQS的acquire()方法

所有Lock实现类的lock()方法，底层最终都会调用**AQS的acquire()独占锁获取方法**，完整底层执行链路：

1. 子类锁（ReentrantLock）重写AQS的 `tryAcquire()` 模板方法，实现自定义抢锁逻辑（重入判断、公平/非公平抢占）；

2. 调用AQS通用模板方法 `acquire(int arg)`，执行核心抢占逻辑；

3. 先调用 `tryAcquire()` 尝试抢占锁，抢占成功直接返回；

4. 抢占失败则调用 `addWaiter()` 将当前线程封装为Node节点，加入AQS同步队列；

5. 调用 `acquireQueued()` 让队列节点自旋尝试抢锁，多次失败后通过LockSupport阻塞线程；

6. 等待锁释放后被唤醒，继续自旋竞争锁，直至抢占成功。

**核心结论**：lock() 只是对外暴露的统一入口，真正的排队、阻塞、唤醒逻辑全部由AQS实现。

### 8.1.3 使用注意事项：必须在finally中调用unlock()

lock() 是显式加锁，不会像synchronized一样自动释放锁，生产使用存在强规范，也是高频踩坑点：

- **强制规范**：lock() 必须放在 try 代码块外部，unlock() 必须放在 finally 代码块中；

- **避坑原理**：若业务代码抛出异常，未手动解锁会导致锁永久不释放，造成线程死锁、资源卡死、服务雪崩；

- **禁止写法**：禁止在try内部加锁，禁止不写finally解锁。

```java
// 标准正确写法
LOCK.lock();
try {
    // 同步业务逻辑
} finally {
    // 无论正常结束还是异常结束，必然释放锁
    LOCK.unlock();
}

```

## 8.2 `unlock()` 方法：释放锁

### 8.2.1 方法定义与作用：释放锁，唤醒等待线程

`void unlock()` 为显式锁解锁方法，核心作用：**释放当前线程持有的锁资源，更新同步状态，唤醒AQS同步队列中等待的后继线程**。

对于可重入锁，unlock() 不会直接释放锁，而是逐层递减重入次数，只有当重入次数归零、state状态重置为0时，锁才会完全释放，同时触发线程唤醒逻辑。

### 8.2.2 底层流程：调用AQS的release()方法

unlock() 底层依赖AQS的 `release()` 独占锁释放方法，完整流程：

1. 调用子类重写的 `tryRelease()` 方法，尝试释放锁，递减重入次数、更新state状态；

2. 若释放后锁未完全空闲（state≠0，重入未结束），直接返回，不唤醒线程；

3. 若锁完全释放（state=0），调用AQS的 `unparkSuccessor()` 方法；

4. 找到head节点的有效后继等待节点，通过LockSupport唤醒阻塞线程；

5. 被唤醒的线程重新自旋竞争锁资源。

### 8.2.3 异常场景下的锁释放规范

生产环境中，锁释放的异常处理是保障服务稳定性的关键，核心规范如下：

- 禁止在 catch 中解锁，统一在 finally 解锁，保证无论正常/异常流程都能释放锁；

- 解锁前可增加判断：当前线程是否为锁持有者，防止非法解锁抛出 `IllegalMonitorStateException`；

- 可重入锁必须保证**加锁次数与解锁次数一致**，否则会出现锁残留、永久死锁。

```java
// 安全解锁示例
if (LOCK.isHeldByCurrentThread()) {
    LOCK.unlock();
}

```

## 8.3 `tryLock()` 方法：非阻塞/超时获取锁

lock() 是永久阻塞抢锁，极易引发线程堆积、死锁问题，而 tryLock 系列方法提供了**非阻塞、可超时**的抢锁能力，是生产解决死锁、优化并发阻塞的核心方案。

### 8.3.1 `tryLock()`：非阻塞尝试获取锁，成功返回true/false

`boolean tryLock()` 为**无阻塞尝试抢锁方法**，核心逻辑：

- 线程尝试一次CAS抢占锁资源；

- 抢占成功立即返回 true；

- 抢占失败**不阻塞线程、不入队排队**，直接返回 false；

该方法不会产生线程阻塞，不会占用线程资源，适合允许抢锁失败、无需强制执行的业务场景。

### 8.3.2 `tryLock(long timeout, TimeUnit unit)`：超时获取锁

带超时的 tryLock 是生产高频最优用法，核心作用：**在指定时间内自旋尝试抢锁，超时未抢到则直接返回失败，放弃抢锁**。

底层逻辑：线程限时自旋CAS抢占锁，不会永久阻塞，超时后主动退出竞争，避免线程永久挂起。方法支持响应中断，抢锁过程中线程被中断会直接抛出异常。

```java
// 超时抢锁完整示例
if (LOCK.tryLock(2, TimeUnit.SECONDS)) {
    try {
        // 抢到锁执行业务
    } finally {
        LOCK.unlock();
    }
} else {
    // 超时未抢到锁，执行降级逻辑
    System.out.println("系统繁忙，稍后重试");
}

```

### 8.3.3 使用场景：避免长时间阻塞、防止死锁

tryLock 系列方法的核心价值是**消除永久阻塞风险**，典型落地场景：

- **防止死锁**：多线程多锁嵌套场景，通过超时放弃机制打破死锁循环；

- **接口防雪崩**：高并发场景限时抢锁，失败直接降级，避免线程大量阻塞堆积；

- **非强一致性场景**：允许抢锁失败、支持重试、无需强制串行执行的业务；

- **定时任务场景**：任务有执行时限，禁止永久阻塞占用线程池资源。

## 8.4 `lockInterruptibly()`方法：可中断获取锁

### 8.4.1 支持线程中断的锁获取方式

`void lockInterruptibly()` 是**可中断阻塞加锁方法**，区别于普通lock()：lock() 阻塞过程中**不响应线程中断**，而 lockInterruptibly() 阻塞等待锁的过程中，若线程被中断，会立即抛出 `InterruptedException`，终止抢锁流程。

简单理解：普通阻塞是“死等不响应中断”，可中断阻塞是“可被唤醒终止等待”。

### 8.4.2 中断机制的底层实现

底层基于AQS的 `acquireInterruptibly()` 方法实现，核心流程：

1. 线程尝试通过 tryAcquire() 抢占锁，成功直接返回；

2. 抢占失败，线程封装节点入队阻塞；

3. 阻塞期间持续检测线程中断标识；

4. 若检测到线程被中断，直接抛出异常、终止抢锁、退出队列；

5. 无中断则持续阻塞，等待锁释放唤醒。

### 8.4.3 可中断锁的适用场景

- **任务取消场景**：异步任务、线程池任务需要主动终止，禁止任务阻塞堆积；

- **服务停机场景**：项目优雅停机时，可中断阻塞线程，避免线程卡死无法退出；

- **超时熔断场景**：外部触发中断，快速终止无效阻塞线程，释放资源。

---

# 9. `LockSupport` 工具类的作用

LockSupport 是JUC提供的**线程阻塞与唤醒底层工具类**，是整个AQS框架实现线程等待、阻塞、唤醒的底层依赖。AQS同步队列中所有线程的挂起与唤醒，全部由LockSupport的park/unpark方法实现，是JUC并发体系的最底层支撑。

## 9.1 LockSupport概述

### 9.1.1 LockSupport：线程阻塞与唤醒的底层工具类

LockSupport 位于 `java.util.concurrent.locks`包，是**无锁、静态工具类**，专门用于控制线程的阻塞与唤醒。相较于Object的wait/notify，LockSupport 更加灵活、安全、无语法限制，是AQS、Lock、线程池的核心底层依赖。

所有JUC中线程排队阻塞、精准唤醒的底层逻辑，最终都会调用 LockSupport 方法实现。

### 9.1.2 核心方法：park()/unpark()

LockSupport 核心只有两组核心方法，支撑全部线程调度能力：

- **park()**：阻塞当前线程，让线程休眠挂起，放弃CPU执行权；

- **parkNanos(long nanos)**：限时阻塞当前线程，超时自动唤醒；

- **unpark(Thread thread)**：精准唤醒**指定线程**，无需竞争、无需队列遍历。

### 9.1.3 与Object的wait()/notify()的对比

LockSupport 彻底解决了传统 wait/notify 的设计缺陷，核心对比如下：

| 对比维度 | wait()/notify()                                 | LockSupport park()/unpark()        |
| -------- | ----------------------------------------------- | ---------------------------------- |
| 锁依赖   | 必须持有synchronized锁，否则抛异常              | **无需任何锁**，任意场景可直接使用 |
| 唤醒精度 | notify随机唤醒、notifyAll批量唤醒，无法精准控制 | **精准唤醒指定线程**               |
| 执行顺序 | 必须先wait后notify，顺序颠倒永久阻塞            | 支持先unpark后park，不会永久阻塞   |
| 中断响应 | 被唤醒后可响应中断                              | park阻塞可直接响应线程中断         |
| 底层机制 | 对象监视器机制                                  | 许可证机制                         |

## 9.2 park()/unpark()方法详解

### 9.2.1 park()：阻塞当前线程

`LockSupport.park()` 作用：**阻塞当前调用线程**，线程进入WAITING状态，停止执行、释放CPU，等待被唤醒。

线程从park阻塞状态恢复执行只有三种情况：

1. 其他线程调用 `unpark(当前线程)` 精准唤醒；

2. 其他线程对当前线程发起中断（interrupt）；

3. 虚假唤醒（极少场景，代码需兼容）。

### 9.2.2 unpark(Thread t)：唤醒指定线程

`LockSupport.unpark(Thread t)` 作用：**精准唤醒目标线程t**，无论目标线程是否处于阻塞状态，都可以为其发放唤醒许可证。

这是JUC实现**精准线程调度**的核心根基，彻底告别notify随机唤醒的不确定性，也是Condition精准唤醒、AQS队列有序唤醒的底层支撑。

### 9.2.3 park/unpark的许可证机制：先unpark后park也可唤醒

LockSupport 最核心、面试最高频的原理：**许可证机制（Permit）**。

JVM为每个线程维护一个**唯一的许可证**，许可证状态只有0和1：

- **park()**：检测许可证，有许可证（1）则消耗许可证、不阻塞直接执行；无许可证（0）则阻塞线程；

- **unpark()**：为线程发放许可证，将许可证置为1，多次unpark只会保留1张许可证；

**核心特性（高频面试题）**：

1. **先unpark、后park**：提前发放许可证，后续执行park不会阻塞，直接放行；

2. **多次unpark无效**：许可证最多1张，重复unpark不会叠加；

3. **park消耗许可证**：一次park消耗一张许可证，必须等待下次unpark。

该机制完美解决了wait/notify顺序颠倒导致的永久死锁问题。

## 9.3 LockSupport在AQS中的应用

### 9.3.1 AQS中线程阻塞与唤醒的底层依赖LockSupport

AQS 本身不具备线程阻塞唤醒能力，所有队列线程的挂起与唤醒，**100%依赖LockSupport实现**：

- AQS线程抢锁失败、需要排队阻塞时，调用 LockSupport.park() 挂起线程；

- 锁释放、需要唤醒后继线程时，调用 LockSupport.unpark() 精准唤醒队列节点线程；

- Condition条件队列的等待唤醒，同样基于LockSupport实现。

简单总结：**AQS是并发调度框架，LockSupport是线程调度的底层执行者**。

### 9.3.2 等待队列节点的park/unpark流程

AQS同步队列完整park/unpark流转流程：

1. 线程抢锁失败，封装为Node节点进入同步队列；

2. 节点自旋尝试抢锁多次失败后，执行 park() 阻塞线程；

3. 前驱节点释放锁后，执行 unpark() 唤醒当前节点线程；

4. 线程被唤醒后，重新自旋竞争锁；

5. 抢锁成功则出队执行业务，失败则再次park阻塞。

### 9.3.3 LockSupport的底层实现与性能优势

LockSupport 的 park/unpark 底层基于**Unsafe类native方法** 实现，由操作系统底层调度，性能极强：

- **无锁开销**：无需依赖对象锁，纯底层线程调度，执行效率极高；

- **精准调度**：点对点线程唤醒，无无效唤醒、无批量竞争；

- **顺序安全**：许可证机制规避线程先后执行顺序问题，无死锁风险；

- **轻量级阻塞**：相较于synchronized重量级阻塞，上下文切换开销更小。

