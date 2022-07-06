//
//  Middleware.swift
//  UnidirectionalFlow
//
//  Created by Majid Jabrayilov on 23.06.22.
//
public protocol Middleware<State, Action, Dependencies> {
    associatedtype State
    associatedtype Action
    associatedtype Dependencies
    
    func process(
        state: State,
        with action: Action,
        using dependencies: Dependencies
    ) async -> Action?
}

struct SendableMiddleware<State, Action, Dependencies>: Middleware {
    let closure: @Sendable (State, Action, Dependencies) async -> Action?
    
    func process(state: State, with action: Action, using dependencies: Dependencies) async -> Action? {
        await closure(state, action, dependencies)
    }
}
