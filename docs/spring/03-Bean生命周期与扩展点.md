# 03-Bean 生命周期与扩展点

## 本章概述

上一章我们彻底掌握了Spring IoC容器的核心原理、依赖注入、Bean注册规则，明白了Spring如何接管对象的控制权。而本章将深入IoC容器的**核心运行内核**：Bean完整生命周期与Spring扩展机制。

如果说IoC容器是Spring的骨架，那么**Bean生命周期**就是Spring运行的完整脉络，**扩展点机制**就是Spring具备高可扩展性、支撑SpringBoot自动配置、AOP、事务、动态代理等所有高级功能的核心基石。

很多开发者只会用Spring，却不懂Bean的创建、赋值、初始化、运行、销毁全流程，导致遇到循环依赖报错、Bean初始化异常、事务失效、代理失效、资源泄漏等问题时无法排查。同时Bean生命周期、两大核心后置处理器、扩展点机制是Java后端**面试高频压轴考点**。

本章将从零拆解Bean完整11步生命周期、每一个阶段的底层逻辑、四种初始化/销毁方式优先级、作用域对生命周期的影响，同时深度剖析Spring容器级、Bean级核心扩展点，结合实操代码、生产避坑、面试答题模板，帮助大家做到**懂原理、会实操、能排错、稳面试**。

## 1. Bean 生命周期整体总览

### 1.1 什么是Bean生命周期？核心阶段宏观划分

**Bean生命周期**指Spring IoC容器中，一个Bean对象从**被容器扫描注册、创建实例、属性赋值、初始化、对外提供服务、最终销毁释放资源**的一整套完整的执行流程。

用生活化类比理解：Bean的生命周期和人的一生完全一致：出生（实例化）→ 成长赋值（依赖注入）→ 学习准备（初始化）→ 工作服务（运行阶段）→ 退休死亡（销毁释放）。Spring容器全程管控单例Bean的全生命周期。

从宏观维度，可将Bean生命周期划分为**五大核心阶段**，所有Spring Bean都严格遵循该顺序执行：

1. **解析注册阶段**：扫描配置、生成BeanDefinition并注册到容器（无对象创建，仅存元数据）

2. **实例化阶段**：通过反射创建Bean原始空对象（无属性赋值）

3. **依赖注入阶段**：完成字段、Setter、构造器属性填充，解决循环依赖

4. **初始化增强阶段**：后置处理器增强、自定义初始化方法执行、代理生成

5. **运行销毁阶段**：对外提供业务服务、容器关闭后执行销毁逻辑、释放资源

**核心重点**：只有**单例Bean**会被Spring完整托管全生命周期；多例Bean仅由容器创建，后续运行、销毁完全不受容器管控。

### 1.2 Spring Bean 完整生命周期11步流程总览

结合Spring源码执行顺序，标准化的Bean完整生命周期共分为**11个核心步骤**，是面试口述、源码阅读的核心标准流程，顺序不可颠倒：

**完整11步执行顺序**：

1. 容器启动，加载XML/注解/JavaConfig配置，扫描组件包

2. 解析所有Bean，生成**BeanDefinition**元数据，注册至容器注册表

3. 执行**BeanFactoryPostProcessor**容器级扩展，修改Bean定义

4. 通过反射执行**构造方法实例化Bean**，创建原始空对象

5. 完成**依赖注入**（字段/Setter/构造器赋值），解决单例循环依赖

6. 执行**BeanPostProcessor前置处理**（初始化前增强）

7. 执行**@PostConstruct**注解初始化方法

8. 执行**InitializingBean#afterPropertiesSet**接口初始化方法

9. 执行自定义**init-method**初始化方法

10. 执行**BeanPostProcessor后置处理**（生成AOP代理对象，核心增强）

11. Bean完成初始化，存入一级缓存，对外提供服务；容器关闭时执行销毁逻辑

**核心结论**：AOP代理、事务增强等所有高级特性，全部在第10步后置处理器阶段完成。

### 1.3 生命周期设计的核心价值与应用场景

Spring设计统一的Bean生命周期，并非单纯的流程规范，而是为了解决企业级开发的核心痛点，提供极高的拓展性和规范性。

#### 1. 核心价值

