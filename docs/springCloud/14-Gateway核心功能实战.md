# 14-Gateway 核心功能实战

## 本章概述

本章为**Spring Cloud Gateway 核心组件实战落地章节**，承接第13章 Gateway 基础环境搭建内容，聚焦网关核心能力的实操落地，是搭建生产级微服务网关、实现流量统一管控的核心关键章节。本章核心目标是帮助开发者彻底掌握 Gateway 完整的路由配置体系、断言与过滤器核心机制，熟练实现静态路由、动态路由的配置与优化，掌握路由优先级、冲突处理、配置复用等进阶能力，同时能够独立排查路由转发常见问题，具备生产级网关路由的搭建与运维能力。本章内容属于微服务网关核心实操内容，后续将衔接网关过滤器实战、限流熔断、跨域处理等高级功能，是微服务流量治理体系的核心铺垫章节，同时覆盖大量面试高频考点，兼顾实操落地与面试通关双重需求。

---

# 1. Gateway 路由配置详解

路由是 Spring Cloud Gateway 的**核心核心能力**，网关所有的流量转发、过滤、拦截、重写等功能都基于路由规则实现。简单来说，Gateway 的核心工作逻辑为：客户端请求到达网关 → 匹配路由断言规则 → 执行路由过滤器处理请求 → 转发至目标服务 → 返回响应结果。路由配置主要分为静态路由和动态路由两大类，静态路由适用于固定接口、第三方服务代理场景，动态路由适配微服务集群自动发现场景，本章将从基础配置、底层原理、实操示例、最佳实践多维度全面讲解。

## 1.1 静态路由配置

静态路由指**手动固定配置路由规则**，路由的目标地址、匹配规则不会随服务注册中心状态变化而改变，配置后固定生效。静态路由是 Gateway 最基础的路由模式，配置简单、稳定性高，主要适用于第三方接口代理、固定地址服务转发、静态资源访问等场景。静态路由支持**YAML/Properties配置文件**和**Java代码**两种配置方式，两种方式各有优劣，可根据项目场景灵活选择。

### 1.1.1 配置文件方式静态路由（YAML/Properties）

配置文件方式是项目中最常用的静态路由配置方式，核心优势为**无需修改代码、无需重启服务（配合配置中心可动态刷新）、配置集中统一、便于运维管理**。官方推荐使用 YAML 格式配置，层级清晰、可读性更强。

#### 一、路由核心参数说明

Gateway 路由配置由四大核心参数组成，所有路由规则都基于这四个参数构建，是必须掌握的基础核心知识点：

- **id**：路由唯一标识，字符串格式，全局唯一。用于区分不同路由规则，无固定命名规范，建议遵循`服务名-功能-版本`命名格式，例如`user-service-route`。若未手动配置，网关会自动生成随机唯一ID，生产环境建议手动指定，便于问题排查。

- **uri**：路由转发的**目标地址**，支持两种协议：固定地址协议（http/https）、服务发现协议（lb）。静态路由一般使用 http/https 协议指定固定地址，动态路由使用 lb 协议从注册中心拉取服务列表。

- **predicates**：路由断言（匹配规则），是请求转发的前提条件。客户端请求必须**完全匹配所有断言规则**，才会触发当前路由转发。Gateway 内置十余种断言规则，支持路径、请求头、请求参数、请求时间、请求方法等多维度匹配。

- **filters**：路由过滤器，请求匹配成功后执行的预处理/后处理逻辑。可对请求头、请求参数、响应结果进行修改、拦截、重写、限流等操作，支持内置过滤器和自定义过滤器。

#### 二、YAML完整配置示例

以下为可直接复制运行的 YAML 静态路由配置，实现将网关 `/api/user/**` 请求转发至固定用户服务地址，附带详细注释：

```yaml
spring:
  cloud:
    gateway:
      # 静态路由配置列表，可配置多个路由规则
      routes:
        # 路由唯一ID，自定义命名
        - id: user-service-static-route
          # 静态路由目标地址：固定http地址
          uri: http://127.0.0.1:8081
          # 路由断言：请求路径匹配规则
          predicates:
            # 匹配所有以 /api/user/ 开头的请求路径
            - Path=/api/user/**
          # 路由过滤器：统一处理请求路径
          filters:
            # 路径重写：将 /api/user/xxx 重写为 /user/xxx，去除统一前缀
            - RewritePath=/api/user/(?<path>.*), /$\{path}

```

#### 三、Properties配置示例

适配传统 Properties 配置文件场景，等效路由配置如下：

```properties
# 路由唯一标识
spring.cloud.gateway.routes[0].id=user-service-static-route
# 固定转发地址
spring.cloud.gateway.routes[0].uri=http://127.0.0.1:8081
# 路径断言规则
spring.cloud.gateway.routes[0].predicates[0].name=Path
spring.cloud.gateway.routes[0].predicates[0].args[pattern]=/api/user/**
# 路径重写过滤器
spring.cloud.gateway.routes[0].filters[0].name=RewritePath
spring.cloud.gateway.routes[0].filters[0].args[regexp]=/api/user/(?<path>.*)
spring.cloud.gateway.routes[0].filters[0].args[replacement]=/${path}

```

#### 四、静态路由适用场景

- **第三方接口代理**：对接支付宝、微信、OSS 等外部第三方接口，服务地址固定，无需服务发现。

- **固定服务转发**：项目中独立部署、不注册到注册中心的固定服务、老旧单体服务。

- **静态资源访问**：转发图片、文档、静态页面等固定资源请求。

- **测试环境专用**：测试环境固定服务地址调试，避免动态服务发现带来的不稳定问题。

### 1.1.2 Java代码方式静态路由配置

除配置文件外，Gateway 支持通过**Java代码Bean注入**的方式定义静态路由，核心原理是创建`RouteLocator` 实例，手动组装路由ID、断言、过滤器、目标地址等规则。代码配置灵活性更高，支持动态编码逻辑、条件判断，适用于复杂定制化路由场景。

#### 一、核心配置代码实现

创建网关配置类，注入 RouteLocator Bean，实现代码级静态路由配置，完整可运行代码如下：

```java
import org.springframework.cloud.gateway.route.RouteLocator;
import org.springframework.cloud.gateway.route.builder.RouteLocatorBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Gateway代码方式静态路由配置类
 */
@Configuration
public class GatewayRouteConfig {

    /**
     * 构建路由定位器，定义代码级静态路由
     */
    @Bean
    public RouteLocator customStaticRoute(RouteLocatorBuilder builder) {
        return builder.routes()
                // 路由唯一ID
                .route("order-service-static-route", r -> r
                        // 路径断言：匹配/api/order/**所有请求
                        .path("/api/order/**")
                        // 静态转发固定服务地址
                        .uri("http://127.0.0.1:8082")
                        // 路径重写过滤器
                        .filters(f -> f.rewritePath("/api/order/(?<path>.*)", "/$\\{path}"))
                )
                // 可继续追加多个路由规则
                .build();
    }
}

```

#### 二、多路由配置的优先级管理

当代码中存在多个路由规则时，可通过 **order 属性** 设置路由优先级，优先级数值越小，路由匹配优先级越高。未手动设置时，默认优先级为0。

```java
@Bean
public RouteLocator customRouteLocator(RouteLocatorBuilder builder) {
    return builder.routes()
            // 优先级1：高优先级路由，精准匹配
            .route("pay-service-route", 1, r -> r.path("/api/pay/**").uri("http://127.0.0.1:8083"))
            // 优先级2：低优先级路由，模糊匹配
            .route("common-service-route", 2, r -> r.path("/api/common/**").uri("http://127.0.0.1:8084"))
            .build();
}

```

#### 三、代码配置与配置文件配置的对比

两种静态路由配置方式各有优劣，适配不同业务场景，核心对比总结如下：

|对比维度|配置文件方式（YAML/Properties）|Java代码方式|
|---|---|---|
|灵活性|低，仅支持固定配置，无逻辑判断|高，支持编码逻辑、条件判断、动态计算|
|可维护性|高，配置集中、无需改代码、运维友好|低，路由规则分散在代码中，修改需重启服务|
|动态刷新|支持（配合Nacos配置中心）|不支持，修改代码必须重启服务|
|适用场景|绝大多数固定路由、常规业务路由|复杂定制路由、带业务逻辑的路由规则|
|开发效率|高，配置简洁、快速落地|低，编码量大，需要手动编写Bean代码|
## 1.2 动态路由配置

动态路由是 Spring Cloud Gateway 适配**微服务架构**的核心能力，区别于静态路由固定地址转发，动态路由基于服务注册中心实现，无需手动配置每个服务的转发地址。网关会自动从 Nacos/Eureka/Consul 等注册中心拉取服务列表，根据服务名自动完成路由转发，支持服务上下线自动感知、负载均衡自动切换，是生产环境微服务网关的主流配置方式。

### 1.2.1 基于服务发现的动态路由（lb://协议）

动态路由的核心是 **lb:// 协议**，lb 是 load balance（负载均衡）的缩写。网关通过该协议识别动态路由，从服务注册中心获取对应服务的集群节点列表，结合内置负载均衡算法实现请求分发。

#### 一、动态路由前置依赖配置

使用动态路由必须引入服务发现依赖，确保网关服务能注册到注册中心、拉取服务列表。以 Nacos 服务发现为例，Maven 依赖配置如下：

```xml
<!-- Nacos服务发现依赖 -->
<dependency>
    <groupId>com.alibaba.cloud</groupId>
    <artifactId>spring-cloud-starter-alibaba-nacos-discovery</artifactId>
</dependency>
<!-- Gateway网关核心依赖 -->
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-gateway</artifactId>
</dependency>

```

#### 二、服务发现开启配置

启动类添加服务发现注解，配置文件配置注册中心地址，开启动态路由能力：

1、启动类注解配置

```java
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.client.discovery.EnableDiscoveryClient;

@SpringBootApplication
// 开启服务发现，支持拉取注册中心服务列表
@EnableDiscoveryClient
public class GatewayApplication {
    public static void main(String[] args) {
        SpringApplication.run(GatewayApplication.class, args);
    }
}

```

2、YAML核心配置

```yaml
spring:
  # Nacos注册中心配置
  cloud:
    nacos:
      discovery:
        server-addr: 127.0.0.1:8848 # Nacos地址
    gateway:
      # 开启服务发现动态路由（核心配置）
      discovery:
        locator:
          enabled: true # 开启基于服务名的自动路由映射
          lower-case-service-id: true # 开启服务名小写匹配

```

#### 三、动态路由手动配置示例

