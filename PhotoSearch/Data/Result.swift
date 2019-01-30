//
//  Result.swift
//  PhotoSearch
//
//  Created by Nadim Alam on 16/01/2019.
//  Copyright © 2019 Nadim Alam. All rights reserved.
//

import Foundation

enum Result<ResultType> {
    case results(ResultType)
    case error(Error)
}
