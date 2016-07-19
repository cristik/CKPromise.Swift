//
//  CKPromiseTests.swift
//  CKPromiseTests
//
//  Created by Cristian Kocza on 06/06/16.
//  Copyright © 2016 Cristik. All rights reserved.
//

import XCTest
@testable import CKPromise_Swift

extension PromiseState: Equatable {}

/// Just for testing purposes
func ==<S,E>(lhs: PromiseState<S,E>, rhs: PromiseState<S,E>) -> Bool {
    return String(stringInterpolationSegment: lhs) == String(stringInterpolationSegment: rhs)
}

class CKPromiseTests: XCTestCase {
    let promise = Promise<Int, String>()
    
    func testNewlyCreatedPromiseIsInPendingState() {
        XCTAssertEqual(PromiseState<Int,String>.pending, promise.state)
    }
    
    // 2.1.1 When pending, a promise:
    // 2.1.1.1 may transition to either the fulfilled or rejected state.
    func testResolvedPromiseIsInFulfilledState() {
        promise.resolve(5)
        XCTAssertEqual(PromiseState<Int,String>.fulfilled(5), promise.state)
    }

    // 2.1.1 When pending, a promise:
    // 2.1.1.1 may transition to either the fulfilled or rejected state.
    func testRejectedPromiseIsInRejecteState() {
        promise.reject("a")
        XCTAssertEqual(PromiseState<Int,String>.rejected("a"), promise.state)
    }
    
    // 2.1.2 When fulfilled, a promise:
    // 2.1.2.1 must not transition to any other state.
    // 2.1.2.1 must have a value, which must not change.
    func testResolvingAgainKeepsInResolved() {
        promise.resolve(5)
        promise.resolve(6)
        switch promise.state {
        case .fulfilled(let value):
            XCTAssertEqual(value, 5)
            break
        default:
            XCTFail()
        }
    }
    