除自动映射外，可手动配置动态路由规则，精准控制单个服务的路由匹配逻辑，lb://后直接填写**注册中心的服务名**：

```yaml
spring:
  cloud:
    gateway:
      routes:
        # 用户服务动态路由
        - id: user-service-dynamic-route
          # lb:// + 注册中心服务名，自动负载均衡转发
          uri: lb://user-service
          predicates:
            - Path=/api/user/**
          filters:
            - RewritePath=/api/user/(?<path>.*), /$\{path}
        # 订单服务动态路由
        - id: order-service-dynamic-route
          uri: lb://order-service
          predicates:
            - Path=/api/order/**
          filters:
            - RewritePath=/api/order/(?<path>.*), /$\{path}
```

#### 四、动态路由负载均衡支持

Gateway 内置集成 Spring Cloud LoadBalancer 负载均衡组件，基于 lb:// 协议的动态路由**默认开启负载均衡**，无需额外配置。默认采用**轮询策略**分发请求，同时支持自定义负载均衡策略（随机、加权、一致性哈希等），适配服务集群多节点部署场景，有效解决单点故障、提升服务并发能力。

### 1.2.2 动态路由的实现原理

理解动态路由底层原理，是解决生产环境路由异常、优化网关性能的核心，本节拆解动态路由的完整工作机制。

#### 一、服务列表拉取与路由更新机制

网关启动后会执行以下核心流程，完成动态路由初始化与实时更新：

1. **启动初始化**：网关服务启动时，通过服务发现客户端（Nacos Discovery）向注册中心发起请求，拉取所有已注册的服务名、节点IP、端口信息，缓存到网关本地内存中。

2. **路由规则生成**：根据开启的自动路由映射配置，自动生成「服务名-请求路径」的路由规则，绑定 lb:// 转发协议。

3. **实时监听更新**：网关与注册中心建立长连接，实时监听服务状态变更事件（服务上线、下线、节点变更）。

4. **动态刷新路由**：当注册中心服务列表发生变化时，网关自动更新本地缓存的服务节点列表，刷新路由转发映射，无需重启服务。

#### 二、服务上下线对动态路由的影响

- **服务上线**：新服务节点注册到注册中心后，网关实时感知，自动将新节点加入负载均衡节点列表，后续请求自动分发至新节点，实现服务扩容无感生效。

- **服务下线**：服务主动下线或心跳超时被注册中心剔除后，网关立即移除失效节点，不再向故障节点转发请求，**自动实现故障隔离**，避免请求报错。

- **集群节点变更**：服务集群节点数量增减、IP端口变更时，网关实时同步，路由转发规则自动适配，无需人工干预。

#### 三、动态路由的性能与稳定性优化

- **本地缓存优化**：网关将服务列表、路由规则缓存至本地内存，避免每次请求都请求注册中心，大幅提升路由匹配性能。

- **心跳机制优化**：调整服务心跳检测频率，减少无效监听事件，降低网关与注册中心的网络交互压力。

- **路由懒加载**：开启路由懒加载配置，仅在请求首次匹配对应服务时初始化路由规则，减少网关启动耗时。

- **故障重试机制**：配置负载均衡重试策略，节点转发失败时自动重试其他节点，提升请求稳定性。

## 1.3 路由配置进阶与最佳实践

基础路由配置可满足简单业务场景，生产环境中多路由并存、规则复杂、流量量大，需要掌握路由优先级、冲突处理、配置复用、问题排查等进阶能力，保障网关路由高效、稳定、可维护运行。

### 1.3.1 路由优先级配置（order属性）

Gateway 支持通过 **order 属性** 手动指定路由优先级，用于控制多路由规则的匹配顺序。核心规则：**order 数值越小，优先级越高，越先被匹配**；未手动配置 order 时，默认值为0。

优先级核心使用场景：精准路由与模糊路由共存时，精准路由设置更高优先级（更小数值），避免被模糊路由拦截。

YAML优先级配置示例：

```yaml
spring:
  cloud:
    gateway:
      routes:
        # 精准路由：高优先级（order=-1），优先匹配支付接口
        - id: pay-service-route
          order: -1
          uri: lb://pay-service
          predicates:
            - Path=/api/pay/notify/**
        # 模糊路由：低优先级（order=0），匹配所有支付相关接口
        - id: pay-common-route
          order: 0
          uri: lb://pay-service
          predicates:
            - Path=/api/pay/**

```

### 1.3.2 多路由规则的匹配顺序与冲突处理

#### 一、默认匹配顺序

网关路由匹配遵循两大核心规则：1、优先匹配 **order 优先级高** 的路由；2、优先级相同时，按照**配置文件从上到下的顺序**依次匹配；3、请求一旦匹配成功一个路由，不再匹配后续路由。

#### 二、常见路由冲突场景与解决方案

- **场景1：路径规则重叠**：路由A匹配 `/api/**`，路由B匹配 `/api/user/**`，模糊规则优先匹配，导致精准规则失效。
        

**解决方案**：给精准路径路由设置更小的order值，提升优先级，优先匹配精准规则。
      

- **场景2：相同路径多规则**：同一请求路径匹配多个路由的断言规则，导致路由匹配混乱。
        

**解决方案**：细化断言规则，增加请求头、请求方法、请求参数等多维度匹配，区分不同路由场景。
      

- **场景3：自动路由与手动路由冲突**：开启服务自动路由后，手动配置的路由失效。
        

**解决方案**：手动路由优先级高于自动路由，无需特殊配置，自动路由仅作为兜底规则。
      

### 1.3.3 路由配置的解耦与复用（配置文件模块化）

生产环境服务数量多，所有路由配置写在同一个 YAML 文件中会导致配置臃肿、难以维护。Gateway 支持**配置文件模块化拆分**，将不同业务模块的路由拆分到独立配置文件，实现配置解耦、复用。

#### 一、模块化拆分方案

在资源目录下新建`routes` 文件夹，创建不同业务路由配置文件：`user-route.yml`、`order-route.yml`、`pay-route.yml`。

以 user-route.yml 为例：

```yaml
# 用户服务独立路由配置
spring:
  cloud:
    gateway:
      routes:
        - id: user-service-route
          order: 0
          uri: lb://user-service
          predicates:
            - Path=/api/user/**
          filters:
            - RewritePath=/api/user/(?<path>.*), /$\{path}

```

#### 二、主配置文件引入子配置

在主 application.yml 中通过 `spring.profiles.include` 引入所有模块化路由配置：

```yaml
spring:
  profiles:
    # 引入所有拆分的路由配置文件
    include: routes/user-route,routes/order-route,routes/pay-route

```

#### 三、通用过滤器复用

对于所有路由通用的过滤器（跨域、请求日志、参数过滤），可配置**全局默认过滤器**，无需每个路由重复配置：

```yaml
spring:
  cloud:
    gateway:
      # 全局过滤器，所有路由生效
      default-filters:
        # 统一添加响应头
        - AddResponseHeader=X-Gateway-Source, SpringCloud-Gateway
        # 统一请求日志打印
        - RequestLog

```

### 1.3.4 路由配置常见问题排查（路由不匹配、转发失败）

汇总生产环境路由配置高频报错问题、排查思路与解决方案，是实战落地必备避坑要点。

#### 一、路由不匹配（404 找不到路由）

- **问题现象**：请求网关地址返回404，提示无匹配路由规则。

- **常见原因**：路径断言规则配置错误、order优先级过低被拦截、请求路径大小写不匹配、未开启服务自动路由。

- **排查方案**：开启网关调试日志，查看路由匹配日志；核对断言路径正则；开启小写服务名匹配配置；调整路由优先级。

#### 二、路由转发失败（503 服务不可用）

- **问题现象**：路由匹配成功，但是转发目标服务失败，返回503。

- **常见原因**：服务未注册到注册中心、服务节点下线、lb服务名配置错误、网络端口不通。

- **排查方案**：登录Nacos查看服务注册状态；核对路由uri中的服务名；测试网关与目标服务网络连通性；查看服务启动日志是否正常。

#### 三、路径重写失效问题

- **问题现象**：请求路径带前缀，后端服务接收路径错误，接口报错。

- **常见原因**：重写正则表达式错误、过滤器配置顺序错误、重写规则与断言路径不匹配。

- **排查方案**：校验正则表达式合法性；确保路径重写过滤器优先执行；对齐断言路径与重写规则。

#### 四、多路由冲突导致请求异常

- **问题现象**：本应匹配精准路由的请求，被模糊路由拦截，导致转发服务错误。

- **解决方案**：严格通过order属性区分优先级，精准路由优先，模糊路由兜底；细化各路由断言规则，避免路径重叠。

---

# 2. Predicate 断言详解与实战

Spring Cloud Gateway 中的 Predicate（断言）来自 Java8 函数式接口，本质是一个**返回布尔值的匹配规则**。网关的核心执行逻辑为：客户端请求到达网关后，遍历所有路由规则，依次执行路由下配置的所有断言，**全部断言匹配通过**才会命中当前路由，执行后续过滤器与转发逻辑。若无任何路由断言匹配请求，网关直接返回 404 未找到资源。断言是实现精准路由、流量细分、接口权限控制的核心能力，生产环境几乎所有复杂网关策略都依赖断言实现。

## 2.1 断言的核心作用与匹配规则

### 2.1.1 断言的定义：请求匹配条件

**断言（RoutePredicate）**是 Gateway 为路由设置的**请求准入匹配条件**，是路由规则的核心组成部分。简单来说，断言就是一套筛选规则，用于告诉网关：**只有满足所有预设条件的请求，才允许使用当前路由规则进行转发**。

脱离断言的路由没有实际意义，默认的路由匹配全部依赖断言规则实现。断言可以从请求的**路径、请求方法、请求头、Cookie、请求参数、主机地址、请求时间**等全维度对请求进行筛选，实现精细化的流量匹配。

核心价值：

- 实现**一个服务多路由、不同请求走不同策略**；

- 精准拦截非法请求、异常请求，提前过滤无效流量；

- 为灰度发布、限流分级、接口白名单提供匹配依据；

- 解决多路由规则重叠、冲突问题，精准区分流量。

### 2.1.2 断言的匹配逻辑（AND/OR组合）

Gateway 断言拥有固定的组合匹配逻辑，是面试与生产排错的核心知识点，必须牢记：

#### 1、同路由下多断言：默认**AND 与逻辑**

同一个路由规则中，配置多个不同类型的断言时，必须**所有断言全部匹配成功**，请求才能命中该路由，任意一个断言匹配失败则整体匹配失败。

示例：路由同时配置 Path 路径断言 + Method 请求方法断言，请求必须路径匹配 **且** 请求方法匹配，才能转发成功。

