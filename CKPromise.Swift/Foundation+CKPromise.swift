//
//  Foundation+CKPromise.swift
//  CKPromise.Swift
//
//  Created by Cristian Kocza on 20/07/16.
//  Copyright © 2016 Cristik. All rights reserved.
//

import Foundation

public extension NSURLSession {
    func sendRequest<T: NSURLResponse>(request: NSURLRequest) -> Promise<(T, NSData), NSError> {
        let promise = Promise<(T, NSData), NSError>()
        let task = self.dataTaskWithRequest(request) { data, urlResponse, error in
            if let error = error {
                // we have an error, means the request failed, reject promise
                promise.reject(error)
            } else if let data = data, urlResponse = urlResponse as? T {
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
    
    func sendHTTPRequest(request: NSURLRequest) -> Promise<(NSHTTPURLResponse, NSData), NSError> {
        guard let scheme = request.URL?.scheme where ["http", "https"].contains(scheme) else {
            return Promise.rejected(NSError.invalidURLRequestError())
        }
        return sendRequest(request)
    }
}

public extension NSData {
    func parseJSON<T>() -> Promise<T, NSError> {
        let promise = Promise<T, NSError>()
        do {
            let parsedJSON = try NSJSONSerialization.JSONObjectWithData(self, options: [])
            if let result = parsedJSON as? T {
                promise.resolve(result)
            } else {
                promise.reject(NSError.castError("\(parsedJSON.dynamicType)", to: "\(T.self)"))
            }
        } catch let err {
            promise.reject(err as NSError)
        }
        return promise
    }
}

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
