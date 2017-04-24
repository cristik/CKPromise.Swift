//
//  CKPromiseTests.swift
//  CKPromiseTests
//
//  Created by Cristian Kocza on 06/06/16.
//  Copyright © 2016 Cristik. All rights reserved.
//

import XCTest
@testable import CKPromise_Swift

extension Result: Equatable {}

/// Just for testing purposes
public func ==<S>(lhs: Result<S>, rhs: Result<S>) -> Bool {
    return String(stringInterpolationSegment: lhs) == String(stringInterpolationSegment: rhs)
}

extension String: Error {}

class CKPromiseTests: XCTestCase {
    let promise = Promise<Int>()
    
    func testNewlyCreatedPromiseIsInPendingState() {
        XCTAssertNil(promise.result)
    }
    
    // 2.1.1 When pending, a promise:
    // 2.1.1.1 may transition to either the fulfilled or rejected state.
    func testResolvedPromiseIsInFulfilledState() {
        promise.resolve(5)
        XCTAssertEqual(Result<Int>.success(5), promise.result)
    }

    // 2.1.1 When pending, a promise:
    // 2.1.1.1 may transition to either the fulfilled or rejected state.
    func testRejectedPromiseIsInRejecteState() {
        promise.reject("a")
        XCTAssertEqual(Result<Int>.failure("a"), promise.result)
    }
    
    // 2.1.2 When fulfilled, a promise:
    // 2.1.2.1 must not transition to any other state.
    // 2.1.2.1 must have a value, which must not change.
    func testResolvingAgainKeepsInResolved() {
        promise.resolve(5)
        promise.resolve(6)
        switch promise.result {
        case .some(.success(let value)):
            XCTAssertEqual(value, 5)
            break
        default:
            XCTFail()
        }
    }
    
    func testRejectingAfteResolvingKeepsInResolved() {
        promise.resolve(5)
        promise.reject("a")
        switch promise.result {
        case .some(.success(let value)):
            XCTAssertEqual(value, 5)
            break
        default:
            XCTFail()
        }
    }
    
    // 2.1.3 When rejected, a promise:
    // 2.1.3.1 must not transition to any other state.
    // 2.1.3.2 must have a reason, which must not change.
    func testRejectingAgainKeepsInRejected() {
        promise.reject("a")
        promise.reject("b")
        switch promise.result {
        case .some(.failure(let reason)):
            XCTAssertEqual(reason as? String, "a")
            break
        default:
            XCTFail()
        }
    }
    
    func testResolvingAfterRejectingKeepsInRejected() {
        promise.reject("a")
        promise.resolve(1)
        switch promise.result {
        case .some(.failure(let reason)):
            XCTAssertEqual(reason as? String, "a")
            break
        default:
            XCTFail()
        }
    }
    
    // If onFulfilled is a function:
    // it must be called after promise is fulfilled, with promise’s value as its first argument.
    // it must not be called before promise is fulfilled.
    // it must not be called more than once.
    // onFulfilled or onRejected must not be called until the execution context stack contains only platform code.
    func testCompletionSuccess() {
        var cnt = 0
        var value = Result(value: 0)
        let ex = expectation(description: "")
        let _ = promise.onCompletion {
            cnt += 1
            value =  $0
            ex.fulfill()
        }
        XCTAssertEqual(0, cnt)
        promise.resolve(7)
        XCTAssertEqual(0, cnt)
        let _ = promise.onSuccess { _ in }
        waitForExpectations(timeout: 0.1, handler: nil)
        XCTAssertEqual(1, cnt)
        XCTAssertEqual(Result(value: 7), value)
    }
    
    func testSuccess() {
        var cnt = 0
        var value = 0
        let ex = expectation(description: "")
        let _ = promise.onSuccess {
            cnt += 1
            value =  $0
            ex.fulfill()
        }
        XCTAssertEqual(0, cnt)
        promise.resolve(7)
        XCTAssertEqual(0, cnt)
        let _ = promise.onSuccess { _ in }
        waitForExpectations(timeout: 0.1, handler: nil)
        XCTAssertEqual(1, cnt)
        XCTAssertEqual(7, value)
    }
    
