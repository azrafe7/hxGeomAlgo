package hxGeomAlgo;

import haxe.ds.BalancedTree;
import hxGeomAlgo.EarClipper.Tri;



/** Specifies the method to use in the simplification process. */
enum SimplificationMethod {
	MaxPoints(n:Int);		// Allow max n points (n > 2).
	ThresholdArea(a:Float);	// Filter out all triangles with area <= a.
	Ratio(r:Float);			// Retain r ratio of all points (0 <= r <= 1). 
}

/**
 * ...
 * @author azrafe7
 */
class VisvalingamWhyatt
{	
	static private var method:SimplificationMethod;
	static private var minHeap;
	
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
		
		// add triangles to minHeap
		for (i in 1...numPoints - 1) {
			triangle = new Triangle(points[i - 1], points[i], points[i + 1]);
			triangle.index = i;
			if (points[i].x == 31 && points[i].y == 5) {
				trace("corner", triangle.area);
			}
			if (triangle.area > thresholdArea) {
				triangles.push(triangle);
				minHeap.push(triangle);
			}
		}
		
		// assign prev, next to triangles
		var numTriangles = triangles.length;
		for (i in 0...numTriangles) {
			triangle = triangles[i];
			if (i > 0) triangle.prev = triangles[i - 1];
			if (i < numTriangles - 1) triangle.next = triangles[i + 1];
		}
		
		var pp = [];
		for (t in minHeap.data) {
			pp.push(t.points[1]);
		}
		trace(PolyTools.findDuplicatePoints(pp));
		
		// filter triangles
		var firstTriangle = triangles[0];
		while ((minHeap.length > maxPoints - 2) && (triangle = minHeap.pop()) != null) {
			trace(triangle.area);
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
			
			minHeap.rebuild();
		}
		
		pp = [];
		for (t in minHeap.data) {
			pp.push(t.points[1]);
		}
		trace(PolyTools.findDuplicatePoints(pp));

		var res = [points[0]];
		minHeap.data.sort(function (t1:Triangle, t2:Triangle):Int 
		{
			return t1.index - t2.index;
		});
		for (t in minHeap.data) res.push(t.points[1]);
		res.push(points[numPoints - 1]);
		
		/*
		var res = [firstTriangle.points[0], firstTriangle.points[1]];
		triangle = firstTriangle;
		while ((triangle = triangle.next) != null) res.push(triangle.points[2]);
		*/
		return res;
	}
	
	static private function updateTriangle(t:Triangle)
	{
		//minHeap.remove(t);
		t.calcArea();
		//minHeap.push(t);
	}
}


private class Triangle
{
	public var points:Array<HxPoint>;
	public var prev:Triangle = null;
	public var next:Triangle = null;	
	public var area:Float = 0;
	public var index:Int = -1;
	
	public function new(a:HxPoint, b:HxPoint, c:HxPoint):Void 
	{
		points = [a, b, c];
		calcArea();
	}
	
	public function calcArea():Float
	{
		//trace('(${points[0].x} - ${points[2].x}) * (${points[1].y} - ${points[0].y}) - (${points[0].x} - ${points[1].x}) * (${points[2].y} - ${points[0].y})');
		area = (points[0].x - points[2].x) * (points[1].y - points[0].y) - 
			   (points[0].x - points[1].x) * (points[2].y - points[0].y);
		area = area < 0 ? -area : area;
		return area;
	}
	
    public function compare(other:Triangle):Int {
        var diff = area - other.area;
        return diff < 0 ? -1 : diff > 0 ? 1 : 0;
    }
}

typedef Comparable<T> = {
	function compare(other:T):Int;
}

/** 
 * MinHeap implementation (over Array).
 * 
 * @see http://en.wikipedia.org/wiki/Binary_heap
 * 
 * @author azrafe7
 */
class MinHeap<T:Comparable<T>>
{
	public var data:Array<T>;
	
	public function new():Void 
	{
		data = new Array<T>();
	}
	
	public var length(get, null):Int;
	private function get_length():Int
	{
		return data.length;
	}
	
	public function push(t:T):Void 
	{
		var i = data.length;
		data[i] = t;
		bubbleUp(i);
	}
	
    public function pop():T
    {
        if (data.length == 0) return null;
        
        var res = data[0];
        var len = data.length;
        var lastObj = data.pop();
		if (len > 1) {
            data[0] = lastObj;
            bubbleDown(0);
        }
        return res;
    }
    
	public function top():T
	{
		return data.length > 0 ? data[0] : null;
	}
	
    public function remove(obj:T):Int
    {
        var res = data.indexOf(obj);
		if (res < 0) return res;
		
        var len = data.length;
        var lastObj = data.pop();
		if (res != len - 1) {
            data[res] = lastObj;
            lastObj.compare(obj) < 0 ? bubbleUp(res) : bubbleDown(res);
        }
		//validate();
        return res;
    }
    
	inline public function clear():Void 
	{
#if (cpp || php)
		data.splice(0, data.length);
#else
		untyped data.length = 0;
#end
	}
	
	public function rebuild():Void 
	{
		var clonedData = [].concat(data);
		clear();
		for (obj in clonedData) push(obj);
	}
	
    private function bubbleDown(i:Int):Void
    {
        var left = leftOf(i);
        var right = rightOf(i);
        var smallest = i;
        if (left < data.length && data[left].compare(data[smallest]) < 0) smallest = left;
        if (right < data.length && data[right].compare(data[smallest]) < 0) smallest = right;
        if (smallest != i) {
            swap(smallest, i);
            bubbleDown(smallest);
        }
    }
    
	private function bubbleUp(i:Int):Void
	{
		while (i > 0) {
			var parent = parentOf(i);
			if (data[i].compare(data[parent]) < 0) swap(parent, i);
			i--;
		}
	}
	
	public function validate():Void 
	{
		if (data.length > 0) _validate(0);
	}
	
	private function _validate(i:Int):Void
	{
		var len = data.length;
		var left = leftOf(i);
		var right = rightOf(i);
		
		if (left < len) {
			assert(data[i].compare(data[left]) <= 0, 'Broken heap shape invariant (parent@$i vs leftChild@left).');
			_validate(leftOf(i));
		}
		if (right < len) {
			assert(data[i].compare(data[right]) <= 0, 'Broken heap shape invariant(parent@$i vs rightChild@right).');
			_validate(rightOf(i));
		}
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
		data[i] = data[j];
		data[j] = temp;
	}

	inline private static function assert(cond:Bool, ?message:String) {
		if (!cond) throw "ASSERT FAILED!" + (message != null ? message : "");
	}
}