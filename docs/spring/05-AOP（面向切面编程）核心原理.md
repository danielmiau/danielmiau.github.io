# 05-AOP（面向切面编程）核心原理

## 本章概述

在前面章节我们吃透了Spring IoC容器、Bean生命周期、依赖注入（DI）核心原理，解决了**对象创建、依赖管理**的核心问题，而AOP（面向切面编程）是Spring框架仅次于IoC的第二大核心特性，也是Spring生态中**无侵入功能拓展的核心基石**。

日常开发中，事务控制、接口日志记录、权限校验、限流防重、耗时监控、动态数据源切换等通用功能，全部基于AOP实现。如果没有AOP，所有通用逻辑都需要硬编码嵌入业务代码，会导致代码极度冗余、业务与非业务逻辑耦合严重、维护成本极高。

本章将从**基础概念、专业术语、切点语法、五大通知、执行顺序、动态代理底层、失效坑点、实战落地、源码流程、面试真题**全方位拆解AOP核心知识。彻底解决开发者核心困惑：AOP为什么能实现无侵入增强？内部调用为什么失效？JDK和CGLIB代理区别？事务为什么会基于AOP失效？如何手写AOP实现通用业务功能？

读完本章，你将彻底掌握Spring AOP的落地用法与底层原理，能够独立手写企业级AOP通用组件，同时全覆盖AOP相关面试高频考点，彻底摆脱只会用、不懂原理的尴尬处境。

## 1. AOP 基础核心概念

### 1.1 什么是 AOP？底层思想与生活类比

**AOP（Aspect Oriented Programming，面向切面编程）**，是一种**面向方法增强**的编程思想，核心作用是：**在不修改原有业务代码的前提下，对方法进行前置、后置、异常、环绕增强**，实现通用逻辑的统一抽离与复用。

简单来说：AOP就是**把所有重复的、通用的、与核心业务无关的代码，从业务方法中抽离出来，统一管理、统一执行**，实现**业务逻辑与通用逻辑解耦**。

#### 生活化通俗类比

我们以「上班工作」为核心业务：

- 核心业务：敲代码、处理需求、对接业务（核心逻辑，必须自己完成）

- 通用重复操作：上班打卡、下班打卡、工作记录、异常报备、考勤统计（通用逻辑，重复且与核心业务无关）

传统编程方式：每次工作都手动完成打卡、记录，相当于业务代码中硬编码通用逻辑，冗余繁琐。

AOP编程思想：安排一个行政（切面），在上班前自动打卡、下班后自动记录、出错自动报备，**完全不用核心业务（本人）参与，不改变工作内容，自动增强通用能力**。

这就是AOP的核心：**无侵入增强、通用逻辑抽离、解耦复用**。

### 1.2 AOP 与 OOP 面向对象编程的区别与互补

很多开发者会混淆AOP和OOP，其实二者是**互补关系，而非替代关系**，OOP是纵向封装，AOP是横向切入，共同构建完整的Java编程体系。

#### 1. OOP 面向对象编程

核心思想：**纵向抽取、封装继承**，以类和对象为核心，通过封装、继承、多态实现代码复用，解决的是**业务模块纵向拆分**的问题。

局限性：无法解决**跨模块、跨类的横向通用逻辑复用**，比如所有Service的日志记录、所有接口的权限校验，OOP无法优雅统一处理。

#### 2. AOP 面向切面编程

核心思想：**横向切入、动态增强**，以方法切面为核心，横向拦截所有匹配的方法，统一植入通用逻辑，解决OOP的短板。

#### 3. 二者互补关系

- OOP负责：拆分业务模块、封装业务对象、实现业务逻辑复用

- AOP负责：统一增强所有模块的通用横向逻辑，无侵入拓展功能

**生产结论**：正常业务开发用OOP，通用功能增强用AOP，二者缺一不可。

### 1.3 AOP 解决的核心问题：代码冗余、侵入式硬编码

在没有AOP之前，所有通用逻辑只能硬编码在业务代码中，带来三大致命问题，也是AOP诞生的核心价值。

#### 1. 代码极度冗余

每个业务方法都需要写日志、判空、权限、异常捕获、耗时统计，大量重复代码充斥业务层，核心业务逻辑被淹没。

#### 2. 业务与非业务逻辑高度耦合

通用逻辑和核心业务写在同一个方法中，修改通用规则需要改动所有业务代码，牵一发而动全身。

#### 3. 维护成本极高、扩展性极差

新增通用功能需要全量修改业务代码，删除功能也需要逐行删除，极易引入Bug，无法统一管控。

#### AOP完美解决以上问题

- 通用逻辑只写一次，全局所有方法复用

- 完全不修改业务代码，无侵入增强

- 统一管控、统一修改、按需开启关闭，扩展性拉满

### 1.4 AOP 核心应用场景（日志、事务、权限、限流、监控）

AOP是企业级开发的**万能增强工具**，几乎所有非业务的通用横向功能，都基于AOP实现，核心生产场景如下：

**1. 统一日志处理**：接口入参、出参、操作日志、异常日志统一记录，无需每个接口手写日志代码

**2. 事务控制**：@Transactional注解底层基于AOP实现，方法前后开启、提交、回滚事务

**3. 权限校验**：拦截所有接口，统一校验用户权限、角色、登录状态

**4. 限流防重**：拦截接口请求，实现接口限流、防重复提交、幂等性校验

**5. 性能监控**：统计每个接口、每个方法的执行耗时，精准定位慢接口、慢方法

**6. 动态数据源切换**：基于切面注解，动态切换主从数据源、多数据源

**7. 缓存操作**：方法执行前查询缓存、执行后更新缓存，统一封装缓存逻辑

**8. 参数校验**：统一拦截方法参数，做通用参数校验、数据脱敏处理

### 1.5 Spring AOP 与 AspectJ 关系、区别与选型

新手极易混淆Spring AOP和AspectJ，这里做彻底区分，明确底层关系和生产选型。

#### 1. AspectJ 是什么？

AspectJ是**独立的、完整的AOP框架**，拥有专属的语法、编译器，支持编译期织入、类加载期织入、运行期织入，功能极其强大，是AOP的标准规范实现。

#### 2. Spring AOP 是什么？

Spring AOP是**Spring框架自带的轻量级AOP实现**，**基于AspectJ注解语法，但不依赖AspectJ编译器**，仅支持运行期动态代理织入，功能精简、适配Spring容器。

#### 3. 核心区别对比

|对比维度|Spring AOP|AspectJ|
|---|---|---|
|框架属性|Spring内置、轻量级|独立完整AOP框架、重量级|
|织入时机|仅运行期织入|编译期、类加载期、运行期全覆盖|
|实现原理|动态代理（JDK/CGLIB）|字节码修改技术|
|功能范围|仅支持方法级别拦截|支持方法、字段、构造器、代码块拦截|
|项目依赖|SpringBoot自动集成，无需额外引入|需要单独引入依赖、配置编译器|
#### 4. 生产选型结论