    // If onRejected is a function,
    // it must be called after promise is rejected, with promise’s reason as its first argument.
    // it must not be called before promise is rejected.
    // it must not be called more than once.
    // onFulfilled or onRejected must not be called until the execution context stack contains only platform code.
    func testCompletionReject() {
        var cnt = 0
        var result = Result(value: 0)
        let ex = expectation(description: "")
        promise.onCompletion {
            cnt += 1
            result = $0
            ex.fulfill()
        }
        XCTAssertEqual(0, cnt)
        promise.reject("b")
        XCTAssertEqual(0, cnt)
        let _ = promise.onSuccess({_ in })
        waitForExpectations(timeout: 0.1, handler: nil)
        XCTAssertEqual(1, cnt)
        XCTAssertEqual("b", result.error as? String)
    }
    
    func testReject() {
        var cnt = 0
        var reason: String? = "a"
        let ex = expectation(description: "")
        promise.onFailure { (rsn: Error) -> Void in
            cnt += 1
            reason = rsn as? String
            ex.fulfill()
        }
        XCTAssertEqual(0, cnt)
        promise.reject("b")
        XCTAssertEqual(0, cnt)
        let _ = promise.onSuccess({_ in })
        waitForExpectations(timeout: 0.1, handler: nil)
        XCTAssertEqual(1, cnt)
        XCTAssertEqual("b", reason)
    }
    
    // then may be called multiple times on the same promise.
    // If/when promise is fulfilled, all respective onFulfilled callbacks must execute in the order of their originating calls to then.
    func testSuccessOrder() {
        var order = [Int]()
        let ex1 = expectation(description: "")
        let ex2 = expectation(description: "")
        let ex3 = expectation(description: "")
        let _ = promise.onSuccess({ _ in
            order.append(1)
            ex1.fulfill()
        })
        promise.onSuccess { _ in
            order.append(2)
            ex2.fulfill()
        }
        promise.onSuccess { _ in
            order.append(3)
            ex3.fulfill()
        }
        promise.resolve(15)
        waitForExpectations(timeout: 0.1, handler: nil)
        XCTAssertEqual([1,2,3], order)
    }
    
    // If/when promise is rejected, all respective onRejected callbacks must execute in the order of their originating calls to then
    func testFailureOrder() {
        var order = [Int]()
        let ex1 = expectation(description: "")
        let ex2 = expectation(description: "")
        let ex3 = expectation(description: "")
        promise.onFailure { (rsn: Error) -> Void in
            order.append(1)
            ex1.fulfill()
        }
        let _ = promise.onFailure { (rsn: Error) -> Void in
            order.append(2)
            ex2.fulfill()
        }
        let _ = promise.onFailure { (rsn: Error) -> Void in
            order.append(3)
            ex3.fulfill()
        }
        promise.reject("h")
        waitForExpectations(timeout: 0.1, handler: nil)
        XCTAssertEqual([1,2,3], order)
    }
    
    // 2.2.7.1 If either onFulfilled or onRejected returns a value x, run the Promise Resolution Procedure [[Resolve]](promise2, x).
    func testResolveResolvesPromise2WithTheReturnedValue() {
        var value = 0.0
        let ex = expectation(description: "")
        promise.onSuccess { _ in return 9.1}.onSuccess  {
            value = $0
            ex.fulfill()
        }
        promise.resolve(2)
        waitForExpectations(timeout: 0.1, handler: nil)
        XCTAssertEqual(9.1, value)
    }
    
    func testRejectResolvesPromise2WithTheReturnedValue() {
        let ex = expectation(description: "")
        let promise2 = promise.onFailure { (_) -> Int in
            ex.fulfill()
            return 18
        }
        promise.reject("jk")
        waitForExpectations(timeout: 0.1, handler: nil)
        XCTAssertEqual(Result(value: 18), promise2.result)
    }
    
    // 2.2.7.2 If either onFulfilled or onRejected throws an exception e, promise2 must be rejected with e as the reason.
    // not implemented
    
    // If onFulfilled is not a function and promise1 is fulfilled, promise2 must be fulfilled with the same value as promise1.
    // If onRejected is not a function and promise1 is rejected, promise2 must be rejected with the same reason as promise1
    // N/A
    
    
    // 2.3.2 If x is a promise, adopt its state
    func testResolveWithAPendingPromiseKeepsThisOnePending() {
        let otherPromise = Promise<Int>()
        promise.resolve(otherPromise)
        XCTAssertNil(promise.result)
    }
    