- **统一对象管理规范**：所有Bean遵循同一套生命周期，避免开发者手动管理对象导致的资源混乱、内存泄漏。

- **预留海量扩展点位**：在实例化前后、初始化前后、容器启动前后预留扩展点，支撑Spring AOP、事务、自动配置、动态代理等核心功能。

- **资源自动化管控**：支持Bean初始化预热、容器关闭自动释放连接池、线程池、网络连接等资源。

- **完美解耦业务与底层逻辑**：开发者可在指定生命周期节点植入自定义逻辑，无需修改源码。

#### 2. 生产应用场景

- 项目启动**缓存预热**：在Bean初始化阶段加载热点数据到缓存

- 资源初始化：初始化Redis、MySQL、MQ连接池、注册客户端实例

- 项目关闭资源释放：关闭连接、销毁线程池、提交事务、清理临时数据

- 自定义注解增强：通过后置处理器实现自定义权限、日志、限流注解

### 1.4 面试高频：手绘Bean完整生命周期流程

**📌面试满分答题模板（可直接背诵）**

Spring Bean生命周期分为容器解析、实例化、注入、初始化、运行、销毁六大阶段，完整执行流程如下：

首先容器启动扫描配置，解析生成BeanDefinition并完成注册，随后执行容器级后置处理器修改Bean定义；之后通过构造器反射实例化Bean，完成依赖注入与循环依赖解决；接着执行Bean后置处理器前置增强，依次执行@PostConstruct、InitializingBean、init-method初始化逻辑；最后执行后置处理器后置增强生成代理Bean，存入容器缓存对外提供服务；容器关闭时触发@PreDestroy、DisposableBean、destroy-method完成资源释放。

**面试官加分点**：主动说明两个核心边界：单例Bean容器启动初始化、多例Bean使用时初始化；构造器循环依赖无法解决、只有Setter/字段注入可解决。

## 2. Bean 实例化阶段详解

### 2.1 Bean定义加载与BeanDefinition注册回顾

Bean实例化的**前置必要条件**是BeanDefinition注册完成。很多新手混淆「Bean定义注册」和「Bean实例化」，核心区别：**注册是存模板，实例化是造对象**。

容器启动初期，Spring会解析XML配置、扫描@Component注解、解析@Bean方法，将每一个需要托管的类，封装为**BeanDefinition**元数据对象。BeanDefinition中存储了类全路径、作用域、依赖关系、初始化方法、销毁方法、属性配置等所有模板信息。

随后Spring通过**BeanDefinitionRegistry**将所有BeanDefinition注册到全局Map注册表中。此时**没有创建任何对象**，仅保存了Bean的创建规则。

**💡核心原理**：Spring采用「模板与实例分离」设计，先统一注册所有模板，再批量实例化对象，方便后置处理器统一修改模板，实现全局拓展。

### 2.2 单例Bean vs 多例Bean 实例化时机差异

实例化时机是单例与多例Bean最核心的区别，直接决定生命周期执行逻辑、缓存机制、循环依赖支持能力。

#### 1. 单例Bean（singleton）

- **实例时机**：非懒加载单例Bean在**容器启动完成前批量预实例化**

- **生命周期**：与IoC容器同生共死，容器启动创建、容器关闭销毁

- **缓存机制**：完整进入三级缓存，支持循环依赖解决

- **执行特点**：全局唯一，全程被容器托管所有生命周期阶段

#### 2. 多例Bean（prototype）

- **实例时机**：**懒加载机制**，每次调用getBean/依赖注入时才创建新对象

- **生命周期**：容器只负责创建，不负责初始化后置增强、不负责销毁

- **缓存机制**：不进入三级缓存，无任何缓存

- **执行特点**：每次获取全新对象，无法解决循环依赖

**⚠️避坑指南**：绝大多数业务Bean使用单例，仅有状态、数据隔离的场景使用多例，切勿滥用多例导致频繁创建对象、性能下降、资源无法释放。

### 2.3 懒加载 @Lazy 原理与生效条件

默认情况下，单例Bean在容器启动时预加载，Spring提供**@Lazy**注解打破该规则，实现单例Bean懒加载。

#### 1. 核心原理

