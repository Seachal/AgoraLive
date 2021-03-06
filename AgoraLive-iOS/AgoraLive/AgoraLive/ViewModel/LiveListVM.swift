//
//  LiveListVM.swift
//  AgoraLive
//
//  Created by CavanSu on 2020/2/21.
//  Copyright © 2020 Agora. All rights reserved.
//

import UIKit
import RxSwift
import RxRelay
import AlamoClient

struct Room {
    var name: String
    var roomId: String
    var imageURL: String
    var personCount: Int
    var imageIndex: Int
    var owner: LiveRole
    
    init(name: String = "", roomId: String, imageURL: String = "", personCount: Int = 0, owner: LiveRole) {
        self.name = name
        self.roomId = roomId
        self.imageURL = imageURL
        self.personCount = personCount
        self.imageIndex = Int(Int64(self.roomId)! % 12)
        self.owner = owner
    }
    
    init(dic: StringAnyDic) throws {
        self.name = try dic.getStringValue(of: "roomName")
        self.roomId = try dic.getStringValue(of: "roomId")
        
        if let personCount = try? dic.getIntValue(of: "currentUsers") {
            self.personCount = personCount
        } else {
            self.personCount = 0
        }
        
        if let imageURL = try? dic.getStringValue(of: "thumbnail") {
            self.imageURL = imageURL
        } else {
            self.imageURL = ""
        }
        
        let ownerJson = try dic.getDictionaryValue(of: "owner")
        self.owner = try LiveRoleItem(dic: ownerJson)
        
        #warning("next version")
        self.imageIndex = Int(Int64(self.roomId)! % 12)
    }
}

class LiveListVM: NSObject {
    fileprivate var multiList = [Room]() {
        didSet {
            switch presentingType {
            case .multi:
                presentingList.accept(multiList)
            default:
                break
            }
        }
    }
    
    fileprivate var singleList = [Room](){
        didSet {
            switch presentingType {
            case .single:
                presentingList.accept(singleList)
            default:
                break
            }
        }
    }
    
    fileprivate var pkList = [Room]() {
        didSet {
            switch presentingType {
            case .pk:
                presentingList.accept(pkList)
            default:
                break
            }
        }
    }
    
    fileprivate var virtualList = [Room]() {
        didSet {
            switch presentingType {
            case .virtual:
                presentingList.accept(virtualList)
            default:
                break
            }
        }
    }
    
    fileprivate var shoppingList = [Room]() {
        didSet {
            switch presentingType {
            case .shopping:
                presentingList.accept(shoppingList)
            default:
                break
            }
        }
    }
    
    var presentingType = LiveType.multi {
        didSet {
            switch presentingType {
            case .multi:
                presentingList.accept(multiList)
            case .single:
                presentingList.accept(singleList)
            case .pk:
                presentingList.accept(pkList)
            case .virtual:
                presentingList.accept(virtualList)
            case .shopping:
                presentingList.accept(shoppingList)
            }
        }
    }
    
    var presentingList = BehaviorRelay(value: [Room]())
}

extension LiveListVM {
    func fetch(count: Int = 10, success: Completion = nil, fail: Completion = nil) {
        guard let lastRoom = self.presentingList.value.last else {
            return
        }
        
        let client = ALCenter.shared().centerProvideRequestHelper()
        let requestListType = presentingType
        let parameters: StringAnyDic = ["nextId": lastRoom.roomId,
                                        "count": count,
                                        "type": requestListType.rawValue]
        
        let url = URLGroup.roomPage
        let event = RequestEvent(name: "room-page")
        let task = RequestTask(event: event,
                               type: .http(.get, url: url),
                               timeout: .low,
                               header: ["token": ALKeys.ALUserToken],
                               parameters: parameters)
        
        let successCallback: DicEXCompletion = { [weak self] (json: ([String: Any])) in
            guard let strongSelf = self else {
                return
            }
            
            let object = try json.getDataObject()
            let jsonList = try object.getValue(of: "list", type: [StringAnyDic].self)
            let list = try [Room](dicList: jsonList)
            
            switch requestListType {
            case .multi:
                strongSelf.multiList.append(contentsOf: list)
            case .single:
                strongSelf.singleList.append(contentsOf: list)
            case .pk:
                strongSelf.pkList.append(contentsOf: list)
            case .virtual:
                strongSelf.virtualList.append(contentsOf: list)
            case .shopping:
                strongSelf.shoppingList.append(contentsOf: list)
            }
            
            if let success = success {
                success()
            }
        }
        let response = ACResponse.json(successCallback)
        
        let retry: ACErrorRetryCompletion = { (error: Error) -> RetryOptions in
            if let fail = fail {
                fail()
            }
            return .resign
        }
        
        client.request(task: task, success: response, failRetry: retry)
    }
    
    func refetch(success: Completion = nil, fail: Completion = nil) {
        let client = ALCenter.shared().centerProvideRequestHelper()
        let requestListType = presentingType
        let currentCount = presentingList.value.count < 10 ? 10 : presentingList.value.count
        let parameters: StringAnyDic = ["count": currentCount,
                                        "type": requestListType.rawValue]
        
        let url = URLGroup.roomPage
        let event = RequestEvent(name: "room-page-refetch")
        let task = RequestTask(event: event,
                               type: .http(.get, url: url),
                               timeout: .low,
                               header: ["token": ALKeys.ALUserToken],
                               parameters: parameters)
        
        let successCallback: DicEXCompletion = { [weak self] (json: ([String: Any])) in
            guard let strongSelf = self else {
                return
            }
            
            try json.getCodeCheck()
            let object = try json.getDataObject()
            let jsonList = try object.getValue(of: "list", type: [StringAnyDic].self)
            let list = try [Room](dicList: jsonList)
            
            switch requestListType {
            case .multi:
                strongSelf.multiList = list
            case .single:
                strongSelf.singleList = list
            case .pk:
                strongSelf.pkList = list
            case .virtual:
                strongSelf.virtualList = list
            case .shopping:
                strongSelf.shoppingList = list
            }
            
            if let success = success {
                success()
            }
        }
        let response = ACResponse.json(successCallback)
        
        let retry: ACErrorRetryCompletion = { (error: Error) -> RetryOptions in
            if let fail = fail {
                fail()
            }
            return .resign
        }
        
        client.request(task: task, success: response, failRetry: retry)
    }
}

fileprivate extension Array where Element == Room {
    init(dicList: [StringAnyDic]) throws {
        var array = [Room]()
        for item in dicList {
            let room = try Room(dic: item)
            array.append(room)
        }
        self = array
    }
}
