/**
 * Connected components labeling (8 connectivity) implementation.
 * 
 * Based on the paper of:
 * 
 * Fu Chang, Chun-jen Chen, Chi-jen Lu: A linear-time component-labeling algorithm using contour tracing technique (2004)
 * 
 * @see http://www.iis.sinica.edu.tw/papers/fchang/1362-F.pdf
 * 
 * @author azrafe7
 */

package hxGeomAlgo;

import flash.display.BitmapData;
import hxGeomAlgo.HxPoint;
import hxGeomAlgo.PolyTools.Poly;
import openfl.geom.Rectangle;
import openfl.utils.ByteArray;


@:enum abstract Connectivity(Int) {
	var FOUR_CONNECTED = 4;
	var EIGHT_CONNECTED = 8;
}

class CCLabeler
{
	/** Minimum alpha value to consider a pixel opaque. */
	public var alphaThreshold:Int;

	/** BitmapData containing the labeling info. */
	public var labelMap:BitmapData;
	
	/** Whether to store contours' points while labeling. */
	public var traceContours:Bool;
	
	/** Type of connectivity to search for. */
	public var connectivity:Connectivity;
	
	/** 
	 * Contours' points found while labeling (external contours
	 * are in clockwise order, while internal ones are in ccw order).
	 */
	public var contours(default, null):Array<Poly>;
	
	/** Number of connected components found. */
	public var numComponents(default, null):Int;

	
	private var MARKED:UInt = 0xFFFFFFFF;
	private var UNLABELED:UInt = 0x00000000;
	
	private var searchDir:Array<{dx:Int, dy:Int}> = [
		{dx:  1, dy:  0}, // 0
		{dx:  1, dy:  1}, // 1    +-------x
		{dx:  0, dy:  1}, // 2    | 5 6 7
		{dx: -1, dy:  1}, // 3    | 4 P 0
		{dx: -1, dy:  0}, // 4    | 3 2 1
		{dx: -1, dy: -1}, // 5    y
		{dx:  0, dy: -1}, // 6
		{dx:  1, dy: -1}  // 7
	];
	
	private var tracingDir:Int = 0;
	private var labelIndex:Int = 0;
	private var contourPoint:HxPoint = new HxPoint();
	private var secondContourPoint:HxPoint = new HxPoint();
	
	private var sourceBMD:BitmapData;
	private var sourceBytes:ByteArray;
	private var markedPixels:BitmapData;
	private var markedBytes:ByteArray;
	private var labelBytes:ByteArray;
	
	private var clipRect:Rectangle;
	private var width:Int;
	private var height:Int;
	
	private var colors:Array<UInt> = [];
	private var hue:Float = .60;

	/**
	 * Constructor.
	 * 
	 * @param	bmd				BitmapData to use as source for labeling.
	 * @param	alphaThreshold  Minimum alpha value to consider a pixel opaque.
	 * @param	traceContours	Whether to store contours' points while labeling.
	 * @param	connectivity	Type of connectivity to search for (defaults to EIGHT_CONNECTED).
	 * @param	clipRect		The region of bmd to process (defaults to the entire image).
	 */
	public function new(bmd:BitmapData, alphaThreshold:Int = 1, traceContours:Bool = true, connectivity:Connectivity = Connectivity.EIGHT_CONNECTED, clipRect:Rectangle = null)
	{
		setSource(bmd, clipRect);
		
		this.alphaThreshold = alphaThreshold;
		this.connectivity = connectivity;
		this.traceContours = traceContours;
		numComponents = 0;
	}
	
	/** 
	 * Updates the BitmapData to use as source and its clipRect. 
	 * 
	 * NOTE: If you modifiy your bitmapData between calls to run() you may 
	 * also want to re-set the source so that the byteArrays get updated too.
	 */
	public function setSource(bmd:BitmapData, clipRect:Rectangle = null)
	{
		this.sourceBMD = bmd;
		this.clipRect = clipRect != null ? clipRect : bmd.rect;
		
		width = Std.int(this.clipRect.width);
		height = Std.int(this.clipRect.height);
		labelMap = new BitmapData(width, height, true, UNLABELED);
		markedPixels = labelMap.clone();
		
		sourceBytes = bmd.getPixels(this.clipRect);
		labelBytes = labelMap.getPixels(labelMap.rect);
		markedBytes = markedPixels.getPixels(markedPixels.rect);
	}
	
