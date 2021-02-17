//
//  QueueHelpers.swift
//  AWattPrice
//
//  Created by Léon Becker on 12.02.21.
//

import Foundation

/// Run task asynchronous in queue if condition is true. Optionally parse deadline - is only used if condition is true, as tasks are only then run asynchronous.
func runAsyncInQueueIf(
    isTrue condition: Bool,
    in runQueue: DispatchQueue,
    withDeadline deadline: DispatchTime? = nil,
    tasks: @escaping () -> ()
) {
    if condition {
        if deadline != nil {
            runQueue.asyncAfter(deadline: deadline!) {
                tasks()
            }
        } else {
            runQueue.async {
                tasks()
            }
        }
    } else {
        tasks()
    }
}
