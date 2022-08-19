//
//  CloudKitModel.swift
//  PoC-MyTasks
//
//  Created by Leandro Rodrigues on 18/08/22.
//

import Foundation
import CloudKit

public protocol CloudKitModelProtocol {
    init?(record: CKRecord)
    var record: CKRecord { get }
}