	/**
	 * Labels 8-connected components and writes them in the returned BitmapData (also stored in `labelMap`).
	 * If `traceContours` has been set, it also saves contours' points in the `contours` variable.
	 */
	public function run():BitmapData
	{
		contours = traceContours ? new Array<Poly>() : null;
		numComponents = 0;
		labelIndex = 0;
		
		var	isLabeled:Bool;
		var leftLabeledPixel:UInt;
		
		var x, y = 0;
		while (y < height) {
			x = 0;
			while (x < width) {
				isLabeled = getPixel(labelBytes, x, y, UNLABELED) != UNLABELED;
				if (isPixelSolid(x, y))
				{
					if (!isLabeled && !isPixelSolid(x, y - 1)) { // external contour
						//trace("external contour @ " + x + "," + y);
						setLabel(x, y, labelToColor(labelIndex));
						isLabeled = true;
						contourTrace(x, y, labelToColor(labelIndex), 7);
						labelIndex++;
					}
					if (!isPixelSolid(x, y + 1) && getPixel(markedBytes, x, y + 1, MARKED) != MARKED) { // internal contour
						//trace("internal contour @ " + x + "," + y);
						if (!isLabeled) {
							leftLabeledPixel = getPixel(labelBytes, x - 1, y);
							setLabel(x, y, leftLabeledPixel);
							isLabeled = true;
						}
						contourTrace(x, y, getPixel(labelBytes, x, y), 3);
					}
					if (!isLabeled) // internal point not belonging to any contour
					{
						//trace("internal point @ " + x + "," + y);
						leftLabeledPixel = getPixel(labelBytes, x - 1, y);
						setLabel(x, y, leftLabeledPixel);
					}
				}
				x++;
			}
			y++;
		}
		
		labelBytes.position = 0;
		markedBytes.position = 0;
		labelMap.setPixels(labelMap.rect, labelBytes);
		markedPixels.setPixels(markedPixels.rect, markedBytes);
		
		numComponents = labelIndex;
		return labelMap;	
	}
	
	/**
	 * Traces the contour starting at `x`, `y`.
	 * 
	 * @param	x			Starting x of the contour
	 * @param	y			Starting y of the contour
	 * @param	labelColor	Color to use
	 * @param	dir			Initial tracing direction
	 */
	private function contourTrace(x:Int, y:Int, labelColor:UInt, dir:Int)
	{
		var startX:Int = x,
			startY:Int = y,
			poly:Poly = null,
			nextPointExists;
		
		if (contours != null) {
			poly = new Poly();
			poly.push(new HxPoint(x, y));
			contours.push(poly);
		}
		
		contourPoint.setTo(x, y);
		tracingDir = dir;
		//trace(x, y, StringTools.hex(getPixel(sourceBytes(x, y)), "dir: " + tracingDir);
		var firstPoint = true;
		while (true) {
			nextPointExists = nextOnContour(x, y, contourPoint);
			if (firstPoint) {
				secondContourPoint.setTo(contourPoint.x, contourPoint.y);
				firstPoint = false;
			}
			if (nextPointExists) {
				tracingDir = (tracingDir + 6) % 8;	// update direction
				x = Std.int(contourPoint.x);
				y = Std.int(contourPoint.y);
				//trace(x, y, StringTools.hex(getPixel(sourceBytes, x, y)), "dir: " + tracingDir);
				if (x == startX && y == startY) { // we're back to starting point
					nextOnContour(x, y, contourPoint);
					
					// break if next point is the same we found with the first call to nextOnContour
					// (which can actually be different based on tracing direction - f.e. in an x-shaped pattern)
					if (contourPoint.x == secondContourPoint.x && contourPoint.y == secondContourPoint.y) {
						break;
					}
				} else { // found next point on contour
					if (contours != null) {
						poly.push(contourPoint.clone());
					}
					setLabel(x, y, labelColor);
				}
			} else { // isolated pixel
				break;
			}
		}
	}
	