99%的Java业务项目，**直接使用Spring AOP即可**，完全满足业务方法增强需求；只有极致性能、精细化字节码增强场景，才需要引入原生AspectJ。

**核心常识**：我们日常写的@Before、@Around等注解，都是AspectJ的注解，Spring AOP复用了这套语法。

## 2. AOP 专业术语全解（面试必背）

AOP拥有六大核心专业术语，是面试必考基础，也是看懂AOP底层流程的前提，全部用大白话+实操场景讲解，无晦涩理论。

### 2.1 连接点 JoinPoint 概念与识别范围

**连接点（JoinPoint）**：Spring容器中**所有可以被AOP拦截、增强的点位**，统称为连接点。

通俗理解：**所有可被切面切入的“候选点位”**。

**Spring AOP支持的连接点范围**：**仅支持Bean的公共方法**。

⚠️ 重点限制：Spring AOP不支持私有方法、静态方法、final方法、构造器、字段的拦截，这些都不属于有效连接点。

一个项目中所有Service、Controller的公共方法，都是天然的连接点，等待被切面拦截。

### 2.2 切点 Pointcut 作用、表达式匹配规则

**切点（Pointcut）**：从所有连接点中，**筛选出需要真正拦截的方法**，是AOP的筛选规则。

通俗理解：连接点是所有候选人，切点是**筛选条件**，符合条件的方法才会被切面增强。

核心作用：通过切点表达式，精准定位需要拦截的包、类、方法、注解，实现**精准定向增强**，避免全局无效拦截。

示例：拦截所有com.service包下的所有方法，就是一条切点规则。

### 2.3 通知 Advice 五种类型详解

**通知（Advice）**：AOP拦截到目标方法后，**具体要执行的增强逻辑**，也就是切面的业务代码。

Spring AOP一共提供五种通知类型，覆盖所有增强场景：

1. **@Before 前置通知**：目标方法执行前执行

2. **@AfterReturning 返回通知**：目标方法正常执行成功后执行（异常不执行）

3.**@AfterThrowing 异常通知**：目标方法抛出异常时执行（正常成功不执行）

4. **@After 最终通知**：无论方法正常/异常，最后都会执行

5. **@Around 环绕通知**：万能通知，手动控制方法执行前后、异常、终止，权限最高

### 2.4 切面 Aspect 定义与组成结构

**切面（Aspect）**：**切点 + 通知的结合体**，是一个完整的AOP功能类。

通俗理解：切面就是一个**通用功能增强工具类**，包含「拦截规则（切点）」和「增强逻辑（通知）」。

切面结构必须满足两个条件：

1. 类上标注 **@Aspect** 注解，标识为切面类

2. 类中定义切点表达式 + 对应通知方法

简单结构示例：

```java
@Aspect // 标识当前类为切面类
@Component // 交给Spring管理
public class LogAspect {
    // 切点：拦截规则
    @Pointcut("execution(* com.service.*.*(..))")
    public void pointCut(){}

    // 通知：增强逻辑
    @Before("pointCut()")
    public void beforeLog(){
        System.out.println("方法执行前记录日志");
    }
}

```

### 2.5 目标对象 Target、代理对象 Proxy 区别

**目标对象（Target）**：被AOP拦截的**原始业务对象**，包含原生业务逻辑，无任何增强。

**代理对象（Proxy）**：Spring基于目标对象动态生成的**增强对象**，包含原生业务逻辑+切面增强逻辑。

**核心原理**：AOP不会修改目标对象源码，而是生成代理对象，通过代理对象调用方法，实现无侵入增强。

**关键结论**：我们业务中@Autowired注入的Bean，绝大多数被AOP增强的都是**代理对象**，而非原始目标对象。

### 2.6 织入 Weaving 时机与三种织入方式

**织入（Weaving）**：将切面增强逻辑，嵌入到目标方法的过程，叫做织入。

一共有三种织入时机，Spring AOP仅支持第三种：

1. **编译期织入**：编译代码时直接修改字节码，AspectJ专属，性能最高

2. **类加载期织入**：类加载阶段修改字节码，需要特殊类加载器

3. **运行期织入**：Spring AOP默认方式，容器启动后、方法调用时动态代理织入，灵活无侵入

**面试考点**：Spring AOP 只支持**运行期动态织入**。

## 3. AOP 切点表达式语法详解

切点表达式是AOP精准拦截的核心，语法灵活、功能强大，是开发实操和面试的重点，本节全覆盖常用语法、通配符、组合规则与避坑点。

### 3.1 execution 执行表达式语法格式与通配符

**execution**是Spring AOP最常用、最核心的切点表达式，用于精准匹配方法的执行规则。

#### 1. 标准语法格式

```java
execution(修饰符 返回值 包名.类名.方法名(参数列表))

```

#### 2. 三大通配符含义

- *****：匹配任意字符、任意单层内容（匹配单个层级）

- **..**：匹配任意多层路径、任意参数（匹配多层级、任意数量）

- **+**：匹配当前类及所有子类

#### 3. 常用实操示例

```java
// 拦截com.service包下所有类的所有方法
execution(* com.service.*.*(..))

// 拦截com.service及所有子包下所有方法
execution(* com.service..*.*(..))

// 拦截所有返回值为void的方法
execution(void *..*.*(..))

// 拦截指定类的所有方法
execution(* com.service.UserService.*(..))

```

### 3.2 within、this、target、args 常用表达式用法

#### 1. within：按包/类范围拦截

用于限定拦截的类范围，语法简洁，适合批量拦截指定包。

```java
// 拦截com.service包下所有类
within(com.service.*)

```

#### 2. target：匹配目标对象类型

匹配原始目标对象的类型，基于接口/父类拦截所有实现类。

#### 3. this：匹配代理对象类型

匹配生成后的代理对象类型，极少单独使用。

#### 4. args：匹配方法参数

根据方法参数类型、参数数量精准拦截。

### 3.3 @annotation 注解切点精准匹配自定义注解

**@annotation**是生产中最常用的精准拦截方式，通过自定义注解标记方法，仅拦截带指定注解的方法，精准度最高、无无效拦截。

#### 实操流程

1. 自定义业务注解 @LogRecord

2. 业务方法上标注该注解

3. 切面通过@annotation精准拦截

```java
// 切点：仅拦截带@LogRecord注解的方法
@Pointcut("@annotation(com.annotation.LogRecord)")

```

**最佳实践**：企业级AOP通用功能，优先使用注解切点，精准可控、性能最优。

### 3.4 切点表达式逻辑运算（&& || !）组合使用

多个切点规则可以通过逻辑运算组合，实现复杂拦截场景：

- **&**& 同时满足多个规则

