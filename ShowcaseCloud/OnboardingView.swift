//
//  WelcomeFeature.swift
//  ShowcaseCloud
//
//  Created by Ghenadie Vasiliev-Pusca on 07.02.2024.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct OnboardingView {
    @ObservableState
    struct State: Equatable {
        enum Path: Equatable {
            case welcome
            case newProfile
            case restoreFromBackup
        }
        
        var firstAccountName: String = ""
        var root: Path = .welcome
        
        var availableBackups: [Profile] = []
        var isFetchingBackups: Bool = false
        var selectedBackup: Profile? = nil
    }
    
    enum Action {
        case newProfileTapped
        case restoreFromBackupTapped
        case createNewProfile
        case firstAccountNameChanged(String)
        case selectedProfileBackup(Profile)
        case confirmedSelectedBackup
        
        case fetchAvailableBackups(TaskResult<[Profile]>)
        
        case completeWithProfile(Profile)
    }
    
    @Dependency(\.userDefaults) var userDefaults
    @Dependency(\.cloudKitClient) var cloudKitClient
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .newProfileTapped:
            state.root = .newProfile
            return .none
        case .restoreFromBackupTapped:
            state.root = .restoreFromBackup
            state.isFetchingBackups = true
            return .run { send in
                let result = await TaskResult { try await cloudKitClient.queryAllProfiles() }
                await send(.fetchAvailableBackups(result))
            }
        case .createNewProfile:
            let profile = Profile(accounts: [.init(name: state.firstAccountName)])
            return .run { send in
                try userDefaults.set(JSONEncoder().encode(profile), forKey: "activeProfile")
                await send(.completeWithProfile(profile))
            }
        case let .firstAccountNameChanged(name):
            state.firstAccountName = name
            return .none
            
        case let .fetchAvailableBackups(.success(profiles)):
            state.isFetchingBackups = false
            state.availableBackups = profiles
            return .none
            
        case .fetchAvailableBackups:
            return .none
        case .completeWithProfile:
            return .none
        case let .selectedProfileBackup(profile):
            state.selectedBackup = profile
            return .none
        case .confirmedSelectedBackup:
            guard let selectedBackup = state.selectedBackup else {
                return .none
            }
            return .run { send in
                try userDefaults.set(JSONEncoder().encode(selectedBackup), forKey: "activeProfile")
                await send(.completeWithProfile(selectedBackup))
            }
        }
    }
}

extension OnboardingView {
    struct View: SwiftUI.View {
        let store: StoreOf<OnboardingView>
        
        var body: some SwiftUI.View {
            switch store.root {
            case .welcome:
                welcomeView()
            case .newProfile:
                createProfileView()
            case .restoreFromBackup:
                restoreFromBackup()
            }
        }
        
        private func welcomeView() -> some SwiftUI.View {
            VStack {
                Spacer()
                Text("Welcome to the cloud it POC")
                Spacer()
                Button("New Profile") {
                    store.send(.newProfileTapped, animation: .smooth)
                }.buttonStyle(.borderedProminent)
                Button("Restore from backup") {
                    store.send(.restoreFromBackupTapped)
                }.buttonStyle(.borderedProminent)
            }
        }
        
        private func createProfileView() -> some SwiftUI.View {
            VStack {
                Spacer()
                Text("Create your first profile")
                TextField("First account name", text: .init(get: {
                    store.firstAccountName
                }, set: { name in
                    store.send(.firstAccountNameChanged(name))
                }))
                .textFieldStyle(.roundedBorder)
                
                Spacer()
                Button("Continue") {
                    store.send(.createNewProfile)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        
        private func restoreFromBackup() -> some SwiftUI.View {
            VStack {
                Spacer()
                Text("List of available Backups")
                if store.isFetchingBackups {
                    Spacer()
                    ProgressView()
                    Text("Fetching backups")
                    Spacer()
                    
                } else {
                    List(store.availableBackups) { profile in
                        Section {
                            ForEach(profile.accounts) {
                                Text($0.name)
                            }
                        } header: {
                            HStack {
                                Text(profile.id.uuidString)
                                if profile.id == store.selectedBackup?.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .onTapGesture {
                                store.send(.selectedProfileBackup(profile))
                            }
                        }
                    }
                }
                Button("Continue") {
                    store.send(.confirmedSelectedBackup)
                }.buttonStyle(.borderedProminent)
            }
        }
    }
}
