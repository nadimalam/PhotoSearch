//
//  PhotoCollectionViewCell.swift
//  PhotoSearch
//
//  Created by Nadim Alam on 17/01/2019.
//  Copyright © 2019 Nadim Alam. All rights reserved.
//

import UIKit

class PhotoCollectionViewCell: UICollectionViewCell {    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    override var isSelected: Bool {
        didSet {
            imageView.layer.borderWidth = isSelected ? 6 : 0
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        imageView.layer.borderColor = themeColor.cgColor
        isSelected = false
    }
}
