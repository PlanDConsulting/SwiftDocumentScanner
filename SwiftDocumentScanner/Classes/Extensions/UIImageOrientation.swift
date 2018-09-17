//
//  UIImageOrientation.swift
//  DocumentScanner
//
//  Created by Joey Patino on 9/17/18.
//

import AVFoundation

public extension UIImageOrientation {
	public init(videoOrientation: AVCaptureVideoOrientation) {
		switch videoOrientation {
		case .portrait: self = .up
		case .portraitUpsideDown: self = .down
		case .landscapeLeft: self = .left
		case .landscapeRight: self = .right
		}
	}

	public var rotation: CGFloat {
		switch self {
		case .up: return 0
		case .down: return 180
		case .left: return 90
		case .right: return -90
		default: return 0
		}
	}
}


