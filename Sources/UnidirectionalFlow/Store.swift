//
//  Store.swift
//  UnidirectionalFlow
//
//  Created by Majid Jabrayilov on 11.06.22.
//
import Foundation
import Combine

/// Type that stores the state of the app or feature.
@MainActor @dynamicMemberLookup public final class Store<State, Action>: ObservableObject {
    /// The current state of the store
    @Published private var state: State

    private let reducer: any Reducer<State, Action>
    private let middlewares: any Collection<any Middleware<State, Action>>
    private var subscribers = Set<AnyCancellable>()

    /// Creates an instance of `Store` with the folowing parameters.
    public init(
        initialState state: State,
        reducer: some Reducer<State, Action>,
        middlewares: some Collection<any Middleware<State, Action>>,
        publishers: some Collection<AnyPublisher<Action, Never>>
    ) {
        self.state = state
        self.reducer = reducer
        self.middlewares = middlewares

        for publisher in publishers {
            publisher.sink { action in
                Task { await self.send(action) }
            }
            .store(in: &subscribers)
        }
    }
    
    /// A subscript providing access the state of the store.
    public subscript<T>(dynamicMember keyPath: KeyPath<State, T>) -> T {
        state[keyPath: keyPath]
    }
    
    /// Use this method to mutate the state of the store by feeding actions.
    public func send(_ action: Action) async {
        state = reducer.reduce(oldState: state, with: action)

        await withTaskGroup(of: Optional<Action>.self) { group in
            middlewares.forEach { middleware in
                _ = group.addTaskUnlessCancelled {
                    await middleware.process(state: self.state, with: action)
                }
            }
            
            for await case let nextAction? in group where !Task.isCancelled {
                await send(nextAction)
            }
        }
    }
}

extension Store {
    /// Use this method to create another `Store` deriving from the current one.
    public func derived<DerivedState: Equatable, DerivedAction: Equatable>(
        deriveState: @escaping (State) -> DerivedState,
        deriveAction: @escaping (DerivedAction) -> Action
    ) -> Store<DerivedState, DerivedAction> {
        let derived = Store<DerivedState, DerivedAction>(
            initialState: deriveState(state),
            reducer: IdentityReducer(),
            middlewares: [
                SendableMiddleware { _, action in
                    await self.send(deriveAction(action))
                    return nil
                }
            ],
            publishers: []
        )
        
        $state
            .map(deriveState)
            .removeDuplicates()
            .assign(to: &derived.$state)
        
        return derived
    }
}

import SwiftUI

extension Store {
    /// Use this method to create a `SwiftUI.Binding` from any instance of `Store`.
    public func binding<Value>(
        extract: @escaping (State) -> Value,
        embed: @escaping (Value) -> Action
    ) -> Binding<Value> {
        .init(
            get: { extract(self.state) },
            set: { newValue in Task { await self.send(embed(newValue)) } }
        )
    }
}
