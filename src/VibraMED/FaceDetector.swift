//
//  FaceDetector.swift
//  VibraMED
//
//  Created by Elsys Corp. on 08.12.2020.
//

import Foundation
import UIKit
import AVFoundation
import VIEngineLib

class FaceDetector {
    let PHOTOS_EXIF_0ROW_TOP_0COL_LEFT            = 1 //   1  =  0th row is at the top, and 0th column is on the left (THE DEFAULT).
    let PHOTOS_EXIF_0ROW_TOP_0COL_RIGHT            = 2 //   2  =  0th row is at the top, and 0th column is on the right.
    let PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT      = 3 //   3  =  0th row is at the bottom, and 0th column is on the right.
    let PHOTOS_EXIF_0ROW_BOTTOM_0COL_LEFT       = 4 //   4  =  0th row is at the bottom, and 0th column is on the left.
    let PHOTOS_EXIF_0ROW_LEFT_0COL_TOP          = 5 //   5  =  0th row is on the left, and 0th column is the top.
    let PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP         = 6 //   6  =  0th row is on the right, and 0th column is the top.
    let PHOTOS_EXIF_0ROW_RIGHT_0COL_BOTTOM      = 7 //   7  =  0th row is on the right, and 0th column is the bottom.
    let PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM       = 8  //   8  =  0th row is on the left, and 0th column is the bottom.
    let ROTATION_0:Int32! // = 1
    let ROTATION_90:Int32! // = 2
    let ROTATION_180:Int32! // = 3
    let ROTATION_270:Int32! // = 4
    
    private var base:CameraViewController!
    private var faceDetector:CIDetector! // = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: [CIDetectorAccuracy : CIDetectorAccuracyLow])

    init(_ base:CameraViewController) {
        self.base = base
        let jni = self.base.engine.jni
        
        self.ROTATION_0 = jni.tag2Id("ROTATION_0")
        self.ROTATION_90 = jni.tag2Id("ROTATION_90")
        self.ROTATION_180 = jni.tag2Id("ROTATION_180")
        self.ROTATION_270 = jni.tag2Id("ROTATION_270")
    }
    
    public func captureFace(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        detectFacesWithCIDetector( output, sampleBuffer: sampleBuffer,  from: connection)
    }
    private func detectFacesWithCIDetector(_ captureOutput: AVCaptureOutput, sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            // got an image
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        let attachments = CMCopyDictionaryOfAttachments(allocator: kCFAllocatorDefault, target: sampleBuffer, attachmentMode: kCMAttachmentMode_ShouldPropagate)as! [CIImageOption : Any]
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer, options: attachments )
            
        let curDeviceOrientation = UIDevice.current.orientation
        let exifOrientation = self.exifOrientation(from: curDeviceOrientation)
            
        let imageOptions = [CIDetectorImageOrientation: exifOrientation]
        
        if faceDetector == nil {
            self.faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: [CIDetectorAccuracy : CIDetectorAccuracyLow])
        }
        let features = faceDetector?.features(in: ciImage, options: imageOptions)
            
        if(features != nil && features!.count > 0) {
            // get the clean aperture
            // the clean aperture is a rectangle that defines the portion of the encoded pixel dimensions
            // that represents image data valid for display.
            let fdesc = CMSampleBufferGetFormatDescription(sampleBuffer)!
            let clap = CMVideoFormatDescriptionGetCleanAperture(fdesc, originIsAtTopLeft: false )
            

             self.processFaceBoxes(for: features!, forVideoBox: clap, orientation: curDeviceOrientation)
        } else {
            
            self.base.engine.jni.engineSetFace(0, and_y: 0, and_w: 0, and_h: 0)
        }
    }
    
    private func exifOrientation(from curDeviceOrientation: UIDeviceOrientation) -> Int {
            var exifOrientation: Int = 0
        let isUsingFrontFacingCamera:Bool = (self.base.videoDevicePosition == .front)

        
            /* kCGImagePropertyOrientation values
             The intended display orientation of the image. If present, this key is a CFNumber value with the same value as defined
             by the TIFF and EXIF specifications -- see enumeration of integer constants.
             The value specified where the origin (0,0) of the image is located. If not present, a value of 1 is assumed.
             
             used when calling featuresInImage: options: The value for this key is an integer NSNumber from 1..8 as found in kCGImagePropertyOrientation.
             If present, the detection will be done based on that orientation but the coordinates in the returned features will still be based on those of the image. */
            
            

            
            switch curDeviceOrientation {
            case .portraitUpsideDown:  // Device oriented vertically, home button on the top
                exifOrientation = PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM
            case .landscapeLeft:       // Device oriented horizontally, home button on the right
                if isUsingFrontFacingCamera {
                    exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT
                } else {
                    exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT
                }
            case .landscapeRight:      // Device oriented horizontally, home button on the left
                if isUsingFrontFacingCamera {
                    exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT
                } else {
                    exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT
                }
            case .portrait:            // Device oriented vertically, home button on the bottom
                fallthrough
            default:
                exifOrientation = PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP
            }
            return exifOrientation
    }
    private func cgImagePropertyOrientation(from deviceOrientation: UIDeviceOrientation) -> CGImagePropertyOrientation {
            return CGImagePropertyOrientation(rawValue: UInt32(exifOrientation(from: deviceOrientation)))!
    }
    
    private func faceRect(_ r:CGRect, forVideoBox clap: CGRect, orientation: Int32) ->CGRect {
        var w = r.size.width
        var h = r.size.height
        var x = r.origin.x + w/2
        var y = r.origin.y + h/2
        let w1 = clap.size.width-1
        let h1 = clap.size.height-1
        let tx = x
        let ty = y
        let tw = w
        let th = h
        
        if(orientation == ROTATION_0) {
            x = h1-ty
            y = tx
            w = th
            h = tw
        } else
        if(orientation == -ROTATION_0) {
            x = ty
            y = tx
            w = th
            h = tw
        } else
        if(orientation == ROTATION_90) {
            x = w1 - tx
            y = h1 - ty
        } else
        if(orientation == -ROTATION_90) {
            x = w1 - tx
        } else
        if(orientation == ROTATION_180) {
            x = h1-ty
            y = tx
            w = th
            h = tw
        } else
        if(orientation == -ROTATION_180) {
            x = ty
            y = tx
            w = th
            h = tw
        } else
        if(orientation == ROTATION_270) {
            // ok
        } else
        if(orientation == -ROTATION_270) {
            y = h1 - ty
        }
        return CGRect(x: x-w/2, y : y-h/2, width: w, height: h )
    }
    
    private func processFaceBoxes(for observations: [CIFeature], forVideoBox clap: CGRect, orientation: UIDeviceOrientation) {
        for feature in observations {
            self.base.onFace(faceRect(feature.bounds,forVideoBox: clap, orientation: self.base.engine.viOrientation))
        }
    }
}