- **||** 满足任意一个规则

- **!** 取反、排除指定规则

```java
// 拦截service包下所有方法，排除TestService类
@Pointcut("execution(* com.service..*.*(..)) && !within(com.service.TestService)")

```

### 3.5 公共切点抽取 @Pointcut 注解复用

为了避免切点表达式重复编写，通过**@Pointcut**注解抽取公共切点，统一复用、统一维护。

```java
@Aspect
@Component
public class LogAspect {
    // 抽取公共切点
    @Pointcut("execution(* com.service..*.*(..))")
    public void servicePointCut(){}

    // 直接复用切点
    @Before("servicePointCut()")
    public void beforeLog(){}
}

```

**最佳实践**：一个切面只定义一个公共切点，所有通知统一复用，便于后期统一修改拦截规则。

### 3.6 切点匹配常见坑与排查技巧

#### 1. 常见坑点

- 通配符层级写错：* 无法匹配子包，.. 才可以匹配多层路径

- 修饰符限制：execution默认只匹配public方法，非public方法无法拦截

- 包名书写错误、大小写不匹配导致切点失效

#### 2. 排查技巧

- 简化切点表达式，从大范围匹配逐步缩小范围

- 开启Spring AOP日志，查看切点匹配日志

- 优先使用注解切点替代包路径切点，减少匹配错误

## 4. AOP 五大通知类型实战

五大通知是AOP功能落地的核心，本节提供完整可运行代码、执行规则、场景适配，全覆盖实操细节。

### 4.1 @Before 前置通知：方法执行前介入

**执行时机**：目标方法**执行之前**执行

**适用场景**：参数校验、权限校验、请求日志记录、接口限流

**特点**：无法获取方法返回值，方法未执行，无结果数据

### 4.2 @AfterReturning 返回通知：正常执行后置处理

**执行时机**：目标方法**正常执行成功、无异常**后执行

**适用场景**：成功日志记录、结果封装、缓存更新、数据统计

**特点**：可获取方法返回值，**方法抛异常则不执行**

```java
// returning接收返回值
@AfterReturning(value = "servicePointCut()", returning = "result")
public void afterReturn(Object result){
    System.out.println("方法执行成功，返回值：" + result);
}

```

### 4.3 @AfterThrowing 异常通知：方法抛出异常拦截

**执行时机**：目标方法**抛出异常**时执行

**适用场景**：异常日志记录、异常告警、事务回滚辅助处理

**特点**：方法正常执行则不执行，可捕获异常信息

```java
@AfterThrowing(value = "servicePointCut()", throwing = "e")
public void afterThrow(Exception e){
    System.out.println("方法执行异常：" + e.getMessage());
}

```

### 4.4 @After 最终通知：无论正常/异常都会执行

**执行时机**：目标方法执行完毕（正常/异常）**最后执行**

**适用场景**：资源释放、链接关闭、统一后置收尾操作

**特点**：类似finally代码块，必然执行，无法获取返回值和异常详情

### 4.5 @Around 环绕通知：万能通知、手动控制执行流程

**环绕通知是AOP权限最高、功能最全的万能通知**，可以完全手动控制目标方法是否执行、何时执行、前后逻辑、异常捕获、返回值修改。

**执行时机**：包裹整个目标方法执行全过程

**适用场景**：耗时监控、全局异常捕获、动态修改返回值、限流防重、万能增强

```java
@Around("servicePointCut()")
public Object around(ProceedingJoinPoint joinPoint) throws Throwable {
    // 前置逻辑
    long start = System.currentTimeMillis();
    Object result = null;
    try {
        // 手动执行目标方法
        result = joinPoint.proceed();
    } catch (Exception e) {
        // 异常逻辑
        throw e;
    }
    // 后置逻辑
    long end = System.currentTimeMillis();
    System.out.println("方法执行耗时：" + (end - start));
    return result;
}

```

**核心注意**：环绕通知必须手动调用 `joinPoint.proceed()`，否则目标方法不会执行。

### 4.6 JoinPoint 获取方法签名、参数、目标类实战

除环绕通知外，其余四种通知可通过JoinPoint对象获取目标方法的所有信息，是AOP数据获取的核心对象。

```java
@Before("servicePointCut()")
public void before(JoinPoint joinPoint){
    // 获取目标类名
    String className = joinPoint.getSignature().getDeclaringTypeName();
    // 获取方法名
    String methodName = joinPoint.getSignature().getName();
    // 获取方法参数
    Object[] args = joinPoint.getArgs();
    System.out.println("类："+className+" 方法："+methodName+" 参数："+ Arrays.toString(args));
}

```

### 4.7 五大通知执行顺序、优先级规则

**正常无异常执行顺序**：@Around前置 → @Before → 目标方法 → @AfterReturning → @After → @Around后置

**异常执行顺序**：@Around前置 → @Before → 目标方法报错 → @AfterThrowing → @After → 环绕通知抛出异常

**面试必考**：环绕通知优先级最高，包裹所有普通通知。

## 5. AOP 切面优先级与执行顺序

### 5.1 多切面共存执行顺序规则

当多个切面同时拦截同一个目标方法时，Spring默认的执行规则：**切面优先级数字越小，优先级越高**。

高优先级切面：先进后出（外层切面）

低优先级切面：后进先出（内层切面）

### 5.2 @Order 注解设置切面优先级

通过 **@Order(int)** 注解指定切面优先级，数值越小优先级越高，默认优先级为int最大值。

```java
@Aspect
@Component
@Order(1) // 优先级最高
public class LogAspect {}

@Aspect
@Component
@Order(2) // 优先级次之
public class AuthAspect {}

```

### 5.3 同切面内不同通知执行先后流程

同一个切面类中，通知执行顺序固定：环绕前置 → 前置通知 → 方法执行 → 返回/异常通知 → 最终通知 → 环绕后置。

### 5.4 嵌套切面、多层代理执行链路拆解

多层切面嵌套执行链路类似栈结构：高优先级切面先进入、后结束，低优先级切面后进入、先结束，形成完整的代理调用链路，所有切面层层包裹目标方法。

## 6. Spring AOP 动态代理底层核心
AOP 底层**唯一核心**就是：**动态代理**。
Spring AOP 没有编译期修改字节码，也没有修改源码，全程靠**运行时动态生成代理对象**，用代理对象包裹目标对象，实现方法前置/后置/环绕增强。

这一章是 AOP **面试最重、底层最核心、源码最关键**的一章，我给你重新完整重写，大白话+原理+流程+代码+规则+面试点全部拉满。

### 6.1 动态代理两种实现：JDK 动态代理 vs CGLIB 代理
Spring AOP 只给开发者暴露一套切面、注解用法，但底层背地里有**两套动态代理实现**：
1. **JDK 动态代理**：**基于接口**实现
2. **CGLIB 动态代理**：**基于继承子类+字节码**实现

