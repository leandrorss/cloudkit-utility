//
//  CloudKitUtility.swift
//
//  Created by Leandro Rodrigues on 18/08/22.
//

import Foundation
import CloudKit
import Combine

public class CloudKitUtility { }

extension CloudKitUtility {
    // MARK: - iCloud Status
    static public func getiCloudStatus() -> Future<Bool, Error> {
        Future { promise in
            CKContainer.default().accountStatus { status, error in
                switch status {
                case .available:
                    promise(.success(true))
                case .couldNotDetermine:
                    promise(.failure(CloudKitError.iCloudAccountNotDetermined))
                case .restricted:
                    promise(.failure(CloudKitError.iCloudAccountRestricted))
                case .noAccount:
                    promise(.failure(CloudKitError.iCloudAccountNotFound))
                case .temporarilyUnavailable:
                    promise(.failure(CloudKitError.iCloudAccountTemporarilyUnavailable))
                default:
                    promise(.failure(CloudKitError.iCloudAccountUnknown))
                }
            }
        }
    }
    
    // MARK: - Permission
    public static func requestApplicationPermission(permission: CKApplicationPermissions) -> Future<Bool, Error> {
        Future { promise in
            CKContainer.default().requestApplicationPermission(permission.value) { status, error in
                if status == .granted {
                    promise(.success(true))
                } else {
                    promise(.failure(CloudKitApplicationPermissionError.notGranted))
                }
            }
        }
    }
    
    // MARK: - User
    static func fetchiCloudUserRecordID(completion: @escaping (Result<CKRecord.ID, Error>) -> Void)  {
        CKContainer.default().fetchUserRecordID { userId, error in
            if let userId = userId {
                completion(.success(userId))
            } else {
                completion(.failure(CloudKitFetchRecordError.iCloudCouldNotFetchUserRecordID))
            }
        }
    }
    
    // MARK: - Helpers & Errors
    struct CKContainerApplicationPermission {
        var permission: CKContainer.ApplicationPermissions
    }
    
    public enum CKApplicationPermissions {
        case userDiscoverability
        
        var value: CKContainer.ApplicationPermissions {
            switch self {
            case .userDiscoverability:
                return .userDiscoverability
            }
        }
    }
    
    enum CloudKitApplicationPermissionError: String, LocalizedError {
        case notGranted
    }
    
    enum CloudKitFetchRecordError: String, LocalizedError {
        case iCloudCouldNotFetchUserRecordID
    }
    
    enum CloudKitError: String, LocalizedError {
        case iCloudAccountNotDetermined
        case iCloudAccountNotFound
        case iCloudAccountRestricted
        case iCloudAccountUnknown
        case iCloudAccountTemporarilyUnavailable
    }
    
    public enum CloudKitDatabase {
        case publicData
        case privateData
        case sharedData
    }
    
}

extension CloudKitUtility {
    // MARK: -- CRUD
    
    // Create
    static public func add<T: CloudKitModelProtocol>(
        item: T,
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        // Save to CloudKit
        save(record: item.record, completion: completion)
    }
    
    // Update
    static public func update<T: CloudKitModelProtocol>(
        item: T,
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        add(item: item, completion: completion)
    }
    
