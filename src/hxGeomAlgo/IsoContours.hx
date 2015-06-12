/**
 * IsoContours implementation (Clockwise).
 * 
 * Based on:
 * 
 * @see http://en.wikipedia.org/wiki/Marching_squares
 * 
 * @author azrafe7
 */

package hxGeomAlgo;

import haxe.ds.ArraySort;
import haxe.Timer;
import hxGeomAlgo.HxPoint.HxPointData;
import hxPixels.Pixels;
import haxe.ds.ObjectMap;



typedef IsoFunction = Pixels->Int->Int->Float; // function(pixels:Pixels, x:Int, y:Int):Float


class IsoContours
{

	public var isoFunction:IsoFunction;
	
	private var pixels:Pixels;
	private var width:Int;
	private var height:Int;
	
	private var point:HxPoint = new HxPoint();

	var values:Array<Array<Float>>;
	
	/**
	 * Constructor.
	 * 
	 * @param	pixels			Pixels to use as source.
	 */
	public function new(pixels:Pixels, isoFunction:IsoFunction = null)
	{
		this.pixels = pixels;
		this.width = pixels.width;
		this.height = pixels.height;
		this.values = null;
		
		if (isoFunction == null) this.isoFunction = iso;
	}
	
	/*
	 * Pad pixels with a 1px border (with value 0) on all sides
	 * Scan padded pixels from top to bottom, and left to right (i.e. row by row)
	 * Compute values using iso and assign binaryIdx of current cell to grid while scanning
	 * (Grid will be of size paddedPixels.width-1 x paddedPixels.height-1)
	 * If current cell is an active cell
	 *   save grid x,y in startingActiveCell and lastActiveCell
	 *   follow the contour and add points to current contour 
	 *   if we're going horizontally update lastActiveCell
	 *   break out when we arrive at startActiveCell
	 *   assign startActiveCell = lastActiveCell+1
	 *   repeat
	 *   
	 */
	public function find(isoValue:Float = 0, addBorders:Bool = true, recalcValues:Bool = true):Array<Array<HxPoint>> {
		
		var startTime = Timer.stamp();
		var points = march(isoValue, addBorders, recalcValues);
		trace("  march: " + (Timer.stamp() - startTime));
		
		startTime = Timer.stamp();
		removeDegenerateSegments(points);
		trace("  remove: " + (Timer.stamp() - startTime));
		
		startTime = Timer.stamp();
 		var contours = merge(points);
		trace("  merge: " + (Timer.stamp() - startTime));
		
		//return [points];
		return contours;
	}
	
	function removeDegenerateSegments(points:Array<HxPoint>):Int {
		var numDegenerates = 0;
		
		var i = points.length - 2;
		while (i >= 0) {
			var p = points[i];
			var q = points[i + 1];
			if (p.equals(q)) {
				numDegenerates++;
				points.splice(i, 2);
			}
			i -= 2;
		}
		
		return numDegenerates;
	}
	
	function swapSegments(points:Array<HxPoint>, i:Int, j:Int) {
		var tmp = points[i];
		points[i] = points[j];
		points[j] = tmp;
		tmp = points[i + 1];
		points[i + 1] = points[j + 1];
		points[j + 1] = tmp;
	}
	
