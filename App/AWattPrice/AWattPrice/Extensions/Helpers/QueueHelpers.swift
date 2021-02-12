//
//  QueueHelpers.swift
//  AWattPrice
//
//  Created by Léon Becker on 12.02.21.
//

import Foundation

/// Runs the tasks asynchronous if runAsync is true. If not the tasks will be ran synchronous. All tasks are run in in the specified run queue (for example: main queue, the global queue with qos background).
func runQueueSyncOrAsync(
    _ runQueue: DispatchQueue,
    _ runAsync: Bool,
    deadlineIfAsync: DispatchTime? = nil,
    tasks: @escaping () -> ()
) {
    if runAsync {
        if deadlineIfAsync != nil {
            runQueue.asyncAfter(deadline: deadlineIfAsync!) {
                tasks()
            }
        } else {
            runQueue.async {
                tasks()
            }
        }
    } else {
        runQueue.sync {
            tasks()
        }
    }
}

/// Will run the tasks (synchronous or asynchronous) in the specified run queue if the condition is true. Therefor the function runQueueSyncOrAsync is used in the background. If the condition is false the tasks will be ran synchronous in the current queue.
func runInQueueIf(
    isTrue condition: Bool,
    in runQueue: DispatchQueue,
    runAsync: Bool,
    withDeadlineIfAsync: DispatchTime? = nil,
    tasks: @escaping () -> ()
) {
    if condition {
        runQueueSyncOrAsync(runQueue, runAsync, deadlineIfAsync: withDeadlineIfAsync) {
            tasks()
        }
    } else {
        tasks()
    }
}
