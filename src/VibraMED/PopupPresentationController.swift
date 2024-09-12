//
//  PopupPresentationController.swift
//  VibraMED
//
//  Created by Elsys Corp. on 10.12.2020.
//

import Foundation
import UIKit


class PopupPresentationController: UIPresentationController {
    override var frameOfPresentedViewInContainerView: CGRect {
          
        let bounds = containerView!.bounds
        let w = max( bounds.width / 5, 290.0)
        let h = max( bounds.height / 5, 182.0)
        
        return CGRect(x: (bounds.width-w)/2,
                      y: (bounds.height-h )/2,
                      width: w,
                      height: h)
    }
    
    // PresentationController.swift
    override func presentationTransitionWillBegin() {
        super.presentationTransitionWillBegin()
        containerView?.addSubview(presentedView!)
    }
    
    // PresentationController.swift
    override func containerViewDidLayoutSubviews() {
        super.containerViewDidLayoutSubviews()
        presentedView?.frame = frameOfPresentedViewInContainerView
    }
}


