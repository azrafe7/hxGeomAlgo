/**
 * Visvalingam-Whyatt implementation.
 * 
 * Based on:
 * 
 * Visvalingam M., Whyatt J. D.: Line generalisation by repeated elimination of the smallest area (1992)
 * @see https://hydra.hull.ac.uk/resources/hull:8338	(Visvalingam, Whyatt)
 * @see http://bost.ocks.org/mike/simplify/				(JS - by Mike Bostock)
 * @see https://github.com/jonasmalacofilho/dheap		(Haxe - Jonas Malaco Filho)
 * @see http://en.wikipedia.org/wiki/Binary_heap 		(Binary (Min)Heap) 
 * 
 * @author azrafe7
 */

package hxGeomAlgo;

import hxGeomAlgo.Debug;


/** Specifies the method to use in the simplification process. */
enum SimplificationMethod {
	MaxPoints(n:Int);		// Allow max n points (n > 2).
	ThresholdArea(a:Float);	// Filter out all triangles with area <= a.
	Ratio(r:Float);			// Retain r ratio of all points (0 < r <= 1). 
}


class VisvalingamWhyatt
{	
	static private var method:SimplificationMethod;
	static private var minHeap:MinHeap<Triangle>;
	
	/**
	 * Simplify polyline.
	 * 
	 * @param	points		Array of points defining the polyline.
	 * @param	method		The method to use in the simplification process.
	 * @return	An array of points defining the simplified polyline.
	 */
	static public function simplify(points:Array<HxPoint>, method:SimplificationMethod = null):Array<HxPoint>
	{
		var numPoints = points.length;
		if (numPoints < 3) return [].concat(points);
		VisvalingamWhyatt.method = method == null ? SimplificationMethod.ThresholdArea(0) : method;
		
		var thresholdArea:Float = 0.0;
		var maxPoints = numPoints;
		switch (VisvalingamWhyatt.method) 
		{
			case MaxPoints(n)    : maxPoints = n;
			case ThresholdArea(a): thresholdArea = a;
			case Ratio(r)        : maxPoints = Std.int(points.length * r);
			default:
		}
		if (maxPoints < 2) maxPoints = 2;
		if (thresholdArea < 0) thresholdArea = 0;
		
		minHeap = new MinHeap<Triangle>();
		var triangles = [];
		var triangle:Triangle;
		
		// add triangles to array, and filter by threshold area
		for (i in 1...numPoints - 1) {
			triangle = new Triangle(points[i - 1], points[i], points[i + 1]);
			triangle.calcArea();
			if (triangle.area > thresholdArea) {
				triangles.push(triangle);
			}
		}
		
		// assign prev, next to triangles, adjust vertices,
		// recalc area and add them to minHeap
		var numTriangles = triangles.length;
		for (i in 0...numTriangles) {
			triangle = triangles[i];
			if (i > 0) {
				triangle.prev = triangles[i - 1];
				triangle.points[0] = triangle.prev.points[1];
			} else {
				triangle.points[0] = points[0];
			}
			if (i < numTriangles - 1) {
				triangle.next = triangles[i + 1];
				triangle.points[2] = triangle.next.points[1];
			} else {
				triangle.points[2] = points[numPoints - 1];
			}
			triangle.calcArea();
			minHeap.push(triangle);
		}
		
		// filter triangles
		var firstTriangle = triangles[0];
		while (minHeap.length > maxPoints - 2) {
			triangle = minHeap.pop();
			
			if (triangle.prev != null) {
				triangle.prev.next = triangle.next;
				triangle.prev.points[2] = triangle.points[2];
				updateTriangle(triangle.prev);
			} else if (triangle.next != null) {
				firstTriangle = triangle.next;
			}
			
			if (triangle.next != null) {
				triangle.next.prev = triangle.prev;
				triangle.next.points[0] = triangle.points[0];
				updateTriangle(triangle.next);
			}
		#if (GEOM_CHECKS)
			minHeap.validate();
		#end
		}
		
		var res = [points[0]];
		triangle = maxPoints > 2 ? firstTriangle : null;
		while (triangle != null) {
			res.push(triangle.points[1]);
			triangle = triangle.next;
		}
		res.push(points[numPoints - 1]);
		
		return res;
	}
	
	static private function updateTriangle(triangle:Triangle)
	{
		minHeap.remove(triangle);
		triangle.calcArea();
		minHeap.push(triangle);
	}
}


private class Triangle implements Heapable<Triangle>
{
	public var position:Int;
	
	public var points:Array<HxPoint>;
	public var prev:Triangle = null;
	public var next:Triangle = null;	
	public var area:Float = 0;
	
	public function new(a:HxPoint, b:HxPoint, c:HxPoint):Void 
	{
		points = [a, b, c];
	}
	
