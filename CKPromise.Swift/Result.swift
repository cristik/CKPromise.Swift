//
//  Result.swift
//  Pods
//
//  Created by Cristian Kocza on 27/10/2016.
//
//

public enum Result<T> {
    public typealias MT = T
    
    case success(T)
    case failure(Error)
    
    public init(value: T) {
        self = .success(value)
    }
    
    public init(error: Error) {
        self = .failure(error)
    }
    
    public init(closure: () throws -> T) {
        do {
            self = try .success(closure())
        } catch let error {
            self = .failure(error)
        }
    }
    
    public func flatMap<U>(transform: (T) -> Result<U>) -> Result<U> {
        switch self {
        case .success(let value): return transform(value)
        case .failure(let error): return .failure(error)
        }
    }
    
    public func map<U>(transform: (T) throws -> U) -> Result<U>{
        switch self {
        case .success(let value): return Result<U> { try transform(value) }
        case .failure(let error): return .failure(error)
        }
    }
    
    public var value: T? {
        get {
            guard case .success(let value) = self else { return nil }
            return value
        }
    }
    
    public var error: Error? {
        get {
            guard case .failure(let error) = self else { return nil }
            return error
        }
    }
}
