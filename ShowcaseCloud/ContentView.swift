//
//  ContentView.swift
//  ShowcaseCloud
//
//  Created by Ghenadie Vasiliev-Pusca on 06.02.2024.
//

import SwiftUI
import ComposableArchitecture

@Reducer
struct MainFeature {
    struct State: Equatable {
        @PresentationState public var destination: Destination.State?
        
        init(destination: Destination.State? = nil) {
            self.destination = destination
        }
        
        init() {
            self.init(destination: .splash(.init()))
        }
    }
    
    @Reducer
    public struct Destination {
        public enum State: Equatable {
            case splash(SplashFeature.State)
            case profile(ProfileFeature.State)
            case onboarding(OnboardingView.State)
        }
        
        public enum Action {
            case splash(SplashFeature.Action)
            case profile(ProfileFeature.Action)
            case onboarding(OnboardingView.Action)
        }
        
        public var body: some ReducerOf<Self> {
            Scope(state: \.splash, action: \.splash) {
                SplashFeature()
            }
            Scope(state: \.profile, action: \.profile) {
                ProfileFeature()
            }
            Scope(state: \.onboarding, action: \.onboarding) {
                OnboardingView()
            }
        }
    }
    
    enum Action {
        case destination(PresentationAction<Destination.Action>)
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .destination(.presented(.splash(.completeWithProfile(profile)))):
                if let profile {
                    state.destination = .profile(.init(profile: profile))
                } else {
                    state.destination = .onboarding(.init())
                }
                
                return .none
            case let .destination(.presented(.onboarding(.completeWithProfile(profile)))):
                state.destination = .profile(.init(profile: profile))
                return .none
                
            case .destination(.presented(.profile(.logout))):
                state.destination = .onboarding(.init())
                return .none
            case .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination) {
            Destination()
        }
    }
}

extension MainFeature {
    struct View: SwiftUI.View {
        let store: StoreOf<MainFeature>
        
        var body: some SwiftUI.View {
            Group {
                IfLetStore(
                    self.store.scope(state: \.destination?.splash, action: \.destination.splash),
                    then: SplashFeature.View.init(store:)
                )
                
                IfLetStore(
                    self.store.scope(state: \.destination?.onboarding, action: \.destination.onboarding),
                    then: OnboardingView.View.init(store:)
                )
                
                IfLetStore(
                    self.store.scope(state: \.destination?.profile, action: \.destination.profile),
                    then: ProfileFeature.View.init(store:)
                )
            }
        }
    }
}
