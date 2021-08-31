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
    case update
}

struct NotificationTask<PayloadType: NotificationTaskPayload>: BaseNotificationTask {
    var type: NotificationTaskType
    var payload: PayloadType
}

enum NotificationType: String, Encodable {
    case priceBelow = "price_below"
}

protocol SubDesubNotificationInfo: Encodable {  }

protocol UpdatedNotificationData: Encodable {
    func anyDataUpdated() -> Bool
}

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

struct SubDesubPayload<InfoType: SubDesubNotificationInfo>: NotificationTaskPayload {
    var notificationType: NotificationType
    var active: Bool
    var notificationInfo: InfoType
    
    enum CodingKeys: String, CodingKey {
        case active
        case notificationType = "notification_type"
        case notificationInfo = "notification_info"
    }
}

// Update task

enum UpdateSubject: String, Encodable {
    case general
    case priceBelow = "price_below"
}

struct UpdatePayload<UpdatedDataType: UpdatedNotificationData>: NotificationTaskPayload {
    var subject: UpdateSubject
    var updatedData: UpdatedDataType
    
    enum CodingKeys: String, CodingKey {
        case subject
        case updatedData = "updated_data"
    }
}

struct UpdatedPriceBelowNotificationData: UpdatedNotificationData {
    var belowValue: Int?
    
    enum CodingKeys: String, CodingKey {
        case belowValue = "below_value"
    }
    
    func anyDataUpdated() -> Bool {
        if belowValue != nil {
            return true
        } else {
            return false
        }
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
    private var priceBelowUpdateTask: NotificationTask<UpdatePayload<UpdatedPriceBelowNotificationData>>?
    
    init(token: String) {
        self.token = token
    }
    
    func addAddTokenTask(_ payload: AddTokenPayload, overwrite: Bool = true) {
        guard overwrite == true || addTokenTask == nil else { return }
        addTokenTask = NotificationTask(type: .addToken, payload: payload)
    }
    
    func addPriceBelowSubDesubTask(_ payload: SubDesubPayload<SubDesubPriceBelowNotificationInfo>) {
        priceBelowSubDesubTask = NotificationTask(type: .subscribeDesubscribe, payload: payload)
    }
    
    func addPriceBelowUpdateTask(_ payload: UpdatePayload<UpdatedPriceBelowNotificationData>) {
        priceBelowUpdateTask = NotificationTask(type: .update, payload: payload)
    }

    func getPackedTasks() -> PackedNotificationTasks {
        var tasks = [AnyEncodable]()
        addTokenTask.map { tasks.append(AnyEncodable($0)) }
        priceBelowSubDesubTask.map { tasks.append(AnyEncodable($0)) }
        priceBelowUpdateTask.map { tasks.append(AnyEncodable($0)) }
        
        let packedTasks = PackedNotificationTasks(token: token, tasks: tasks)
        return packedTasks
    }
}
