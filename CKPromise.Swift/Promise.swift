//
//  Promise.swift
//  CKPromise.Swift
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
    public func onCompletion<V>(_ handler: @escaping (Result<S>) throws -> V) -> Promise<V> {
        let promise2: Promise<V> = chainedPromise()
        register(success: {
            do {
                try promise2.resolve(handler(Result<S>(value: $0)))
            } catch {
                promise2.reject(error)
            }
        }, failure: {
            do {
                try promise2.resolve(handler(Result<S>(error: $0)))
            } catch {
                promise2.reject(error)
            }
        })
        return promise2
    }
    
    @discardableResult
    public func onCompletion<V>(_ handler: @escaping (Result<S>) throws -> Promise<V>) -> Promise<V> {
        let promise2: Promise<V> = chainedPromise()
        register(success: {
            do {
                try promise2.resolve(handler(Result<S>(value: $0)))
            } catch {
                promise2.reject(error)
            }
        }, failure: {
            do {
                try promise2.resolve(handler(Result<S>(error: $0)))
            } catch {
                promise2.reject(error)
            }
        })
        return promise2
    }
    
    /// Resolves the promise with the given value. Executes all registered
    /// callbacks, in the order they were scheduled
    public func resolve(_ value: S) {
        withLock {
            guard result == nil else { return }
            
            result = .success(value)
            for handler in self.successHandlers {
                self.dispatch(value, handler)
            }
            self.successHandlers.removeAll()
            self.failureHandlers.removeAll()
        }
    }
    
    /// Resolves the promise with the given promise. This makes the receiver
    // take the state of the given promise
    public func resolve(_ promise: Promise<S>) {
        withLock {
            guard result == nil, promise !== self else { return }
            promise.register(success: { self.resolve($0) },
                             failure: { self.reject($0) })
        }
    }
    
    /// Rejects the promise with the given reason. Executes all registered
    /// failure callbacks, in the order they were scheduled
    public func reject(_ reason: Error) {
        withLock {
            guard result == nil else { return }
            
            result = .failure(reason)
            for handler in self.failureHandlers {
                self.dispatch(reason, handler)
            }
            self.successHandlers.removeAll()
            self.failureHandlers.removeAll()
        }
    }
    
    internal func register(success: ((S) -> Void)?,
                           failure: ((Error) -> Void)?) {
        withLock {
            switch result {
            case .none:
                if let success = success { successHandlers.append(success) }
                if let failure = failure { failureHandlers.append(failure) }
            case .some(.success(let value)):
                if let success = success { dispatch(value, success) }
            case let .some(.failure(reason)):
                if let failure = failure { dispatch(reason, failure) }
            }
        }
    }
    
    internal func dispatch<T>(_ arg: T, _ handler: @escaping (T) -> Void) {
        DispatchQueue.main.async {
            handler(arg)
        }
    }
    
    private func withLock<T>(_ f: () -> T) -> T {
        pthread_mutex_lock(&mutex)
        defer { pthread_mutex_unlock(&mutex) }
        return f()
    }
}
