//
//  Foundation+CKPromise.swift
//  CKPromise.Swift
//
//  Created by Cristian Kocza on 20/07/16.
//  Copyright © 2016 Cristik. All rights reserved.
//

import Foundation

public func promisify<T>(_ call: () throws -> T) -> Promise<T> {
    let promise = Promise<T>()
    do {
        promise.resolve(try call())
    } catch let err {
        promise.reject(err)
    }
    return promise
}

public extension URLSession {
    /// Creates a promise that gets resolved if the request succeeds. A data task
    /// is used for the transfer.
    /// The promise will be rejected under the following circumstances:
    /// - an error occurred
    /// - there is no received data
    /// - the url response could not be casted to the type passed as the generic argument
    func send<T: URLResponse>(request: URLRequest) -> Promise<(T, Data)> {
        return send(request: request, processor: { ($0 as! T, $1) })
    }
    
    func send<R: URLResponse, V>(request: URLRequest, processor: @escaping (R, Data) throws -> V) -> Promise<V> {
        let promise = Promise<V>()
        let task = self.dataTask(with: request) { data, urlResponse, error in
            if let error = error {
                // we have an error, means the request failed, reject promise
                promise.reject(error as NSError)
            } else if let data = data, let urlResponse = urlResponse as? R {
                // we don't have an error and we have data, resolve promise with
                // the processed value
                do {
                    promise.resolve(try processor(urlResponse, data))
                } catch let err {
                    promise.reject(err)
                }
            } else {
                // we have neither error, nor data, report a generic error
                // another approach would have been to resolve the promise
                // with an empty NSData object
                promise.reject(NSError.genericError())
            }
        }
        task.resume()
        return promise
    }
    
    /// Same as sendRequest(), but with a NSHTTPURLResponse
    /// Checks if the url schema is http/https, and if not it rejects the promise
    /// without sending the actual requesst
    func sendHTTP(request: URLRequest) -> Promise<(HTTPURLResponse, Data)> {
        guard let scheme = request.url?.scheme, ["http", "https"].contains(scheme) else {
            return Promise(rejectedWith: NSError.invalidURLRequestError())
        }
        return send(request: request)
    }
}

public extension Data {
    
    func parsedJSON<T>(to: T.Type) throws -> T {
        return try parsedJSON()
    }
    
    /// Tries to parse the JSON represented by itself, and cast the parsed dat
    /// to the generic argument. If the parsing and casting succeed, the promise
    /// is marked as resolved, otherwise it's rejected
    func parsedJSON<T>() throws -> T {
        let parsedJSON = try JSONSerialization.jsonObject(with: self as Data, options: [])
        if let result = parsedJSON as? T {
            return result
        } else {
            throw NSError.castError(from: "\(type(of: parsedJSON))", to: "\(T.self)")
        }
    }
}

/// Some dummy errors
public extension NSError {
    class func genericError() -> NSError {
        return NSError(domain: "GenericErrorDomain", code: -1, userInfo: nil)
    }
    
    class func invalidJSONError() -> NSError {
        return NSError(domain: "InvalidJSONErrorDomain", code: -1, userInfo: nil)
    }
    
    class func invalidURLRequestError() -> NSError {
        return NSError(domain: "InvalidURLRequestErrorDomain", code: -1, userInfo: nil)
    }
    
    class func castError(from: String, to: String) -> NSError {
        return NSError(domain: "CastErrorDomain", code: -1, userInfo:[
            NSLocalizedDescriptionKey: "Cast faile: expected a \(to), received a \(from)"])
    }
}

enum DictionaryExtractError: Error {
    case keyNotFound, typeMismatch
}

public protocol DictionaryInitializable {
    static func from(dictionary: [String:Any]) throws -> Self
}

public extension DictionaryInitializable {
    static func from(dictionaries: [[String:Any]]) throws -> [Self] {
        return try dictionaries.map { try from(dictionary: $0) }
    }
}

public extension Dictionary {
    func extract<T>(_ key: Key) throws -> T {
        guard let value = self[key] else { throw DictionaryExtractError.keyNotFound }
        guard let result = value as? T else { throw DictionaryExtractError.typeMismatch }
        return result
    }
    
    func extract<T>(_ key: Key, defaultValue: T) throws -> T {
        guard let value = self[key] else { return defaultValue }
        guard let result = value as? T else { throw DictionaryExtractError.typeMismatch }
        return result
    }
    
    func extracto<T>(_ key: Key) throws -> T? {
        guard let value = self[key] else { return nil }
        guard let result = value as? T else { throw DictionaryExtractError.typeMismatch }
        return result
    }
}
