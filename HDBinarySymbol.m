//
//  HDBinarySymbol.m
//  HDBinarySymbol
//
//  Created by Hse7enD on 2020/3/9.
//  Copyright © 2020 huyao. All rights reserved.
//

#import "HDBinarySymbol.h"
#import <dlfcn.h>
#import <libkern/OSAtomic.h>

/// 初始化原子队列
static OSQueueHead hd_list = OS_ATOMIC_QUEUE_INIT;

/// 定义节点结构体
typedef struct {
    void *pc; // 存下获取到的PC
    void *next; // 指向下一个节点
} HDNode;

/// 开始检测
void hd_startDetection(void) {
    NSMutableArray *arr = [NSMutableArray array];

    while(true) {
        // 出栈原子队列
        HDNode *node = OSAtomicDequeue(&hd_list, offsetof(HDNode, next));

        // 退出机制
        if (node == NULL) { break; }

        // 获取函数信息
        Dl_info info;
        dladdr(node->pc, &info);
        NSString *sname = [NSString stringWithCString:info.dli_sname encoding:NSUTF8StringEncoding];

        //        NSLog(@"dli_sname === %s \n", info.dli_sname);

        // 处理c函数及block前缀
        BOOL isObjc = [sname hasPrefix:@"+["] || [sname hasPrefix:@"-["];

        // c函数和block需要加 _ 下划线前缀。
        sname = isObjc ? sname : [@"_" stringByAppendingString:sname];

        // 去重
        if (![arr containsObject:sname]) {
            // 因为入栈的时候是从上至下，取出的时候方向是从下至上，那么就需要倒序，直接插在数组头部即可
            [arr insertObject:sname atIndex:0];
        }
    }

    // 去掉当前方法，启动的时候不会用到这个。(当前c函数得加 _ 下划线前缀)
    NSString *currentMethod = [NSString stringWithFormat:@"_%s", __func__];
    if ([arr containsObject:currentMethod]) {
        [arr removeObject:currentMethod];
    }

    // 数组合成字符串
    NSString *funcStr = [arr componentsJoinedByString:@"\n"];

    // 写入文件
    NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"link.order"];
    NSData *fileContents = [funcStr dataUsingEncoding:NSUTF8StringEncoding];
    [[NSFileManager defaultManager] createFileAtPath:filePath contents:fileContents attributes:nil];

    NSLog(@"link.order ==== %@", filePath);
}

/// MARK: - llvm: SanitizerCoverage
/// https://clang.llvm.org/docs/SanitizerCoverage.html
void __sanitizer_cov_trace_pc_guard_init(uint64_t *start, uint64_t *stop) {
    static uint64_t N; // Counter for the guards.

    if (start == stop || *start) return; // Initialize only once.

    // NSLog(@"__sanitizer_cov_trace_pc_guard_init: %p %p \n", start, stop);

    for (uint64_t *x = start; x < stop; x++) {
        *x = ++N; // Guards should start from 1.
    }
}

void __sanitizer_cov_trace_pc_guard(uint32_t *guard) {
    // 方法调用时插入的参数guard为0，默认的函数实现会直接return，导致无法捕获到load方法。
    // if (!*guard) return;

    // NSLog(@"__sanitizer_cov_trace_pc_guard: %p \n", guard);

    void *PC = __builtin_return_address(0);
    
    // 分配内存
    HDNode *node = malloc(sizeof(HDNode));
    *node = (HDNode){PC, NULL};

    // 入栈原子队列
    OSAtomicEnqueue(&hd_list, node, offsetof(HDNode, next));
}

/// MARK: - HDBinarySymbol
@implementation HDBinarySymbol

@end

