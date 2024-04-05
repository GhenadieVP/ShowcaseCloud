import CloudKit
import os
import ComposableArchitecture
import DependenciesAdditions

public struct CloudKitClient: DependencyKey {
    public let checkAccountStatus: CheckAccountStatus
    public let queryProfile: QueryProfile
    public let uploadProfile: UploadProfile
    public let queryAllProfiles: QueryAllProfiles
    public let deleteProfile: DeleteProfile
}

extension CloudKitClient {
    public typealias CheckAccountStatus = () async throws -> CKAccountStatus
    public typealias QueryProfile = (UUID) async throws -> CKRecord?
    public typealias UploadProfile = (Profile) async throws -> CKRecord
    public typealias QueryAllProfiles = () async throws -> [Profile]
    public typealias DeleteProfile = (UUID) async throws -> Void
}

extension CloudKitClient {
    public static let liveValue: CloudKitClient = {

        func fetchProfileRecord(_ id: CKRecord.ID) async throws -> CKRecord {
            return try await CKContainer.default().privateCloudDatabase.record(for: id)
        }

        return .init(
            checkAccountStatus: {
                try await CKContainer.default().accountStatus()
            },
            queryProfile: { id in
                try? await fetchProfileRecord(.init(recordName: id.uuidString))

            },
            uploadProfile: { profile in
                do {
                    // First we have to fetch the existing record and then update.
                    let existingRecord = try await fetchProfileRecord(.init(recordName: profile.id.uuidString))
                    let fileManager = FileManager.default
                    let tempDirectoryURL = fileManager.temporaryDirectory
                    let fileURL = tempDirectoryURL.appendingPathComponent(UUID().uuidString)
                    try! JSONEncoder().encode(profile).write(to: fileURL)

                    existingRecord[.content] = CKAsset(fileURL: fileURL)

                    let record = try await CKContainer.default().privateCloudDatabase.save(existingRecord)
                    try fileManager.removeItem(at: fileURL)
                    return record
                } catch {
                    let err = error as? CKError
                    switch err?.code {
                    case .unknownItem: // Item not in iCloud, create anew
                        do {
                            let fileManager = FileManager.default
                            let tempDirectoryURL = fileManager.temporaryDirectory
                            let fileURL = tempDirectoryURL.appendingPathComponent(UUID().uuidString)
                            try! JSONEncoder().encode(profile).write(to: fileURL)

                            let record = CKRecord(recordType: .profile, recordID: .init(recordName: profile.id.uuidString))
                            record[.content] = CKAsset(fileURL: fileURL)

                            let savedRecord = try await CKContainer.default().privateCloudDatabase.save(record)
                            try fileManager.removeItem(at: fileURL)
                            return savedRecord
                        } catch {
                            throw error
                        }
                    default:
                        break
                    }
                    throw error
                }
            },
            queryAllProfiles: {
                do {
                    let records = try await CKContainer.default().privateCloudDatabase.records(
                        matching: .init(
                            recordType: .profile,
                            predicate: .init(value: true)
                        )
                    )
                    return try records.matchResults.compactMap { try? $0.1.get() }.map { record in
                        guard record.recordType == .profile else {
                            fatalError()
                        }

                        guard let asset = record["Content"] as? CKAsset, let fileURL = asset.fileURL else {
                            fatalError()
                        }

                        let fileManager = FileManager.default
                        let data = try Data(contentsOf: fileURL)

                        let profile = try! JSONDecoder().decode(Profile.self, from: data)
                        return profile
                    }
                } catch {
                    throw error
                }
            },
            deleteProfile: { id in
                try await CKContainer.default().privateCloudDatabase.deleteRecord(withID: .init(recordName: id.uuidString))
            }
        )
    }()


    func save(_ record: CKRecord) async throws {
        try await CKContainer.default().privateCloudDatabase.save(record)
    }
}

extension DependencyValues {
    public var cloudKitClient: CloudKitClient {
        get { self[CloudKitClient.self] }
        set { self[CloudKitClient.self] = newValue }
    }
}

extension Profile {
    var cloudRecord: CKRecord {
        let record = CKRecord(recordType: .profile, recordID: .init(recordName: id.uuidString))
        record[.content] = try! JSONEncoder().encode(self)
        return record
    }
}

extension CKRecord.RecordType {
    static let profile = "ProfileV2"
}

extension CKRecord.FieldKey {
    static let content = "Content"
}

extension CKRecord {
    func decodeProfile() -> Profile {
        guard self.recordType == .profile else {
            fatalError()
        }

        guard let data = self[.content] as? Data else {
            fatalError()
        }

        return try! JSONDecoder().decode(Profile.self, from: data)
    }
}


public struct Account: Identifiable, Codable, Equatable {
    public var id = UUID()
    public var name: String
}

public struct Profile: Identifiable, Codable, Equatable {
    public var id = UUID()
    public var accounts: [Account]
}