	function merge(points:Array<HxPoint>) {
		if (points.length <= 2) return [points];
		
		var isoLines = [];
		
		var segments = [];
		trace(points.length >> 1);
		
		/*var notFounds = [];
		for (i in 0...(points.length >> 1) - 1) {
			var p0 = points[2 * i];
			var q0 = points[2 * i + 1];
			
			var found = false;
			for (j in 0...points.length >> 1) {
				if (i == j) continue;
				var p1 = points[2 * j];
				var q1 = points[2 * j + 1];
				
				if (q0.equals(p1)) {
					found = true;
					break;
				}
			}
			
			if (!found) {
				trace("not found for " + q0);
				notFounds.push(q0);
			}
		}
		
		trace(notFounds.length + " points not found ");
		
		return notFounds;*/
		
		var nAppends = 0;
		var nInserts = 0;
		
		var len = points.length;
		var i = 0;
		while (i < len) {
			var start = points[i];
			var end = points[i + 1];
			
			var reversedIsoLine = [start];
			var isoLine = [end];
			
			var j = len - 2;
			while (j > i) {
				var p = points[j];
				var q = points[j + 1];
				
				if (end.equals(p)) {
					isoLine.push(q);
					end = q;
					//points.splice(j, 2);
					len = len - 2;
					swapSegments(points, j, len);
					j = len; // restart from end
					nAppends++;
				} else if (start.equals(q)) {
					reversedIsoLine.push(p);
					//isoLine.insert(0, p);
					start = p;
					//points.splice(j, 2);
					len = len - 2;
					swapSegments(points, j, len);
					j = len; // restart from end
					nInserts++;
				}
				j -= 2;
			}
			
			reversedIsoLine.reverse();
			isoLines.push(reversedIsoLine.concat(isoLine));
			i += 2;
		}
		
		trace(nAppends, nInserts);
		return isoLines;
	}
	
	function removeFromMap(map:Map<String, Array<HxPoint>>, key:String, item:HxPoint) {
		var arr = map[key];
		for (i in 0...arr.length) {
			if (arr[i].equals(item)) {
				arr.splice(i, 1);
				break;
			}
		}
		if (map[key].length == 0) map.remove(key);
	}
	
	function march(isoValue:Float = 0, addBorders:Bool = true, recalcValues:Bool = true) {
		var paddingBorder = addBorders ? 1 : 0;
		
		var points = [];
		
		if (recalcValues || values == null) {
			values = [];
			
			for (x in 0...width + 2 * paddingBorder) {
				values[x] = [];
				
				for (y in 0...height + 2 * paddingBorder) {
					
					var value = isoFunction(pixels, x - paddingBorder, y - paddingBorder);
					values[x][y] = value;
				}
			}
		}
		
		var offset = .5 - paddingBorder;
		for (x in 0...width + 2 * paddingBorder - 1) {
			
			for (y in 0...height + 2 * paddingBorder - 1) {
				
				// calc binaryIdx (CW from msb)
				var topLeft = values[x][y];
				var topRight = values[x + 1][y];
				var bottomRight = values[x + 1][y + 1];
				var bottomLeft = values[x][y + 1];
				
				var binaryIdx = 0;
				if (topLeft > isoValue) binaryIdx += 8;
				if (topRight > isoValue) binaryIdx += 4;
				if (bottomRight > isoValue) binaryIdx += 2;
				if (bottomLeft > isoValue) binaryIdx += 1;
				
				if (binaryIdx != 0 && binaryIdx != 15) {
					
					var topPoint = new HxPoint(offset + x + interp(isoValue, topLeft, topRight), offset + y);
					var leftPoint = new HxPoint(offset + x, offset + y + interp(isoValue, topLeft, bottomLeft));
					var rightPoint = new HxPoint(offset + x + 1, offset + y + interp(isoValue, topRight, bottomRight));
					var bottomPoint = new HxPoint(offset + x + interp(isoValue, bottomLeft, bottomRight), offset + y + 1);
						
					// resolve saddle ambiguities
					if (binaryIdx == 5 || binaryIdx == 10) {
						var avgValue = (topLeft + topRight + bottomRight + bottomLeft) / 4;
						if (avgValue <= 0) { // flip binaryIdx
							binaryIdx = ~binaryIdx & 15;
						}
					}
					
					// add segments (pairs of points) based on binaryIdx. 
					// CW order is granted, meaning that the first point of a segment is the 
					// second point of another segment (except for open isolines)
					switch (binaryIdx) { 
						case 1: 
							addSegment(points, bottomPoint, leftPoint);
						case 2: 
							addSegment(points, rightPoint, bottomPoint);
						case 3: 
							addSegment(points, rightPoint, leftPoint);
						case 4: 
							addSegment(points, topPoint, rightPoint);
						case 5: // saddle
							addSegment(points, topPoint, leftPoint);
							addSegment(points, bottomPoint, rightPoint);
						case 6: 
							addSegment(points, topPoint, bottomPoint);
						case 7: 
							addSegment(points, topPoint, leftPoint);
						case 8: 
							addSegment(points, leftPoint, topPoint);
						case 9: 
							addSegment(points, bottomPoint, topPoint);
						case 10: // saddle
							addSegment(points, leftPoint, bottomPoint);
							addSegment(points, rightPoint, topPoint);
						case 11: 
							addSegment(points, rightPoint, topPoint);
						case 12: 
							addSegment(points, leftPoint, rightPoint);
						case 13: 
							addSegment(points, bottomPoint, rightPoint);
						case 14: 
							addSegment(points, leftPoint, bottomPoint);
						default:
					}
				}
			}
		}
		
		//printGrid(values);
		
		//convert2Ascii(grid);
		
		return points;
	}
	