#### 2、不同路由间规则：默认 **OR 或逻辑**

多个独立路由规则之间为或逻辑，请求只要命中其中任意一个路由的全部断言规则，即可完成转发。同时网关会根据路由优先级（order）优先匹配高优先级路由，匹配成功后不再遍历后续路由。

#### 3、同一类型多断言（同路由）：特殊或逻辑

同一个路由下配置多个**同类型断言**（多个Path、多个Method），网关会自动采用 OR 逻辑，满足任意一个即可匹配成功。

### 2.1.3 内置断言的工作流程

Gateway 内置断言的完整执行流程为标准化流水线，所有内置断言均遵循该机制，底层基于 WebFlux 异步响应式执行：

1. **请求接入**：客户端 HTTP/HTTPS 请求抵达网关 Netty 服务端口；

2. **路由初始化**：网关加载本地所有路由规则（静态+动态），按 order 优先级排序；

3. **遍历路由规则**：从最高优先级路由开始，依次获取当前路由的所有断言规则；

4. **逐断言校验**：按照配置顺序，逐一执行断言匹配逻辑，校验请求参数；

5. **结果判定**：同路由所有断言全部匹配通过 → 命中当前路由；任意失败 → 跳过当前路由，匹配下一个；

6. **后续执行**：路由匹配成功后，进入过滤器链路，最终转发至目标服务；无任何路由匹配则返回 404。

**核心特性**：断言执行在过滤器之前，属于**请求前置筛选**，匹配失败不会执行任何过滤器逻辑，性能损耗极低，适合做流量前置过滤。

## 2.2 常用内置断言详解

Spring Cloud Gateway 官方内置了**十余种高频断言**，覆盖 95% 以上生产场景，无需自定义开发即可满足绝大多数路由匹配需求。本节针对企业开发最常用的7类断言，提供完整原理说明、配置示例、匹配规则、适用场景与避坑点，所有代码可直接复制运行。

### 2.2.1 Path 断言：请求路径匹配

**Path 断言是最核心、使用频率最高的断言**，用于匹配客户端的请求 URL 路径，是所有路由的必备断言。支持精确匹配、通配符匹配、路径变量匹配三种模式。

#### 1、精确匹配与通配符匹配

通配符规则：`/**` 匹配任意多级路径，`/*` 匹配单级路径。

```yaml
spring:
  cloud:
    gateway:
      routes:
        - id: path-route-demo
          uri: lb://user-service
          predicates:
            # 匹配所有 /user/ 开头的任意路径
            - Path=/user/**

```

匹配规则说明：

- 匹配成功：/user/list、/user/info/1001、/user/address/list

- 匹配失败：/order/list、/user（无后缀路径不匹配）

#### 2、路径变量匹配

支持通过 `{变量名}` 定义路径占位符，可精准匹配带参数的 RESTful 风格接口路径。

```yaml
predicates:
  # 匹配 /user/数字ID 格式路径，id为路径变量
  - Path=/user/{id}

```

匹配成功：/user/1001、/user/2002；可在后续过滤器中获取 id 参数做业务处理。

#### 避坑指南

Path 断言匹配**不区分请求参数**，仅匹配 URL 路径部分，? 后的 query 参数不参与匹配。

### 2.2.2 Method 断言：请求方法匹配（GET/POST/PUT/DELETE）

Method 断言用于**限制路由仅匹配指定 HTTP 请求方法**，可实现不同请求方法的接口路由隔离，适配 RESTful 接口规范。

```yaml
spring:
  cloud:
    gateway:
      routes:
        - id: method-route-demo
          uri: lb://user-service
          predicates:
            - Path=/user/**
            # 仅匹配 GET、POST 请求
            - Method=GET,POST

```

核心规则：

- 支持同时配置多个请求方法，逗号分隔；

- 严格大小写匹配，必须大写（GET/POST/PUT/DELETE）；

- 生产场景常用于区分查询接口（GET）与提交接口（POST）的流量策略。

### 2.2.3 Header 断言：请求头匹配（如Token、User-Agent）

Header 断言用于匹配客户端请求头中的参数，常用于**身份校验、客户端类型区分、灰度流量控制**，是生产环境权限拦截的核心断言。

语法格式：`Header=请求头key, 正则匹配规则`

```yaml
predicates:
  - Path=/api/**
  # 匹配携带 Token 请求头，且 Token 值为非空字符串
  - Header=Token, .+
  # 匹配移动端客户端（User-Agent包含Mobile字段）
  - Header=User-Agent, .*Mobile.*

```

场景价值：可实现无权限 Token 的请求直接在网关层拦截，无需转发至业务服务，减少业务服务压力。

### 2.2.4 Query 断言：请求参数匹配

Query 断言用于匹配 URL 中的**请求参数（Query参数）**，支持匹配参数存在、参数值正则匹配两种模式，适用于根据请求参数细分流量场景。

```yaml
predicates:
  - Path=/api/order/**
  # 匹配存在 status 参数的请求
  - Query=status
  # 匹配 type 参数值为 1/2 的请求
  - Query=type, [12]

```

匹配说明：

- 单参数名：仅判断参数是否存在，不校验参数值；

- 参数名+正则：校验参数值是否符合正则规则；

- 仅匹配 URL 拼接的 query 参数，不匹配 POST 请求体参数。

### 2.2.5 Cookie 断言：Cookie值匹配

Cookie 断言用于匹配客户端携带的 Cookie 信息，语法与 Header 断言一致，支持正则匹配，常用于用户会话识别、灰度用户筛选场景。

```yaml
predicates:
  - Path=/api/**
  # 匹配存在 userId Cookie，且值为数字的请求
  - Cookie=userId, \d+

```

### 2.2.6 Host 断言：请求主机名匹配

Host 断言用于匹配请求的域名/主机地址，可实现**多域名路由分流**，同一网关绑定多个域名时，根据域名分发不同服务流量。

```yaml
predicates:
  # 匹配所有以 xxx.com 结尾的域名请求
  - Host=**.xxx.com

```

生产场景：前台域名、后台管理域名、移动端域名分流至不同服务集群。

### 2.2.7 After/Before/Between 断言：时间范围匹配

时间类断言用于限制路由的**生效时间范围**，适用于限时活动、定时接口开放、流量定时管控场景。时间必须使用 **UTC 标准时间格式**。

```yaml
predicates:
  # 仅匹配 2026-01-01 之后的请求
  - After=2026-01-01T00:00:00+08:00[Asia/Shanghai]
  # 仅匹配指定时间段内的请求
  - Between=2026-01-01T00:00:00+08:00[Asia/Shanghai],2026-12-31T23:59:59+08:00[Asia/Shanghai]

```

避坑：时间必须携带时区参数，否则会出现时间匹配偏差，导致路由失效。

## 2.3 断言组合与自定义断言

内置断言可满足基础场景，生产复杂场景需要**多断言组合精准匹配**，或通过自定义断言实现个性化流量筛选。本节讲解组合断言实战、自定义断言完整开发流程、注册方式、验证方案与生产最佳实践。

### 2.3.1 多断言组合使用（Path+Method+Header）

多断言组合是生产环境最常用的配置方式，通过 **AND 与逻辑** 实现多维度精准限流、权限拦截、流量筛选。

#### 实战场景

实现：仅允许 `/api/user/save` 路径、POST 请求、携带合法 Token 请求头的流量访问用户保存接口。

```yaml
spring:
  cloud:
    gateway:
      routes:
        - id: user-save-route
          uri: lb://user-service
          predicates:
            # 维度1：路径匹配
            - Path=/api/user/save
            # 维度2：请求方法匹配
            - Method=POST
            # 维度3：必须携带Token请求头
            - Header=Token, .+

```

匹配逻辑：三个条件**同时满足**才会命中路由，任意条件缺失直接拦截，大幅提升接口安全性。

### 2.3.2 自定义断言开发（实现PredicateSpec接口）

当内置断言无法满足业务需求（如自定义签名校验、设备类型精准筛选、白名单IP匹配）时，需要开发自定义断言。Gateway 提供标准化扩展接口 **RoutePredicateFactory**，本节提供可直接落地的完整开发流程。

#### 开发场景

自定义断言：实现仅允许携带指定`App-Type` 请求头（app/android/ios）的请求通过，拦截非法客户端请求。

#### 第一步：自定义断言工厂类

```java
import org.springframework.cloud.gateway.handler.predicate.AbstractRoutePredicateFactory;
import org.springframework.cloud.gateway.handler.predicate.RoutePredicateFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ServerWebExchange;
import java.util.Arrays;
import java.util.List;
import java.util.function.Predicate;

/**
 * 自定义App类型断言工厂
 * 规范：类名必须以 RoutePredicateFactory 结尾
 */
@Component
public class AppTypeRoutePredicateFactory extends AbstractRoutePredicateFactory<AppTypeRoutePredicateFactory.Config> {

    // 构造器绑定配置参数
    public AppTypeRoutePredicateFactory() {
        super(Config.class);
    }

    // 读取配置文件参数顺序
    @Override
    public List<String> shortcutFieldOrder() {
        return Arrays.asList("appType");
    }

    // 核心匹配逻辑
    @Override
    public Predicate<ServerWebExchange> apply(Config config) {
        return exchange -> {
            // 获取请求头中的App-Type
            String appType = exchange.getRequest().getHeaders().getFirst("App-Type");
            // 匹配配置文件中允许的客户端类型
            return config.getAppType().equals(appType);
        };
    }

    // 配置参数实体
    public static class Config {
        private String appType;

        public String getAppType() {
            return appType;
        }

        public void setAppType(String appType) {
            this.appType = appType;
        }
    }
}

```

#### 核心开发规范（面试高频）

- 自定义断言类必须继承 **AbstractRoutePredicateFactory**；

- 类名固定后缀 **RoutePredicateFactory**，前缀为断言名称；

- 通过 shortcutFieldOrder 绑定配置参数，实现yaml简洁配置；

- apply 方法为核心匹配逻辑，返回布尔值。

### 2.3.3 自定义断言的注册与生效验证

#### 1、配置文件使用自定义断言

断言名称为类名前缀 `AppType`，直接在路由中配置使用：

```yaml
spring:
  cloud:
    gateway:
      routes:
        - id: custom-predicate-route
          uri: lb://user-service
          predicates:
            - Path=/api/app/**
            # 自定义断言：仅允许android客户端
            - AppType=android

```

#### 2、生效验证方案

- 携带请求头 `App-Type: android`：请求匹配成功，正常转发；

- 无请求头/值为ios/app：断言匹配失败，返回404；

- 开启网关 debug 日志，可查看断言匹配详细日志，快速排查生效问题。

