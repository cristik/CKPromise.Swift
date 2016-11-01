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
open class Promise<S> {
    internal var result: Result<S>?
    private var mutex = pthread_mutex_t()
    private var successHandlers: [(S) -> Void] = []
    private var failureHandlers: [(Error) -> Void] = []
    
    /// Creates a pending promise
    public init() {
        var attr = pthread_mutexattr_t()
        guard pthread_mutexattr_init(&attr) == 0,
            pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_NORMAL) == 0,
            pthread_mutex_init(&mutex, &attr) == 0 else {
                preconditionFailure()
        }
    }
    
    deinit {
        pthread_mutex_destroy(&mutex)
    }
    
    public static func fulfilled(with value: S) -> Promise {
        return Promise(fulfilledWith: value)
    }
    
    public static func rejected(with reason: Error) -> Promise {
        return Promise(rejectedWith: reason)
    }
    
    /// Creates a fulfilled promise
    public convenience init(fulfilledWith value: S) {
        self.init()
        result = .success(value)
    }
    
    /// Creates a rejected promise
    public convenience init(rejectedWith reason: Error) {
        self.init()
        result = .failure(reason)
    }
    
    /// Returns a promise that waits for the gived promises to either success
    /// or fail. Reports success if at least one of the promises succeeded, and
    /// failure if all of them failed.
    public static func when<S2>(all promises: [Promise<S2>]) -> Promise<[S2]> {
        let promise2 = Promise<[S2]>()
        var remainingPromises: Int = promises.count
        var values = [S2]()
        var errors = [Error]()
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
    
    /// Helper method for derived promises. This method is called when
    /// a chained promise needs to be constructed, instead of directly calling
    /// the promise constructor
    open func chainedPromise<V>() -> Promise<V> {
        return Promise<V>()
    }
    
    /// This is the `then` method. It allows clients to observe the promise's
    /// result - either success or failure.
    /// The success/failure handlers are dispatched on the main thread, in an
    /// async manner, thus after the current runloop cycle ends
    /// Returns a promise that gets fulfilled with the result of the
    /// success/failure callback
    @discardableResult
    public func on<V>(success: @escaping (S) throws -> V, failure: @escaping (Error) throws -> V) -> Promise<V> {
        pthread_mutex_lock(&mutex)
        defer { pthread_mutex_unlock(&mutex) }
        
        let promise2: Promise<V> = chainedPromise()
        registerSuccess {
            do {
                try promise2.resolve(success($0))
            } catch let error {
                promise2.reject(error)
            }
        }
        
        registerFailure {
            do {
                try promise2.resolve(failure($0))
            } catch let error {
                promise2.reject(error)
            }
        }
        
        return promise2
    }
    
    @discardableResult
    public func on<V>(success: @escaping (S) throws -> Promise<V>, failure: @escaping (Error) throws -> V) -> Promise<V> {
        pthread_mutex_lock(&mutex)
        defer { pthread_mutex_unlock(&mutex) }
        
        let promise2: Promise<V> = chainedPromise()
        registerSuccess {
            do {
                try promise2.resolve(success($0))
            } catch let error {
                promise2.reject(error)
            }
        }
        registerFailure {
            do {
                try promise2.resolve(failure($0))
            } catch let error {
                promise2.reject(error)
            }
        }
        return promise2
    }
    
    @discardableResult
    public func on<V>(success: @escaping (S) throws -> V, failure: @escaping (Error) throws -> Promise<V>) -> Promise<V> {
        pthread_mutex_lock(&mutex)
        defer { pthread_mutex_unlock(&mutex) }
        
        let promise2: Promise<V> = chainedPromise()
        registerSuccess {
            do {
                try promise2.resolve(success($0))
            } catch let error {
                promise2.reject(error)
            }
        }
        registerFailure {
            do {
                try promise2.resolve(failure($0))
            } catch let error {
                promise2.reject(error)
            }
        }
        return promise2
    }
    
    /// Returns a promise that gets fulfilled with the result of the
    /// success/failure callback.
    @discardableResult
    public func on<V>(success: @escaping (S) throws -> Promise<V>, failure: @escaping (Error) throws -> Promise<V>) -> Promise<V> {
        pthread_mutex_lock(&mutex)
        defer { pthread_mutex_unlock(&mutex) }
        
        let promise2: Promise<V> = chainedPromise()
        registerSuccess {
            do {
                try promise2.resolve(success($0))
            } catch let error {
                promise2.reject(error)
            }
        }
        registerFailure {
            do {
                try promise2.resolve(failure($0))
            } catch let error {
                promise2.reject(error)
            }
        }
        return promise2
    }
    
    /// Returns a promise that gets fulfilled with the result of the
    /// success callback
    @discardableResult
    public func onSuccess<V>(_ success: @escaping (S) throws -> V) -> Promise<V> {
        pthread_mutex_lock(&mutex)
        defer { pthread_mutex_unlock(&mutex) }
        
        let promise2: Promise<V> = chainedPromise()
        registerSuccess {
            do {
                try promise2.resolve(success($0))
            } catch let error {
                promise2.reject(error)
            }
        }
        registerFailure { promise2.reject($0) }
        return promise2
    }
    
    /// Returns a promise that gets fulfilled with the result of the
    /// success callback
    @discardableResult
    public func onSuccess<V>(_ success: @escaping (S) throws -> Promise<V>) -> Promise<V> {
        pthread_mutex_lock(&mutex)
        defer { pthread_mutex_unlock(&mutex) }
        
        let promise2: Promise<V> = chainedPromise()
        registerSuccess {
            do {
                try promise2.resolve(success($0))
            } catch let error {
                promise2.reject(error)
            }
        }
        registerFailure { promise2.reject($0) }
        return promise2
    }
    
    /// Registers a failure callback. The returned promise gets resolved with
    /// the value returned by the callback
    @discardableResult
    public func onFailure(_ failure: @escaping (Error) throws -> S) -> Promise<S> {
        pthread_mutex_lock(&mutex)
        defer { pthread_mutex_unlock(&mutex) }
        
        let promise2: Promise<S> = chainedPromise()
        registerSuccess { promise2.resolve($0) }
        registerFailure {
            do {
                try promise2.resolve(failure($0))
            } catch let error {
                promise2.reject(error)
            }
        }
        return promise2
    }
    
    /// Registers a failure callback. The returned promise gets resolved with
    /// the value returned by the callback
    @discardableResult
    public func onFailure(_ failure: @escaping (Error) throws -> Promise<S>) -> Promise<S> {
        pthread_mutex_lock(&mutex)
        defer { pthread_mutex_unlock(&mutex) }
        
        let promise2: Promise<S> = chainedPromise()
        registerSuccess { promise2.resolve($0) }
        registerFailure {
            do {
                try promise2.resolve(failure($0))
            } catch let error {
                promise2.reject(error)
            }
        }
        return promise2
    }
    
    /// Registers a failure callback. Returns nothing, this is an helper to be
    // used at the end of promise chains
    @discardableResult
    public func onFailure(_ failure: @escaping (Error) throws -> Void) {
        pthread_mutex_lock(&mutex)
        defer { pthread_mutex_unlock(&mutex) }
        
        registerFailure { try? failure($0) }
    }
    
    /// Registers a callback that is called in both promise resolutions
    @discardableResult
    public func onCompletion<V>(_ handler: @escaping (Result<S>) throws -> V) -> Promise<V> {
        let promise2: Promise<V> = chainedPromise()
        registerSuccess {
            do {
                try promise2.resolve(handler(Result<S>(value: $0)))
            } catch {
                promise2.reject(error)
            }
        }
        registerFailure {
            do {
                try promise2.resolve(handler(Result<S>(error: $0)))
            } catch {
                promise2.reject(error)
            }
        }
        return promise2
    }
    
    @discardableResult
    public func onCompletion<V>(_ handler: @escaping (Result<S>) throws -> Promise<V>) -> Promise<V> {
        let promise2: Promise<V> = chainedPromise()
        registerSuccess {
            do {
                try promise2.resolve(handler(Result<S>(value: $0)))
            } catch {
                promise2.reject(error)
            }
        }
        registerFailure {
            do {
                try promise2.resolve(handler(Result<S>(error: $0)))
            } catch {
                promise2.reject(error)
            }
        }
        return promise2
    }
    
    /// Resolves the promise with the given value. Executes all registered
    /// callbacks, in the order they were scheduled
    public func resolve(_ value: S) {
        pthread_mutex_lock(&mutex)
        defer { pthread_mutex_unlock(&mutex) }
        
        guard result == nil else { return }
        
        result = .success(value)
        for handler in self.successHandlers {
            self.dispatch(value, handler)
        }
        self.successHandlers.removeAll()
        self.failureHandlers.removeAll()
    }
    
    /// Resolves the promise with the given promise. This makes the receiver
    // take the state of the given promise
    public func resolve(_ promise: Promise<S>) {
        pthread_mutex_lock(&mutex)
        defer { pthread_mutex_unlock(&mutex) }
        
        guard result == nil, promise !== self else { return }
        
        promise.registerSuccess { self.resolve($0) }
        promise.registerFailure { self.reject($0) }
    }
    
    /// Rejects the promise with the given reason. Executes all registered
    /// failure callbacks, in the order they were scheduled
    public func reject(_ reason: Error) {
        pthread_mutex_lock(&mutex)
        defer { pthread_mutex_unlock(&mutex) }
        
        guard result == nil else { return }
        
        result = .failure(reason)
        for handler in self.failureHandlers {
            self.dispatch(reason, handler)
        }
        self.successHandlers.removeAll()
        self.failureHandlers.removeAll()
    }
    
    private func registerSuccess(handler: @escaping (S)->Void) {
        switch result {
        case .none: successHandlers.append(handler)
        case .some(.success(let value)): dispatch(value, handler)
        case .some(.failure): break
        }
    }
    
    private func registerFailure(handler: @escaping (Error)->Void) {
        switch result {
        case .none: failureHandlers.append(handler)
        case .some(.success): break
        case .some(.failure(let reason)): dispatch(reason, handler)
        }
    }
    
    
    private func dispatch<T>(_ arg: T, _ handler: @escaping (T) -> Void) {
        DispatchQueue.main.async {
            handler(arg)
        }
    }
}
