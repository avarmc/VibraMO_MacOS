//
//  PopupPanelTransition.swift
//  VibraMED
//
//  Created by Elsys Corp. on 10.12.2020.
//

import Foundation
import UIKit

class PopupPanelTransition: NSObject, UIViewControllerTransitioningDelegate {
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        return PopupPresentationController(presentedViewController: presented,
                                                               presenting: presenting ?? source)
    }
}
