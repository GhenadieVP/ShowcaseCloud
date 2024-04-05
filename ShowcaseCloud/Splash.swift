//
//  Splash.swift
//  ShowcaseCloud
//
//  Created by Ghenadie Vasiliev-Pusca on 06.02.2024.
//
import SwiftUI
import ComposableArchitecture
import CloudKit

@Reducer
struct SplashFeature {
    @ObservableState
    struct State: Equatable {
        var accountStatus: CKAccountStatus?
        
        init(accountStatus: CKAccountStatus? = nil) {
            self.accountStatus = accountStatus
        }
    }
    
    
    enum Action {
        case task
        case statusResult(CKAccountStatus)
        case completeWithProfile(Profile?)
    }
    
    @Dependency(\.userDefaults) var userDefaults
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .task:
            guard let profileData = userDefaults.data(forKey: "activeProfile") else {
                return .send(.completeWithProfile(nil))
            }
            
            return .send(.completeWithProfile(try! JSONDecoder().decode(Profile.self, from: profileData)))
        case let .statusResult(status):
            state.accountStatus = status
            return .none
        case .completeWithProfile:
            return .none
        }
    }
}

extension SplashFeature {
    struct View: SwiftUI.View {
        let store: StoreOf<SplashFeature>
        
        var body: some SwiftUI.View {
            ProgressView()
                .task {
                    store.send(.task)
                }
        }
    }
}
