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
    private let privQueue: dispatch_queue_t
    private var successHandlers: [(S) -> Void] = []
    private var failureHandlers: [(E) -> Void] = []
    
    /// Creates a pending promise
    public required init() {
        privQueue = dispatch_queue_create("", DISPATCH_QUEUE_SERIAL)
    }
    
    /// Creates a fulfilled promise
    public class func fulfilled(value: S) -> Promise{
        let promise = Promise()
        promise.resolve(value)
        return promise
    }
    
    /// Creates a rejected promise
    public class func rejected(reason: E) -> Promise {
        let promise = Promise()
        promise.reject(reason)
        return promise
    }
    
    /// This is the `then` method. It allows clients to observe the promise's
    /// result - either success or failure.
    /// The success/failure handlers are dispatched on the main thread, in an
    /// async manner, thus after the current runloop cycle ends
    /// Returns a promise that gets fulfilled with the result of the 
    /// success/failure callback
    public func on<V>(success success: (S) -> V, failure: (E) -> V) -> Promise<V,E> {
        let promise2 = Promise<V,E>()
        dispatch_sync(privQueue) {[unowned self] in
            self.registerSuccess({ promise2.resolve(success($0)) })
            self.registerFailure({ promise2.resolve(failure($0)) })
        }
        return promise2
    }
    
    /// Returns a promise that gets fulfilled with the result of the
    /// success/failure callback.
    public func on<V>(success success: (S) -> Promise<V,E>, failure: (E) -> Promise<V,E>) -> Promise<V,E> {
        let promise2 = Promise<V,E>()
        dispatch_sync(privQueue) {[unowned self] in
            self.registerSuccess({ promise2.resolve(success($0)) })
            self.registerFailure({ promise2.resolve(failure($0)) })
        }
        return promise2
    }
    
    /// Returns a promise that gets fulfilled with the result of the
    /// success callback
    public func onSuccess<V>(success: (S) -> V) -> Promise<V,E> {
        let promise2 = Promise<V,E>()
        dispatch_sync(privQueue) {[unowned self] in
            self.registerSuccess({ promise2.resolve(success($0)) })
            self.registerFailure({ promise2.reject($0) })
        }
        return promise2
    }
    
    /// Returns a promise that gets fulfilled with the result of the
    /// success callback
    public func onSuccess<V>(success: (S) -> Promise<V,E>) -> Promise<V,E> {
        let promise2 = Promise<V,E>()
        dispatch_sync(privQueue) {[unowned self] in
            self.registerSuccess({ promise2.resolve(success($0)) })
            self.registerFailure({ promise2.reject($0) })
        }
        return promise2
    }
       
    /// Registers a failure callback. The returned promise gets resolved with
    /// the value returned by the callback
    public func onFailure(failure: (E) -> S) -> Promise<S,E> {
        let promise2 = Promise<S,E>()
        dispatch_sync(privQueue) {[unowned self] in
            self.registerSuccess({ promise2.resolve($0) })
            self.registerFailure({ promise2.resolve(failure($0)) })
        }
        return promise2
    }
    
    /// Registers a failure callback. The returned promise gets resolved with
    /// the value returned by the callback
    public func onFailure(failure: (E) -> Promise<S,E>) -> Promise<S,E> {
        let promise2 = Promise<S,E>()
        dispatch_sync(privQueue) {[unowned self] in
            self.registerSuccess({ promise2.resolve($0) })
            self.registerFailure({ promise2.resolve(failure($0)) })
        }
        return promise2
    }
    
    /// Resolves the promise with the given value. Executes all registered  
    /// callbacks, in the order they were scheduled
    public func resolve(value: S) {
        guard case .pending = state else {
            return
        }
        dispatch_sync(privQueue) {[unowned self] in
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
    public func resolve(promise: Promise<S,E>) {
        guard case .pending = state else {
            return
        }
        if  promise === self {
            return
        }
        dispatch_sync(privQueue) {[unowned self] in
            promise.registerSuccess({ self.resolve($0) })
            promise.registerFailure({ self.reject($0) })
        }
    }
    
    /// Rejects the promise with the given reason. Executes all registered
    /// failure callbacks, in the order they were scheduled
    public func reject(reason: E) {
        guard case .pending = state else {
            return
        }
        dispatch_sync(privQueue) {[unowned self] in
            self.state = .rejected(reason)
            for handler in self.failureHandlers {
                self.dispatch(reason, handler)
            }
            self.successHandlers.removeAll()
            self.failureHandlers.removeAll()
        }
    }
}

extension Promise {
    /// Returns a promise that waits for the gived promises to either success
    /// or fail. Reports success if at least one of the promises succeeded, and
    /// failure if all of them failed.
    public static func when<S2,E2>(promises: [Promise<S2,E2>]) -> Promise<[S2],E2> {
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
            promise.registerSuccess({
                remainingPromises -= 1
                values.append($0);
                check()
            })
            promise.registerFailure({
                remainingPromises -= 1
                errors.append($0);
                check()
            })
        }
        return promise2
    }
}

extension Promise {
    private func registerSuccess(handler: (S)->Void) {
        switch state {
        case .pending: successHandlers.append(handler)
        case .fulfilled(let value): dispatch(value, handler)
        case .rejected: break
        }
    }
    
    private func registerFailure(handler: (E)->Void) {
        switch state {
        case .pending: failureHandlers.append(handler)
        case .fulfilled: break
        case .rejected(let reason): dispatch(reason, handler)
        }
    }
    
    
    private func dispatch<T>(arg: T, _ handler: (T) -> Void) {
        dispatch_async(dispatch_get_main_queue()) {
            handler(arg)
        }
    }
}

internal enum PromiseState<S,E> {
    case pending
    case fulfilled(S)
    case rejected(E)
}