### 2.3.4 断言配置的最佳实践与性能影响

#### 一、生产最佳实践

1. **优先使用路径断言前置过滤**：Path 断言匹配效率最高，所有路由必须配置 Path 断言，优先过滤无效路径流量；

2. **多断言精简配置**：避免单路由配置过多断言（建议不超过3个），过多断言会增加匹配耗时；

3. **精准路由优先，模糊路由兜底**：高精准、高优先级的断言路由配置更小的order值，优先匹配；

4. **时间断言规避时区问题**：所有时间断言必须指定时区，统一使用上海时区；

5. **自定义断言轻量化**：自定义断言逻辑尽量简单，禁止耗时IO、数据库查询操作。

#### 二、性能影响分析

- **内置断言性能极高**：基于内存匹配、无网络IO，单请求断言匹配耗时微秒级，对网关QPS几乎无影响；

- **不当配置会引发性能问题**：路由数量过多、断言正则过于复杂、自定义断言包含耗时逻辑，会导致网关吞吐量下降；

- **优化方案**：精简无效路由、简化正则规则、自定义断言仅做内存级匹配、路由按优先级合理拆分。

#### 三、高频避坑总结

- 同路由多断言是 **AND** 逻辑，不同路由是 **OR** 逻辑，极易混淆导致路由失效；

- Header、Cookie 断言正则不能为空匹配，否则会拦截正常请求；

- 时间断言必须携带时区，否则时区偏移导致匹配异常；

- 自定义断言类名必须遵循规范，否则网关无法自动注册生效。

---

# 3. Filter 过滤器详解与实战

Spring Cloud Gateway 的 Filter（过滤器）是网关的**请求处理核心单元**，基于 WebFlux 响应式编程模型实现，作用于路由匹配成功之后、请求转发前后。网关通过过滤器对**入站请求**和**出站响应**进行统一拦截与加工处理，是网关实现流量治理、请求改造、响应封装、权限控制、日志收集、限流熔断的核心载体。相较于断言只做「匹配放行/拦截」，过滤器可以对请求链路做深度定制，是 Gateway 区别于传统网关、功能强大的核心原因。

## 3.1 过滤器的核心作用与分类

### 3.1.1 过滤器的定义：请求/响应的处理单元

**Gateway 过滤器**是一组链式执行的处理器单元，专门用于对**已匹配路由的请求和响应**进行预处理与后处理。简单来说，断言决定「请求能不能进路由」，过滤器决定「请求进去之后怎么被处理」。

过滤器的核心执行阶段分为两类，覆盖完整请求链路：

- **Pre 前置处理**：请求转发至目标服务**之前**执行，可实现请求路径修改、请求头添加、参数补齐、权限校验、黑名单拦截等操作；

- **Post 后置处理**：目标服务响应结果返回网关**之后**、返回客户端**之前**执行，可实现响应头修改、状态码重置、响应数据封装、日志打印等操作。

核心价值：将所有微服务的通用流量处理逻辑**统一收敛到网关层**，避免每个业务服务重复开发通用逻辑，实现解耦、统一管控、降本增效。

### 3.1.2 过滤器的分类：全局过滤器 vs 局部过滤器

Gateway 过滤器严格分为**局部过滤器（GatewayFilter）**和**全局过滤器（GlobalFilter）**两大类，二者作用范围、使用场景、生效规则完全不同，是面试高频对比考点，也是生产配置的核心区分点。

#### 一、局部过滤器（GatewayFilter）

局部过滤器又称**路由过滤器**，仅对**当前配置的单条路由规则**生效，不同路由可配置不同的过滤器逻辑，粒度更精细。

- 生效范围：仅绑定的单条路由；

- 配置方式：在对应路由的 filters 节点下单独配置；

- 适用场景：单服务专属的流量处理，如某服务专属路径重写、专属请求头配置；

- 内置过滤器绝大多数为局部过滤器。

#### 二、全局过滤器（GlobalFilter）

全局过滤器对**网关所有路由、所有请求**全局生效，无需绑定指定路由，优先级统一管控。

- 生效范围：网关全部请求，无路由区分；

- 配置方式：代码注册 Bean 或全局默认配置；

- 适用场景：全网关通用逻辑，如全局日志打印、全局跨域、全局 Token 校验、全局限流；

- Gateway 核心底层过滤器、自定义全局拦截器均采用该类型。

#### 两类过滤器核心对比表

| 对比维度 | 局部过滤器 GatewayFilter     | 全局过滤器 GlobalFilter  |
| -------- | ---------------------------- | ------------------------ |
| 生效范围 | 仅单条绑定路由               | 全局所有路由请求         |
| 配置方式 | YAML 路由内配置              | Java Bean 全局注册       |
| 粒度精度 | 细粒度，按需配置             | 粗粒度，全局统一         |
| 典型场景 | 单服务路径重写、专属参数修改 | 全局日志、跨域、权限拦截 |

### 3.1.3 过滤器的执行流程（pre/post阶段）

Gateway 基于 WebFlux 响应式模型，所有过滤器统一遵循**先 Pre、后路由转发、最后 Post** 的标准执行流程，该流程是理解过滤器顺序、排查链路异常的核心底层逻辑。

#### 完整执行链路

1. **路由匹配阶段**：请求进入网关，经过断言匹配，命中对应路由规则；

2. **Pre 前置执行阶段**：按照过滤器优先级顺序，依次执行所有全局过滤器、局部过滤器的 Pre 预处理逻辑（请求修改、校验、拦截）；

3. **服务转发阶段**：所有 Pre 逻辑执行完毕且无拦截，网关将处理后的请求转发至目标微服务；

4. **Post 后置执行阶段**：目标服务返回响应结果后，网关**逆序**执行所有过滤器的 Post 后处理逻辑（响应修改、状态重置、日志收尾）；

5. **响应返回阶段**：后置处理完成，最终响应结果返回客户端。

#### 核心特性（面试重点）

- Pre 阶段：**正序执行**（order 越小越先执行）；

- Post 阶段：**逆序执行**（order 越大越先执行）；

- 任意过滤器 Pre 阶段拦截请求（终止链路），将直接跳过服务转发和后续所有 Pre 逻辑，直接进入当前已执行过滤器的 Post 收尾逻辑。

## 3.2 常用内置过滤器详解

Spring Cloud Gateway 官方提供了**数十种开箱即用的内置局部过滤器**，覆盖路径处理、请求头/参数修改、响应改造、限流熔断等绝大多数生产场景，无需自定义开发即可完成 90% 以上的流量管控需求。本节分类讲解高频内置过滤器，提供可直接落地的完整配置、参数说明、适用场景与避坑要点。

### 3.2.1 请求路径修改类过滤器

路径修改类过滤器是生产使用频率最高的过滤器，主要用于解决**网关路由前缀与后端服务接口路径不匹配**的问题，实现请求路径的统一适配。

#### 1、StripPrefix：去除路径前缀

核心作用：剔除请求路径的指定层级前缀，只保留后半部分路径转发至后端服务。参数为**去除的路径层级数**。

实操场景：网关请求路径 `/api/user/list`，后端服务真实路径 `/user/list`，需要剔除一级前缀 /api。

```yaml
spring:
  cloud:
    gateway:
      routes:
        - id: strip-prefix-route
          uri: lb://user-service
          predicates:
            - Path=/api/**
          filters:
            # 去除1级路径前缀
            - StripPrefix=1

```

路径转换效果：`/api/user/list` → `/user/list`

避坑要点：层级数必须准确，配置错误会导致后端接口404；仅剔除前缀层级，不支持模糊匹配。

#### 2、RewritePath：重写请求路径

核心作用：通过**正则表达式**全局重写请求路径，灵活性远高于 StripPrefix，支持复杂路径替换、动态路径匹配。

实操场景：统一去除业务前缀、适配新旧接口路径兼容。

```yaml
filters:
  # 正则匹配 /api/xxx 路径，重写为 /xxx
  - RewritePath=/api/(?<path>.*), /$\{path}

```

路径转换效果：`/api/order/save` → `/order/save`

#### 3、PrefixPath：添加路径前缀

核心作用：为所有匹配请求**统一拼接路径前缀**，适用于后端服务接口统一存在固定前缀的场景。

实操场景：后端服务所有接口都带 /server 前缀，网关请求无该前缀，自动补齐。

```yaml
filters:
  # 统一添加 /server 前缀
  - PrefixPath=/server

```

路径转换效果：`/user/list` → `/server/user/list`

### 3.2.2 请求头/参数修改类过滤器

该类过滤器用于在网关层统一修改请求头、请求参数，实现参数透传、权限标识传递、参数补齐等通用能力，无需业务服务处理。

#### 1、AddRequestHeader：添加请求头

核心作用：网关转发请求时，**自动追加/覆盖请求头**，透传给后端服务。常用于传递网关标识、客户端版本、灰度标识等。

```yaml
filters:
  # 统一添加网关来源请求头
  - AddRequestHeader=X-Gateway-Source, SpringCloud-Gateway
  # 透传客户端真实IP
  - AddRequestHeader=X-Real-IP, $\{remoteAddr}

```

#### 2、AddRequestParameter：添加请求参数

核心作用：自动为请求拼接 URL Query 参数，适配后端接口需要固定参数的场景。

```yaml
filters:
  # 统一添加来源标识参数
  - AddRequestParameter=source, gateway

```

#### 3、RemoveRequestHeader：移除请求头

核心作用：过滤客户端非法请求头、敏感请求头，避免隐私泄露或参数冲突。

```yaml
filters:
  # 移除客户端携带的敏感Cookie头
  - RemoveRequestHeader=Cookie

```

### 3.2.3 响应修改类过滤器

响应类过滤器作用于**Post 后置阶段**，用于修改返回给客户端的响应数据、响应头、状态码，统一封装网关响应规范。

#### 1、AddResponseHeader：添加响应头

统一为响应结果添加响应头，常用于跨域配置、缓存策略、服务标识返回。

```yaml
filters:
  # 添加跨域允许域名响应头
  - AddResponseHeader=Access-Control-Allow-Origin, *
  # 标记网关响应时间
  - AddResponseHeader=X-Gateway-Time, $\{time}

```

#### 2、RemoveResponseHeader：移除响应头

剔除后端服务返回的冗余、敏感响应头，统一响应输出规范。

```yaml
filters:
  # 移除服务版本冗余响应头
  - RemoveResponseHeader=Server
```

#### 3、SetStatus：设置响应状态码

强制修改 HTTP 响应状态码，适配特殊业务拦截场景。

```yaml
filters:
  # 统一设置响应状态码为200
  - SetStatus=200 OK

```

