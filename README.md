# 二进制重排（Page Falut）

### 步骤一：如果用git管理的话，就创建一个用于生成link.order文件的分支。

### 步骤二：添加 Build Setting 设置
相关链接：[https://clang.llvm.org/docs/SanitizerCoverage.html](https://clang.llvm.org/docs/SanitizerCoverage.html)

1. Target -> Build Setting -> Custom Complier Flags -> Other C Flags 添加：
```
-fsanitize-coverage=func,trace-pc-guard
```

2. Other Swift Flags 添加：
```
-sanitize-coverage=func
-sanitize=undefined
```

### 步骤三：调用HDBinarySymbol文件里的 hd_startDetection() 函数。
1. swift使用添加桥接文件Bridging-Header。
2. 在你需要二进制重排的地方调用hd_startDetection()，如didFinishLaunching里，或第一个渲染的控制器里的viewDidAppear里。
3. 查看控制台日志：link.order ==== 的path路径。
4. 根据path路径导出link.order文件。

### 步骤四：设置 order file
1. git切回正常分支，把导出的link.order文件存放到项目工程的自定义资源文件夹中，需求重新生成就切回指定分支拉取最新代码重新生成link.order文件。
2. 设置路径：Target -> Build Setting -> Linking -> Order File 
如：${SRCROOT}/YOURProject/Resources/link.order