被@Lazy标记的单例Bean，容器启动时**不实例化、不初始化**，仅注册BeanDefinition模板，在**第一次被业务代码调用/注入**时，才执行完整的实例化、注入、初始化流程。

#### 2. 生效条件

- 仅对**单例Bean**生效，多例Bean本身就是懒加载，@Lazy无效

- 注解可标记在类上、方法上、注入字段上

#### 3. 实操示例

```java
// 类级别懒加载：启动不初始化，首次使用才创建
@Service
@Lazy
public class LazyService {}

```

#### 4. 生产价值

用于启动耗时久、初始化资源多、低频使用的Bean，**缩短项目启动时间**，优化启动性能。

### 2.4 构造方法实例化：无参构造、有参构造依赖

Spring Bean的实例化**底层唯一依赖构造方法**，所有Bean对象最终都是通过反射构造方法创建，这是实例化的底层核心。

#### 1. 无参构造（默认首选）

如果类没有自定义构造方法，编译器默认生成无参构造，Spring直接通过无参构造实例化空对象，后续通过Setter/字段完成依赖注入。

**⚠️常见报错**：如果自定义了有参构造，且未声明无参构造，Spring实例化会直接报错 `No default constructor found`。

#### 2. 有参构造（构造器注入）

Spring4.3+版本，若类中**仅有一个有参构造**，可省略@Autowired，容器自动识别并通过有参构造完成实例化+依赖注入，一步到位。

#### 3. 核心区别

- 无参构造：先实例化空对象，后填充属性

- 有参构造：实例化的同时直接完成依赖注入，无空对象阶段

### 2.5 工厂Bean FactoryBean 创建对象流程

普通Bean通过构造方法实例化，而**FactoryBean工厂Bean**是特殊Bean，拥有独立的实例化流程，专门用于创建复杂对象。

#### 1. 执行流程

1. 容器加载FactoryBean的BeanDefinition，实例化工厂本身

2. 容器识别当前Bean是FactoryBean类型，自动调用**getObject()**方法

3. 将getObject()返回的复杂对象注册为最终Bean，而非工厂本身

#### 2. 核心特点

- FactoryBean本身是一个Bean，但其生产的对象才是业务使用的Bean

- 适合创建创建逻辑复杂、第三方开源组件、连接池对象

- 前缀&可获取工厂本身Bean：`context.getBean("&factoryBean")`

#### 3. 典型场景

MyBatis的SqlSessionFactoryBean、Redis客户端、线程池对象全部基于此机制创建。

## 3. 依赖注入阶段

### 3.1 属性填充原理：字段/Setter/构造器注入执行时机

依赖注入是Bean实例化后的**必经核心阶段**，目的是为空白Bean对象填充依赖属性，解除代码耦合。三种注入方式的执行时机完全不同，直接影响生命周期和循环依赖解决能力。

#### 1. 构造器注入

- **执行时机**：**实例化阶段同步执行**，创建对象的同时完成依赖赋值

- **特点**：无半成品Bean，无法提前暴露引用，**不支持循环依赖解决**

#### 2. Setter注入

- **执行时机**：构造器实例化完成后，独立的属性填充阶段执行

- **特点**：存在半成品Bean，可提前暴露引用，支持循环依赖

#### 3. 字段注入（@Autowired）

- **执行时机**：和Setter注入一致，实例化完成后统一属性填充

- **特点**：开发最简洁，Spring底层通过反射直接赋值，支持循环依赖

#### 4. 生产最佳实践

必填核心依赖使用构造器注入保证安全性，可选动态依赖使用Setter注入，日常开发禁止滥用字段注入。

### 3.2 循环依赖对生命周期流程的影响

循环依赖会**改变单例Bean的正常生命周期执行顺序**，是生命周期中最特殊的场景。

#### 1. 正常生命周期

实例化 → 依赖注入 → 初始化 → 存入一级缓存

#### 2. 循环依赖生命周期（A依赖B、B依赖A）

1. A实例化，生成半成品对象，存入三级缓存

2. A开始依赖注入，需要B，触发B实例化

3. B依赖注入需要A，从三级缓存获取A半成品完成注入

4. B完成所有生命周期，存入一级缓存

