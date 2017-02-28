//
//  Promise+Additions.swift
//  Pods
//
//  Created by Cristian Kocza on 06/11/2016.
//
//

import Foundation

public extension Promise {
    
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
            promise.register(success: {
                remainingPromises -= 1
                values.append($0);
                check()
            }, failure: {
                remainingPromises -= 1
                errors.append($0);
                check()
            })
        }
        return promise2
    }
    
    /// Returns a promise that gets fulfilled with the result of the
    /// success callback
    @discardableResult
    public func onSuccess<V>(_ success: @escaping (S) throws -> V) -> Promise<V> {
        let promise2: Promise<V> = chainedPromise()
        register(success: {
            do {
                try promise2.resolve(success($0))
            } catch let error {
                promise2.reject(error)
            }
        }, failure: { promise2.reject($0) })
        return promise2
    }
    
    /// Returns a promise that gets fulfilled with the result of the
    /// success callback
    @discardableResult
    public func onSuccess<V>(_ success: @escaping (S) throws -> Promise<V>) -> Promise<V> {
        let promise2: Promise<V> = chainedPromise()
        register(success: {
            do {
                try promise2.resolve(success($0))
            } catch let error {
                promise2.reject(error)
            }
        }, failure: { promise2.reject($0) })
        return promise2
    }
    
    /// Registers a failure callback. The returned promise gets resolved with
    /// the value returned by the callback
    @discardableResult
    public func onFailure(_ failure: @escaping (Error) throws -> S) -> Promise<S> {
        let promise2: Promise<S> = chainedPromise()
        register(success: { promise2.resolve($0) },
                 failure: {
                    do {
                        try promise2.resolve(failure($0))
                    } catch let error {
                        promise2.reject(error)
                    }
        })
        return promise2
    }
    
    /// Registers a failure callback. The returned promise gets resolved with
    /// the value returned by the callback
    @discardableResult
    public func onFailure(_ failure: @escaping (Error) throws -> Promise<S>) -> Promise<S> {
        let promise2: Promise<S> = chainedPromise()
        register(success: { promise2.resolve($0) },
                 failure: {
            do {
                try promise2.resolve(failure($0))
            } catch let error {
                promise2.reject(error)
            }
        })
        return promise2
    }
    
    /// Registers a failure callback. This overload doesn't return another promise,
    /// and is useful at the end of the chain
    @discardableResult
    public func onFailure(_ failure: @escaping (Error) throws -> Void) {
        let promise2: Promise<S> = chainedPromise()
        register(success: nil, failure: {
            do {
                try failure($0)
            } catch let error {
                promise2.reject(error)
            }
        })
    }
    
    @discardableResult
    public func onFailure(_ failure: @escaping () throws -> Void) {
        let promise2: Promise<S> = chainedPromise()
        register(success: nil, failure: { _ in
            do {
                try failure()
            } catch let error {
                promise2.reject(error)
            }
        })
    }
}
