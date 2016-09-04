//
//  CKPromise.swift
//  CKPromise
//
//  Created by Cristian Kocza on 06/06/16.
//  Copyright © 2016 Cristik. All rights reserved.
//

import Dispatch

/// A promise represents the eventual result of an asynchronous operation.
/// The primary way of interacting with a promise is through its `then` method,
/// which registers callbacks to receive either a promise’s eventual value or
/// the reason why the promise cannot be fulfilled.
public final class Promise<S, E> {
    internal var state: PromiseState<S,E> = .pending
    private let privQueue: DispatchQueue
    private var successHandlers: [(S) -> Void] = []
    private var failureHandlers: [(E) -> Void] = []
    
    /// Creates a pending promise
    public required init() {
        privQueue = DispatchQueue(label: "CKPromise.Swift")
    }
    
    /// Creates a fulfilled promise
    public convenience init(fulfilledWith value: S) {
        self.init()
        state = .fulfilled(value)
    }
    
    /// Creates a rejected promise
    public convenience init(rejectedWith reason: E) {
        self.init()
        state = .rejected(reason)
    }
    
    /// Returns a promise that waits for the gived promises to either success
    /// or fail. Reports success if at least one of the promises succeeded, and
    /// failure if all of them failed.
    public static func whenAll<S2,E2>(promises: [Promise<S2,E2>]) -> Promise<[S2],E2> {
        let promise2 = Promise<[S2],E2>()
        var remainingPromises: Int = promises.count
        var values = [S2]()
        var errors = [E2]()
        let check = {
            if remainingPromises == 0 {
                if promises.count > 0 && errors.count == promises.count {
                    promise2.reject(errors.first!)
                } else {
                    promise2.resolve(values)
                }
            }
        }
        for promise in promises {
            promise.registerSuccess {
                remainingPromises -= 1
                values.append($0);
                check()
            }
            promise.registerFailure {
                remainingPromises -= 1
                errors.append($0);
                check()
            }
        }
        return promise2
    }
    
    /// This is the `then` method. It allows clients to observe the promise's
    /// result - either success or failure.
    /// The success/failure handlers are dispatched on the main thread, in an
    /// async manner, thus after the current runloop cycle ends
    /// Returns a promise that gets fulfilled with the result of the
    /// success/failure callback
    @discardableResult
    public func on<V>(success: @escaping (S) -> V, failure: @escaping (E) -> V) -> Promise<V,E> {
        let promise2 = Promise<V,E>()
        privQueue.sync {
            self.registerSuccess { promise2.resolve(success($0)) }
            self.registerFailure { promise2.resolve(failure($0)) }
        }
        return promise2
    }
    
    @discardableResult
    public func on<V>(success: @escaping (S) -> Promise<V,E>, failure: @escaping (E) -> V) -> Promise<V,E> {
        let promise2 = Promise<V,E>()
        privQueue.sync {
            self.registerSuccess { promise2.resolve(success($0)) }
            self.registerFailure { promise2.resolve(failure($0)) }
        }
        return promise2
    }
    
    @discardableResult
    public func on<V>(success: @escaping (S) -> V, failure: @escaping (E) -> Promise<V,E>) -> Promise<V,E> {
        let promise2 = Promise<V,E>()
        privQueue.sync {
            self.registerSuccess { promise2.resolve(success($0)) }
            self.registerFailure { promise2.resolve(failure($0)) }
        }
        return promise2
    }
    
    /// Returns a promise that gets fulfilled with the result of the
    /// success/failure callback.
    @discardableResult
    public func on<V>(success: @escaping (S) -> Promise<V,E>, failure: @escaping (E) -> Promise<V,E>) -> Promise<V,E> {
        let promise2 = Promise<V,E>()
        privQueue.sync {
            self.registerSuccess { promise2.resolve(success($0)) }
            self.registerFailure { promise2.resolve(failure($0)) }
        }
        return promise2
    }
    