5. A继续完成剩余依赖注入、初始化、存入一级缓存

#### 3. 核心影响

循环依赖场景下，**两个Bean的生命周期交叉执行**，而非串行执行，三级缓存的半成品Bean起到了临时过渡作用。

### 3.3 自动装配 @Autowired 注入底层触发时机

@Autowired是日常开发最常用的自动装配注解，其底层触发时机固定在**Bean实例化完成之后、初始化方法执行之前**。

#### 1. 底层原理

Spring内置的**AutowiredAnnotationBeanPostProcessor**后置处理器，专门负责解析@Autowired、@Value注解，在属性填充阶段通过反射完成自动注入。

#### 2. 执行顺序定位

构造实例化 → @Autowired自动注入 → 初始化方法执行

#### 3. 核心结论

所有被@Autowired注入的依赖，**在初始化方法中一定已经完成赋值**，不会出现空指针。

## 4. 生命周期回调：初始化阶段

### 4.1 四种初始化方式全梳理

Spring提供四种官方初始化方式，用于在Bean属性赋值完成后，执行自定义初始化业务逻辑，适配不同开发场景。

#### 4.1.1 @PostConstruct 注解初始化

JSR250标准注解，是**开发中最推荐、最常用**的初始化方式，无框架侵入、使用简洁。

**执行时机**：依赖注入完成后，优先级最高，早于所有接口、配置初始化方法。

**实操代码**

```java
@Service
public class InitService {
    // 依赖先注入完成
    @Autowired
    private UserService userService;

    // 注解初始化方法
    @PostConstruct
    public void postConstructInit(){
        // 缓存预热、资源初始化、数据加载
        System.out.println("@PostConstruct 初始化执行");
    }
}

```

#### 4.1.2 InitializingBean 接口 afterPropertiesSet

Spring原生接口，强制实现afterPropertiesSet方法，框架级初始化回调。

**执行时机**：@PostConstruct之后、init-method之前执行。

**实操代码**

```java
@Service
public class InitService implements InitializingBean {
    @Override
    public void afterPropertiesSet() throws Exception {
        System.out.println("InitializingBean 接口初始化执行");
    }
}

```

**缺点**：侵入业务代码，耦合Spring框架，不推荐常规业务使用。

#### 4.1.3 XML/ @Bean 指定 init-method

通过配置方式指定自定义初始化方法，完全解耦代码，适配第三方Bean初始化。

**执行时机**：所有初始化方式中优先级最低。

**实操代码**

```java
// 自定义初始化方法
public void customInit(){
    System.out.println("init-method 自定义初始化执行");
}

// 配置指定初始化方法
@Bean(initMethod = "customInit")
public InitService initService(){
    return new InitService();
}

```

#### 4.1.4 自定义初始化逻辑执行时机

开发者手动编写的业务初始化逻辑，若未使用任何Spring生命周期注解/接口，默认在Bean初始化完成、对外提供服务后执行，不属于Spring生命周期回调。**不推荐**，无法保证依赖注入完成。

### 4.2 四种初始化方式**执行优先级**对比

面试必考核心知识点，**固定优先级顺序不可改变**：

**@PostConstruct > InitializingBean > init-method**

**完整执行链路**：

依赖注入完成 → 注解初始化 → 接口初始化 → 配置初始化方法

**原理说明**：注解属于Java标准规范，优先级最高；Spring原生接口次之；配置文件定义的自定义方法优先级最低。

### 4.3 初始化阶段常见坑：依赖未注入、初始化重复执行

#### 1. 依赖未注入空指针

**问题原因**：将初始化逻辑写在构造方法中，构造方法执行时依赖还未注入。

**解决方案**：所有需要依赖的初始化逻辑，必须写在@PostConstruct及之后的初始化阶段。

#### 2. 初始化方法重复执行

**问题原因**：同时配置多种初始化方式，导致多段初始化逻辑重复执行。

**解决方案**：业务开发统一只使用@PostConstruct一种初始化方式，简洁且无重复风险。

## 5. Bean 后置处理器介入（扩展点核心）

### 5.1 BeanPostProcessor 整体作用定位

**BeanPostProcessor**是Spring**最重要的Bean级扩展点**，是AOP动态代理、事务增强、注解解析、Bean自定义增强的底层核心。