💡 核心前提：
Spring AOP 本身**不自己造代理逻辑**，只是封装了这两种原生代理，自动帮你选择、自动帮你创建代理对象。

| 对比维度            | JDK 动态代理        | CGLIB 动态代理                        |
| :------------------ | :------------------ | :------------------------------------ |
| 依赖来源            | JDK 原生自带        | 第三方字节码框架（SpringBoot 已内置） |
| 实现依据            | **接口**            | **类继承**                            |
| 有无侵入            | 无                  | 无                                    |
| 适用对象            | 实现了接口的类      | **没有接口**的普通类                  |
| 能否代理 final 类   | 可以（有接口就行）  | **不能**                              |
| 能否代理 final 方法 | 可以（接口非final） | **不能**                              |
| 代理生成方式        | 动态生成接口实现类  | ASM 字节码生成子类                    |

---

### 6.2 JDK 动态代理原理、使用限制（必须有接口）
#### 6.2.1 核心原理（大白话）
JDK 动态代理核心三要素：
- `Interface` 接口
- `InvocationHandler` 调用处理器（拦截逻辑）
- `Proxy` 工具类（自动生成代理类字节码）

执行流程：
1. 目标类 **必须实现若干接口**
2. JDK 动态代理**自动在内存中生成一个实现同样接口的代理类**
3. 代理类里所有接口方法，都会统一转给 `InvocationHandler.invoke()`
4. 我们在 invoke 方法里写：**前置逻辑 → 调用原方法 → 后置逻辑**
5. 外部调用时，**用代理对象代替原对象**，就实现了增强

#### 6.2.2 手写 JDK 动态代理 Demo（看懂就是真懂）
##### 1）业务接口
```java
public interface UserService {
    void addUser();
}
```

##### 2）目标实现类
```java
public class UserServiceImpl implements UserService {
    @Override
    public void addUser() {
        System.out.println("执行业务：新增用户");
    }
}
```

##### 3）自定义调用处理器（增强逻辑）
```java
import java.lang.reflect.InvocationHandler;
import java.lang.reflect.Method;

public class MyInvocationHandler implements InvocationHandler {

    // 被代理的目标对象
    private final Object target;

    public MyInvocationHandler(Object target) {
        this.target = target;
    }

    @Override
    public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
        // 前置增强 等价于 @Before
        System.out.println("JDK代理：方法执行前");

        // 执行原目标方法
        Object result = method.invoke(target, args);

        // 后置增强 等价于 @AfterReturning
        System.out.println("JDK代理：方法执行后");
        return result;
    }
}
```

##### 4）测试生成代理
```java
import java.lang.reflect.Proxy;

public class JdkProxyTest {
    public static void main(String[] args) {
        // 1. 原生目标对象
        UserService target = new UserServiceImpl();

        // 2. 生成代理对象
        UserService proxy = (UserService) Proxy.newProxyInstance(
                target.getClass().getClassLoader(),
                target.getClass().getInterfaces(),
                new MyInvocationHandler(target)
        );

        // 3. 调用代理方法
        proxy.addUser();
    }
}
```

运行你就能看到：**前后都被加了日志，业务代码完全没改**。

#### 6.2.3 硬性限制（面试必问）
1. **强制要求目标类必须实现接口**
   没有接口，JDK 动态代理直接用不了，因为它只能**基于接口生成代理**。
2. 只能对**接口里的公共方法**做代理
3. 私有方法、静态方法、普通类无接口，一概不支持。

#### 6.2.4 本质总结
JDK 动态代理：**只能代理接口，不能代理普通裸类**。

---

### 6.3 CGLIB 字节码代理原理、继承子类实现代理
#### 6.3.1 核心原理
CGLIB 全称 Code Generation Library，是**字节码生成框架**。

核心思想：
- 不要求接口
- 直接**在内存中动态生成目标类的子类**
- 子类**重写父类所有非final方法**
- 在重写的方法里植入：前置、后置、异常、环绕逻辑
- 用**子类代理对象**替代原对象，完成增强

#### 6.3.2 核心组件
- `Enhancer`：字节码增强器，用来创建代理类
- `MethodInterceptor`：方法拦截器，等同于 JDK 的 InvocationHandler
- 底层依赖 ASM 操作字节码，不用手写 class

#### 6.3.3 手写 CGLIB 代理 Demo
```java
import net.sf.cglib.proxy.Enhancer;
import net.sf.cglib.proxy.MethodInterceptor;
import net.sf.cglib.proxy.MethodProxy;
import java.lang.reflect.Method;

// 普通类，不需要任何接口
public class UserService {
    public void addUser() {
        System.out.println("执行业务：新增用户");
    }
}

// CGLIB 拦截器
class CglibInterceptor implements MethodInterceptor {
    @Override
    public Object intercept(Object obj, Method method, Object[] args, MethodProxy proxy) throws Throwable {
        System.out.println("CGLIB代理：方法前置");
        // 调用父类原方法
        Object result = proxy.invokeSuper(obj, args);
        System.out.println("CGLIB代理：方法后置");
        return result;
    }
}

// 测试
class CglibTest {
    public static void main(String[] args) {
        Enhancer enhancer = new Enhancer();
        // 设置父类
        enhancer.setSuperclass(UserService.class);
        // 设置拦截逻辑
        enhancer.setCallback(new CglibInterceptor());
        // 创建代理子类对象
        UserService proxy = (UserService) enhancer.create();
        proxy.addUser();
    }
}
```

#### 6.3.4 CGLIB 两大硬性限制（面试高频）
1. **不能代理被 final 修饰的类**
   原理是靠**继承子类**，final 类不能被继承，直接无法生成代理子类。
2. **不能代理被 final、private、static 修饰的方法**
   - final 方法不能被子类重写
   - private 子类不可见
   - static 属于类不属于实例，无法拦截

#### 6.3.5 本质总结
CGLIB 代理：**靠继承子类重写方法，有无接口都能代理**。

---

### 6.4 Spring 自动选择代理的规则（什么时候用JDK/什么时候用CGLIB）
#### 6.4.1 Spring 官方选择规则（Spring 5 / SpringBoot 2+）
1. **如果目标类实现了接口**
   默认优先使用 **JDK 动态代理**
2. **如果目标类没有实现任何接口**
   自动降级强制使用 **CGLIB 代理**
3. 可以手动强制全局统一使用 CGLIB：
```yaml
spring:
  aop:
    proxy-target-class: true
```
- `proxy-target-class=true`：强制全部用 CGLIB
- `proxy-target-class=false`：有接口用JDK，无接口用CGLIB

#### 6.4.2 面试标准答题版
- 目标类**实现接口** → 默认 JDK 动态代理
- 目标类**无接口** → 自动使用 CGLIB 代理
- 配置 `proxy-target-class=true` 强制全部使用 CGLIB

