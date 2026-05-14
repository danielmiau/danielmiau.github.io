# SpringCloud 知识体系目录
> 个人整理 SpringCloud Alibaba 全套学习笔记，覆盖微服务架构、核心组件、生产实践、拓展专题与面试复盘，循序渐进，适合后端开发复习、面试突击、日常查阅。

---

## 目录总览

| 模块       | 文件                                                         | 备注                                                         |
| :--------- | :----------------------------------------------------------- | :----------------------------------------------------------- |
| 微服务基础 | [01-微服务架构核心概念详解](docs/springCloud/01-微服务架构核心概念详解.md) | 微服务定义、设计理念、架构演进、与单体架构对比               |
| 微服务基础 | [02-SpringCloud全家桶整体认知](docs/springCloud/02-SpringCloud全家桶整体认知.md) | SpringCloud生态概述、版本演进、与SpringBoot关系、Netflix vs Alibaba选型 |
| 微服务基础 | [03-SpringCloud开发环境搭建](docs/springCloud/03-SpringCloud开发环境搭建.md) | 开发环境配置、依赖管理、父工程与公共模块搭建                 |
| 微服务基础 | [04-微服务基础工程搭建实战](docs/springCloud/04-微服务基础工程搭建实战.md) | 多模块项目搭建、统一异常处理、全局返回封装、日志规范         |
| 注册中心   | [05-注册中心原理与主流组件对比](docs/springCloud/05-注册中心原理与主流组件对比.md) | 服务注册发现原理、CAP理论、Eureka/Nacos/Consul对比           |
| 注册中心   | [06-Nacos注册中心实战精讲](docs/springCloud/06-Nacos注册中心实战精讲.md) | Nacos部署、服务注册与发现、健康检查、集群配置                |
| 负载均衡   | [07-Ribbon负载均衡核心原理与实战](docs/springCloud/07-Ribbon负载均衡核心原理与实战.md) | 负载均衡策略、服务实例筛选、超时与重试配置                   |
| 服务调用   | [08-OpenFeign声明式远程调用实战](docs/springCloud/08-OpenFeign声明式远程调用实战.md) | Feign接口定义、请求/响应处理、超时配置、日志配置             |
| 服务调用   | [09-Feign高级优化与踩坑总结](docs/springCloud/09-Feign高级优化与踩坑总结.md) | 请求头传递、异步调用、异常处理、常见报错与解决方案           |
| 熔断限流   | [10-微服务雪崩问题与容错机制原理](docs/springCloud/10-微服务雪崩问题与容错机制原理.md) | 雪崩成因、熔断降级/限流的设计思想、容错模式对比              |
| 熔断限流   | [11-Sentinel核心实战（熔断+降级）](docs/springCloud/11-Sentinel核心实战（熔断+降级）.md) | Sentinel控制台部署、熔断降级规则、热点Key限流                |
| 熔断限流   | [12-Sentinel限流与高级规则配置](docs/springCloud/12-Sentinel限流与高级规则配置.md) | 流控模式、关联限流、系统保护、规则持久化                     |
| API网关    | [13-网关核心思想与Gateway入门](docs/springCloud/13-网关核心思想与Gateway入门.md) | 网关定位、Gateway架构、路由与断言基础                        |
| API网关    | [14-Gateway核心功能实战](docs/springCloud/14-Gateway核心功能实战.md) | 动态路由、过滤器链、跨域配置、统一鉴权、日志处理             |
| API网关    | [15-Gateway高阶实战与优化](docs/springCloud/15-Gateway高阶实战与优化.md) | 限流熔断集成、负载均衡配置、性能调优、集群部署               |
| 配置中心   | [16-Nacos配置中心核心实战](docs/springCloud/16-Nacos配置中心核心实战.md) | 配置中心原理、配置加载与刷新、多环境配置                     |
| 配置中心   | [17-Nacos配置高阶管理](docs/springCloud/17-Nacos配置高阶管理.md) | Namespace/Group/DataId隔离、配置共享、敏感信息加密           |
| 消息驱动   | [18-微服务异步通信与MQ选型](docs/springCloud/18-微服务异步通信与MQ选型.md) | 异步通信优势、消息中间件对比、事务消息与顺序消息             |
| 消息驱动   | [19-SpringCloud Stream核心实战](docs/springCloud/19-SpringCloudStream核心实战.md) | Stream架构、Binder配置、消息生产与消费                       |
| 消息驱动   | [20-Stream高阶与业务解耦实战](docs/springCloud/20-Stream高阶与业务解耦实战.md) | 消息过滤、消息重试、死信队列、业务解耦场景                   |
| 链路追踪   | [21-SkyWalking链路追踪实战](docs/springCloud/21-SkyWalking链路追踪实战.md) | 链路追踪原理、SkyWalking部署、微服务接入、链路查询           |
| 监控运维   | [22-SpringBootAdmin服务监控实战](docs/springCloud/22-SpringBootAdmin服务监控实战.md) | 监控端点配置、服务健康检查、JVM监控、告警配置                |
| 安全认证   | [23-SpringCloud统一认证授权实战](docs/springCloud/23-SpringCloud统一认证授权实战.md) | JWT认证、网关鉴权、权限控制、会话管理                        |
| 容器化部署 | [24-微服务Docker容器化打包](docs/springCloud/24-微服务Docker容器化打包.md) | Dockerfile编写、多阶段构建、镜像优化、本地测试               |
| 集群部署   | [25-微服务集群部署实战](docs/springCloud/25-微服务集群部署实战.md) | 单机多服务部署、端口规划、注册中心集群适配、日志持久化       |
| 综合实战   | [26-SpringCloud全栈综合实战项目](docs/springCloud/26-SpringCloud全栈综合实战项目.md) | 项目需求分析、架构设计、模块拆分、组件整合、调优自测         |
| 生产调优   | [27-SpringCloud生产级性能调优总结](docs/springCloud/27-SpringCloud生产级性能调优总结.md) | 核心组件调优、Feign/Ribbon/Sentinel参数优化、高并发场景方案  |
| 面试复盘   | [28-SpringCloud高频面试题与踩坑手册](docs/springCloud/28-SpringCloud高频面试题与踩坑手册.md) | 核心组件原理问答、架构设计重点、高频报错与解决方案           |
| 拓展专题   | [29-SpringCloud分布式事务解决方案（Seata）](docs/springCloud/29-SpringCloud分布式事务解决方案（Seata）.md) | 分布式事务痛点、Seata原理、AT/TCC/SAGA模式实战               |
| 拓展专题   | [30-SpringCloud灰度发布、蓝绿部署](docs/springCloud/30-SpringCloud灰度发布、蓝绿部署.md) | 发布策略对比、蓝绿部署实现、灰度发布方案、无停机发布流程     |
| 拓展专题   | [31-微服务日志统一收集（ELK）实战](docs/springCloud/31-微服务日志统一收集（ELK）实战.md) | 日志痛点、ELK部署、Filebeat采集、日志查询与可视化            |
| 拓展专题   | [32-SpringCloud Alibaba完整生态对比总结](docs/springCloud/32-SpringCloudAlibaba完整生态对比总结.md) | 生态全景梳理、核心组件解析、与Netflix生态对比、架构选型指南  |

---

## 笔记说明
1.  整体基于 **SpringCloud Alibaba 2021.0.5.0 稳定版本**，适配 SpringBoot 2.7.x/3.x，兼顾历史版本与新版本特性，核心原理与生产实践结合。
2.  笔记整体延续 **「原理+实战+面试」三位一体** 风格，每个章节均包含：概念定义 → 核心原理 → 场景价值 → 实操示例 → 避坑指南 → 面试考点。
3.  内容会持续迭代优化，补充更多生产场景案例与面试真题，适合长期沉淀为个人技术知识库。
