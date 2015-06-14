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


/** function(pixels:Pixels, x:Int, y:Int):Float */
typedef IsoFunction = Pixels->Int->Int->Float;


class IsoContours
{

	public var isoFunction:IsoFunction;
	
	var pixels:Pixels;
	var width:Int;
	var height:Int;
	
	var values:Array<Array<Float>>;

	var adjacencyMap:AdjacencyMap;
	
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
	
	public function find(isoValue:Float = 0, addBorders:Bool = true, recalcValues:Bool = true):Array<Array<HxPoint>> {
		
		var startTime = Timer.stamp();
		march(isoValue, addBorders, recalcValues);
		trace("  march: " + (Timer.stamp() - startTime));
		
		startTime = Timer.stamp();
 		var contours = merge();
		trace("  merge: " + (Timer.stamp() - startTime));
		
		return contours;
	}
	
	function merge() {
		
		var isoLines = [];
		
		var segment = null;
		while ((segment = adjacencyMap.getFirstSegment()) != null) {
			
			var start = segment.from;
			var end = segment.to;
			
			var reversedIsoLine = [start];
			var isoLine = [end];
			
			while (true) {
				end = adjacencyMap.getEndingPointOf(end);
				start = adjacencyMap.getStartingPointOf(start);
				
				if (end != null) {
					isoLine.push(end);
				}
				if (start != null) {
					reversedIsoLine.push(start);
				}
				
				if (start == null && end == null) break;
			}
			
			reversedIsoLine.reverse();
			isoLines.push(reversedIsoLine.concat(isoLine));
		}
		
		return isoLines;
	}
	
	function march(isoValue:Float = 0, addBorders:Bool = true, recalcValues:Bool = true) {
		
		adjacencyMap = new AdjacencyMap();
		
		// run isoFunction through all pixels
		if (recalcValues || values == null) {
			values = [];
			
			for (x in 0...width + 2) {
				values[x] = [];
				
				for (y in 0...height + 2) {
					
					var value = isoFunction(pixels, x - 1, y - 1);
					values[x][y] = value;
				}
			}
		}
		
		// adjust loop variables
		var offset = -.5;
		var startX = 0;
		var startY = 0;
		var endX = width + 1;
		var endY = height + 1;
		if (!addBorders) {
			startX = 1;
			startY = 1;
			endX = width;
			endY = height;
		}
		
		// march
		for (x in startX...endX) {
			
			for (y in startY...endY) {
				
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
						
					// resolve saddle ambiguities by using central (/average) value
					if (binaryIdx == 5 || binaryIdx == 10) {
						var avgValue = (topLeft + topRight + bottomRight + bottomLeft) / 4;
						if (avgValue <= 0) binaryIdx = ~binaryIdx & 15; // flip binaryIdx
					}
					
					// add segments (pairs of points) based on binaryIdx. 
					// consistent order is enforced, meaning that the first point of a 
					// segment is guaranteed to be the second point of another segment 
					// (except for head and tail segments of open isolines of course)
					switch (binaryIdx) { 
						case 1: 
							addSegment(leftPoint, bottomPoint);
						case 2: 
							addSegment(bottomPoint, rightPoint);
						case 3: 
							addSegment(leftPoint, rightPoint);
						case 4: 
							addSegment(rightPoint, topPoint);
						case 5: // saddle
							addSegment(leftPoint, topPoint);
							addSegment(rightPoint, bottomPoint);
						case 6: 
							addSegment(bottomPoint, topPoint);
						case 7: 
							addSegment(leftPoint, topPoint);
						case 8: 
							addSegment(topPoint, leftPoint);
						case 9: 
							addSegment(topPoint, bottomPoint);
						case 10: // saddle
							addSegment(bottomPoint, leftPoint);
							addSegment(topPoint, rightPoint);
						case 11: 
							addSegment(topPoint, rightPoint);
						case 12: 
							addSegment(rightPoint, leftPoint);
						case 13: 
							addSegment(rightPoint, bottomPoint);
						case 14: 
							addSegment(bottomPoint, leftPoint);
						default:
					}
				}
			}
		}
	}
	
	function addSegment(fromPoint:HxPoint, toPoint:HxPoint) {
		if (fromPoint.equals(toPoint)) return;
		
		adjacencyMap.addSegment(fromPoint, toPoint);
	}
	
	public function interp(isoValue:Float, fromValue:Float, toValue:Float):Float {
		if (fromValue == toValue) return 0;
		return (isoValue - fromValue) / (toValue - fromValue);
	}
	
	static public function iso(pixels:Pixels, x:Int, y:Int):Float {
		if (isOutOfBounds(pixels, x, y)) return 0;
		else return ((pixels.getPixel32(x, y) >> 24) & 0xFF);
	}
	
	inline static public function isOutOfBounds(pixels:Pixels, x:Int, y:Int):Bool {
		return (x < 0 || y < 0 || x >= pixels.width || y >= pixels.height);
	}	
}


class AdjacencyMap {

	var firstIdx:Int = 0;
	var segments:Array<Segment>;
	
	var mapStartToEnd:Map<String, Array<Int>>;
	var mapEndToStart:Map<String, Array<Int>>;
	
	public function new():Void {
		segments = [];
		mapStartToEnd = new Map();
		mapEndToStart = new Map();
	}
	
	public function addSegment(from:HxPoint, to:HxPoint):Void {
		var fromKey = from.toString();
		var toKey = to.toString();
		
		var idx = segments.length;
		segments.push(new Segment(from, to));
		
		if (mapStartToEnd.exists(fromKey)) mapStartToEnd[fromKey].push(idx);
		else mapStartToEnd[fromKey] = [idx];
		
		if (mapEndToStart.exists(toKey)) mapEndToStart[toKey].push(idx);
		else mapEndToStart[toKey] = [idx];
	}
	
	public function getStartingPointOf(end:HxPoint):HxPoint {
		if (end == null) return null;
		
		var start = null;
		var endKey = end.toString();
		
		if (mapEndToStart.exists(endKey)) {
			var entry = mapEndToStart[endKey];
			var idx = entry[0];
			start = segments[idx].from;
			removeSegmentAt(idx);
		}
		
		return start;
	}
	
	public function getEndingPointOf(start:HxPoint):HxPoint {
		if (start == null) return null;
		
		var end = null;
		var startKey = start.toString();
		
		if (mapStartToEnd.exists(startKey)) {
			var entry = mapStartToEnd[startKey];
			var idx = entry[0];
			end = segments[idx].to;
			removeSegmentAt(idx);
		}
		
		return end;
	}
	
	public function getFirstSegment():Segment {
		var segment = null;
		
		for (i in firstIdx...segments.length) {
			segment = segments[i];
			if (segment != null) {
				removeSegmentAt(i);
				firstIdx = i;
				break;
			}
		}
		
		return segment;
	}
	
	function removeSegmentAt(i:Int) {
		var segment = segments[i];
		
		var startKey = segment.from.toString();
		var endKey = segment.to.toString();
		
		var entry = mapStartToEnd[startKey];
		entry.remove(i);
		if (entry.length == 0) mapStartToEnd.remove(startKey);
		
		entry = mapEndToStart[endKey];
		entry.remove(i);
		if (entry.length == 0) mapEndToStart.remove(endKey);
		
		segments[i] = null;
	}	
}

private class Segment {
	public var from:HxPoint;
	public var to:HxPoint;
	
	public function new(from:HxPoint, to:HxPoint):Void {
		this.from = from;
		this.to = to;
	}
}