### 3.2.4 限流与熔断类过滤器（与Sentinel集成）

Gateway 无缝集成 Sentinel 实现网关层面的**流量限流、熔断降级、流量整形**，通过内置过滤器实现全网关流量管控，是生产环境高可用的核心保障。

#### 一、核心依赖引入

```xml
<!-- Sentinel网关限流依赖 -->
<dependency>
    <groupId>com.alibaba.cloud</groupId>
    <artifactId>spring-cloud-alibaba-sentinel-gateway</artifactId>
</dependency>

```

#### 二、核心过滤器说明

- **SentinelGatewayFilter**：网关核心限流熔断过滤器，拦截所有请求，执行 Sentinel 流量规则校验；

- **GlobalFilter 全局生效**：集成后自动全局注册，无需手动配置路由；

#### 三、核心能力

- 支持**路由维度限流**：对单个服务路由单独配置限流阈值；

- 支持**API 分组限流**：批量管控同类接口流量；

- 支持熔断降级：服务异常率过高时自动熔断，避免雪崩；

- 支持流量整形：匀速排队、预热限流，适配突发流量。

## 3.3 过滤器链与执行顺序

多个过滤器同时生效时，执行顺序直接决定请求处理结果，顺序错乱会导致路径重写失效、参数覆盖、拦截异常等生产问题。本节拆解过滤器链构建机制、order 优先级规则、内置过滤器默认顺序与性能优化方案。

### 3.3.1 过滤器链的构建与执行流程

网关在请求匹配成功后，会自动构建一条**完整过滤器责任链**，构建与执行流程如下：

1. **过滤器汇总**：合并当前路由的局部过滤器 + 全局所有全局过滤器；

2. **优先级排序**：根据每个过滤器的 order 值从小到大排序；

3. **Pre 正序执行**：按排序后的顺序，依次执行所有过滤器的前置处理逻辑；

4. **服务转发**：前置逻辑全部执行完成后转发请求；

5. **Post 逆序执行**：从最后一个执行的过滤器开始，反向执行后置处理逻辑；

6. **链路结束**：所有后置逻辑执行完毕，返回响应给客户端。

### 3.3.2 过滤器的order属性与执行顺序控制

**order 属性是控制过滤器执行顺序的唯一核心依据**，数值规则固定且必须牢记：

- **数值越小，优先级越高**；

- **Pre 阶段**：order 小的先执行，order 大的后执行；

- **Post 阶段**：order 大的先执行，order 小的后执行；

- 未手动配置 order 时，过滤器默认优先级为 **0**。

#### 自定义顺序配置示例

```yaml
filters:
  # 优先级最高，最先执行pre，最后执行post
  - name: RewritePath
    args:
      regexp: /api/(?<path>.*)
      replacement: /$\{path}
    order: -100
  # 默认优先级0
  - AddRequestHeader=X-Test, test

```

#### 生产顺序最佳实践

固定通用执行顺序，避免链路错乱：**路径重写（高优先级）→ 参数/请求头修改 → 权限校验 → 限流熔断 → 响应修改（低优先级）**

### 3.3.3 内置过滤器的默认执行顺序

Gateway 内置过滤器拥有**固定默认order值**，无需手动配置，默认遵循标准化执行顺序，核心内置过滤器默认优先级从高到低如下：

1. 路径处理类过滤器（StripPrefix、RewritePath、PrefixPath）：order = -1000 左右，最高优先级，优先处理路径；

2. 请求参数/请求头修改过滤器：order = 0；

3. 限流熔断过滤器：order = 100；

4. 响应头、状态码修改过滤器：order = 200，低优先级，后置执行。

核心避坑：如果自定义过滤器需要依赖路径重写结果，必须将自定义过滤器 order 设置**大于路径过滤器**，否则会读取到未处理的原始路径。

### 3.3.4 过滤器链的性能影响与优化

#### 一、性能影响因素

- **过滤器数量过多**：单路由配置大量冗余过滤器，增加链路执行耗时；

- **自定义过滤器耗时操作**：Pre 阶段存在数据库查询、远程调用、复杂计算等同步阻塞操作；

- **顺序错乱重复处理**：过滤器顺序错误导致参数重复覆盖、重复加工，造成资源浪费；

- **全局过滤器滥用**：非通用逻辑配置为全局过滤器，所有请求无效执行。

#### 二、生产优化方案

1. **精简过滤器数量**：删除冗余、无效过滤器，合并相同功能过滤器；
2. **严格区分全局与局部过滤器**：通用逻辑全局配置，专属逻辑局部路由配置，避免全局无效执行；
3. **自定义过滤器异步化**：耗时操作全部采用响应式异步实现，禁止同步阻塞；
4. **固定过滤器执行顺序**：通过手动指定 order 固化链路顺序，避免默认顺序错乱；
5. **增加过滤器熔断机制**：自定义过滤器异常时快速失败，不阻塞整条请求链路。

---

# 4. 自定义过滤器开发实战

Gateway 内置过滤器仅能满足通用流量处理场景，实际业务开发中大量个性化需求（统一鉴权、链路日志、参数脱敏、灰度标记、流量统计）需要通过**自定义过滤器**实现。自定义过滤器分为局部过滤器（GatewayFilter）和全局过滤器（GlobalFilter）两类，拥有标准化开发规范，是 Gateway 扩展能力的核心体现。本章将从零实现完整的自定义过滤器，讲解开发规范、阶段逻辑、配置方式、生效验证与生产实战场景。

## 4.1 局部过滤器开发（GatewayFilter）

局部过滤器（GatewayFilter）是**路由级别**的自定义过滤器，仅对绑定的单条路由生效，粒度精细、灵活度高，适用于单服务、单业务专属的流量处理逻辑。局部过滤器拥有固定的开发规范，必须实现 `GatewayFilterFactory` 抽象工厂类，遵循「工厂类+配置实体+过滤逻辑」的标准化开发模式。

### 4.1.1 实现GatewayFilterFactory接口

自定义局部过滤器必须继承 **AbstractGatewayFilterFactory** 抽象类（官方标准规范），不能直接实现接口，该抽象类封装了过滤器注册、配置解析的通用逻辑，简化开发成本。

**开发强制规范（面试高频）**：

- 过滤器工厂类名必须以`GatewayFilterFactory` 结尾，前缀为过滤器名称（配置文件使用前缀名）；

- 必须定义静态内部 Config 类，用于接收 YAML 配置参数；

- 必须重写 `shortcutFieldOrder` 方法，绑定配置参数顺序；

- 核心过滤逻辑在 `apply`方法中实现。

基础骨架代码（通用模板，可复用）：

```java
import org.springframework.cloud.gateway.filter.GatewayFilter;
import org.springframework.cloud.gateway.filter.factory.AbstractGatewayFilterFactory;
import org.springframework.stereotype.Component;
import reactor.core.publisher.Mono;
import java.util.Arrays;
import java.util.List;

/**
 * 自定义局部过滤器模板
 * 类名前缀为过滤器名称，后缀固定GatewayFilterFactory
 */
@Component
public class CustomLocalGatewayFilterFactory extends AbstractGatewayFilterFactory<CustomLocalGatewayFilterFactory.Config> {

    // 绑定配置实体
    public CustomLocalGatewayFilterFactory() {
        super(Config.class);
    }

    // 配置参数顺序绑定
    @Override
    public List<String> shortcutFieldOrder() {
        // 对应配置文件中的参数顺序
        return Arrays.asList("enable");
    }

    // 核心过滤逻辑
    @Override
    public GatewayFilter apply(Config config) {
        // 返回过滤器实例，实现pre/post逻辑
        return (exchange, chain) -> {
            // ===================== Pre 前置逻辑 =====================
            // 路由转发前执行：请求拦截、参数修改、权限校验

            // ===================== Post 后置逻辑 =====================
            return chain.filter(exchange).then(Mono.fromRunnable(() -> {
                // 服务响应后执行：响应修改、日志统计
            }));
        };
    }

    // 配置参数实体类，接收yaml配置参数
    public static class Config {
        // 自定义开关参数
        private Boolean enable;

        public Boolean getEnable() {
            return enable;
        }

        public void setEnable(Boolean enable) {
            this.enable = enable;
        }
    }
}

```

### 4.1.2 过滤器配置参数定义与解析

局部过滤器支持**自定义配置参数**，可以在 YAML 中动态控制过滤器开关、规则、参数，实现配置化动态适配，无需修改代码重启服务。

核心解析原理：

网关启动时，通过 `shortcutFieldOrder` 定义的参数顺序，自动将 YAML 配置的参数映射到 Config 实体类中，开发者可在 apply 方法中获取配置参数，实现动态逻辑控制。

带参数的完整配置示例：

```yaml
spring:
  cloud:
    gateway:
      routes:
        - id: custom-filter-route
          uri: lb://user-service
          predicates:
            - Path=/api/user/**
          filters:
            # 自定义局部过滤器，传入参数true（开启过滤器）
            - CustomLocal=true

```

参数解析说明：

- 配置名称 `CustomLocal` 对应工厂类前缀 `CustomLocalGatewayFilterFactory`；

- 参数 true 自动映射到 Config 类的 enable 属性；

- 支持多参数配置，只需拓展 shortcutFieldOrder 和 Config 属性即可。

### 4.1.3 pre阶段与post阶段逻辑编写

局部过滤器完整支持 **Pre 前置处理** 和 **Post 后置处理** 双阶段逻辑，适配不同业务场景，基于 WebFlux 响应式编程实现，全程异步非阻塞。

#### 1、Pre 前置阶段（请求转发前）

常用于：请求参数校验、请求头修改、权限拦截、黑名单过滤、路径预处理。若校验失败，可直接通过 `exchange.getResponse().setStatusCode()` 设置响应状态码，终止请求链路。

#### 2、Post 后置阶段（服务响应后）

常用于：响应数据修改、响应头追加、请求耗时统计、日志收尾、结果脱敏。通过 `chain.filter(exchange).then()` 实现后置监听。

#### 完整双阶段逻辑示例

```java
@Override
public GatewayFilter apply(Config config) {
    return (exchange, chain) -> {
        // Pre 前置逻辑：仅开启状态下执行
        if (config.getEnable()) {
            System.out.println("局部过滤器Pre执行，请求路径：" + exchange.getRequest().getPath());
            // 可在此处拦截请求，直接返回响应
            // exchange.getResponse().setStatusCode(HttpStatus.UNAUTHORIZED);
            // return exchange.getResponse().setComplete();
        }

        // Post 后置逻辑
        return chain.filter(exchange).then(Mono.fromRunnable(() -> {
            if (config.getEnable()) {
                System.out.println("局部过滤器Post执行，请求结束");
            }
        }));
    };
}

```

