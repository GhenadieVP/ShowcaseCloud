import ComposableArchitecture
import SwiftUI
import DependenciesAdditions
import CloudKit

@Reducer
struct ProfileFeature {
    @ObservableState
    struct State: Equatable {
        var profile: Profile
        var fetchingProfile: Bool = false
        var isUploadingProfileBackup: Bool = false
        var iCloudStatus: String?
        
        var lastBackupTime: String?
    }
    
    enum Action {
        case task
        case addDummyAccount
        case deleteProfileTapped
        case logoutTapped
        
        case profileUploadResult(TaskResult<CKRecord>)
        case accountStatus(TaskResult<CKAccountStatus>)
        case cloudRecordStatus(TaskResult<CKRecord?>)
        case logout
    }
    
    @Dependency(\.cloudKitClient) var cloudKitClient
    @Dependency(\.userDefaults) var userDefaults
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .task:
            return .run { [id = state.profile.id] send in
                let status = await TaskResult { try await cloudKitClient.checkAccountStatus() }
                
                let cloudRecord = await TaskResult { try await cloudKitClient.queryProfile(id) }
                
                await send(.accountStatus(status))
                await send(.cloudRecordStatus(cloudRecord))
            }
            
        case let .accountStatus(.success(status)):
            switch status {
            case .couldNotDetermine:
                state.iCloudStatus = "Could not determine"
            case .available:
                state.iCloudStatus = "Available"
            case .restricted:
                state.iCloudStatus = "Retricted"
            case .noAccount:
                state.iCloudStatus = "No Account"
            case .temporarilyUnavailable:
                state.iCloudStatus = "Temporarily Unavailable"
            @unknown default:
                state.iCloudStatus = "Uknown"
            }
            return .none
        case .accountStatus:
            state.iCloudStatus = "Failed to determine"
            return .none
            
        case let .cloudRecordStatus(.success(.some(record))):
            state.lastBackupTime = record.modificationDate?.formatted() ?? "--"
            return .none
        case .cloudRecordStatus:
            state.lastBackupTime = "--"
            return .none
        case .addDummyAccount:
            state.profile.accounts.append(.init(name: "Acccount \(UUID().uuidString)"))
            
            return uploadProfileBackup(&state)
        case let .profileUploadResult(.success(record)):
            state.lastBackupTime = record.modificationDate?.formatted() ?? "--"
            state.isUploadingProfileBackup = false
            return .none
            
        case .profileUploadResult:
            state.isUploadingProfileBackup = false
            return .none
            
        case .deleteProfileTapped:
            userDefaults.removeValue(forKey: "activeProfile")
            return .run { [id = state.profile.id] send in
                try await cloudKitClient.deleteProfile(id)
                await send(.logout)
            }
        case .logoutTapped:
            userDefaults.removeValue(forKey: "activeProfile")
            return .send(.logout)
            
        case .logout:
            return .none
        }
    }
    
    private func uploadProfileBackup(_ state: inout State) -> Effect<Action> {
        state.isUploadingProfileBackup = true
        return .run { [profile = state.profile] send in
            let result = await TaskResult {
                try await cloudKitClient.uploadProfile(profile)
            }
            await send(.profileUploadResult(result))
        }
    }
}

extension ProfileFeature {
    struct View: SwiftUI.View {
        let store: StoreOf<ProfileFeature>
        
        var body: some SwiftUI.View {
            VStack {
                HStack {
                    Text("iCloud status: ")
                    if let iCloudStatus = store.iCloudStatus {
                        Text(iCloudStatus)
                    } else {
                        ProgressView()
                    }
                    Spacer()
                }
                HStack {
                    Text("Last Backup: ")
                    if let lastBackupTime = store.lastBackupTime, !store.isUploadingProfileBackup {
                        Text(lastBackupTime)
                    } else {
                        ProgressView()
                    }
                    Spacer()
                }
                if store.fetchingProfile {
                    VStack {
                        ProgressView()
                        Text("Fetching profile from iCloud")
                    }
                } else {
                    if store.isUploadingProfileBackup {
                        VStack {
                            ProgressView()
                            Text("Uploading backup to iCloud")
                        }
                    }
                    
                    
                    List(store.profile.accounts) {
                        Text($0.name)
                    }
                    
                    Button("Add dummy account") {
                        store.send(.addDummyAccount)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Delete Profile") {
                        store.send(.deleteProfileTapped)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Logout") {
                        store.send(.logoutTapped)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    // Toggle("iCloud sync", isOn: .constant(true))
                }
            }
            .padding()
            .task {
                store.send(.task)
            }
        }
    }
}
