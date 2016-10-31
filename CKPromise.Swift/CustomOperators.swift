//
//  CustomOperators.swift
//  Pods
//
//  Created by Cristian Kocza on 29/10/2016.
//
//

infix operator »: BindPrecedence
infix operator »+: BindPrecedence
infix operator »-: BindPrecedence

public func »<T,U>(lhs:T?, rhs: (T) throws -> U) throws -> U? {
    guard let lhs = lhs else { return nil }
    return try rhs(lhs)
}

public func »<T,U>(lhs: [T], rhs: (T) throws -> U) throws -> [U] {
    return try lhs.map(rhs)
}

@discardableResult
public func »<T,U>(lhs: Promise<T>, rhs: @escaping (Result<T>) -> U) -> Promise<U> {
    return lhs.onCompletion(rhs)
}

public func »+<T,U>(lhs: Promise<T>, rhs: @escaping (T) -> Promise<U>) -> Promise<U> {
    return lhs.onSuccess(rhs)
}

public func »+<T,U>(lhs: Promise<T>, rhs: @escaping (T) -> U) -> Promise<U> {
    return lhs.onSuccess(rhs)
}

public func »-<T>(lhs: Promise<T>, rhs: @escaping (Error) -> Promise<T>) -> Promise<T> {
    return lhs.onFailure(rhs)
}

@discardableResult
public func »-<T>(lhs: Promise<T>, rhs: @escaping (Error) -> T) -> Promise<T> {
    return lhs.onFailure(rhs)
}

