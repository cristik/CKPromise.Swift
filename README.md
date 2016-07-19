 [![Build Status](https://travis-ci.org/cristik/CKPromise.Swift.svg?branch=master)](https://travis-ci.org/cristik/CKPromise.Swift)

# CKPromise.Swift

An Swift attempt to implement the Promises/A+ proposal, with full support for generics, to be able to benefit of Swifts strong type system. Full specs can be found at http://promisesaplus.com/.

The implementation tries to follow the Promise/A+ specs as much as possible, however due to the stong type system of Swift not all could be followed.

The current implementation doesn't yet implement circular promise chain detection, support for this will be added later on.

## Installation

### Via github

1. `git clone https://github.com/cristik/CKPromise.Swift.git`
2. Add the `CKPromise.Swift.xcproject` to your project/workspace
3. Link against the `CKPromise_Swift` target

### Via Cocoapods
1. Add `pod 'CKPromise.Swift'` to your Podfile
2. Run `pod install`

## Usages

Let's see the promises in action. Let's begin with a simple task - sending a 
`NSURLSession` request and parsing the received data into a dictionary.

Firstly, let's extend `NSURLSession` and `NSData` with promises support for
sending a request, and parsing a JSON:

```swift
extension NSURLSession {
    func sendRequest(request: NSURLRequest) -> Promise<NSData,NSError> {
        let promise = Promise<NSData,NSError>()
        let task = self.dataTaskWithRequest(request) { data, urlResponse, error in
            if let error = error {
                // we have an error, means the request failed, reject promise
                promise.reject(error)
            } else if let data = data {
                // we don't have an error and we have data, resolve promise
                promise.resolve(data)
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
}

extension NSData {
    func parseJSON() -> Promise<[NSObject:AnyObject], NSError> {
        let promise = Promise<[NSObject:AnyObject], NSError>()
        if let parsedJSON = try? NSJSONSerialization.JSONObjectWithData(self, options: []),
            let result = parsedJSON as? [NSObject:AnyObject] {
            // yay, we were able to parse, and received a dictionary
            promise.resolve(result)
        } else {
            // :( report an invalid json error
            promise.reject(NSError.invalidJSONError())
        }
        return promise
    }
}
```
which we can use as follows:
```swift
    let request = NSURLRequest(URL: NSURL(string: "https://jsonplaceholder.typicode.com/posts/1")!)
    NSURLSession.sharedSession().sendRequest(request).onSuccess({
        return $0.parseJSON()
    }).onSuccess( {
        print("Parsed JSON: \($0)")
    }).onFailure( {
        print("Failed with error: \($0)")
    })
```
The success callbacks of the `sendRequest` promise returns another promise, a
JSON parsing one, which enables us to nicely chain promises.
If any of the two promises fail, the executino will go straight to the last
failure handler, which helps us as we don't have to write multiple failure
handlers.

This doesn't seems much, so let's add another step: creating a `Post` object from
the parsed dictionary.
Here's a possible implementation of `Post` in regards to promises:
```swift
struct Post {
    private(set) var id: Int = 0
    private(set) var userId: Int = 0
    private(set) var title: String = ""
    private(set) var body: String = ""

    static func fromDictionary(dictionary: [NSObject:AnyObject]) -> Promise<Post,NSError> {
        let promise = Promise<Post,NSError>()
        guard let id = dictionary["id"] as? Int,
            userId = dictionary["userId"] as? Int else {
                promise.reject(NSError.invalidDictionaryError())
                return promise
        }
        var post = Post()
        post.id = id
        post.userId = userId
        post.title = dictionary["title"] as? String ?? ""
        post.body = dictionary["body"] as? String ?? ""

        promise.resolve(post)

        return promise
    }
}
```
Basically we've added support for creating a `Post` from a dictionary in a 
promish way. How we'd make use of this? Well, simple enough:
```swift
let request = NSURLRequest(URL: NSURL(string: "https://jsonplaceholder.typicode.com/posts/1")!)
NSURLSession.sharedSession().sendRequest(request).onSuccess({
        return $0.parseJSON()
    }).onSuccess({
        return Post.fromDictionary($0)
    }).onSuccess({
        print("Parsed post: \($0)")
    }).onFailure( {
        print("Failed with error: \($0)")
    })
```
We can go further and chain promises for as long as we need.

Now, let's go back to `NSURLSession`. Remember the `sendRequest` method? What if
we want to also return the url response along with the data? Not hard at all,
thanks to tuples:
```swift
extension NSURLSession {
    func sendRequest(request: NSURLRequest) -> Promise<(NSURLResponse, NSData),NSError> {
        let promise = Promise<(NSURLResponse, NSData),NSError>()
        let task = self.dataTaskWithRequest(request) { data, urlResponse, error in
            if let error = error {
                promise.reject(error)
            } else if let data = data, urlResponse = urlResponse {
                promise.resolve((urlResponse, data))
            } else {
                promise.reject(NSError.genericError())
            }
        }
        task.resume()
        return promise
    }
}
```
Now, most of the times we'll be sending http requests and it will be nice if we
could make use of the `NSHTTPURLResponse` subclass without having to resort to
downcasting. Something along the lines:
```swift
func sendHTTPRequest(request: NSURLRequest) -> Promise<(NSHTTPURLResponse, NSData),NSError>
```
Well, that's not hard to do, but first we need to tweak a little bit the 
`sendRequest` method:
```swift
extension NSURLSession {
    func sendRequest<T: NSURLResponse)(request: NSURLRequest) -> Promise<(T, NSData),NSError> {
        let promise = Promise<(T, NSData),NSError>()
        let task = self.dataTaskWithRequest(request) { data, urlResponse, error in
            if let error = error {
                promise.reject(error)
            } else if let data = data, urlResponse = urlResponse as? T {
                promise.resolve((urlResponse, data))
            } else {
                promise.reject(NSError.genericError())
            }
        }
        task.resume()
        return promise
    }

    func sendHTTPRequest(request: NSURLRequest) -> Promise<(NSHTTPURLResponse, NSData),NSError> {
        return sendRequest(request)
    }
}
```
Just as simple as that, thanks to the generics support.
But wait, what if the url request doesn't correspond to a http request? We might
want to fail fast in this case, and not even send the request, instead of failing
at the downcast step after receiving the server response. Well, as you guessed,
that's also not hard at all:

func sendHTTPRequest(request: NSURLRequest) -> Promise<(NSHTTPURLResponse, NSData),NSError> {
    guard ["http", "https"].contains(request.url.scheme) else {
        return Promise.rejected(NSError.invalidRequestError())
    }
    return sendRequest(request)
}
```

Another common case for promises is recovering from failures. A contrived
example would be a failed POST on a resource to be retried by a PUT in case of
a failure. How would an scenario like this be implemented:
```swift
let postRequest = NSURLRequest(...)
let putRequest = NSURLRequest(...)
NSURLSession.sharedSession().sendRequest(postRequest).onFailure({
    // if the post request fails, try with a put one
    return NSURLSession.sharedSession().sendRequest(putRequest)
}).onSuccess({
    // we end up here in two cases: either the post request succeeded, or it failed
    // and the put one succeeded
}).onFailure({
    // both requests failed
})
```
Again, the promises allow us to declare the data processing in a linear flow, I'd
day in a more natural one.