---

### 6.5 代理对象创建时机、初始化流程
#### 6.5.1 代理什么时候创建？
不是项目一启动就全生成，也不是调用方法才生成。

正确时机：
> **Bean 完成 实例化 → 依赖注入 → 初始化方法执行完毕 之后**
> 由 Bean 后置处理器，判断当前 Bean 是否需要 AOP 增强
> 需要增强 → 生成代理对象 → **用代理对象替换掉容器里原始的目标对象**

#### 6.5.2 完整生命周期流程
1. Spring 扫描 Bean，通过无参构造**实例化原始目标对象**
2. 执行属性填充、依赖注入
3. 执行 `@PostConstruct`、InitializingBean 初始化
4. 进入 **BeanPostProcessor 后置处理器** 回调
5. 遍历所有切面切点，匹配当前 Bean 的方法
6. 匹配成功 → 走 JDK/CGLIB 生成**代理对象**
7. **把代理对象放入 Spring 容器，覆盖原始对象**
8. 后续 `@Autowired` 注入拿到的**全是代理对象**

#### 6.5.3 关键底层结论
- 你 `@Autowired UserService userService`
  拿到的**不是原生对象，是代理对象**
- 只有代理对象调用方法，才会走 AOP 拦截
- **本类内部方法自己调自己，走的是原生对象，不走代理 → AOP 失效**

---

### 6.6 两种代理性能对比、生产选型建议
#### 6.6.1 性能对比
1. **启动阶段**
   - JDK 代理：简单、启动快
   - CGLIB 要生成字节码、创建子类：启动稍慢

2. **运行阶段**
   现代 JVM 经过 JIT 优化后，**两者运行性能几乎无差别**。

3. **内存开销**
   CGLIB 生成子类，会多一个类结构，内存略高，但业务项目完全感知不到。

#### 6.6.2 生产环境选型最佳实践
1. **不用手动干预**，让 Spring 自动适配即可
2. 规范业务层 **面向接口编程**，天然走 JDK 代理，更规范
3. 工具类、没有接口的业务类，交给 Spring 自动走 CGLIB
4. 不要随便强制开 `proxy-target-class=true`，违背默认规范

#### 6.6.3 面试总结版
- JDK 代理：基于接口、原生无依赖、适合面向接口业务开发
- CGLIB 代理：基于字节码继承、支持无接口类、受 final 限制
- Spring 自动根据有无接口切换代理，业务开发无需手动指定

---

## 7. AOP 经典失效场景与避坑指南

AOP失效是生产高频问题、面试必考重难点，本节全覆盖所有失效场景、底层原理和解决方案。

### 7.1 内部调用失效：本类方法互相调用 AOP 不生效原理

**失效场景**：同一个类中，A方法直接调用本类B方法，B方法的AOP增强失效。

**底层原理**：内部调用是**原始对象调用**，而非代理对象调用，AOP仅拦截代理对象的方法，原始对象调用无增强。

**解决方案**：

1. 手动从容器获取代理对象调用方法

2. 开启AOP上下文暴露代理对象

3. 拆分方法到不同类，避免内部调用

### 7.2 静态方法、final 方法无法被 AOP 代理原因

- **静态方法**：属于类而非对象，动态代理基于对象代理，无法拦截静态方法

- **final方法**：CGLIB通过重写方法增强，final方法不可重写，无法代理

### 7.3 私有方法 AOP 失效底层原理

Spring AOP仅支持**公共方法**拦截，私有方法权限私有，无法被代理类重写、无法被外部调用，切点无法匹配，直接失效。

### 7.4 多切面顺序混乱、通知不执行排查

常见原因：切面优先级未指定、切点范围重叠、通知执行异常终止链路、切面未交给Spring容器管理。

解决方案：统一配置@Order优先级、精准优化切点范围、捕获切面异常避免链路中断。

### 7.5 事务注解 @Transactional 基于 AOP 的常见失效场景

事务失效90%都是AOP失效导致：

1. 内部调用导致事务失效

2. 方法为私有、静态、final导致事务失效

3. 异常类型不匹配、未抛出指定异常导致事务不回滚

### 7.6 AOP 失效通用排查思路与解决方案

1. 检查切面是否添加@Aspect+@Component，交给Spring管理
2. 检查切点表达式是否精准匹配目标方法
3. 检查方法是否为public、非静态、非final
4. 检查是否存在本类内部调用
5. 检查切面优先级是否被覆盖

你说得对，第八章我之前写得太简略了，我现在按你的要求，把这 5 个实战案例补成**可直接运行、带注释、可落地**的完整章节，保证每个案例都有：
- 场景说明
- 核心原理
- 完整代码（注解 + 切面）
- 使用示例
- 避坑指南

---

## 8. AOP 高级拓展实战（完整版）

### 8.1 自定义注解 + AOP 实现日志统一记录
#### 场景说明
项目中每个接口/业务方法都要记录入参、出参、耗时、操作人、异常信息，手动写日志代码会非常冗余，用 AOP 实现无侵入日志记录，一次配置全局生效。

#### 实现步骤

##### 1. 自定义日志注解
```java
import java.lang.annotation.*;

@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
@Documented
public @interface LogRecord {
    // 操作模块，如：用户模块、订单模块
    String module() default "";
    // 操作描述，如：新增用户、修改订单
    String description() default "";
    // 是否记录返回值
    boolean recordResult() default true;
}
```

##### 2. 日志切面实现
```java
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.aspectj.lang.annotation.Pointcut;
import org.aspectj.lang.reflect.MethodSignature;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import java.lang.reflect.Method;
import java.util.Arrays;

@Aspect
@Component
public class LogRecordAspect {

    private static final Logger log = LoggerFactory.getLogger(LogRecordAspect.class);

    // 切点：所有带 @LogRecord 注解的方法
    @Pointcut("@annotation(com.example.annotation.LogRecord)")
    public void pointcut() {}

    @Around("pointcut()")
    public Object around(ProceedingJoinPoint joinPoint) throws Throwable {
        long start = System.currentTimeMillis();
        MethodSignature signature = (MethodSignature) joinPoint.getSignature();
        Method method = signature.getMethod();
        LogRecord logRecord = method.getAnnotation(LogRecord.class);

        // 记录请求信息
        log.info("[{}] 模块：{}，操作：{}，方法：{}，参数：{}",
                logRecord.module(),
                logRecord.description(),
                method.getName(),
                Arrays.toString(joinPoint.getArgs()));

        Object result = null;
        try {
            // 执行目标方法
            result = joinPoint.proceed();
            long cost = System.currentTimeMillis() - start;
            // 记录返回值
            if (logRecord.recordResult()) {
                log.info("[{}] 模块：{}，操作：{}，方法：{}，耗时：{}ms，返回值：{}",
                        logRecord.module(),
                        logRecord.description(),
                        method.getName(),
                        cost,
                        result);
            }
        } catch (Throwable e) {
            long cost = System.currentTimeMillis() - start;
            log.error("[{}] 模块：{}，操作：{}，方法：{}，耗时：{}ms，异常：{}",
                    logRecord.module(),
                    logRecord.description(),
                    method.getName(),
                    cost,
                    e.getMessage(), e);
            throw e;
        }
        return result;
    }
}
```