核心定位：**对所有完成实例化、依赖注入的Bean，在初始化前后进行无侵入增强**，全局生效，是Spring高拓展性的灵魂。

### 5.2 前置后置回调：postProcessBeforeInitialization / postProcessAfterInitialization

BeanPostProcessor包含两个核心回调方法，精准介入生命周期两个节点：

#### 1. postProcessBeforeInitialization（初始化前置）

**执行时机**：依赖注入完成、**所有初始化方法执行之前**

**作用**：修改Bean属性、预处理Bean数据

#### 2. postProcessAfterInitialization（初始化后置）

**执行时机**：**所有初始化方法执行完成之后**

**作用**：生成AOP代理对象、完成Bean最终增强、替换原始Bean

**核心结论**：我们业务中使用的Bean，绝大多数都是后置处理器生成的**代理Bean**，而非原始Bean。

### 5.3 AOP 代理何时介入生命周期？

这是面试高频难点：**AOP代理对象在Bean初始化完成后生成**。

完整顺序：原始Bean实例化 → 依赖注入 → 初始化方法全部执行 → BeanPostProcessor后置处理 → **生成代理Bean** → 代理Bean存入容器

**核心价值**：保证代理对象拥有原始Bean的所有初始化数据，不会丢失初始化逻辑。

### 5.4 自定义 BeanPostProcessor 实操与业务应用

```java
// 自定义全局Bean后置处理器
@Component
public class CustomBeanPostProcessor implements BeanPostProcessor {

    // 初始化前置处理
    @Override
    public Object postProcessBeforeInitialization(Object bean, String beanName) throws BeansException {
        System.out.println("Bean【"+beanName+"】初始化前置处理");
        return bean;
    }

    // 初始化后置处理，可实现自定义代理、增强
    @Override
    public Object postProcessAfterInitialization(Object bean, String beanName) throws BeansException {
        System.out.println("Bean【"+beanName+"】初始化后置增强完成");
        return bean;
    }
}

```

**业务应用场景**：自定义日志注解、权限校验、接口限流、动态字段填充全部基于此扩展点实现。

## 6. Bean 就绪 & 运行阶段

### 6.1 单例Bean放入一级缓存、对外提供服务

当Bean完成实例化、依赖注入、初始化、后置增强、代理生成后，代表Bean完全就绪。Spring会将**完整可用的代理Bean**存入**一级缓存singletonObjects**。

一级缓存是Spring的最终Bean缓存，所有业务请求、依赖获取，都会从一级缓存直接获取Bean，保证全局单例、高性能复用。

此时Bean正式进入**运行阶段**，常驻内存，等待业务调用，直至容器关闭。

### 6.2 多例Bean运行期特点：不缓存、不管理生命周期

多例Bean完成创建和初始化后，**不会存入任何缓存**，Spring容器直接放弃管理。

运行阶段特点：

1. 每次调用都创建全新对象，无复用

2. 容器不跟踪多例Bean状态，不执行后置增强

3. 容器关闭时不会执行销毁方法，资源需要手动释放

4. 无法参与循环依赖缓存机制

### 6.3 有状态Bean在单例中的线程安全避坑

**核心避坑原则**：Spring单例Bean是**单例多线程**，天然线程不安全。

- **无状态Bean**：无成员变量、不存储数据，线程安全（Service、Dao）

- **有状态Bean**：包含可修改成员变量，多线程并发修改会出现数据错乱

**解决方案**：禁止在单例Bean中定义可修改成员变量；如需状态存储，使用ThreadLocal隔离线程数据，或改为多例Bean。

## 7. Bean 销毁阶段

### 7.1 销毁触发条件：容器关闭、上下文刷新

Bean销毁阶段**不会自动触发**，必须满足指定条件：

1. 手动调用 `context.close()` 关闭IoC容器

2. SpringBoot项目优雅停机、项目重启、服务下线

3. 容器上下文刷新刷新容器

**重点**：异常宕机、强制kill进程不会触发销毁方法，会导致资源泄漏。

### 7.2 三种销毁方式

#### 7.2.1 @PreDestroy 注解销毁

JSR250标准注解，优先级最高，业务首选。

