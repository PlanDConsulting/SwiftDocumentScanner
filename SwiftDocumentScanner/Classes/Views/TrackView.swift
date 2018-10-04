//
//  TrackView.swift
//  DocumentScanner
//
//  Created by Jonas Beckers on 25/02/18.
//

import UIKit

public final class TrackView: UIView {

	public var lineColor: UIColor = .green {
		didSet { shape.strokeColor = lineColor.cgColor }
	}
	public var fillColor: UIColor = UIColor.green.withAlphaComponent(0.5) {
		didSet { shape.fillColor = fillColor.cgColor }
	}
	public var lineWidth: CGFloat = 2 {
		didSet { shape.lineWidth = lineWidth }
	}

	private var shape = CAShapeLayer()
	private var updated: Double = 0

	override init(frame: CGRect) {
		super.init(frame: frame)

		setup()
	}

	required public init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)

		setup()
	}

	private func setup() {
		shape.strokeColor = lineColor.cgColor
		shape.fillColor = fillColor.cgColor
		shape.lineWidth = lineWidth

		layer.addSublayer(shape)
	}

	override public func layoutSubviews() {
		super.layoutSubviews()

		shape.frame = bounds
		shape.strokeColor = lineColor.cgColor
		shape.fillColor = fillColor.cgColor
		shape.lineWidth = lineWidth
	}

	func update(path: UIBezierPath?) {
		if let path = path {
			shape.path = path.cgPath
		} else {
			shape.path = nil
		}
	}

}