	/** @see http://web.archive.org/web/20120305071015/http://www.btinternet.com/~se16/hgb/triangle.htm */
	public function calcArea():Float
	{
		//trace('(${points[0].x} - ${points[2].x}) * (${points[1].y} - ${points[0].y}) - (${points[0].x} - ${points[1].x}) * (${points[2].y} - ${points[0].y})');
		area = ((points[0].x * points[2].y - points[2].x * points[0].y) +
			    (points[1].x * points[0].y - points[0].x * points[1].y) +
				(points[2].x * points[1].y - points[1].x * points[2].y)) * .5;
		if (area < 0) area = -area;
		return area;
	}
	
    public function compare(other:Triangle):Int {
        var diff = area - other.area;
        return diff < 0 ? -1 : diff > 0 ? 1 : 0;
    }
}


interface Heapable<T> {
	var position:Int;
	function compare(other:T):Int;
}

/** 
 * MinHeap implementation (over Array).
 * 
 * @see http://en.wikipedia.org/wiki/Binary_heap
 * 
 * @author azrafe7
 */
class MinHeap<T:Heapable<T>>
{
	private var data:Array<T>;
	
	public function new():Void 
	{
		data = new Array<T>();
	}
	
	/** Number of elements in the MinHeap. */
	public var length(default, null):Int = 0;
	
	/** Inserts `obj` into the MinHeap. */
	public function push(obj:T):Void 
	{
		var i = length;
		set(obj, i);
		length++;
		if (length > 1) bubbleUp(i);
	}
	
	/** Returns the smallest element and removes it from the MinHeap. Or null if the MinHeap is empty. */
    public function pop():T
    {
        if (length == 0) return null;
        
        var res = data[0];
        var len = length;
        var lastObj = data[len - 1];
		data[len - 1] = null;
		length--;
		if (len > 1) {
            set(lastObj, 0);
            bubbleDown(0);
        }
		
        return res;
    }
    
	/** Returns the smallest element without removing it from the MinHeap. Or null if the MinHeap is empty. */
	public function top():T
	{
		return length > 0 ? data[0] : null;
	}
	
	/** Removes `obj` from the MinHeap. Checks for correctness are only done in debug. */
    public function remove(obj:T):Int
    {
        var pos = obj.position;
		Debug.assert((pos >= 0 && pos < length), "Object not found.");
		Debug.assert(data[pos] == obj, '`obj` and retrieved object at $pos don\'t match.');
		
        var len = length;
        var lastObj = data[len - 1];
		data[len - 1] = null;
		length--;
		if (pos != len - 1) {
            set(lastObj, pos);
            lastObj.compare(obj) < 0 ? bubbleUp(pos) : bubbleDown(pos);
        }
        return pos;
    }
    
	inline public function clear():Void 
	{
	#if (flash || js)
		untyped data.length = 0;
	#else
		data.splice(0, length);
	#end
		length = 0;
	}
	
    private function bubbleDown(i:Int):Void
    {
        var left = leftOf(i);
        var right = rightOf(i);
        var smallest = i;
        if (left < length && data[left].compare(data[smallest]) < 0) smallest = left;
        if (right < length && data[right].compare(data[smallest]) < 0) smallest = right;
        if (smallest != i) {
            swap(smallest, i);
            bubbleDown(smallest);
        }
    }
    
	private function bubbleUp(i:Int):Void
	{
		while (i > 0 && !(data[i].compare(data[parentOf(i)]) > 0)) {
			var parent = parentOf(i);
			swap(parent, i);
			i = parent;
		}
	}
	
	public function validate():Void 
	{
		if (length > 0) _validate(0);
	}
	
	public function toArray():Array<T>
	{
		return [].concat(data);
	}
	
	private function _validate(i:Int):Void
	{
		var len = length;
		var left = leftOf(i);
		var right = rightOf(i);
		
		if (left < len) {
			Debug.assert(data[i].compare(data[left]) <= 0, 'Broken heap invariant (parent@$i > leftChild@$left).');
			_validate(leftOf(i));
		}
		if (right < len) {
			Debug.assert(data[i].compare(data[right]) <= 0, 'Broken heap invariant (parent@$i > rightChild@$right).');
			_validate(rightOf(i));
		}
	}
	
	private function set(obj:T, index:Int):Void
	{
		data[index] = obj;
		obj.position = index;
	}
	
	inline private function leftOf(i:Int):Int
	{
		return  2 * i + 1;
	}
	
	inline private function rightOf(i:Int):Int
	{
		return  2 * i + 2;
	}
	
	inline private function parentOf(i:Int):Int
	{
		return (i - 1) >> 1;
	}
	
	inline private function swap(i:Int, j:Int):Void
	{
		var temp = data[i];
		set(data[j], i);
		set(temp, j);
	}
}