```java
@Service
public class ResourceService {
    @PreDestroy
    public void preDestroyClose(){
        // 关闭连接、释放线程池
        System.out.println("@PreDestroy 资源释放");
    }
}

```

#### 7.2.2 DisposableBean 接口 destroy 方法

Spring原生销毁接口，优先级次于@PreDestroy。

```java
@Service
public class ResourceService implements DisposableBean {
    @Override
    public void destroy() throws Exception {
        System.out.println("DisposableBean 销毁执行");
    }
}

```

#### 7.2.3 XML/ @Bean 指定 destroy-method

配置式销毁，优先级最低，适配第三方Bean资源释放。

```java
@Bean(destroyMethod = "close")
public RedisClient redisClient(){
    return new RedisClient();
}

```

### 7.3 销毁执行优先级与资源释放最佳实践

**销毁优先级固定顺序**：@PreDestroy > DisposableBean > destroy-method

**💡最佳实践**：

1. 业务自定义Bean统一使用@PreDestroy释放资源

2. 第三方组件使用destroy-method配置关闭方法

3. 连接池、线程池、MQ客户端必须配置销毁逻辑，避免资源泄漏

### 7.4 多例Bean为什么不会执行销毁方法？

**核心原理**：Spring容器仅缓存、管理单例Bean的生命周期。多例Bean创建后，容器不会保存其引用，无法追踪Bean状态，因此容器关闭时无法调用销毁方法。

**避坑方案**：多例Bean的资源释放需要开发者手动调用关闭方法，不能依赖Spring生命周期。

## 8. IoC 容器两大核心扩展点深度剖析

### 8.1 扩展点整体分类：容器级扩展 vs Bean级扩展

Spring所有扩展点分为两大类，层级、时机、能力完全不同：

- **容器级扩展（BeanFactoryPostProcessor）**：作用于容器启动早期，修改Bean定义模板，全局生效，Bean实例化前执行

- **Bean级扩展（BeanPostProcessor）**：作用于每个Bean实例，对Bean对象增强，实例化后执行

### 8.2 BeanFactoryPostProcessor 容器级扩展

#### 8.2.1 执行时机：BeanDefinition注册后、Bean实例化前

这是容器级扩展的核心特点：**只改模板，不改实例**。所有Bean还未创建，仅存在BeanDefinition元数据。

#### 8.2.2 能力：修改Bean定义、新增Bean定义

可动态修改Bean的作用域、类路径、属性、初始化方法，甚至动态注册新的BeanDefinition，是Spring配置解析、占位符替换的底层核心。

#### 8.2.3 实操示例与底层源码作用

```java
@Component
public class CustomBeanFactoryProcessor implements BeanFactoryPostProcessor {
    @Override
    public void postProcessBeanFactory(ConfigurableListableBeanFactory beanFactory) throws BeansException {
        // 获取指定Bean定义
        BeanDefinition beanDefinition = beanFactory.getBeanDefinition("userService");
        // 动态修改Bean作用域为多例
        beanDefinition.setScope("prototype");
        System.out.println("容器级扩展：修改Bean定义完成");
    }
}

```

### 8.3 BeanPostProcessor Bean级扩展

#### 8.3.1 执行时机与两次回调完整流程

每个Bean初始化前后都会触发两次回调，是Bean实例级别的精细化扩展。

#### 8.3.2 与AOP、事务、动态代理的关联

Spring的AOP代理、@Transactional事务增强、自定义注解全部依赖BeanPostProcessor实现，在初始化后置阶段完成代理替换。

#### 8.3.3 多个BeanPostProcessor执行顺序控制

通过实现**Ordered**接口，设置order值，数值越小优先级越高，越先执行。

## 9. 其他常用扩展点

### 9.1 Environment 环境变量与属性绑定扩展

Spring通过Environment扩展点统一解析系统环境变量、JVM参数、配置文件参数，配合@Value实现动态属性注入，支撑多环境配置切换。

### 9.2 @Conditional 条件Bean注册扩展

条件化注册扩展点，根据环境、类存在性、配置参数动态判断是否注册Bean，是SpringBoot自动配置的核心原理，实现**按需加载Bean**。

