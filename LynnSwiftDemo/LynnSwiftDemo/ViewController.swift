//
//  ViewController.swift
//  LynnSwiftDemo
//
//  Created by 姬冠杰 on 2018/11/27.
//  Copyright © 2018年 jgj. All rights reserved.
//

import UIKit
import HandyJSON
let url = "/v22/index.php/Home/misc/banners"

struct FLBannerModel: HandyJSON {
    let banner_name: String = ""
    let banner_image_id: String = ""
    let banner_type: String = ""
    let banner_post_id: String = ""
    let banner_tag_id: String = ""
    let banner_h5_link: String = ""
    let banner_image_url: String =   fddf""
}


class ViewController: UIViewController {
    
    var datas: [FLBannerModel] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Network.default.request(CommonTargetTypeApi.getRequest(url, [: ]), successClosure: { (json) in
            guard let parameter = json.dictionaryObject,
                let data = parameter["data"] as? Array<Any>
                else { return }
            if let items = [FLBannerModel].deserialize(from: data) as? [FLBannerModel] {
                self.datas = items
            }
        }) { (error) in
            
        }
    }
}