    static private func save(record: CKRecord, completion: @escaping (Result<Bool, Error>) -> Void) {
        CKContainer.default().publicCloudDatabase.save(record) { record, error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(true))
            }
        }
    }
    
    // Read
    public struct CloudKitRequestQuery {
        let predicate: NSPredicate
        let recordType: CKRecord.RecordType
        let sortDescriptor: [NSSortDescriptor]?
        let resultsLimit: Int?
        let database: CloudKitDatabase
        let zoneName: String
        
        public init(
            predicate: NSPredicate,
            recordType: CKRecord.RecordType,
            sortDescriptor: [NSSortDescriptor]? = nil,
            resultsLimit: Int? = nil,
            database: CloudKitDatabase = .publicData,
            zoneName: String = CKRecordZone.default().zoneID.zoneName
        ) {
            self.predicate = predicate
            self.recordType = recordType
            self.sortDescriptor = sortDescriptor
            self.resultsLimit = resultsLimit
            self.database = database
            self.zoneName = zoneName
        }
    }
    
    static private func createOperation(
        requestQuery: CloudKitRequestQuery
    ) -> CKQueryOperation {
        let query = CKQuery(recordType: requestQuery.recordType, predicate: requestQuery.predicate)
        query.sortDescriptors = requestQuery.sortDescriptor
        let queryOperation = CKQueryOperation(query: query)
        if let limit = requestQuery.resultsLimit {
            queryOperation.resultsLimit = limit
        }
        
        let ckRecordZoneID = CKRecordZone(zoneName: requestQuery.zoneName)
        queryOperation.zoneID = ckRecordZoneID.zoneID
        
        return queryOperation
    }
    
    static private func getDatabase(cloudkitDatabase: CloudKitDatabase) -> CKDatabase.Scope {
        switch cloudkitDatabase {
        case .privateData:
            return .private
        case .publicData:
            return .public
        case .sharedData:
            return .shared
        }
    }
    
    static public func fetch<T: CloudKitModelProtocol> (
        requestQuery: CloudKitRequestQuery
    ) -> Future<[T], Error> {
        Future { promise in
            CloudKitUtility.fetch(requestQuery: requestQuery) { (items: [T]) in
                promise(.success(items))
            }
        }
    }
    
    static private func fetch<T: CloudKitModelProtocol>(requestQuery: CloudKitRequestQuery, completion: @escaping (_ items: [T]) -> ()) {
        // Creating operation
        let operation = createOperation(requestQuery: requestQuery)
        
        var returnedItems: [T] = []
        // Getting items from query
        addRecordMatchedBlock(operation: operation) { item in
            returnedItems.append(item)
        }
        // Query completion
        addQueryResultBlock(operation: operation) { finished in
            completion(returnedItems)
        }
        // Execute operation
        add(operation: operation, database: requestQuery.database)
    }
    
    static private func addRecordMatchedBlock<T: CloudKitModelProtocol>(
        operation: CKQueryOperation, completion: @escaping (_ item: T) -> ()) {
            if #available(iOS 15.0, *) {
                operation.recordMatchedBlock = { (record, result) in
                    switch result {
                    case .success(let record):
                        guard let item = T(record: record) else { return }
                        completion(item)
                    case .failure(let error):
                        print("Error addRecordMatchedBlock: \(error.localizedDescription)")
                        break
                    }
                }
            } else {
                operation.recordFetchedBlock = { record in
                    guard let item = T(record: record) else { return }
                    completion(item)
                }
            }
        }
    
    static private func addQueryResultBlock(operation: CKQueryOperation, completion: @escaping (_ finished: Bool) -> ()) {
        if #available(iOS 15.0, *) {
            operation.queryResultBlock = { result in
                completion(true)
            }
        } else {
            operation.queryCompletionBlock = { cursor, error in
                completion(true)
            }
        }
    }
    
    static private func add(operation: CKDatabaseOperation, database: CloudKitDatabase) {
        switch database {
        case .publicData:
            CKContainer.default().publicCloudDatabase.add(operation)
        case .privateData:
            CKContainer.default().privateCloudDatabase.add(operation)
        case .sharedData:
            CKContainer.default().sharedCloudDatabase.add(operation)
        }
        
    }
    
    // Delete
    static func delete<T: CloudKitModelProtocol>(item: T) -> Future<Bool, Error> {
        Future { promise in
            CloudKitUtility.delete(record: item.record, completion: promise)
        }
    }
    
    static private func delete(record: CKRecord, completion: @escaping (Result<Bool, Error>) -> Void) {
        CKContainer.default().publicCloudDatabase.delete(withRecordID: record.recordID) { record, error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(true))
            }
        }
    }
}
