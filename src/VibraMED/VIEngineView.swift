//
//  VIEngineView.swift
//  
//
//  Created by Elsys Corp. on 07.12.2020.
//

import UIKit

class VIEngineView: UIImageView {

    private let serialQueue = DispatchQueue(label: "Elsys-Corp.VibraMED.VIEngineView")
    private var img:UIImage!
    private let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
    private var viOrientation:Int = 0
    
    override init(frame: CGRect) {
         super.init(frame: frame)
         commonInit()
     }

    required init?(coder aDecoder: NSCoder) {
         super.init(coder: aDecoder)
         commonInit()
    }
    
    private func commonInit() {
    }
    
    public func setImage(pixels: UnsafeMutablePointer<UInt32>, width: Int, height: Int, viOrientation: Int) {
        self.serialQueue.sync {
            self.viOrientation = viOrientation
            self.img = imageFromARGB32Bitmap(pixels:pixels,width:width,height:height)
        }
        DispatchQueue.main.async {
            self.updateImage()
        }
    }
    
    func updateImage() {
        DispatchQueue.main.async {
            if(self.img != nil) {
  
                self.image = self.img
                self.img = nil

                self.setNeedsDisplay()
            }
        }
    }

    
    private func imageFromARGB32Bitmap(pixels: UnsafeMutablePointer<UInt32>, width: Int, height: Int) -> UIImage? {
        guard width > 0 && height > 0 else { return nil }
        
        
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        let bitsPerComponent = 8
        let bitsPerPixel = 32


        guard let providerRef = CGDataProvider(data: NSData(bytes: pixels,
                                length: width*height*4)
            )
            else { return nil }

        guard let cgim = CGImage(
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bitsPerPixel,
            bytesPerRow: width * 4,
            space: rgbColorSpace,
            bitmapInfo: bitmapInfo,
            provider: providerRef,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
            )
            else { return nil }

        return UIImage(cgImage: cgim)
    }
}