	/** Finds the next point on contour and stores it into `nextPoint` (returns false if no next point exists). */
	private function nextOnContour(x:Int, y:Int, nextPoint:HxPoint):Bool
	{
		var isolatedPixel = true,
			cx, cy,
			numSteps = 8,
			step = 1;
			
		// if we're in FOUR_CONNECTED mode then only even values of `tracingDir` are possible 
		// (i.e. no diagonals and we advance by two)
		if (connectivity == Connectivity.FOUR_CONNECTED) {
			if (tracingDir & 1 == 1) tracingDir = (tracingDir + 1) % 8;
			numSteps = 4;
			step = 2;
		}
		
		var dir = tracingDir;
		
		for (i in 0...numSteps) {
			cx = x + searchDir[tracingDir].dx;
			cy = y + searchDir[tracingDir].dy;
			nextPoint.setTo(cx, cy);
			if (isPixelSolid(cx, cy)) {
				isolatedPixel = false;
				break;
			} else { // set non-solid pixel as marked
				//trace("- " + cx + "," + cy);
				setPixel(markedBytes, cx, cy, MARKED);
			}
			tracingDir = (tracingDir + step) % 8;
		}
		
		return !isolatedPixel;
	}
	
	/**
	 * Maps `label` to a color. 
	 * Override this to use your own label-to-color mapping. 
	 */
	public function labelToColor(label:Int):UInt 
	{
		if (label >= colors.length) {
			colors[label] = 0xFF000000 | getColorFromHSV(hue, .9, 1);
			hue = (hue + .12) % 1.0;
		}
		return colors[label];
	}
	
	/**
	 * Override this to have a way to add logic everytime a pixel is labeled.
	 */
	private function setLabel(x:Int, y:Int, labelColor:UInt):Void 
	{
		setPixel(labelBytes, x, y, labelColor);
	}
	
	/**
	 * Returns the 32-bit pixel color at position (`x`, `y`) from `ba`.
	 * If the specified position is out of bounds, `outerValue` is returned.
	 */
	inline private function getPixel(ba:ByteArray, x:Int, y:Int, outerValue:UInt = 0):UInt 
	{
		var pos:UInt = (y * width + x) << 2;
		var res = outerValue;
		if (x >= 0 && y >= 0 && x < width && y < height) {
			ba.position = pos;
			res = ba.readUnsignedInt();
		}
		return res;
	}
	
	/**
	 * Writes a 32-bit pixel `color` at position (`x`, `y`) in `ba`.
	 * If the specified position is out of bounds nothing is written.
	 */
	inline private function setPixel(ba:ByteArray, x:Int, y:Int, color:UInt):Void
	{
		var pos:UInt = (y * width + x) << 2;
		ba.position = pos;
		if (x >= 0 && y >= 0 && x < width && y < height) ba.writeUnsignedInt(color);
	}

	/** 
	 * Returns true if the pixel at `x`, `y` is opaque (according to `alphaThreshold`). 
	 * Override this to use your own logic to identify solid pixels.
	 */
	private function isPixelSolid(x:Int, y:Int):Bool {
		return (getPixel(sourceBytes, x, y, 0) >> 24 & 0xFF) >= alphaThreshold;
	}
	
	private function getColorFromHSV(h:Float, s:Float, v:Float):UInt
	{
		h = Std.int(h * 360);
		var hi:Int = Math.floor(h / 60) % 6,
			f:Float = h / 60 - Math.floor(h / 60),
			p:Float = (v * (1 - s)),
			q:Float = (v * (1 - f * s)),
			t:Float = (v * (1 - (1 - f) * s));
		switch (hi)
		{
			case 0: return Std.int(v * 255) << 16 | Std.int(t * 255) << 8 | Std.int(p * 255);
			case 1: return Std.int(q * 255) << 16 | Std.int(v * 255) << 8 | Std.int(p * 255);
			case 2: return Std.int(p * 255) << 16 | Std.int(v * 255) << 8 | Std.int(t * 255);
			case 3: return Std.int(p * 255) << 16 | Std.int(q * 255) << 8 | Std.int(v * 255);
			case 4: return Std.int(t * 255) << 16 | Std.int(p * 255) << 8 | Std.int(v * 255);
			case 5: return Std.int(v * 255) << 16 | Std.int(p * 255) << 8 | Std.int(q * 255);
			default: return 0;
		}
		return 0;
	}
}
