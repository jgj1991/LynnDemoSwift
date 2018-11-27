//
//  SwiftNetworkManager.swift
//  FiveLine
//
//  Created by limx on 2018/4/30.
//  Copyright © 2018年 张亮. All rights reserved.
//

import Foundation
import Moya
import Alamofire
import SwiftyJSON
import RxSwift
import RxCocoa
import HandyJSON
import PromiseKit

/*
    TODO
    1. 参数和分页
    2. 使用Plugin添加公共参数
    3. 后期修改为HTTPS
 
    参考：
     https://blog.csdn.net/xiaochong2154/article/details/78449641
 
    2018-05-01 by limx
 */


/********************************************************************
 
  用法示例：

    // 使用Network.default 单例请求
    Network.default.request(TargetType, success: { (json) in
        debugPrint(json)
    }, failure: {{ (err) in
        debugPrint(err)
        }})

    // 直接使用provider，不使用RxSwift
    Network.provider.request(MultiTarget(target), progress: { (progressRes) in
        if progressRes.completed {
            progress(1.0)
        }
        else {
            progress(progressRes.progress)
        }
    }, completion: { (result) in
        switch result {
        case .success(let res):
            do {
                let js = try JSON(res.mapJSON())
                success(js)
            }
            catch let err {
                failure(err)
            }
            break
        case .failure(let err):
            failure(err)
            break
        }
    })
    // 直接使用provider，使用RxSwift
    Network.provider.rx.request(MultiTarget(target))
    .mapJSON()
        .subscribe { (event) in
            switch event {
            case let .success(response):
                let js = JSON(response)
                success(js)
                break
            case let .error(err):
                failure(err)
                break
            }
    }
    .disposed(by: dispose)
 
    or...
 
    Network.provider.rx.request(MultiTarget(target))
        .mapJSON().subscribe(onSuccess: { (json) in
            debugPrint(json)
        }) { (err) in
            debugPrint(err.localizedDescription)
        }.disposed(by: dispose)

    取回数据后json转HandyJson
    Network.provider.rx.request(MultiTarget(target))
        .mapHandyJSON(HandyJSON.self, atKeyPath: "data.objc")
        .subscribe { (event) in
            switch event {
            case let .success(objc):
                debugPrint(objc.description)
                break
            case let .error(err):
                failure(err)
                break
            }
        }
        .disposed(by: dispose)
 
    // 自己从 res 转 HandyJSON
     Network.provider.rx.request(MultiTarget(target)).asObservable()
        [.mapJSON] 可以先转成json再做mapModel，也可以直接mapModel
         .mapModel { (Any) -> HandyJSON? in
 
            return HandyJSON.deserialize(from: [: ], designatedPath: "xxx.xxx")
         }
         .subscribe { (event) in
 
         }.disposed(by: dispose)
*/

public final class Network {
    
    /// Network 单例对象，
    public static let `default` = Network()
    
    /// Moya provider 类实例, Network.provider.rx.request() 或 Network.provider.request()
    public static let provider = MoyaProvider<MultiTarget>(requestClosure: Network.requestMapping, plugins: [Network.loggerPlugin, Network.activityPlugin, Network.reloginPlugin])
    
    
    /// NetworkLoggerPlugin
    private static var loggerPlugin: NetworkLoggerPlugin = {
        #if DEBUG
        return NetworkLoggerPlugin(verbose: true)
        #else
        return NetworkLoggerPlugin(verbose: false)
        #endif
    }()
    
    /// NetworkActivityPlugin
    private static var activityPlugin: NetworkActivityPlugin = {
        return NetworkActivityPlugin { (changeType, target) in
            switch changeType {
            case .began:
                UIApplication.shared.isNetworkActivityIndicatorVisible = true
            case .ended:
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
            }
        }
    }()
    
    private static var reloginPlugin: ReLoginPlugin = ReLoginPlugin()
    
    /// requestClosure
    private static var requestMapping: (Endpoint, MoyaProvider.RequestResultClosure) -> Void = { (endpoint, closure) in
        do {
            var urlRequest = try endpoint.urlRequest()
//            let param = urlRequest.
            urlRequest.timeoutInterval = 35  // 超时时间
            closure(.success(urlRequest))
        } catch MoyaError.requestMapping(let url) {
            closure(.failure(MoyaError.requestMapping(url)))
        } catch MoyaError.parameterEncoding(let error) {
            closure(.failure(MoyaError.parameterEncoding(error)))
        } catch {
            closure(.failure(MoyaError.underlying(error, nil)))
        }
    }
    
