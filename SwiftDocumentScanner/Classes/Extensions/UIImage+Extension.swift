//
//  UIImage+Extension.swift
//  DocumentScanner
//
//  Created by Jonas Beckers on 25/02/18.
//

import UIKit

public extension UIImage {

	public func fixOrientation(orientation: UIImageOrientation? = nil) -> UIImage {
		guard orientation == nil && imageOrientation != .up else { return self }

		var transform = CGAffineTransform.identity
		let orientation = orientation ?? imageOrientation

		switch orientation {
		case .down, .downMirrored:
			transform = transform.translatedBy(x: size.width, y: size.height)
			transform = transform.rotated(by: CGFloat.pi)
		case .left, .leftMirrored:
			transform = transform.translatedBy(x: size.width, y: 0)
			transform = transform.rotated(by: CGFloat.pi / 2)
		case .right, .rightMirrored:
			transform = transform.translatedBy(x: 0, y: size.height)
			transform = transform.rotated(by: -(CGFloat.pi / 2))
		default:
			break
		}

		switch orientation {
		case .upMirrored, .downMirrored:
			transform.translatedBy(x: size.width, y: 0)
			transform.scaledBy(x: -1, y: 1)
		case .leftMirrored, .rightMirrored:
			transform.translatedBy(x: size.height, y: 0)
			transform.scaledBy(x: -1, y: 1)
		default:
			break
		}

		guard let bitsPerComponent = self.cgImage?.bitsPerComponent, let colorSpace = self.cgImage?.colorSpace, let ctx: CGContext = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: bitsPerComponent, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return self }
		ctx.concatenate(transform)

		guard let cgImage = self.cgImage else { return self }
		switch orientation {
		case .left, .leftMirrored, .right, .rightMirrored:
			ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.height, height: size.width))
		default:
			ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
			break
		}

		guard let image: CGImage = ctx.makeImage() else { return self }
		return UIImage(cgImage: image)
	}

}

public extension UIImage {

    public func rotated(by degrees: CGFloat) -> UIImage {
        guard let cgImage = cgImage else { return self }
        //Calculate the size of the rotated view's containing box for our drawing space
        let rotatedViewBox: UIView = UIView(frame: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        let t: CGAffineTransform = CGAffineTransform(rotationAngle: degrees * CGFloat.pi / 180)
        rotatedViewBox.transform = t
        let rotatedSize: CGSize = rotatedViewBox.frame.size
        //Create the bitmap context
        UIGraphicsBeginImageContext(rotatedSize)
        let bitmap: CGContext = UIGraphicsGetCurrentContext()!
        //Move the origin to the middle of the image so we will rotate and scale around the center.
        bitmap.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
        //Rotate the image context
        bitmap.rotate(by: (degrees * CGFloat.pi / 180))
        //Now, draw the rotated/scaled image into the context
        bitmap.scaleBy(x: 1.0, y: -1.0)
        bitmap.draw(cgImage, in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
        let newImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }

}
