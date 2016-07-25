//
//  ManagerTests.swift
//
//  Copyright (c) 2014-2016 Alamofire Software Foundation (http://alamofire.org/)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

@testable import Alamofire
import Foundation
import XCTest

class ManagerTestCase: BaseTestCase {

    // MARK: Initialization Tests

    func testInitializerWithDefaultArguments() {
        // Given, When
        let manager = Manager()

        // Then
        XCTAssertNotNil(manager.session.delegate, "session delegate should not be nil")
        XCTAssertTrue(manager.delegate === manager.session.delegate, "manager delegate should equal session delegate")
        XCTAssertNil(manager.session.serverTrustPolicyManager, "session server trust policy manager should be nil")
    }

    func testDefaultUserAgentHeader() {
        // Given, When
        let userAgent = Manager.defaultHTTPHeaders["User-Agent"]

        // Then
        let osNameVersion: String = {
            let versionString: String

            if #available(OSX 10.10, *) {
                let version = NSProcessInfo.processInfo().operatingSystemVersion
                versionString = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
            } else {
                versionString = "10.9"
            }

            let osName: String = {
                #if os(iOS)
                    return "iOS"
                #elseif os(watchOS)
                    return "watchOS"
                #elseif os(tvOS)
                    return "tvOS"
                #elseif os(OSX)
                    return "OS X"
                #elseif os(Linux)
                    return "Linux"
                #else
                    return "Unknown"
                #endif
            }()

            return "\(osName) \(versionString)"
        }()

        let alamofireVersion: String = {
            guard
                let afInfo = NSBundle(forClass: Manager.self).infoDictionary,
                build = afInfo["CFBundleShortVersionString"]
            else { return "Unknown" }

            return "Alamofire/\(build)"
        }()

        let expectedUserAgent = "Unknown/Unknown (Unknown; build:Unknown; \(osNameVersion)) \(alamofireVersion)"
        XCTAssertEqual(userAgent, expectedUserAgent)
    }

    func testInitializerWithSpecifiedArguments() {
        // Given
        let configuration = URLSessionConfiguration.default
        let delegate = Manager.SessionDelegate()
        let serverTrustPolicyManager = ServerTrustPolicyManager(policies: [:])

        // When
        let manager = Manager(
            configuration: configuration,
            delegate: delegate,
            serverTrustPolicyManager: serverTrustPolicyManager
        )

        // Then
        XCTAssertNotNil(manager.session.delegate, "session delegate should not be nil")
        XCTAssertTrue(manager.delegate === manager.session.delegate, "manager delegate should equal session delegate")
        XCTAssertNotNil(manager.session.serverTrustPolicyManager, "session server trust policy manager should not be nil")
    }

    func testThatFailableInitializerSucceedsWithDefaultArguments() {
        // Given
        let delegate = Manager.SessionDelegate()
        let session: URLSession = {
            let configuration = URLSessionConfiguration.default
            return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        }()

        // When
        let manager = Manager(session: session, delegate: delegate)

        // Then
        if let manager = manager {
            XCTAssertTrue(manager.delegate === manager.session.delegate, "manager delegate should equal session delegate")
            XCTAssertNil(manager.session.serverTrustPolicyManager, "session server trust policy manager should be nil")
        } else {
            XCTFail("manager should not be nil")
        }
    }

    func testThatFailableInitializerSucceedsWithSpecifiedArguments() {
        // Given
        let delegate = Manager.SessionDelegate()
        let session: URLSession = {
            let configuration = URLSessionConfiguration.default
            return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        }()

        let serverTrustPolicyManager = ServerTrustPolicyManager(policies: [:])

        // When
        let manager = Manager(session: session, delegate: delegate, serverTrustPolicyManager: serverTrustPolicyManager)

        // Then
        if let manager = manager {
            XCTAssertTrue(manager.delegate === manager.session.delegate, "manager delegate should equal session delegate")
            XCTAssertNotNil(manager.session.serverTrustPolicyManager, "session server trust policy manager should not be nil")
        } else {
            XCTFail("manager should not be nil")
        }
    }

    func testThatFailableInitializerFailsWithWhenDelegateDoesNotEqualSessionDelegate() {
        // Given
        let delegate = Manager.SessionDelegate()
        let session: URLSession = {
            let configuration = URLSessionConfiguration.default
            return URLSession(configuration: configuration, delegate: Manager.SessionDelegate(), delegateQueue: nil)
        }()

        // When
        let manager = Manager(session: session, delegate: delegate)

        // Then
        XCTAssertNil(manager, "manager should be nil")
    }

    func testThatFailableInitializerFailsWhenSessionDelegateIsNil() {
        // Given
        let delegate = Manager.SessionDelegate()
        let session: URLSession = {
            let configuration = URLSessionConfiguration.default
            return URLSession(configuration: configuration, delegate: nil, delegateQueue: nil)
        }()

        // When
        let manager = Manager(session: session, delegate: delegate)

        // Then
        XCTAssertNil(manager, "manager should be nil")
    }

    // MARK: Start Requests Immediately Tests

    func testSetStartRequestsImmediatelyToFalseAndResumeRequest() {
        // Given
        let manager = Alamofire.Manager()
        manager.startRequestsImmediately = false

        let URL = Foundation.URL(string: "https://httpbin.org/get")!
        let URLRequest = Foundation.URLRequest(url: URL)

        let expectation = self.expectation(description: "\(URL)")

        var response: HTTPURLResponse?

        // When
        manager.request(URLRequest)
            .response { _, responseResponse, _, _ in
                response = responseResponse
                expectation.fulfill()
            }
            .resume()

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertTrue(response?.statusCode == 200, "response status code should be 200")
    }

    // MARK: Deinitialization Tests

    func testReleasingManagerWithPendingRequestDeinitializesSuccessfully() {
        // Given
        var manager: Manager? = Alamofire.Manager()
        manager?.startRequestsImmediately = false

        let URL = Foundation.URL(string: "https://httpbin.org/get")!
        let URLRequest = Foundation.URLRequest(url: URL)

        // When
        let request = manager?.request(URLRequest)
        manager = nil

        // Then
        XCTAssertTrue(request?.task.state == .suspended, "request task state should be '.Suspended'")
        XCTAssertNil(manager, "manager should be nil")
    }

    func testReleasingManagerWithPendingCanceledRequestDeinitializesSuccessfully() {
        // Given
        var manager: Manager? = Alamofire.Manager()
        manager!.startRequestsImmediately = false

        let URL = Foundation.URL(string: "https://httpbin.org/get")!
        let URLRequest = Foundation.URLRequest(url: URL)

        // When
        let request = manager!.request(URLRequest)
        request.cancel()
        manager = nil

        // Then
        let state = request.task.state
        XCTAssertTrue(state == .canceling || state == .completed, "state should be .Canceling or .Completed")
        XCTAssertNil(manager, "manager should be nil")
    }
}