### 4.1.4 局部过滤器的配置与生效验证

#### 1、完整路由配置

```yaml
spring:
  cloud:
    gateway:
      routes:
        - id: user-service-custom-filter-route
          uri: lb://user-service
          predicates:
            - Path=/api/user/**
          filters:
            # 启用自定义局部过滤器
            - CustomLocal=true
            # 叠加内置路径重写过滤器
            - RewritePath=/api/user/(?<path>.*), /$\{path}

```

#### 2、生效验证方式

- 启动网关服务，调用匹配路由的接口，查看控制台 Pre/Post 日志输出；

- 修改配置参数为 false，验证过滤器逻辑是否关闭；

- 切换其他路由，验证过滤器是否**仅当前路由生效**；

#### 3、常见失效问题排查

- 类名后缀不规范，网关无法自动扫描注册；

- 未添加 @Component 注解，过滤器未交给 Spring 管理；

- 配置名称与类名前缀不匹配；

- 路由断言匹配失败，未进入当前路由。

## 4.2 全局过滤器开发（GlobalFilter）

全局过滤器（GlobalFilter）是**全网关所有请求生效**的过滤器，无需绑定任何路由，默认对所有匹配、不匹配的请求统一拦截。适用于全网关通用逻辑：统一鉴权、全局日志、跨域处理、链路ID透传、全局限流等，是生产环境使用最广泛的自定义过滤器。

### 4.2.1 实现GlobalFilter接口

自定义全局过滤器只需实现 **GlobalFilter** 接口，重写核心过滤方法，结合 @Component 注解即可全局注册，开发相较于局部过滤器更简单。

基础完整模板：

```java
import org.springframework.cloud.gateway.filter.GlobalFilter;
import org.springframework.context.annotation.ComponentScan;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Mono;

/**
 * 自定义全局过滤器
 * 全局所有请求都会执行该过滤器逻辑
 */
@Component
public class CustomGlobalFilter implements GlobalFilter {

    @Override
    public Mono<Void> filter(ServerWebExchange exchange, org.springframework.cloud.gateway.filter.GatewayFilterChain chain) {
        // Pre 全局前置逻辑
        System.out.println("全局过滤器Pre执行，请求地址：" + exchange.getRequest().getPath());

        // Post 全局后置逻辑
        return chain.filter(exchange).then(Mono.fromRunnable(() -> {
            System.out.println("全局过滤器Post执行，请求响应完成");
        }));
    }
}

```

### 4.2.2 全局过滤器的执行顺序配置（Ordered接口）

全局过滤器支持两种方式配置执行优先级，实现 **Ordered 接口** 或使用 **@Order 注解**，优先级规则与内置过滤器完全一致：**数值越小，Pre 阶段越先执行，Post 阶段越后执行**。

#### 方式一：实现Ordered接口（推荐，优先级更高）

```java
@Component
public class CustomGlobalFilter implements GlobalFilter, Ordered {

    @Override
    public Mono<Void> filter(ServerWebExchange exchange, org.springframework.cloud.gateway.filter.GatewayFilterChain chain) {
        return chain.filter(exchange);
    }

    // 自定义优先级，-100 高优先级
    @Override
    public int getOrder() {
        return -100;
    }
}

```

#### 方式二：@Order注解

```java
@Component
@Order(-100)
public class CustomGlobalFilter implements GlobalFilter {
    // 过滤逻辑
}

```

#### 生产顺序规范

- 链路ID、日志过滤器：order = -1000（最高优先级，最先执行）；

- 鉴权、权限过滤器：order = -500；

- 参数脱敏、请求改造过滤器：order = 0；

- 响应封装、统计过滤器：order = 500（低优先级）。

### 4.2.3 全局过滤器的应用场景（统一鉴权、日志记录）

全局过滤器主打**全网关通用能力收敛**，核心生产场景如下：

#### 1、全局统一鉴权

拦截所有请求，校验 Token 有效性、权限标识，未登录/无权限请求直接在网关层拦截，无需转发业务服务，减轻后端压力，统一权限管控规范。

#### 2、全局请求日志记录

统一记录请求路径、请求方式、客户端IP、响应耗时、响应状态码，实现全网关日志标准化，便于问题排查、链路追踪。

#### 3、全局链路追踪透传

生成全局 TraceId，透传给所有微服务，实现分布式链路追踪。

#### 4、全局参数统一处理

统一跨域、统一请求头补齐、统一参数脱敏、统一流量标记。

### 4.2.4 全局过滤器与局部过滤器的配合使用

生产环境中，全局过滤器与局部过滤器通常**组合使用**，分工明确、互补适配：全局过滤器做通用兜底，局部过滤器做个性化定制。

#### 组合执行顺序

**高优先级全局过滤器 → 局部过滤器 → 低优先级全局过滤器**

#### 最佳实践组合方案

- 全局过滤器：日志、TraceId、跨域、基础鉴权（所有请求通用）；

- 局部过滤器：单服务专属脱敏、专属路径重写、专属灰度规则（个性化定制）。

#### 核心优势

兼顾**全局统一性**和**业务灵活性**，避免所有逻辑全局堆砌，也避免每个服务重复开发通用逻辑。

## 4.3 自定义过滤器实战场景

本节提供4个企业生产高频落地的自定义过滤器完整案例，代码可直接复制上线使用，覆盖日志统计、链路透传、参数脱敏、性能优化，完全适配生产需求。

### 4.3.1 请求日志记录过滤器（记录请求ID、耗时、来源）

实现能力：全局自动生成 RequestId，记录客户端IP、请求路径、请求方式、响应耗时、状态码，标准化网关日志。

```java
import org.springframework.cloud.gateway.filter.GlobalFilter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.annotation.Order;
import reactor.core.publisher.Mono;
import java.util.UUID;

@Configuration
public class RequestLogFilter {

    @Bean
    @Order(-1000)
    public GlobalFilter requestLogGlobalFilter() {
        return (exchange, chain) -> {
            // 1、生成全局请求ID
            String requestId = UUID.randomUUID().toString().replace("-", "");
            // 存入上下文，供后续过滤器和服务使用
            exchange.getAttributes().put("REQUEST_ID", requestId);

            // 2、记录请求基础信息
            String path = exchange.getRequest().getPath().value();
            String method = exchange.getRequest().getMethod().name();
            String ip = exchange.getRequest().getRemoteAddress().getHostString();
            long startTime = System.currentTimeMillis();

            System.out.printf("【网关请求日志】ID:%s，IP:%s，路径:%s，方法:%s，时间:%d%n",
                    requestId, ip, path, method, startTime);

            // 3、后置统计耗时
            return chain.filter(exchange).then(Mono.fromRunnable(() -> {
                long cost = System.currentTimeMillis() - startTime;
                int status = exchange.getResponse().getStatusCode().value();
                System.out.printf("【网关响应日志】ID:%s，状态码:%d，耗时:%dms%n",
                        requestId, status, cost);
            }));
        };
    }
}

```

### 4.3.2 请求头传递过滤器（如TraceId、Token）

实现能力：将网关生成的 RequestId、客户端 Token 统一透传给后端微服务，实现分布式链路追踪与身份透传。

```java
@Bean
@Order(-900)
public GlobalFilter headerTransferFilter() {
    return (exchange, chain) -> {
        // 获取全局RequestId
        String requestId = exchange.getAttribute("REQUEST_ID");
        // 获取客户端Token
        String token = exchange.getRequest().getHeaders().getFirst("Token");

        // 构造新请求头，透传参数
        org.springframework.http.HttpHeaders headers = new org.springframework.http.HttpHeaders();
        headers.addAll(exchange.getRequest().getHeaders());
        if (requestId != null) {
            headers.add("X-Request-Id", requestId);
        }
        if (token != null) {
            headers.add("X-Client-Token", token);
        }

        // 覆盖请求头，转发给后端服务
        org.springframework.web.server.ServerHttpRequest newRequest = exchange.getRequest().mutate()
                .headers(h -> h.putAll(headers))
                .build();
        org.springframework.web.server.ServerWebExchange newExchange = exchange.mutate().request(newRequest).build();

        return chain.filter(newExchange);
    };
}

```

### 4.3.3 敏感参数脱敏过滤器

实现能力：对请求参数中的手机号、身份证、密码等敏感字段进行脱敏处理，避免日志打印泄露隐私。

```java
@Bean
@Order(0)
public GlobalFilter sensitiveDataMaskFilter() {
    return (exchange, chain) -> {
        // 获取URL请求参数
        String phone = exchange.getRequest().getQueryParams().getFirst("phone");
        if (phone != null && phone.length() == 11) {
            // 手机号脱敏 138****1234
            String maskPhone = phone.substring(0,3) + "****" + phone.substring(7);
            System.out.println("手机号脱敏：" + phone + " -> " + maskPhone);
        }
        return chain.filter(exchange);
    };
}

```

### 4.3.4 自定义过滤器的性能优化与避坑

#### 一、核心性能优化方案

- **禁止同步阻塞操作**：自定义过滤器基于 WebFlux 异步模型，禁止在过滤器中写数据库查询、远程调用、Thread.sleep 等同步阻塞代码，会直接压垮网关吞吐量；

- **精简执行逻辑**：Pre/Post 阶段只保留核心逻辑，复杂计算、数据处理下沉业务服务；

- **合理控制优先级**：高频执行的轻量过滤器设置高优先级，低频过滤器低优先级；

- **增加条件拦截**：对静态资源、健康检查接口跳过过滤器逻辑，减少无效执行。

#### 二、生产高频避坑指南

- 局部过滤器类名必须规范，否则网关无法注册，配置不生效；

- 全局过滤器优先级冲突会导致鉴权失效、日志缺失；

- 修改请求头、请求参数必须构建新的 ServerHttpRequest，直接修改原对象不生效；

- Post 阶段异常不会终止请求，不能用于前置拦截逻辑；

- 过滤器中禁止抛出异常，需手动捕获并封装响应，避免网关500报错。

---

# 5. 跨域处理、请求重写与路径转发

前后端分离架构下，**跨域问题、路径不匹配问题、静态资源转发**是网关最常见的三大落地问题。传统单服务跨域配置分散、维护困难，Gateway 作为统一入口，可实现**全网关统一跨域处理**；通过请求重写、路径剥离、多路径映射能力，彻底解决前后端路径不一致、多服务路径适配、静态资源转发等场景问题，是生产环境必备核心能力。

## 5.1 跨域问题统一处理

### 5.1.1 跨域问题的产生原因与浏览器限制

