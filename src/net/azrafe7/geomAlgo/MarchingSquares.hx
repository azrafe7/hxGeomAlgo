/**
 * Marching Squares implementation (Counterclockwise).
 * 
 * Adapted/modified from:
 * 
 * @see http://devblog.phillipspiess.com/2010/02/23/better-know-an-algorithm-1-marching-squares/	(AS3 - by Phil Spiess)
 * @see http://www.tomgibara.com/computer-vision/marching-squares									(Java - by Tom Gibara)
 * 
 * @author azrafe7
 */

package net.azrafe7.geomAlgo;

import flash.display.BitmapData;
import flash.geom.Point;
import flash.geom.Rectangle;
import flash.utils.ByteArray;


enum StepDirection {
	NONE;
	UP;
	LEFT;
	DOWN;
	RIGHT;
}


class MarchingSquares
{
	/** Minimum alpha value to consider a pixel opaque. */
	public var alphaThreshold:Int = 1;

	private var prevStep:StepDirection = StepDirection.NONE;
	private var nextStep:StepDirection = StepDirection.NONE;
	
	private var bmd:BitmapData = null;
	private var width:Int;
	private var height:Int;
	private var byteArray:ByteArray;
	
	private var point:Point = new Point();


	/**
	 * Constructor.
	 * 
	 * @param	bmd				BitmapData to use as source.
	 * @param	alphaThreshold  Minimum alpha value to consider a pixel opaque.
	 */
	public function new(bmd:BitmapData, alphaThreshold:Int = 1)
	{
		source = bmd;
		
		this.alphaThreshold = alphaThreshold;
	}
	
	/** BitmapData to use as source. */
	public var source(default, set):BitmapData;
	private function set_source(value:BitmapData):BitmapData 
	{
		if (bmd != value) {
			bmd = value;
			byteArray = bmd.getPixels(bmd.rect);
			width = bmd.width;
			height = bmd.height;
		}
		return bmd;
	}
	
	/** 
	 * Finds the perimeter.
	 * 
	 * @param	startPoint	Start from this point (if null it will be calculated automatically).
	 * @return	An array containing the points on the perimeter.
	 */
	public function march(?startPoint:Point = null):Array<Point> 
	{
		if (startPoint == null) findStartPoint();
		else point.setTo(startPoint.x, startPoint.y);
		
		return walkPerimeter(Std.int(point.x), Std.int(point.y));
	}
	
	/** Finds the first opaque pixel location (starting from top-left corner). */
	public function findStartPoint():Point {
		byteArray.position = 0;
		point.setTo(0, 0);
		
		for (idx in byteArray.position...byteArray.length >> 2)
		{
			var alphaIdx:Int = idx << 2;
			if (byteArray[alphaIdx] >= alphaThreshold) {
				point.setTo(idx % width, idx / height);
				break;
			}
		}
		
		return point;
 	}
	
	/** Finds points belonging to the perimeter starting from `startX`, `startY`. */
	private function walkPerimeter(startX:Int, startY:Int):Array<Point> 
	{
		// clamp to source boundaries
		if (startX < 0) startX = 0;
		if (startX > width) startX = width;
		if (startY < 0) startY = 0;
		if (startY > height) startY = height;

		var pointList = new Array<Point>();

		var x:Int = startX;
		var y:Int = startY;

		// loop until we return to the starting point
		var done = false;
		while (!done) {
			step(x, y);

			// add perimeter point to return list (ensuring it's not out of boundaries)
			pointList.push(new Point(x < width ? x : width - 1, y < height ? y : height - 1));

			switch (nextStep)
			{
				case StepDirection.UP:    y--; 
				case StepDirection.LEFT:  x--; 
				case StepDirection.DOWN:  y++; 
				case StepDirection.RIGHT: x++; 
				default: throw "Illegal state at point (x: " + x + ", y: " + y + ").";
			}
			
			done = (x == startX && y == startY);
		}

		return pointList;
	}
	
	/** Calculates the next state for pixel at `x`, `y`. */
	public function step(x:Int, y:Int):Void 
	{
		var upLeft = isPixelSolid(x - 1, y - 1);
		var upRight = isPixelSolid(x, y - 1);
		var downLeft = isPixelSolid(x - 1, y);
		var downRight = isPixelSolid(x, y);
		
		// save previous step
		prevStep = nextStep;

		// calc current state
		var state:Int = 0;

		if (upLeft) state |= 1;
		if (upRight) state |= 2;
		if (downLeft) state |= 4;
		if (downRight) state |= 8;

		if (state == 0 || state == 15) throw "Error: point (x: " + x + ", y: " + y + ") doesn't lie on perimeter.";
		
		switch (state)
		{
			case 1, 5, 13: 
				nextStep = StepDirection.UP;
			case 2, 3, 7: 
				nextStep = StepDirection.RIGHT;
			case 4, 12, 14: 
				nextStep = StepDirection.LEFT;
			case 6:
				nextStep = (prevStep == StepDirection.UP ? StepDirection.LEFT : StepDirection.RIGHT);
			case 8, 10, 11: 
				nextStep = StepDirection.DOWN;
			case 9:
				nextStep = (prevStep == StepDirection.RIGHT ? StepDirection.UP : StepDirection.DOWN);
			default: 
				throw "Illegal state at point (x: " + x + ", y: " + y + ").";
		}
	}
	
	/** Returns true if the pixel at `x`, `y` is opaque (according to `alphaThreshold`). */
	inline public function isPixelSolid(x:Int, y:Int):Bool {
		return (x >= 0 && y >= 0 && x < width && y < height && (byteArray[(y * width + x) << 2] >= alphaThreshold));
	}
}