// MARK: -

class ManagerConfigurationHeadersTestCase: BaseTestCase {
    enum ConfigurationType {
        case `default`, ephemeral, background
    }

    func testThatDefaultConfigurationHeadersAreSentWithRequest() {
        // Given, When, Then
        executeAuthorizationHeaderTestForConfigurationType(.default)
    }

    func testThatEphemeralConfigurationHeadersAreSentWithRequest() {
        // Given, When, Then
        executeAuthorizationHeaderTestForConfigurationType(.ephemeral)
    }

//    ⚠️ This test has been removed as a result of rdar://26870455 in Xcode 8 Seed 1
//    func testThatBackgroundConfigurationHeadersAreSentWithRequest() {
//        // Given, When, Then
//        executeAuthorizationHeaderTestForConfigurationType(.background)
//    }

    private func executeAuthorizationHeaderTestForConfigurationType(_ type: ConfigurationType) {
        // Given
        let manager: Manager = {
            let configuration: URLSessionConfiguration = {
                let configuration: URLSessionConfiguration

                switch type {
                case .default:
                    configuration = .default
                case .ephemeral:
                    configuration = .ephemeral
                case .background:
                    let identifier = "org.alamofire.test.manager-configuration-tests"
                    configuration = .background(withIdentifier: identifier)
                }

                var headers = Alamofire.Manager.defaultHTTPHeaders
                headers["Authorization"] = "Bearer 123456"
                configuration.httpAdditionalHeaders = headers

                return configuration
            }()

            return Manager(configuration: configuration)
        }()

        let expectation = self.expectation(description: "request should complete successfully")

        var response: Response<AnyObject, NSError>?

        // When
        manager.request(.GET, "https://httpbin.org/headers")
            .responseJSON { closureResponse in
                response = closureResponse
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        if let response = response {
            XCTAssertNotNil(response.request, "request should not be nil")
            XCTAssertNotNil(response.response, "response should not be nil")
            XCTAssertNotNil(response.data, "data should not be nil")
            XCTAssertTrue(response.result.isSuccess, "result should be a success")

            if let headers = response.result.value?["headers" as NSString] as? [String: String],
               let authorization = headers["Authorization"]
            {
                XCTAssertEqual(authorization, "Bearer 123456", "authorization header value does not match")
            } else {
                XCTFail("failed to extract authorization header value")
            }
        } else {
            XCTFail("response should not be nil")
        }
    }
}