**跨域定义**：浏览器同源策略限制，当协议、域名、端口任意一个不同时，前端请求后端接口即为跨域请求。

**同源策略核心限制**：浏览器禁止跨域请求的响应数据被前端页面读取，默认拦截跨域响应，抛出 CORS 跨域异常。

**微服务跨域痛点**：若每个微服务单独配置跨域，配置分散、规则不统一、维护成本高，网关作为统一入口，统一处理跨域是最优解，可**完全取消后端服务的跨域配置**，实现统一管控。

**预检请求**：非简单请求（带自定义请求头、POST JSON请求），浏览器会先发 OPTIONS 预检请求，校验跨域权限，预检失败则不发送正式请求。

### 5.1.2 网关全局跨域配置（CORS配置类方式）

代码配置方式优先级最高、功能最全，支持精细化域名管控、预检请求缓存、Cookie 跨域携带，是**生产环境首选方案**。

完整可直接上线配置类：

```java
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.reactive.CorsWebFilter;
import org.springframework.web.cors.reactive.UrlBasedCorsConfigurationSource;
import java.util.Arrays;

/**
 * 网关全局统一跨域配置
 * 统一处理所有路由跨域问题，后端服务无需配置跨域
 */
@Configuration
public class GatewayCorsConfig {

    @Bean
    public CorsWebFilter corsWebFilter() {
        CorsConfiguration corsConfig = new CorsConfiguration();
        // 1、允许跨域的域名，生产环境禁止使用*，需配置具体前端域名
        corsConfig.setAllowedOrigins(Arrays.asList("http://localhost:8080", "https://www.xxx.com"));
        // 2、允许所有请求方法
        corsConfig.setAllowedMethods(Arrays.asList("GET", "POST", "PUT", "DELETE", "OPTIONS"));
        // 3、允许所有请求头
        corsConfig.setAllowedHeaders(Arrays.asList("*"));
        // 4、允许携带Cookie、Token凭证
        corsConfig.setAllowCredentials(true);
        // 5、预检请求缓存时间，3600秒，减少OPTIONS请求次数
        corsConfig.setMaxAge(3600L);

        // 对所有路径生效
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", corsConfig);

        return new CorsWebFilter(source);
    }
}

```

**生产关键注意点**：生产环境**禁止使用 * 允许所有域名**，会导致 Cookie 携带失效、存在安全风险，必须配置具体可信域名。

### 5.1.3 配置文件方式跨域配置

配置文件方式简洁快速，适合测试环境、简单项目，无需编写代码，YAML 一键配置。

```yaml
spring:
  cloud:
    gateway:
      globalcors:
        # 开启全局跨域
        enabled: true
        cors-configurations:
          # 匹配所有路径
          '[/**]':
            # 允许跨域域名（测试环境可用*）
            allowedOrigins: "*"
            # 允许请求方法
            allowedMethods:
              - GET
              - POST
              - PUT
              - DELETE
              - OPTIONS
            # 允许请求头
            allowedHeaders: "*"
            # 允许携带凭证
            allowCredentials: true
            # 预检缓存时间
            maxAge: 3600

```

### 5.1.4 跨域配置的常见问题排查（预检请求、Cookie携带）

#### 1、预检请求OPTIONS 404问题

**原因**：网关路由未匹配 OPTIONS 预检请求，或过滤器拦截了预检请求。

**解决方案**：全局过滤器中放行 OPTIONS 请求，直接返回成功，不做鉴权拦截。

#### 2、Cookie 无法跨域携带

**原因**：allowedCredentials=true 时，allowedOrigins 不能为 *，必须配置具体域名。

**解决方案**：替换 * 为前端真实域名列表。

#### 3、自定义过滤器导致跨域失效

**原因**：自定义全局过滤器优先级高于跨域过滤器，提前拦截响应，跨域响应头未生效。

**解决方案**：调整跨域过滤器优先级为最高，或在自定义过滤器中放行 OPTIONS 请求。

## 5.2 请求重写与路径转发

前后端分离项目中，前端为了接口统一、路由规整，通常会统一添加请求前缀（如 /api），而后端服务接口无该前缀，会导致 404。**请求重写**是解决路径不匹配的核心方案，也是网关生产最常用的能力之一。

### 5.2.1 路径重写场景（前端路径与后端服务路径不匹配）

典型业务场景：

- 前端请求地址：`http://gateway/api/user/list`

- 后端服务真实地址：`http://user-service/user/list`

- 问题：多出 /api 前缀，后端接口404

- 解决方案：通过 RewritePath 重写路径，剔除 /api 前缀

### 5.2.2 RewritePath过滤器配置与使用

**RewritePath** 是官方路径重写过滤器，基于正则表达式实现灵活路径替换，支持动态路径匹配。

标准配置模板：

```yaml
spring:
  cloud:
    gateway:
      routes:
        - id: user-service-rewrite-route
          uri: lb://user-service
          predicates:
            - Path=/api/user/**
          filters:
            # 正则匹配：匹配/api/user/任意路径
            # 重写规则：剔除/api前缀，转发真实路径
            - RewritePath=/api/(?<path>.*), /$\{path}

```

路径转换效果：`/api/user/list` → `/user/list`

### 5.2.3 路径变量传递与重写示例

支持 RESTful 路径变量动态传递，重写后保留路径参数，适配动态接口场景。

示例：

- 前端路径：`/api/user/1001`

- 后端路径：`/user/1001`

配置同上，正则自动捕获后续路径变量，重写后参数完全保留，无丢失。

### 5.2.4 请求重写与服务发现的配合使用

动态路由（lb://协议）必须配合路径重写使用，是微服务标准架构方案：

1. 网关通过 lb:// 从注册中心动态发现服务；

2. 通过 Path 断言匹配统一前缀路径；

3. 通过 RewritePath 剥离前端自定义前缀；

4. 转发至后端真实服务接口。

该组合方案支撑绝大多数微服务网关路由场景，稳定、高效、易维护。

## 5.3 路径转发进阶场景

### 5.3.1 多路径映射到同一服务

生产场景：多个不同前缀路径，需要转发至同一个微服务，可通过多断言路径实现。

```yaml
predicates:
  # 多路径匹配，/api/user/** 和 /api/member/** 都转发至用户服务
  - Path=/api/user/**,/api/member/**
filters:
  - RewritePath=/api/(user|member)/(?<path>.*), /$\{path}

```

### 5.3.2 前缀匹配与路径剥离

除了 RewritePath，**StripPrefix** 路径剥离过滤器更适合固定层级前缀剔除，性能更高、配置更简单。

```yaml
# 剔除1级前缀 /api
predicates:
  - Path=/api/**
filters:
  - StripPrefix=1

```

适用场景：统一层级前缀，性能优于正则重写，优先使用。

### 5.3.3 静态资源请求转发

网关可统一拦截图片、文件、页面等静态资源请求，转发至静态资源服务或本地资源，避免静态资源穿透业务服务。

```yaml
- id: static-resource-route
  uri: lb://static-service
  predicates:
    - Path=/static/**,/file/**,/img/**
  filters:
    - StripPrefix=1

```

### 5.3.4 路径转发的性能优化与缓存配置

#### 性能优化方案

- **静态资源缓存**：通过 AddResponseHeader 添加 Cache-Control 响应头，浏览器缓存静态资源，减少网关请求量；

- **优先使用路径剥离**：固定前缀场景优先 StripPrefix，减少正则匹配耗时；

- **路由精准匹配**：避免模糊路由大范围匹配，减少无效路由遍历；

- **开启网关缓存**：开启路由规则本地缓存，无需每次刷新路由配置。

#### 缓存配置示例

```yaml
filters:
  # 静态资源缓存1小时
  - AddResponseHeader=Cache-Control, max-age=3600

```

---

# 6. Gateway 核心功能生产级优化与避坑

## 6.1 路由与过滤器配置优化

Gateway 默认配置方式在服务数量多、路由规则复杂的场景下，容易出现配置冗余、规则混乱、执行低效、维护困难等问题。生产环境必须通过规范化优化，提升网关的可维护性、稳定性与并发性能。

### 6.1.1 路由配置的模块化与可维护性

随着微服务数量增多，网关 YAML 文件会堆积大量路由规则，直接导致配置臃肿、修改易错、排查困难。**路由模块化**是生产环境统一规范的优化方案。

#### 1、模块化配置核心思想

按照**业务服务维度、功能模块维度**拆分路由配置，单一服务对应一组独立路由规则，做到职责单一、便于迭代维护。同时统一路由命名、断言规则、过滤器配置规范，避免个性化随意配置。

#### 2、标准化路由配置规范（生产通用）

- **路由ID规范**：固定格式 `服务名-功能-route`，如 `user-service-api-route`，杜绝随机命名；

- **断言规范**：统一使用路径前缀匹配，配合请求方法、请求头精准约束，避免超大模糊匹配；

- **过滤器规范**：通用能力全局配置，专属能力路由局部配置，不重复定义；

- **注释规范**：每条路由标注适用场景、创建时间、维护人，便于团队协作。

#### 3、多文件模块化拆分（最优方案）

Spring Cloud Gateway 支持加载外部路由配置文件，可将不同服务的路由规则拆分到独立 YAML 文件，彻底解决单文件臃肿问题。

实现方式：在配置中心或本地资源目录下，创建 `routes/` 文件夹，拆分 `user-route.yml`、`order-route.yml` 等独立配置，主配置文件统一引入。

```yaml
# 主配置文件统一加载路由配置
spring:
  cloud:
    gateway:
      # 加载外部模块化路由配置
      route-location: classpath:routes/*.yml

```

#### 4、动态配置优化

生产环境推荐结合 Nacos 配置中心实现**动态路由配置**，无需重启网关即可更新路由规则，实现配置热更新、灰度路由动态调整、紧急路由下线等能力，极大提升网关运维效率。

### 6.1.2 过滤器链的精简与执行顺序优化

过滤器链冗余、顺序错乱是导致网关性能下降、功能异常的核心原因之一，生产环境必须严格精简过滤器、固化执行顺序。

#### 1、过滤器链精简方案

- **去重精简**：删除重复功能、无效冗余过滤器，避免多次处理同一逻辑；

- **全局收敛**：全网关通用逻辑（跨域、日志、TraceId透传）统一使用全局过滤器，禁止每个路由重复配置局部过滤器；

- **按需加载**：专属业务逻辑使用局部过滤器，仅绑定对应路由，避免全局无效执行；

- **场景跳过**：对健康检查接口、静态资源、OPTIONS预检请求，跳过非必要过滤器（鉴权、脱敏）。

#### 2、生产固定执行顺序（最佳实践）