##### 3. 使用示例
```java
@Service
public class UserService {

    @LogRecord(module = "用户模块", description = "新增用户", recordResult = true)
    public User addUser(User user) {
        // 业务逻辑
        return user;
    }
}
```

#### 避坑指南
- 不要在切面中吞异常，否则业务异常会被掩盖。
- 日志中避免打印敏感信息（如密码、身份证号），可在切面中脱敏处理。

---

### 8.2 自定义注解 + AOP 实现接口权限校验
#### 场景说明
项目中很多接口需要校验用户角色、权限标识，每个接口写权限校验代码非常重复，用 AOP 实现统一权限拦截。

#### 实现步骤

##### 1. 自定义权限注解
```java
import java.lang.annotation.*;

@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
@Documented
public @interface RequirePermission {
    // 需要的权限标识，如 "user:add"
    String value();
    // 是否需要管理员角色
    boolean requireAdmin() default false;
}
```

##### 2. 权限切面实现
```java
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.aspectj.lang.annotation.Pointcut;
import org.aspectj.lang.reflect.MethodSignature;
import org.springframework.stereotype.Component;

import java.lang.reflect.Method;

@Aspect
@Component
public class PermissionAspect {

    // 模拟获取当前登录用户
    private UserInfo getCurrentUser() {
        // 实际项目中从 ThreadLocal / SecurityContext 获取
        return new UserInfo();
    }

    @Pointcut("@annotation(com.example.annotation.RequirePermission)")
    public void pointcut() {}

    @Around("pointcut()")
    public Object around(ProceedingJoinPoint joinPoint) throws Throwable {
        MethodSignature signature = (MethodSignature) joinPoint.getSignature();
        Method method = signature.getMethod();
        RequirePermission permission = method.getAnnotation(RequirePermission.class);

        UserInfo currentUser = getCurrentUser();
        // 校验管理员角色
        if (permission.requireAdmin() && !currentUser.isAdmin()) {
            throw new RuntimeException("无管理员权限");
        }
        // 校验权限标识
        if (!currentUser.getPermissions().contains(permission.value())) {
            throw new RuntimeException("无权限：" + permission.value());
        }
        // 权限校验通过，执行目标方法
        return joinPoint.proceed();
    }
}
```

##### 3. 使用示例
```java
@RestController
@RequestMapping("/user")
public class UserController {

    @PostMapping("/add")
    @RequirePermission(value = "user:add", requireAdmin = true)
    public Result addUser(@RequestBody User user) {
        // 业务逻辑
        return Result.success();
    }
}
```

#### 避坑指南
- 权限校验逻辑要提前抛出异常，不要在切面中吞掉异常。
- 注意权限缓存一致性，用户权限变更后要及时更新缓存。

---

### 8.3 自定义注解 + AOP 实现接口限流防重复提交
#### 场景说明
接口防重、限流是高频需求，用 AOP + Redis 实现无侵入的防重/限流控制，无需修改业务代码。

#### 实现步骤

##### 1. 自定义限流注解
```java
import java.lang.annotation.*;

@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
@Documented
public @interface RateLimit {
    // 限流key前缀
    String key() default "";
    // 时间窗口，单位秒
    int time() default 60;
    // 时间窗口内最大请求数
    int count() default 10;
    // 是否防重提交
    boolean preventRepeat() default false;
}
```

##### 2. 限流切面实现（基于 Redis）
```java
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.aspectj.lang.annotation.Pointcut;
import org.aspectj.lang.reflect.MethodSignature;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

import java.lang.reflect.Method;
import java.util.concurrent.TimeUnit;

@Aspect
@Component
public class RateLimitAspect {

    @Autowired
    private StringRedisTemplate redisTemplate;

    @Pointcut("@annotation(com.example.annotation.RateLimit)")
    public void pointcut() {}

    @Around("pointcut()")
    public Object around(ProceedingJoinPoint joinPoint) throws Throwable {
        MethodSignature signature = (MethodSignature) joinPoint.getSignature();
        Method method = signature.getMethod();
        RateLimit rateLimit = method.getAnnotation(RateLimit.class);

        // 构建限流key：key前缀 + 类名 + 方法名 + 用户标识
        String key = "rate_limit:" + rateLimit.key() + ":" + method.getDeclaringClass().getName() + ":" + method.getName();
        // 实际项目中可以加入用户ID，实现用户级限流
        String userId = "user123";
        key += ":" + userId;

        // 防重提交
        if (rateLimit.preventRepeat()) {
            if (redisTemplate.hasKey(key)) {
                throw new RuntimeException("请勿重复提交");
            }
            redisTemplate.opsForValue().set(key, "1", rateLimit.time(), TimeUnit.SECONDS);
        } else {
            // 计数器限流
            Long count = redisTemplate.opsForValue().increment(key, 1);
            if (count == 1) {
                redisTemplate.expire(key, rateLimit.time(), TimeUnit.SECONDS);
            }
            if (count > rateLimit.count()) {
                throw new RuntimeException("请求过于频繁，请稍后再试");
            }
        }
        return joinPoint.proceed();
    }
}
```

##### 3. 使用示例
```java
@RestController
@RequestMapping("/order")
public class OrderController {

    @PostMapping("/submit")
    @RateLimit(time = 60, count = 5, preventRepeat = true)
    public Result submitOrder(@RequestBody Order order) {
        // 业务逻辑
        return Result.success();
    }
}
```

#### 避坑指南
- Redis 计数器限流存在临界问题，高并发场景建议使用 `Lua` 脚本保证原子性。
- 防重提交的 key 要结合用户ID、请求参数一起生成，避免不同用户/请求被误拦截。

---

### 8.4 AOP 环绕通知实现接口耗时监控、异常统一捕获
#### 场景说明
全局监控所有接口的执行耗时，同时统一捕获异常、封装统一返回结果，减少每个接口重复写 try-catch。

#### 实现步骤