	function addSegment(points:Array<HxPoint>, p:HxPoint, q:HxPoint) {
		if (p.equals(q)) {
			return;
			//trace(p, q);
		}
		var fromPoint = q;
		var toPoint = p;
		points.push(fromPoint);
		points.push(toPoint);
	}
	
	public function interp(isoValue:Float, fromValue:Float, toValue:Float):Float {
		//return .5;
		if (fromValue == toValue) return 0;
		return (isoValue - fromValue) / (toValue - fromValue);
	}
	
	public function printGrid<T>(grid:Array<Array<T>>) {
		var str = "";
		for (y in 0...grid[0].length) {
			for (x in 0...grid.length) {
				str += grid[x][y] + ",";
			}
			str += "\n";
		}
		trace(str);
	}
	
	public function convert2Ascii(grid:Array<Array<Int>>) {
		var str = "";
		for (y in 0...grid[0].length) {
			for (x in 0...grid.length) {
				var binIdx = grid[x][y];
				var char = switch (binIdx) {
					/*case 0: "█";
					case 1: "▜";
					case 2: "▛";
					case 3: "▀";
					case 4: "▙";
					case 5: "▚";
					case 6: "▌";
					case 7: "▘";
					case 8: "▟";
					case 9: "▐";
					case 10: "▞";
					case 11: "▝";
					case 12: "▄";
					case 13: "▗";
					case 14: "▖";
					case 15: " ";*/
					case 0: "0";
					case 1: "\\";
					case 2: "/";
					case 3: "-";
					case 4: "\\";
					case 5: "x";// "\\";
					case 6: "|";
					case 7: "/";
					case 8: "/";
					case 9: "|";
					case 10: "x";// "/";
					case 11: "\\";
					case 12: "-";
					case 13: "/";
					case 14: "\\";
					case 15: " ";
					default: "";
				}
				str += char;
			}
			str += "\n";
		}
		trace(str);
	}
	
	static public function iso(pixels:Pixels, x:Int, y:Int):Float {
		if (isOutOfBounds(pixels, x, y)) return -255;
		else return ((pixels.getPixel32(x, y) >> 24) & 0xFF);
		//else return ((pixels.getPixel32(x, y) >> 16) & 0xFF) - 204;
		/*var ix = Std.int(x); if (ix<0) ix = 0; else if(ix>=pixels.width)  ix = pixels.width -1;
		var iy = Std.int(y); if (iy<0) iy = 0; else if(iy>=pixels.height) iy = pixels.height - 1;
		var fx = x - ix; if (fx<0) fx = 0; else if(fx>1) fx = 1;
		var fy = y - iy; if (fy<0) fy = 0; else if(fy>1) fy = 1;
		var gx = 1 - fx;
		var gy = 1 - fy;

		var a00 = pixels.getPixel32(ix, iy) >>> 24;
		var a01 = pixels.getPixel32(ix, iy + 1) >>> 24;
		var a10 = pixels.getPixel32(ix + 1, iy) >>> 24;
		var a11 = pixels.getPixel32(ix + 1, iy + 1) >>> 24;

		var ret = gx * gy * a00 + fx * gy * a10 + gx * fy * a01 + fx * fy * a11;
		return ret - 0x80;*/
	}
	
	inline static public function isOutOfBounds(pixels:Pixels, x:Int, y:Int):Bool {
		return (x < 0 || y < 0 || x >= pixels.width || y >= pixels.height);
	}	
}