//
//  APINotificationInterface.swift
//  AWattPrice
//
//  Created by Léon Becker on 15.08.21.
//

import Foundation

protocol BaseNotificationTask: Encodable {
    associatedtype Payload: NotificationTaskPayload

    var type: NotificationTaskType { get set }
    var payload: Payload { get set }
}


protocol NotificationTaskPayload: Encodable {  }

enum NotificationTaskType: String, Encodable {
    case addToken = "add_token"
}

struct NotificationTask<PayloadType: NotificationTaskPayload>: BaseNotificationTask {
    var type: NotificationTaskType
    var payload: PayloadType
}

struct AddTokenPayload: NotificationTaskPayload {
    var region: Region
    var tax: Bool
}

struct PackedNotificationTasks: Encodable {
    var token: String
    var tasks: [AnyEncodable]
}


class APINotificationInterface {
    var token: String
    var addTokenTasks = [NotificationTask<AddTokenPayload>]()
    
    init(token: String) {
        self.token = token
    }
    
    func addAddTokenTask(payload: AddTokenPayload) {
        let addTokenTask = NotificationTask(type: .addToken, payload: payload)
        addTokenTasks.append(addTokenTask)
    }
    
    func getPackedTasks() -> PackedNotificationTasks? {
        var tasks = [AnyEncodable]()
        tasks.append(contentsOf: addTokenTasks.map { AnyEncodable($0) })
        
        guard !tasks.isEmpty else { return nil }
        
        let packedTasks = PackedNotificationTasks(token: token, tasks: tasks)
        return packedTasks
    }
}