    func testResolveWithAResolvedPromiseResolvesThisOne() {
        let otherPromise = Promise<Int>()
        let ex = expectation(description: "")
        var value: Int?
        promise.onSuccess {
            value = $0
            ex.fulfill()
        }
        otherPromise.resolve(14)
        promise.resolve(otherPromise)
        waitForExpectations(timeout: 0.1, handler: nil)
        XCTAssertEqual(promise.result, .some(.success(14)))
        XCTAssertEqual(14, value)
    }
    
    func testCompletionResolveWithAPendingPromiseResolvesThisOneWhenTheOtherOneIsResolved() {
        let otherPromise = Promise<Int>()
        let ex = expectation(description: "")
        var result = Result(value: 0)
        promise.onCompletion {
            result = $0
            ex.fulfill()
        }
        promise.resolve(otherPromise)
        otherPromise.resolve(41)
        waitForExpectations(timeout: 0.1, handler: nil)
        XCTAssertEqual(41, result.value)
    }
    
    func testResolveWithAPendingPromiseResolvesThisOneWhenTheOtherOneIsResolved() {
        let otherPromise = Promise<Int>()
        let ex = expectation(description: "")
        var value: Int?
        promise.onSuccess {
            value = $0
            ex.fulfill()
        }
        promise.resolve(otherPromise)
        otherPromise.resolve(41)
        waitForExpectations(timeout: 0.1, handler: nil)
        XCTAssertEqual(41, value)
    }
    
    func testCompletionResolveWithARejectedPromiseRejectsThisOne() {
        let otherPromise = Promise<Int>()
        let ex = expectation(description: "")
        var result = Result(value: 0)
        promise.onCompletion {
            result = $0
            ex.fulfill()
        }
        otherPromise.reject("op")
        promise.resolve(otherPromise)
        waitForExpectations(timeout: 0.1, handler: nil)
        XCTAssertEqual(promise.result, Result<Int>.failure("op"))
        XCTAssertEqual("op", result.error as? String)
    }
    
    func testResolveWithARejectedPromiseRejectsThisOne() {
        let otherPromise = Promise<Int>()
        let ex = expectation(description: "")
        var reason: String?
        promise.onFailure { (rsn: Error) -> Void in
            reason = rsn as? String
            ex.fulfill()
        }
        otherPromise.reject("op")
        promise.resolve(otherPromise)
        waitForExpectations(timeout: 0.1, handler: nil)
        XCTAssertEqual(promise.result, Result<Int>.failure("op"))
        XCTAssertEqual("op", reason)
    }
    
    func testCompletionResolveWithAPendingPromiseRejectsThisOneWhenTheOtherOneGetsRejected() {
        let otherPromise = Promise<Int>()
        let ex = expectation(description: "")
        var result = Result(value: 0)
        promise.onCompletion {
            result = $0
            ex.fulfill()
        }
        promise.resolve(otherPromise)
        otherPromise.reject("pq")
        waitForExpectations(timeout: 0.1, handler: nil)
        XCTAssertEqual("pq", result.error as? String)
    }
    
    func testResolveWithAPendingPromiseRejectsThisOneWhenTheOtherOneGetsRejected() {
        let otherPromise = Promise<Int>()
        let ex = expectation(description: "")
        var reason: String?
        promise.onFailure { (rsn: Error) -> Void in
            reason = rsn as? String
            ex.fulfill()
        }
        promise.resolve(otherPromise)
                otherPromise.reject("pq")
        waitForExpectations(timeout: 0.1, handler: nil)
        XCTAssertEqual("pq", reason)
    }
    
    func testRecoveredFailedPromise() {
        let ex = expectation(description: "")
        var chainValue = [Int]()
        promise.onSuccess { _ in [1,2,3] }.onFailure { _ in [4,5,6] }
            .onSuccess {
                chainValue = $0
                ex.fulfill()
            }
        promise.reject("aReason")
        waitForExpectations(timeout: 0.1, handler: nil)
        XCTAssertEqual([4,5,6], chainValue)
    }
    
    func testResolvePerf() {
        measure {
            for _ in 1...100000 {
                Promise<Int>().resolve(6)
            }
        }
        
    }
}
