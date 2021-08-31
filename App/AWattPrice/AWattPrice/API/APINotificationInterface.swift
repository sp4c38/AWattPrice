//
//  APINotificationInterface.swift
//  AWattPrice
//
//  Created by Léon Becker on 15.08.21.
//

import Foundation

// General protocols

protocol BaseNotificationTask: Encodable {
    associatedtype Payload: NotificationTaskPayload

    var type: NotificationTaskType { get set }
    var payload: Payload { get set }
}


protocol NotificationTaskPayload: Encodable {  }

enum NotificationTaskType: String, Encodable {
    case addToken = "add_token"
    case subscribeDesubscribe = "subscribe_desubscribe"
}

struct NotificationTask<PayloadType: NotificationTaskPayload>: BaseNotificationTask {
    var type: NotificationTaskType
    var payload: PayloadType
}

protocol SubDesubNotificationInfo: Encodable {  }

// Add token task

struct AddTokenPayload: NotificationTaskPayload {
    var region: Region
    var tax: Bool
}

// Subscribe and desubscribe task

struct SubDesubPriceBelowNotificationInfo: SubDesubNotificationInfo {
    var belowValue: Int
    
    enum CodingKeys: String, CodingKey {
        case belowValue = "below_value"
    }
}

enum NotificationType: String, Encodable {
    case priceBelow = "price_below"
}

struct SubDesubPayload<InfoType: SubDesubNotificationInfo>: NotificationTaskPayload {
    var notificationType: NotificationType
    var subElseDesub: Bool
    var notificationInfo: InfoType
    
    enum CodingKeys: String, CodingKey {
        case notificationType = "notification_type"
        case subElseDesub = "sub_else_desub"
        case notificationInfo = "notification_info"
    }
}

// Notification task wrappers

struct PackedNotificationTasks: Encodable {
    var token: String
    var tasks: [AnyEncodable]
}


class APINotificationInterface {
    private var token: String
    private var addTokenTask: NotificationTask<AddTokenPayload>?
    private var priceBelowSubDesubTask: NotificationTask<SubDesubPayload<SubDesubPriceBelowNotificationInfo>>?
    
    init(token: String) {
        self.token = token
    }
    
    func addAddTokenTask(_ payload: AddTokenPayload, overwrite: Bool = true) {
        guard overwrite == true || addTokenTask == nil else { return }
        addTokenTask = NotificationTask(type: .addToken, payload: payload)
    }
    
    func addPriceBelowSubDesubTask(_ payload: SubDesubPayload<SubDesubPriceBelowNotificationInfo>, overwrite: Bool = true) {
        guard overwrite == true || priceBelowSubDesubTask == nil else { return }
        priceBelowSubDesubTask = NotificationTask(type: .subscribeDesubscribe, payload: payload)
    }

    func getPackedTasks() -> PackedNotificationTasks {
        var tasks = [AnyEncodable]()
        addTokenTask.map { tasks.append(AnyEncodable($0)) }
        priceBelowSubDesubTask.map { tasks.append(AnyEncodable($0)) }
        
        let packedTasks = PackedNotificationTasks(token: token, tasks: tasks)
        return packedTasks
    }
}