    func testRejectingAfteResolvingKeepsInResolved() {
        promise.resolve(5)
        promise.reject("a")
        switch promise.state {
        case .fulfilled(let value):
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
        switch promise.state {
        case .rejected(let reason):
            XCTAssertEqual(reason, "a")
            break
        default:
            XCTFail()
        }
    }
    
    func testResolvingAfterRejectingKeepsInRejected() {
        promise.reject("a")
        promise.resolve(1)
        switch promise.state {
        case .rejected(let reason):
            XCTAssertEqual(reason, "a")
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
    func testSuccess() {
        var cnt = 0
        var value = 0
        let ex = expectationWithDescription("")
        let _ = promise.onSuccess({
            cnt += 1
            value =  $0
            ex.fulfill()
        })
        XCTAssertEqual(0, cnt)
        promise.resolve(7)
        XCTAssertEqual(0, cnt)
        let _ = promise.onSuccess({_ in })
        waitForExpectationsWithTimeout(0.1, handler: nil)
        XCTAssertEqual(1, cnt)
        XCTAssertEqual(7, value)
    }
    
    // If onRejected is a function,
    // it must be called after promise is rejected, with promise’s reason as its first argument.
    // it must not be called before promise is rejected.
    // it must not be called more than once.
    // onFulfilled or onRejected must not be called until the execution context stack contains only platform code.
    func testReject() {
        var cnt = 0
        var reason = "a"
        let ex = expectationWithDescription("")
        let _ = promise.on(success: {_ in }, failure: { (rsn: String) -> Void in
            cnt += 1
            reason =  rsn
            ex.fulfill()
        })
        XCTAssertEqual(0, cnt)
        promise.reject("b")
        XCTAssertEqual(0, cnt)
        let _ = promise.onSuccess({_ in })
        waitForExpectationsWithTimeout(0.1, handler: nil)
        XCTAssertEqual(1, cnt)
        XCTAssertEqual("b", reason)
    }
    
    // then may be called multiple times on the same promise.
    // If/when promise is fulfilled, all respective onFulfilled callbacks must execute in the order of their originating calls to then.
    func testSuccessOrder() {
        var order = [Int]()
        let ex1 = expectationWithDescription("")
        let ex2 = expectationWithDescription("")
        let ex3 = expectationWithDescription("")
        let _ = promise.onSuccess( { _ in
            order.append(1)
            ex1.fulfill()
        })
        let _ = promise.onSuccess({ _ in
            order.append(2)
            ex2.fulfill()
        })
        let _ = promise.onSuccess( { _ in
            order.append(3)
            ex3.fulfill()
        })
        promise.resolve(15)
        waitForExpectationsWithTimeout(0.1, handler: nil)
        XCTAssertEqual([1,2,3], order)
    }
    
    // If/when promise is rejected, all respective onRejected callbacks must execute in the order of their originating calls to then
    func testFailureOrder() {
        var order = [Int]()
        let ex1 = expectationWithDescription("")
        let ex2 = expectationWithDescription("")
        let ex3 = expectationWithDescription("")
        let _ = promise.on(success: {_ in }, failure: { _ in
            order.append(1)
            ex1.fulfill()
        })
        let _ = promise.on(success: {_ in }, failure: { _ in
            order.append(2)
            ex2.fulfill()
        })
        let _ = promise.on(success: {_ in }, failure: { _ in
            order.append(3)
            ex3.fulfill()
        })
        promise.reject("h")
        waitForExpectationsWithTimeout(0.1, handler: nil)
        XCTAssertEqual([1,2,3], order)
    }
    
    // 2.2.7.1 If either onFulfilled or onRejected returns a value x, run the Promise Resolution Procedure [[Resolve]](promise2, x).
    func testResolveResolvesPromise2WithTheReturnedValue() {
        var value = 0.0
        let ex = expectationWithDescription("")
        let _ = promise.onSuccess({_ in return 9.1}).onSuccess({
            value = $0
            ex.fulfill()
        })
        promise.resolve(2)
        waitForExpectationsWithTimeout(0.1, handler: nil)
        XCTAssertEqual(9.1, value)
    }
    
    func testRejectResolvesPromise2WithTheReturnedValue() {
        let ex = expectationWithDescription("")
        let promise2 = promise.on(success: { (_) -> Double in XCTFail(); return 0.1 },
                                  failure: { (_) -> Double in ex.fulfill(); return 1.8 })
        promise.reject("jk")
        waitForExpectationsWithTimeout(0.1, handler: nil)
        XCTAssertEqual(PromiseState<Double,String>.fulfilled(1.8), promise2.state)
    }
    
    // 2.2.7.2 If either onFulfilled or onRejected throws an exception e, promise2 must be rejected with e as the reason.
    // not implemented
    
    // If onFulfilled is not a function and promise1 is fulfilled, promise2 must be fulfilled with the same value as promise1.
    // If onRejected is not a function and promise1 is rejected, promise2 must be rejected with the same reason as promise1
    // N/A
    
    
    // 2.3.2 If x is a promise, adopt its state
    func testResolveWithAPendingPromiseKeepsThisOnePending() {
        let otherPromise = Promise<Int, String>()
        promise.resolve(otherPromise)
        XCTAssertEqual(promise.state, PromiseState<Int,String>.pending)
    }
    
    func testResolveWithAResolvedPromiseResolvesThisOne() {
        let otherPromise = Promise<Int, String>()
        let ex = expectationWithDescription("")
        var value: Int?
        let _ = promise.onSuccess({
            value = $0
            ex.fulfill()
        })
        otherPromise.resolve(14)
        promise.resolve(otherPromise)
        waitForExpectationsWithTimeout(0.1, handler: nil)
        XCTAssertEqual(promise.state, PromiseState<Int,String>.fulfilled(14))
        XCTAssertEqual(14, value)
    }
    
    func testResolveWithAPendingPromiseResolvesThisOneWhenTheOtherOneIsResolved() {
        let otherPromise = Promise<Int, String>()
        let ex = expectationWithDescription("")
        var value: Int?
        let _ = promise.onSuccess({
            value = $0
            ex.fulfill()
        })
        promise.resolve(otherPromise)
        otherPromise.resolve(41)
        waitForExpectationsWithTimeout(0.1, handler: nil)
        XCTAssertEqual(41, value)
    }
    
    func testResolveWithARejectedPromiseRejectsThisOne() {
        let otherPromise = Promise<Int, String>()
        let ex = expectationWithDescription("")
        var reason: String?
        let _ = promise.on(success: { _ in XCTFail() }, failure:{
            reason = $0
            ex.fulfill()
        })
        otherPromise.reject("op")
        promise.resolve(otherPromise)
        waitForExpectationsWithTimeout(0.1, handler: nil)
        XCTAssertEqual(promise.state, PromiseState<Int,String>.rejected("op"))
        XCTAssertEqual("op", reason)
    }
    
    func testResolveWithAPendingPromiseRejectsThisOneWhenTheOtherOneGetsRejected() {
        let otherPromise = Promise<Int, String>()
        let ex = expectationWithDescription("")
        var reason: String?
        let _ = promise.on(success: { _ in XCTFail() }, failure:{
            reason = $0
            ex.fulfill()
        })
        promise.resolve(otherPromise)
                otherPromise.reject("pq")
        waitForExpectationsWithTimeout(0.1, handler: nil)
        XCTAssertEqual("pq", reason)
    }
    
    func testRecoveredFailedPromise() {
        let ex = expectationWithDescription("")
        var chainValue = [Int]()
        promise.on(success: { _ in return [1,2,3] }, failure: { _ in
            return [4,5,6]
        }).onSuccess({
            chainValue = $0
            ex.fulfill()
        })
        promise.reject("aReason")
        waitForExpectationsWithTimeout(0.1, handler: nil)
        XCTAssertEqual([4,5,6], chainValue)
    }
}