    /// Returns a promise that gets fulfilled with the result of the
    /// success callback
    @discardableResult
    public func onSuccess<V>(_ success: @escaping (S) -> V) -> Promise<V,E> {
        let promise2 = Promise<V,E>()
        privQueue.sync {
            self.registerSuccess { promise2.resolve(success($0)) }
            self.registerFailure { promise2.reject($0) }
        }
        return promise2
    }
    
    /// Returns a promise that gets fulfilled with the result of the
    /// success callback
    @discardableResult
    public func onSuccess<V>(_ success: @escaping (S) -> Promise<V,E>) -> Promise<V,E> {
        let promise2 = Promise<V,E>()
        privQueue.sync {
            self.registerSuccess { promise2.resolve(success($0)) }
            self.registerFailure { promise2.reject($0) }
        }
        return promise2
    }
    
    /// Registers a failure callback. The returned promise gets resolved with
    /// the value returned by the callback
    @discardableResult
    public func onFailure(_ failure: @escaping (E) -> S) -> Promise<S,E> {
        let promise2 = Promise<S,E>()
        privQueue.sync {
            self.registerSuccess { promise2.resolve($0) }
            self.registerFailure { promise2.resolve(failure($0)) }
        }
        return promise2
    }
    
    /// Registers a failure callback. The returned promise gets resolved with
    /// the value returned by the callback
    @discardableResult
    public func onFailure(_ failure: @escaping (E) -> Promise<S,E>) -> Promise<S,E> {
        let promise2 = Promise<S,E>()
        privQueue.sync {
            self.registerSuccess { promise2.resolve($0) }
            self.registerFailure { promise2.resolve(failure($0)) }
        }
        return promise2
    }
    
    /// Registers a failure callback. Returns nothing, this is an helper to be
    // used at the end of promise chains
    public func onFailure(failure: @escaping (E) -> Void) {
        privQueue.sync {
            self.registerFailure { failure($0) }
        }
    }
    
    /// Resolves the promise with the given value. Executes all registered
    /// callbacks, in the order they were scheduled
    public func resolve(_ value: S) {
        privQueue.sync {
            guard case .pending = self.state else { return }
            
            self.state = .fulfilled(value)
            for handler in self.successHandlers {
                self.dispatch(value, handler)
            }
            self.successHandlers.removeAll()
            self.failureHandlers.removeAll()
        }
    }
    
    /// Resolves the promise with the given promise. This makes the receiver
    // take the state of the given promise
    public func resolve(_ promise: Promise<S,E>) {
        privQueue.sync {
            guard case .pending = self.state, promise !== self else { return }
            
            promise.registerSuccess { self.resolve($0) }
            promise.registerFailure { self.reject($0) }
        }
    }
    
    /// Rejects the promise with the given reason. Executes all registered
    /// failure callbacks, in the order they were scheduled
    public func reject(_ reason: E) {
        privQueue.sync {
            guard case .pending = self.state else { return }
            self.state = .rejected(reason)
            for handler in self.failureHandlers {
                self.dispatch(reason, handler)
            }
            self.successHandlers.removeAll()
            self.failureHandlers.removeAll()
        }
    }
    
    private func registerSuccess(handler: @escaping (S)->Void) {
        switch state {
        case .pending: successHandlers.append(handler)
        case .fulfilled(let value): dispatch(value, handler)
        case .rejected: break
        }
    }
    
    private func registerFailure(handler: @escaping (E)->Void) {
        switch state {
        case .pending: failureHandlers.append(handler)
        case .fulfilled: break
        case .rejected(let reason): dispatch(reason, handler)
        }
    }
    
    
    private func dispatch<T>(_ arg: T, _ handler: @escaping (T) -> Void) {
        DispatchQueue.main.async {
            handler(arg)
        }
    }
}

internal enum PromiseState<S,E> {
    case pending
    case fulfilled(S)
    case rejected(E)
}
