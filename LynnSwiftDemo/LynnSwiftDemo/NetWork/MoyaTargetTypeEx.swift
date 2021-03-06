//
//  SwiftNetworkAPI.swift
//  FiveLine
//
//  Created by limx on 2018/4/30.
//  Copyright © 2018年 张亮. All rights reserved.
//

import UIKit
import Moya
import Alamofire
import SwiftyJSON

let baseUrl =  "http://api.bbwansha.com:8080"

/// 通用请求TargetType
///
/// - getRequest: get请求   urlPath   Parameters
/// - postRequest: post请求   urlPath   Parameters
/// - uploadMultipart: 上传Multipart请求   urlPath   MultipartFormData
/// - uploadFile: 上传请求   urlPath   上传文件路径
/// - download: 下载请求   urlPath   下载完成后保存
/// - downloadWithParams: 带有参数的下载请求   urlPath   Parameters   下载完成后保存
enum CommonTargetTypeApi {
    case getRequest(String, [String: Any]?)
    case postRequest(String, [String: Any]?)
    case uploadMultipart(String, [Moya.MultipartFormData])
    case uploadFile(String, URL)
    case download(String, Moya.DownloadDestination)
    case downloadWithParams(String, [String: Any], Moya.DownloadDestination)
}

extension CommonTargetTypeApi: TargetType {
    
    var baseURL: URL {
        let baseUrlStr : String = baseUrl
        return URL.init(string: baseUrlStr)!
    }
    
    var sampleData: Data {
        return "".data(using: String.Encoding.utf8)!
    }
    
    var path: String {
        switch self {
        case .getRequest(let urlPath, _):
            return urlPath
        case .postRequest(let urlPath, _):
            return urlPath
        case .uploadMultipart(let urlPath, _):
            return urlPath
        case .uploadFile(let urlPath, _):
            return urlPath
        case .download(let urlPath, _):
            return urlPath
        case .downloadWithParams(let urlPath, _, _):
            return urlPath
        }
    }
    
    var method: Moya.Method {
        switch self {
        case .getRequest(_, _):
            return .get
        case .postRequest(_, _):
            return .post
        case .uploadMultipart(_, _):
            return .post
        case .uploadFile(_, _):
            return .post
        case .download(_, _):
            return .get
        case .downloadWithParams(_, _, _):
            return .post
        }
    }
    
    var task: Task {
        switch self {
        case .getRequest(_, let param):
            if let param = param {
                return .requestParameters(parameters: param, encoding: URLEncoding.default)
            }
            return .requestPlain
        case .postRequest(_, let param):
            if let param = param {
                return .requestParameters(parameters: param, encoding: URLEncoding.default)
            }
            return .requestPlain
        case .uploadMultipart(_, let datas):
            return .uploadMultipart(datas)
        case .uploadFile(_, let fileURL):
            return .uploadFile(fileURL)
        case .download(_, let destination):
            return .downloadDestination(destination)
        case .downloadWithParams(_, let params, let destination):
            return .downloadParameters(parameters: params, encoding: URLEncoding.default, destination: destination)
        }
    }
    
    var headers: [String : String]? {
        switch self {
        case .uploadMultipart(_, _):
            return ["Content-type": "multipart/form-data"]
        default:
            return ["Content-type": "application/json"]
        }
    }
}



    