    fileprivate let dispose = DisposeBag()
    
    
    /// 请求 JSON (SwiftyJSON) 格式数据
    ///
    /// - Parameters:
    ///   - target: TargetType
    ///   - success: 成功返回 JSON
    ///   - failure: 失败返回 Error
    public func request(_ target: TargetType, successClosure: @escaping (JSON) -> Void, failureClosure: @escaping (Error) -> Void) {
        Network.provider.rx.request(MultiTarget(target))
        .mapJSON()
            .subscribe { (event) in
                switch event {
                case let .success(response):
                    let json = JSON(response)
                    if json["meta"]["code"] == 200 {
                        successClosure(json)
                    }
                    else {
                        failureClosure(FLError.responseCodeNot200(json["code"].stringValue, json["msg"].stringValue))
                    }
                    break
                case let .error(err):
                    failureClosure(err)
                    break
                }
        }
        .disposed(by: dispose)
    }
    
    
    /// 发送带进度条的请求
    ///
    /// - Parameters:
    ///   - target: TargetType
    ///   - progress: 进度条回调
    ///   - success: 成功回调
    ///   - failure: 失败回调
    public func requestProgress(_ target: TargetType, progressClosure: ((Double) -> Void)? = .none, successClosure: @escaping (JSON) -> Void, failureClosure: @escaping (Error) -> Void) {
        
        let resObserver = Network.provider.rx.requestWithProgress(MultiTarget(target))
            // .share(replay: 1)
//        resObserver.filterProgress().subscribe { (event) in
//            switch event {
//            case .next(let progre):
//                progressClosure?(progre)
//            case .error(let err):
//                failureClosure(err)
//            case .completed:
//                
//                break
//            }
//        }.disposed(by: dispose)
//        
//        resObserver.filterCompleted().mapJSON().subscribe { (event) in
//            switch event {
//            case .next(let res):
//                let json = JSON(res)
//                if json["code"] == "200" {
//                    successClosure(json)
//                }
//                else {
//                    failureClosure(FLError.responseCodeNot200(json["code"].stringValue, json["msg"].stringValue))
//                }
//            case .error(let err):
//                failureClosure(err)
//            case .completed:
//                progressClosure?(1.0)
//            }
//        }.disposed(by: dispose)
        
        resObserver.subscribe { (event) in
            switch event {
            case let .next(proRes):
                if let response = proRes.response {
                    do {
                        let data = try response.mapJSON()
                        let json = JSON(data)
                        if json["code"] == 200 {
                            successClosure(json)
                        }
                        else {
                            failureClosure(FLError.responseCodeNot200(json["code"].stringValue, json["msg"].stringValue))
                        }
                    }
                    catch let err {
                        failureClosure(err)
                    }
                }
                else {
                    progressClosure?(proRes.progress)
                }
                break
            case let .error(err):
                failureClosure(err)
                break
            case .completed:
                progressClosure?(1.0)
                break
            }
        }.disposed(by: dispose)
    }

    // MARK: PromiseKit

    /// 发送请求，返回 Promise<JSON>
    ///
    /// - Parameter target: api target
    /// - Returns: Promise<JSON>
    public func request(_ target: TargetType) -> Promise<JSON> {
        return Promise { seal in
            Network.provider.rx.request(MultiTarget(target))
            .mapJSON()
                .subscribe(onSuccess: { (data) in
                    let json = JSON(data)
                    if json["code"] == "200" {
                        seal.fulfill(json)
                    }
                    else {
                        seal.reject(FLError.responseCodeNot200(json["code"].stringValue, json["msg"].stringValue))
                    }
                }, onError: { (err) in
                    seal.reject(err)
                })
            .disposed(by: dispose)
        }
    }
}

extension Network {
    
    
    /// 通用 get 请求
    ///
    /// - Parameters:
    ///   - urlPath: url的path
    ///   - parameters: 参数
    ///   - successClosure: 成功回调
    ///   - failureClosure: 失败回调
    public func get(_ urlPath: String, parameters: [String: Any]? = nil, successClosure: @escaping (JSON) -> Void, failureClosure: @escaping (Error) -> Void) -> Void {
        Network.default.request(CommonTargetTypeApi.getRequest(urlPath, parameters), successClosure: successClosure, failureClosure: failureClosure)
    }
    
   
    
    
    
    /// 通用 post 请求
    ///
    /// - Parameters:
    ///   - urlPath: url的path
    ///   - parameters: 参数
    ///   - successClosure: 成功回调
    ///   - failureClosure: 失败回调
    public func post(_ urlPath: String, parameters: [String: Any]? = nil, successClosure: @escaping (JSON) -> Void, failureClosure: @escaping (Error) -> Void) -> Void {
        Network.default.request(CommonTargetTypeApi.postRequest(urlPath, parameters), successClosure: successClosure, failureClosure: failureClosure)
    }
    
    // MARK: PromiseKit 方式
//    demo：
//    Network.default.get("homelist")
//    .done { (json) in
//        debugPrint(json)
//    }.catch { (err) in
//        debugPrint(err.localizedDescription)
//    }
//
//    Network.default.get("homelist")
//        .compactMap { (json) -> HomeRecommendBaseModel? in
//            return HomeRecommendBaseModel.deserialize(from: json.dictionaryObject)
//        }.done { (model) in
//            // to do
//        }.catch { (err) in
//            // err
//    }
    /// 发送GET请求，返回Promise对象
    ///
    /// - Parameters:
    ///   - urlPath: url path
    ///   - parameters: 参数
    /// - Returns: Promise<JSON>
    public func get(_ urlPath: String, parameters: [String: Any]? = nil) -> Promise<JSON> {
        return Promise { seal in
            Network.default.request(CommonTargetTypeApi.getRequest(urlPath, parameters), successClosure: { (json) in
                seal.fulfill(json)
            }, failureClosure: { (err) in
                seal.reject(err)
            })
        }
    }
    
    /// 发送POST请求，返回Promise对象
    ///
    /// - Parameters:
    ///   - urlPath: url path
    ///   - parameters: 参数
    /// - Returns: Promise<JSON>
    public func post(_ urlPath: String, parameters: [String: Any]? = nil) -> Promise<JSON> {
        return Promise { seal in
            Network.default.request(CommonTargetTypeApi.postRequest(urlPath, parameters), successClosure: { (json) in
                seal.fulfill(json)
            }, failureClosure: { (err) in
                seal.reject(err)
            })
        }
    }
}