##### 1. 耗时监控切面
```java
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.aspectj.lang.annotation.Pointcut;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

@Aspect
@Component
public class ApiMonitorAspect {

    private static final Logger log = LoggerFactory.getLogger(ApiMonitorAspect.class);

    // 拦截所有 controller 层方法
    @Pointcut("execution(* com.example.controller..*.*(..))")
    public void pointcut() {}

    @Around("pointcut()")
    public Object around(ProceedingJoinPoint joinPoint) {
        long start = System.currentTimeMillis();
        Object result;
        try {
            result = joinPoint.proceed();
        } catch (Throwable e) {
            // 统一异常封装
            log.error("接口执行异常：{}", e.getMessage(), e);
            return Result.fail("系统异常，请稍后再试");
        } finally {
            long cost = System.currentTimeMillis() - start;
            log.info("接口：{} 执行耗时：{}ms",
                    joinPoint.getSignature().toShortString(), cost);
            // 可配置慢接口告警阈值，如超过 1000ms 打印 warn 日志
            if (cost > 1000) {
                log.warn("慢接口告警：{} 耗时 {}ms",
                        joinPoint.getSignature().toShortString(), cost);
            }
        }
        return result;
    }
}
```

##### 2. 使用示例
```java
@RestController
@RequestMapping("/user")
public class UserController {

    @GetMapping("/list")
    public Result listUser() {
        // 业务逻辑，无需写 try-catch，异常会被切面统一捕获
        return Result.success();
    }
}
```

#### 避坑指南
- 切面中捕获异常后，一定要打日志，否则异常栈会丢失，排查问题困难。
- 不要在切面中吞掉业务异常，要封装成统一的错误返回，同时记录日志。

---

### 8.5 基于 AOP 实现数据源动态切换
#### 场景说明
项目读写分离、多数据源场景，需要在不同方法中动态切换数据源，用 AOP + ThreadLocal 实现无侵入数据源切换。

#### 实现步骤

##### 1. 自定义数据源切换注解
```java
import java.lang.annotation.*;

@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
@Documented
public @interface DS {
    // 数据源名称，如 master、slave
    String value();
}
```

##### 2. 数据源上下文持有者
```java
public class DataSourceContextHolder {

    private static final ThreadLocal<String> CONTEXT_HOLDER = new ThreadLocal<>();

    public static void setDataSource(String dataSource) {
        CONTEXT_HOLDER.set(dataSource);
    }

    public static String getDataSource() {
        return CONTEXT_HOLDER.get();
    }

    public static void clear() {
        CONTEXT_HOLDER.remove();
    }
}
```

##### 3. 数据源切换切面
```java
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.aspectj.lang.annotation.Pointcut;
import org.aspectj.lang.reflect.MethodSignature;
import org.springframework.stereotype.Component;

import java.lang.reflect.Method;

@Aspect
@Component
public class DataSourceAspect {

    @Pointcut("@annotation(com.example.annotation.DS)")
    public void pointcut() {}

    @Around("pointcut()")
    public Object around(ProceedingJoinPoint joinPoint) throws Throwable {
        MethodSignature signature = (MethodSignature) joinPoint.getSignature();
        Method method = signature.getMethod();
        DS ds = method.getAnnotation(DS.class);
        try {
            // 设置数据源
            DataSourceContextHolder.setDataSource(ds.value());
            return joinPoint.proceed();
        } finally {
            // 清除数据源，避免污染
            DataSourceContextHolder.clear();
        }
    }
}
```

##### 4. 使用示例
```java
@Service
public class OrderService {

    // 主库写操作
    @DS("master")
    public void addOrder(Order order) {
        // 写操作，自动切换主库
    }

    // 从库读操作
    @DS("slave")
    public Order getOrder(Long id) {
        // 读操作，自动切换从库
    }
}
```

#### 避坑指南
- 数据源切换要在事务开启前执行，否则事务会固定在初始数据源，切换无效。
- ThreadLocal 一定要 `finally` 中清除，避免线程复用导致数据源污染。

---

## 9. AOP 底层源码核心流程
### 9.1 AOP 核心入口：AnnotationAwareAspectJAutoProxyCreator
#### 9.1.1 核心定位
**AnnotationAwareAspectJAutoProxyCreator** 是整个 Spring AOP 功能的**唯一启动入口、核心总控制器**。

它是 Spring 内置的 **Bean 后置处理器**，AOP 所有功能：切面扫描、切点匹配、代理创建、方法拦截，全部由这个类驱动。

#### 9.1.2 核心继承关系（面试必懂）
```
AnnotationAwareAspectJAutoProxyCreator
    ↓ 继承
AspectJAwareAdvisorAutoProxyCreator
    ↓ 继承
AbstractAdvisorAutoProxyCreator
    ↓ 继承
AbstractAutoProxyCreator
    ↓ 实现
BeanPostProcessor（Bean后置处理器）
```
核心意义：
- 实现了 `BeanPostProcessor` → **拥有在Bean初始化后修改Bean的能力**
- Spring AOP 不会修改源码、不会在编译期增强
- 完全依托 **Bean生命周期后置扩展点** 动态生成代理

#### 9.1.3 核心职责
1. 项目启动时**扫描所有 @Aspect 切面类**
2. 解析切面中的切点表达式、五大通知、排序规则
3. 遍历容器所有 Bean，进行切点匹配
4. 为需要增强的 Bean 创建动态代理对象（JDK / CGLIB）
5. **用代理对象覆盖原始Bean**，放入Spring容器

### 9.2 Bean 后置处理器：代理对象创建时机

#### 9.2.1 关键结论（100%面试考点）
**Spring AOP 代理对象，是在 Bean 初始化完成之后才创建的。**

完整执行时机：
1. 构造方法实例化（new 对象）
2. 属性填充（依赖注入）
3. 初始化方法执行（@PostConstruct、InitializingBean）
4. **后置处理器执行 → 生成代理对象**
5. 单例Bean放入一级缓存

#### 9.2.2 核心源码方法
`AbstractAutoProxyCreator#postProcessAfterInitialization()`
这是 **AOP 代理创建的真正入口**。

核心源码逻辑伪代码：
```java
@Override
public Object postProcessAfterInitialization(Object bean, String beanName) {
    // 判断当前Bean是否需要AOP代理
    if (isInfrastructureClass(bean.getClass()) || shouldSkip(bean.getClass(), beanName)) {
        return bean;
    }
    // 关键：如果需要增强，创建代理
    return wrapIfNecessary(bean, beanName);
}
```

#### 9.2.3 重要底层结论
1. **原始Bean一定存在**，代理是后生成的
2. 容器最终保存的是**代理Bean**，原始Bean被丢弃
3. 只有经过代理的对象调用方法，才会走AOP拦截
4. **本类内部调用 AOP 失效的根本原因：调用的是原始对象，不是代理对象**

### 9.3 解析切面、扫描切点、匹配目标 Bean 完整流程
整个流程分为 **启动阶段解析切面 + Bean阶段匹配切点** 两大步骤。

#### 9.3.1 第一步：容器启动，解析所有切面
1. Spring 启动扫描所有 Bean
2. 识别带有 `@Aspect` 注解的类，判定为切面类
3. 解析切面内部所有：
   - @Pointcut 切点规则
   - @Before、@After、@Around 等通知方法