通过 order 属性固化过滤器执行顺序，彻底避免顺序错乱导致的功能异常，标准优先级从高到低如下：

1. 最高优先级（order=-1000）：跨域过滤器、链路ID生成、请求日志初始化；

2. 高优先级（order=-500）：路径重写、路径剥离等路径处理过滤器；

3. 中优先级（order=0）：请求头处理、参数补齐、参数脱敏；

4. 低优先级（order=500）：权限校验、Token鉴权、流量限流；

5. 最低优先级（order=1000）：响应封装、耗时统计、日志收尾。

#### 3、顺序优化核心原则

**先处理路径、再改造参数、最后校验拦截，后置统一收尾**，确保所有依赖前置处理完成后，再执行后续业务逻辑。

### 6.1.3 断言与过滤器的性能影响分析

Gateway 基于 WebFlux 异步非阻塞模型，原生性能极高，但不合理的断言与过滤器配置会严重拖垮网关吞吐量，本节拆解核心性能影响点与优化方案。

#### 1、断言的性能影响

- **正向影响**：断言执行在过滤器之前，可快速拦截无效流量，避免后续链路执行，降低后端压力；

- **负向损耗**：复杂正则断言、大量模糊路由匹配、过多断言组合，会增加路由匹配耗时；

- **核心问题**：网关会遍历所有路由规则匹配请求，路由数量越多、断言越复杂，匹配耗时越高。

#### 2、过滤器的性能影响

- **内置过滤器**：纯内存操作、无IO阻塞，性能损耗几乎可忽略，适合大规模使用；

- **自定义过滤器**：最大性能隐患，若包含同步IO、数据库查询、远程调用、复杂循环计算，会破坏 WebFlux 异步模型，导致网关阻塞、吞吐量骤降；

- **过滤器过多**：单请求链路过滤器数量过多，会累积执行耗时，增加 GC 压力。

#### 3、性能优化总结

- 优先使用精准路径匹配，减少正则模糊匹配；

- 精简路由数量，下线无效、废弃路由；

- 自定义过滤器全程异步非阻塞，禁止同步耗时操作；

- 精简过滤器链路，只保留核心必要逻辑。

## 6.2 常见问题与排查

本节汇总生产环境 Gateway 最高频的四大类疑难问题，提供**问题现象、根因分析、完整排查步骤、最终解决方案**，覆盖90%以上网关线上故障，可直接用于线上问题复盘与修复。

### 6.2.1 路由不匹配问题排查（断言配置错误、路径大小写问题）

#### 1、问题现象

请求正常发起，网关直接返回 404，未转发至目标服务，日志无路由匹配记录。

#### 2、常见根因

- 路径断言配置错误，通配符、正则书写不规范；

- 多断言组合不满足 AND 逻辑，部分断言匹配失败；

- **路径大小写问题**：Gateway 断言默认**区分大小写**，前端路径大小写与配置不一致导致匹配失败；

- 高优先级路由抢占流量，当前路由未执行；

- 请求包含多余参数、请求方法不匹配 Method 断言。

#### 3、排查步骤

1. 开启网关 debug 日志，查看路由匹配日志，确认是否命中目标路由；

2. 核对请求路径、请求方法、请求头是否完全匹配路由所有断言；

3. 注释其他路由，单独测试当前路由，排除路由抢占问题；

4. 统一路径大小写，验证是否为大小写匹配问题。

#### 4、解决方案

- 修正断言正则与通配符配置，简化模糊匹配规则；

- 开启网关路径忽略大小写配置：

```yaml
spring:
  cloud:
    gateway:
      router:
        case-sensitive-path: false

```

### 6.2.2 过滤器不生效问题排查（order顺序、配置错误）

#### 1、问题现象

路由匹配成功，但自定义过滤器、内置过滤器逻辑未执行，无日志、无效果。

#### 2、常见根因

- **执行顺序错误**：低优先级过滤器依赖高优先级过滤器结果，执行顺序倒置导致逻辑失效；

- 局部过滤器绑定路由错误，未命中当前路由；

- 自定义过滤器未添加 @Component 注解，未注册到 Spring 容器；

- 局部过滤器类名不规范，网关无法自动识别加载；

- 前置过滤器拦截请求，终止链路，后续过滤器无执行机会。

#### 3、排查步骤

1. 查看网关启动日志，确认过滤器是否成功加载；

2. 核对 order 优先级，打印执行顺序日志；

3. 临时调高过滤器优先级，排除顺序问题；

4. 关闭其他拦截过滤器，排查链路终止问题。

#### 4、解决方案

- 严格遵循标准化过滤器开发规范，保证类名、注解、配置正确；

- 固化过滤器执行顺序，前置处理优先执行；

- 在过滤器开头添加日志，方便快速定位执行状态。

### 6.2.3 跨域配置不生效问题排查

#### 1、问题现象

已配置跨域规则，前端依然报 CORS 跨域异常，OPTIONS 预检请求失败、Cookie 无法携带。

#### 2、核心根因

- 自定义全局过滤器优先级高于跨域过滤器，提前响应请求，覆盖跨域响应头；

- **allowCredentials=true 与 * 域名不兼容**：开启凭证后，不允许任意域名匹配；

- 未放行 OPTIONS 预检请求，鉴权过滤器拦截预检请求；

- 后端服务残留跨域配置，与网关跨域配置冲突覆盖。

#### 3、解决方案

- 设置跨域过滤器最高优先级，保证最先执行；

- 生产环境替换 * 为具体可信域名列表；

- 全局过滤器放行 OPTIONS 请求，直接返回 200；

- 统一关闭所有后端服务跨域配置，网关唯一管控。

### 6.2.4 路径重写后服务无法接收请求问题排查

#### 1、问题现象

路由匹配成功，网关无报错，但是后端服务接收不到请求路径参数、请求体，或直接404。

#### 2、核心根因

- RewritePath 正则表达式书写错误，路径重写后地址异常；

- StripPrefix 层级配置错误，过度剥离或未剥离前缀；

- 重写过滤器执行顺序靠后，其他过滤器读取了原始路径；

- 路径重写后丢失路径变量、请求参数。

#### 3、解决方案

- 将路径重写过滤器优先级设置为最高，优先处理路径；

- 固定正则写法，统一使用 `/api/(?<path>.*), /$\{path}` 标准模板；

- 层级前缀优先使用 StripPrefix，性能更高、出错率更低；

- 开启网关请求日志，打印重写前后路径，快速定位问题。

## 6.3 面试高频题

本节汇总本章及 Gateway 全文**终极高频面试题**，答案精简标准、直击考点，适配面试口述场景，覆盖 90% Gateway 面试提问。

### 6.3.1 Gateway的路由配置有哪些方式？静态路由和动态路由的区别是什么？

#### 1、路由配置三种方式

- **YAML/Properties 配置文件路由（静态路由）**：本地配置、简单高效、适合固定路由；

- **Java 代码路由**：通过 RouteLocator 编码构建路由，适合复杂动态规则；

- **配置中心动态路由**：结合 Nacos/Apollo 实现热更新路由，生产主流方案。

#### 2、静态路由与动态路由核心区别

- **静态路由**：配置写死在本地配置文件，修改需要重启网关服务，无法实时更新，适合稳定不变的路由规则；

- **动态路由**：配置存储在配置中心，支持热更新、无需重启服务，可实时调整路由、上下线服务、配置灰度规则，适配生产动态运维场景。

### 6.3.2 Gateway的断言和过滤器有什么作用？常用的有哪些？

#### 1、核心作用

- **断言（Predicate）**：请求匹配条件，负责**筛选流量**，只有满足所有断言规则的请求，才能命中当前路由；

- **过滤器（Filter）**：请求处理单元，负责**加工流量**，对匹配成功的请求、响应做预处理和后处理。

#### 2、常用内置断言

Path路径匹配、Method请求方法匹配、Header请求头匹配、Query参数匹配、Cookie匹配、时间范围匹配。

#### 3、常用内置过滤器

路径重写 RewritePath、路径剥离 StripPrefix、请求头/参数新增移除、响应头修改、状态码设置、Sentinel 限流熔断过滤器。

### 6.3.3 如何实现Gateway的自定义过滤器？局部过滤器和全局过滤器的区别是什么？

#### 1、自定义过滤器实现方式

- **局部过滤器**：继承 `AbstractGatewayFilterFactory`，实现工厂方法，配置在指定路由下，仅单路由生效；

- **全局过滤器**：实现 `GlobalFilter` 接口，注册为 Bean，全网关所有请求生效。

#### 2、局部与全局过滤器核心区别

- **生效范围**：局部仅绑定路由生效，全局所有请求生效；

- **配置方式**：局部 YAML 路由配置，全局代码注册 Bean；

- **适用场景**：局部用于单服务个性化逻辑，全局用于全网关通用逻辑（日志、鉴权、跨域）；

- **开发复杂度**：局部需遵循工厂规范，全局开发更简单。

### 6.3.4 如何在Gateway中处理跨域问题？

Gateway 作为统一入口，推荐**网关全局统一处理跨域**，关闭后端所有服务跨域配置，两种实现方案：

1. **代码配置方式（生产首选）**：通过 CorsWebFilter 配置类，精细化配置允许域名、请求方法、请求头、凭证携带、预检缓存时间，稳定性最强、支持复杂场景；

2. **配置文件方式（测试首选）**：YAML 快速开启全局跨域，配置简单、无需编码，适合测试环境快速使用。

核心注意点：开启 Cookie 凭证携带时，禁止使用通配符 *，必须配置具体可信域名；全局过滤器需放行 OPTIONS 预检请求，避免跨域拦截失效。

---

# 本章总结

本章完整完成了 Gateway 核心功能的生产级优化、问题排查与面试复盘，是 Gateway 基础实战体系的收尾章节。核心要点：通过路由模块化、过滤器链路精简、执行顺序固化，实现了网关配置的规范化、高可维护性优化；深入分析了断言与过滤器的性能损耗点，掌握了生产级性能优化方案；针对路由匹配失败、过滤器不生效、跨域失效、路径重写异常四大高频线上问题，形成了标准化的排查与修复方案；同时吃透了 Gateway 路由配置、断言过滤器、自定义过滤器、跨域处理四大核心面试考点。通过本章学习，已完整掌握 Gateway 路由体系、断言体系、过滤器体系、跨域与路径转发、生产优化与问题排错的全链路核心能力，具备独立搭建生产级网关的实战能力。后续章节将基于本章基础，进阶讲解 Gateway 鉴权体系、流量限流、灰度发布、监控告警等高阶实战能力，进一步完善网关高可用架构。