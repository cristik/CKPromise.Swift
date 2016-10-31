//
//  Functional.swift
//  Pods
//
//  Created by Cristian Kocza on 23/10/2016.
//
//

precedencegroup BindPrecedence {
    associativity: left
    higherThan: BitwiseShiftPrecedence
}

precedencegroup FunctionCompositionPrecedence {
    associativity: right
    higherThan: BindPrecedence
}

infix operator »=: BindPrecedence
infix operator ∘: FunctionCompositionPrecedence

public func ∘<T,U,V>(f: @escaping (T) -> U, g: @escaping (U) -> V) -> (T) -> V {
    return { g(f($0)) }
}

public func »=<T,U>(lhs:T?, rhs: (T) -> U?) -> U? {
    guard let lhs = lhs else { return nil }
    return rhs(lhs)
}

public func »=<T,U>(lhs: [T], rhs: (T) -> [U]) -> [U] {
    return lhs.flatMap(rhs)
}

public func »=<T,U>(lhs: Result<T>, rhs: (T) -> Result<U>) -> Result<U> {
    return lhs.flatMap(transform: rhs)
}

public func »=<T,U>(lhs: Promise<T>, rhs: @escaping (Result<T>) -> Promise<U>) -> Promise<U> {
    return lhs.onCompletion(rhs)
}