4. 将「切点+通知」封装为 **Advisor（通知器）**
   - Advisor = 切点匹配规则 + 具体增强逻辑

#### 9.3.2 第二步：每个Bean初始化后，自动匹配切面
每创建完一个Bean，都会执行：
1. 获取容器中所有缓存好的 Advisor
2. 用切点表达式匹配当前Bean的**所有方法**
3. 只要**任意一个方法匹配成功** → 当前Bean需要被AOP增强

#### 9.3.3 第三步：判定是否需要创建代理
- 匹配成功 → 进入代理创建流程
- 匹配失败 → 保留原始Bean，无代理、无AOP增强

### 9.4 代理工厂 ProxyFactory 组装通知与切点
#### 9.4.1 ProxyFactory 核心作用
`ProxyFactory` 是 Spring AOP 的**代理工厂**，屏蔽 JDK/CGLIB 底层差异，统一封装代理参数、拦截器链。

#### 9.4.2 核心组装内容
ProxyFactory 会一次性组装所有必要信息：
1. 目标对象 target（原始Bean）
2. 目标Class类型
3. 所有匹配成功的 Advisor（拦截器链）
4. 切面执行顺序、@Order优先级
5. 代理模式配置（proxy-target-class）

#### 9.4.3 自动选择代理类型（底层源码规则）
```java
// 伪源码：Spring 选择代理的核心逻辑
if (有接口 && !强制CGLIB) {
    // JDK动态代理
    return new JdkDynamicAopProxy(factory);
} else {
    // CGLIB字节码代理
    return new CglibAopProxy(factory);
}
```

#### 9.4.4 最终生成代理对象
ProxyFactory 根据规则，生成：
- JDK 接口代理对象 或
- CGLIB 子类代理对象

### 9.5 调用链路：代理对象拦截 → 通知链执行 → 目标方法执行
这是 **方法运行时 AOP 的完整执行链路**，面试必考、工作底层原理。

#### 9.5.1 第一步：外部调用代理对象方法
我们 `@Autowired` 拿到的是**代理对象**
执行业务方法时，不会直接走原始方法，而是进入代理拦截逻辑。

#### 9.5.2 第二步：生成调用拦截器链
代理对象触发拦截器，Spring 根据当前方法匹配所有切面，**排序生成完整拦截器链**。
包含所有生效的：环绕、前置、后置、异常、最终通知。

#### 9.5.3 第三步：链式递归执行（责任链模式）
AOP 底层采用 **责任链递归调用**：
1. 先执行外层切面逻辑
2. 层层递进，最后执行目标方法
3. 方法执行完毕后，反向逐层执行后置逻辑

#### 9.5.4 完整标准执行链路
**正常无异常执行顺序**
1. 环绕通知前置 @Around
2. 前置通知 @Before
3. 执行目标业务方法
4. 返回通知 @AfterReturning
5. 最终通知 @After
6. 环绕通知后置 @Around

**异常执行顺序**
1. 环绕通知前置 @Around
2. 前置通知 @Before
3. 目标方法抛出异常
4. 异常通知 @AfterThrowing
5. 最终通知 @After
6. 环绕通知捕获异常结束

#### 9.5.5 最终返回结果
所有切面逻辑执行完毕，将结果返回给调用方，完成一次完整AOP增强调用。

### 9.6 本章源码核心总结（面试直接背诵）
1. AOP 核心入口是 **AnnotationAwareAspectJAutoProxyCreator**，是Bean后置处理器。
2. 代理创建时机：**Bean初始化完成之后**，不是启动时、不是调用时。
3. 启动阶段扫描解析切面为Advisor，Bean阶段匹配切点、判定是否需要代理。
4. ProxyFactory 统一组装拦截器链，自动选择 JDK / CGLIB 代理。
5. 方法调用走**责任链模式**，层层执行切面通知，最后执行目标方法。
6. AOP 所有失效问题，本质都是：**没走代理对象、没进拦截链、切点没匹配**。

---

## 10. 本章高频面试题 & 易错点总结

### 10.1 AOP 七大术语面试满分背诵版

**满分答案**：AOP核心七大术语包含连接点、切点、通知、切面、目标对象、代理对象、织入。连接点是所有可拦截点位，切点是筛选规则，通知是增强逻辑，切面是切点和通知的结合体，通过运行期动态织入，生成代理对象实现目标方法无侵入增强。

### 10.2 JDK 动态代理和 CGLIB 代理区别、使用场景

1. 实现方式：JDK基于接口代理，CGLIB基于继承子类字节码代理

2. 限制：JDK必须有接口，CGLIB不能代理final类/方法

3. 场景：有接口默认JDK代理，无接口强制CGLIB代理

### 10.3 AOP 五种通知执行顺序面试题

正常执行：环绕前置→前置通知→目标方法→返回通知→最终通知→环绕后置；异常执行：环绕前置→前置通知→方法报错→异常通知→最终通知。

### 10.4 AOP 内部调用失效原因及三种解决方案

原因：本类方法内部调用使用原始对象，未经过代理对象，AOP无法拦截。解决方案：拆分类、暴露代理对象、手动获取容器代理对象调用。

### 10.5 Spring AOP 和 AspectJ 区别面试常问

Spring AOP是轻量级运行期动态代理实现，仅支持方法拦截；AspectJ是完整AOP框架，支持多时机织入、全维度拦截，Spring AOP复用其注解语法。

### 10.6 AOP 结合事务失效场景经典问答

事务失效核心原因均为AOP失效，包含：内部调用、私有/静态/final方法、无代理对象、切点未匹配等，是生产最高频问题。

## 本章总结

本章全方位、体系化讲解了Spring AOP的所有核心知识点、底层原理、生产实战、失效坑点和面试考点，彻底打通AOP从基础使用到底层源码的全链路。

核心知识点复盘：

1. AOP是横向无侵入增强思想，与OOP纵向封装互补，彻底解决代码冗余、逻辑耦合问题，是Spring通用功能拓展的核心基石。

2. 七大核心术语是AOP的基础，切点精准匹配、五大通知覆盖所有增强场景，环绕通知是功能最全的万能通知。

3. Spring AOP底层基于动态代理实现，自动适配JDK/CGLIB两种代理模式，各有适用场景和限制条件。

4. AOP所有失效场景本质可统一归纳为：无代理对象调用、方法不支持代理、切点匹配失败三大类。

5. 企业级AOP可落地日志、权限、限流、监控、动态数据源等通用功能，极大提升项目规范性和开发效率。

6. AOP源码核心依托Bean后置处理器，容器启动完成代理创建，运行期完成动态织入增强。

熟练掌握本章内容，可独立开发企业级通用AOP组件，彻底解决生产AOP报错、事务失效、功能不生效等问题，全覆盖AOP面试高频考点，夯实Spring核心底层能力。