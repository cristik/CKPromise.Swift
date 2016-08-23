//
//  Foundation+CKPromise.swift
//  CKPromise.Swift
//
//  Created by Cristian Kocza on 20/07/16.
//  Copyright © 2016 Cristik. All rights reserved.
//

import Foundation

public extension URLSession {
    /// Creates a promise that gets resolved if the request succeeds. A data task
    /// is used for the transfer.
    /// The promise will be rejected under the following circumstances:
    /// - an error occurred
    /// - there is no received data
    /// - the url response could not be casted to the type passed as the generic argument
    func sendRequest<T: URLResponse>(request: URLRequest) -> Promise<(T, Data), Error> {
        let promise = Promise<(T, Data), Error>()
        let task = self.dataTask(with: request) { data, urlResponse, error in
            if let error = error {
                // we have an error, means the request failed, reject promise
                promise.reject(error as NSError)
            } else if let data = data, let urlResponse = urlResponse as? T {
                // we don't have an error and we have data, resolve promise
                promise.resolve((urlResponse, data))
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
    func sendHTTPRequest(request: URLRequest) -> Promise<(HTTPURLResponse, Data), Error> {
        guard let scheme = request.url?.scheme, ["http", "https"].contains(scheme) else {
            return Promise.rejected(reason: NSError.invalidURLRequestError())
        }
        return sendRequest(request: request)
    }
}

public extension Data {
    /// Tries to parse the JSON represented by itself, and cast the parsed dat
    /// to the generic argument. If the parsing and casting succeed, the promise
    /// is marked as resolved, otherwise it's rejected
    func parseJSON<T>() -> Promise<T, NSError> {
        let promise = Promise<T, NSError>()
        do {
            let parsedJSON = try JSONSerialization.jsonObject(with: self as Data, options: [])
            if let result = parsedJSON as? T {
                promise.resolve(result)
            } else {
                promise.reject(NSError.castError(from: "\(type(of: parsedJSON))", to: "\(T.self)"))
            }
        } catch let err {
            promise.reject(err as NSError)
        }
        return promise
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
