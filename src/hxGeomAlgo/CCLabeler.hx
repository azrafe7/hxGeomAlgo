package hxGeomAlgo;

import flash.display.BitmapData;
import hxGeomAlgo.HxPoint;
import hxGeomAlgo.HxPoint;
import hxGeomAlgo.HxPoint;
import hxGeomAlgo.HxPoint;
import hxGeomAlgo.PolyTools.Poly;
import openfl.geom.Matrix;
import openfl.geom.Point;
import openfl.system.System;


/**
 * ...
 * @author azrafe7
 */
class CCLabeler
{
	static var MARKED:UInt = 0xFFFFFFFF;
	static var UNLABELED:UInt = 0x00000000;
	
	static var searchDir:Array<{dx:Int, dy:Int}> = [
		{dx:  1, dy:  0}, // 0
		{dx:  1, dy:  1}, // 1    +-------x
		{dx:  0, dy:  1}, // 2    | 5 6 7
		{dx: -1, dy:  1}, // 3    | 4 P 0
		{dx: -1, dy:  0}, // 4    | 3 2 1
		{dx: -1, dy: -1}, // 5    y
		{dx:  0, dy: -1}, // 6
		{dx:  1, dy: -1}  // 7
	];
	
	static var markedPixels:BitmapData;
	static var offset:HxPoint = new HxPoint(1, 1);
	static var paddedBMD:BitmapData;
	static var tracingDir:Int = 0;
	static var labelIndex:Int = 0;
	static var point:HxPoint = new HxPoint();
	static var point2:HxPoint = new HxPoint();
	
	public static var labelMap:BitmapData;
	public static var contours:Array<Poly>;
	public static var numComponents:Int;
	public static var alphaThreshold:Int;

	public static var debugBMD:BitmapData;
	
	
	public function new() 
	{
		
	}
	
	static function draw():Void 
	{
		var p = new Point();
		debugBMD.fillRect(debugBMD.rect, 0);
		debugBMD.copyPixels(labelMap, labelMap.rect, p);
		debugBMD.draw(markedPixels);
		p.x += paddedBMD.width;
		debugBMD.copyPixels(paddedBMD, paddedBMD.rect, p);
		#if neko
		GeomAlgoTest.savePng(debugBMD, "debug" + labelIndex + ".png");
		#end
	}
	
	static public function run(bmd:BitmapData, alphaThreshold:Int = 1, alsoContour:Bool = true):BitmapData
	{
		// clone bmd, and pad it with a 1px transparent border
		paddedBMD = new BitmapData(bmd.width + 2, bmd.height + 2, true, UNLABELED);
		labelMap = paddedBMD.clone();
		markedPixels = paddedBMD.clone();
		paddedBMD.copyPixels(bmd, bmd.rect, offset);
		
		contours = alsoContour ? new Array<Poly>() : null;
		CCLabeler.alphaThreshold = alphaThreshold;
		numComponents = 0;
		labelIndex = 0;
		
		debugBMD = new BitmapData(paddedBMD.width * 2, paddedBMD.height, true, 0);
		
	#if (neko)
		GeomAlgoTest.savePng(paddedBMD, "paddedl.png");
	#end
		
		var width = paddedBMD.width,
			height = paddedBMD.height,
			isLabeled:Bool,
			leftLabeledPixel:UInt;
		
		var x, y = 1;
		while (y < height - 1) {
			x = 1;
			while (x < width - 1) {
				isLabeled = labelMap.getPixel32(x, y) != UNLABELED;
				if (isPixelSolid(x, y))
				{
					if (!isLabeled && !isPixelSolid(x, y - 1)) { // external contour
						//trace("external contour @ " + x + "," + y);
						setLabel(x, y, labelToColor(labelIndex));
						isLabeled = true;
						contourTrace(x, y, labelToColor(labelIndex), 7);
						labelIndex++;
					}
					if (!isPixelSolid(x, y + 1) && markedPixels.getPixel32(x, y + 1) != MARKED) { // internal contour
						//trace("internal contour @ " + x + "," + y);
						if (!isLabeled) {
							isLabeled = true;
							leftLabeledPixel = labelMap.getPixel32(x - 1, y);
							setLabel(x, y, leftLabeledPixel);
						}
						contourTrace(x, y, labelMap.getPixel32(x, y), 3);
					}
					if (!isLabeled) // internal point not belonging to any contour
					{
						//trace("internal point @ " + x + "," + y);
						leftLabeledPixel = labelMap.getPixel32(x - 1, y);
						setLabel(x, y, leftLabeledPixel);
					}
				}
				x++;
			}
			y++;
		}
		
		draw();
		return labelMap;	
	}
	
	static function quit():Void 
	{
		#if flash
			System.exit(1);
		#else
			Sys.exit(1);
		#end
	}
	
	static function setLabel(x:Int, y:Int, labelColor:UInt):Void 
	{
		labelMap.setPixel32(x, y, labelColor);
	}
	
	static function contourTrace(x:Int, y:Int, color:Int, dir:Int)
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
		
		point.setTo(x, y);
		tracingDir = dir;
		//trace(x, y, StringTools.hex(paddedBMD.getPixel32(x, y)), "dir: " + tracingDir);
		var firstPoint = true;
		while (true) {
			nextPointExists = nextOnContour(x, y, point);
			if (firstPoint) {
				point2.setTo(point.x, point.y);
				firstPoint = false;
			}
			if (nextPointExists) {
				tracingDir = (tracingDir + 6) % 8;	// update direction
				x = Std.int(point.x);
				y = Std.int(point.y);
				//trace(x, y, StringTools.hex(paddedBMD.getPixel32(x, y)), "dir: " + tracingDir);
				if (x == startX && y == startY) { // we're back to starting point
					nextOnContour(x, y, point);
					
					// break if next point is the same we found with the first call to nextOnContour
					// (which can actually be different based on tracing direction - f.e. in an x-shaped pattern)
					if (point.x == point2.x && point.y == point2.y) {
						break;
					}
				} else { // found next point on contour
					if (contours != null) {
						poly.push(point.clone());
					}
					setLabel(x, y, color);
				}
			} else { // isolated pixel
				break;
			}
		}
	}
	
	static function nextOnContour(x:Int, y:Int, nextPoint:HxPoint):Bool
	{
		var isolatedPixel = true,
			cx, cy;
		var dir = tracingDir;
		
		for (i in 0...searchDir.length) {
			cx = x + searchDir[tracingDir].dx;
			cy = y + searchDir[tracingDir].dy;
			nextPoint.setTo(cx, cy);
			if (isPixelSolid(cx, cy)) {
				isolatedPixel = false;
				break;
			} else { // set non-solid pixel as marked
				//trace("- " + cx + "," + cy);
				markedPixels.setPixel32(cx, cy, MARKED);
			}
			tracingDir = (tracingDir + 1) % 8;
		}
		
		return !isolatedPixel;
	}
	
	inline static public function labelToColor(label:Int):UInt 
	{
		return 0xFFFF0000 | label * 255 + 250;
	}
	
	/** Returns true if the pixel at `x`, `y` is opaque (according to `alphaThreshold`). */
	inline static public function isPixelSolid(x:Int, y:Int):Bool {
		return ((paddedBMD.getPixel32(x, y) >> 24) & 0xFF) >= alphaThreshold;
	}
}
