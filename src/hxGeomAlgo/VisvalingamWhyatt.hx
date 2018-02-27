/**
 * Visvalingam-Whyatt implementation.
 * 
 * Based on:
 * 
 * Visvalingam M., Whyatt J. D.: Line generalisation by repeated elimination of the smallest area (1992)
 * @see https://hydra.hull.ac.uk/resources/hull:8338	(Visvalingam, Whyatt)
 * @see http://bost.ocks.org/mike/simplify/				(JS - by Mike Bostock)
 * 
 * @author azrafe7
 */

package hxGeomAlgo;

import hxGeomAlgo.Heap;
import hxGeomAlgo.Debug;


/** Specifies the method to use in the simplification process. */
@:expose
enum SimplificationMethod {
  MaxPoints(n:Int);		// Allow max n points (n > 2).
  ThresholdArea(a:Float);	// Filter out all triangles with area <= a.
  Ratio(r:Float);			// Retain r ratio of all points (0 < r <= 1). 
}


@:expose
class VisvalingamWhyatt
{	
#if js
  static function __init__() {
    PolyTools.exposeEnum(SimplificationMethod);
  }
#end

  static private var method:SimplificationMethod;
  static private var minHeap:Heap<Triangle>;
  
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
    
    minHeap = new Heap<Triangle>();
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