### 9.3 ImportSelector / ImportBeanDefinitionRegistrar 动态导入Bean

两大动态导入扩展点，可在不扫描包的情况下，手动批量注册BeanDefinition，是SpringBoot starter、自定义组件注册的底层实现。

### 9.4 ApplicationListener 事件监听扩展点

Spring事件驱动扩展点，监听容器启动、刷新、关闭、自定义业务事件，实现业务解耦，常用于项目启动初始化、消息通知、异步业务处理。

## 10. 作用域对生命周期的影响

### 10.1 singleton 单例：生命周期与容器同生共死

单例Bean完整执行全部生命周期：容器启动初始化、运行常驻、容器关闭销毁，全程被Spring托管，是项目主流Bean类型。

### 10.2 prototype 多例：容器只创建、不管理销毁

多例Bean仅执行实例化、初始化阶段，无缓存、无运行期托管、无销毁回调，生命周期不完整。

### 10.3 request/session/application 作用域生命周期特点

- request：单次HTTP请求生命周期，请求结束立即销毁

- session：用户会话周期，会话过期销毁

- application：与Web容器生命周期一致

### 10.4 单例依赖多例导致生命周期失效避坑

**经典坑点**：单例Service注入多例Bean，仅在Service初始化时注入一次，后续永远复用同一个多例对象，**多例彻底失效**。

**解决方案**：通过ApplicationContext动态获取多例Bean，保证每次获取新对象。

## 11. 本章高频面试题 & 易错点总结

### 11.1 基础问答：完整生命周期流程口述题

**满分答案**：Spring Bean生命周期分为解析注册、实例化、依赖注入、初始化、运行、销毁六个阶段。容器启动扫描生成BeanDefinition并注册，执行容器后置处理器修改Bean定义；通过构造器反射实例化Bean，完成依赖注入；执行Bean前置后置处理器，依次执行@PostConstruct、InitializingBean、init-method初始化，生成代理Bean；存入一级缓存对外服务；容器关闭触发@PreDestroy、DisposableBean、destroy-method完成资源释放。

### 11.2 优先级面试题：初始化/销毁四种方式先后顺序

**初始化优先级**：@PostConstruct > InitializingBean > init-method

**销毁优先级**：@PreDestroy > DisposableBean > destroy-method

### 11.3 扩展点面试：BeanFactoryPostProcessor 与 BeanPostProcessor 区别

1. 执行时机：前者Bean实例化前，后者Bean实例化后

2. 作用对象：前者操作Bean定义模板，后者操作Bean实例对象

3. 扩展层级：前者容器级全局扩展，后者Bean级局部增强

### 11.4 易错点：多例Bean销毁失效、构造器循环依赖、后置处理器执行顺序

1. 多例Bean无销毁回调，容器不管理

2. 构造器注入无半成品Bean，无法解决循环依赖

3. 多个后置处理器通过Ordered接口排序，数值越小优先级越高

### 11.5 结构化答题模板：生命周期类题目标准作答范式

所有生命周期题目统一三段式作答：**定义本质 → 完整流程 → 应用场景+边界条件**，保证答题完整、逻辑清晰、无遗漏。

## 本章总结

本章完整拆解了Spring Bean的**全生命周期底层原理**与**核心扩展机制**，是Spring从入门到进阶的关键分水岭。IoC容器是骨架，Bean生命周期是运行脉络，扩展点是Spring生态强大的核心支撑。

核心知识点复盘：

1. Bean完整生命周期分为11个标准步骤，核心分为实例化、注入、初始化、运行、销毁五大阶段。

2. 初始化、销毁存在固定优先级，业务开发优先使用JSR标准注解，简洁无侵入。

3. 两大核心扩展点：容器级后置处理器修改Bean定义，Bean级后置处理器实现Bean增强、AOP代理。

4. 作用域彻底决定生命周期托管状态，单例完整托管、多例仅创建不管理。

5. 循环依赖、线程安全、资源泄漏、多例失效是生产高频避坑点。

熟练掌握本章内容，可彻底吃透Spring底层运行机制，解决90%的Spring报错问题，同时完美应对所有生命周期、扩展点相关面试压轴题，为后续AOP、事务、SpringBoot自动配置学习打下坚实基础。