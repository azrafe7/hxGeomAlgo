package net.azrafe7.algo;

import flash.geom.Point;

/**
 * Ramer-Douglas-Peucker implementation.
 * 
 * Adapted/modified from:
 * 
 * @see http://karthaus.nl/rdp/		(JS)
 * @see http://stackoverflow.com/questions/849211/shortest-distance-between-a-point-and-a-line-segment		(JS)
 * 
 * @author azrafe7
 */
class RamerDouglasPeucker
{
	static private var point:Point = new Point();
	
	/**
	 * Simplify polyline.
	 * 
	 * @param	points		Array of points defining the polyline.
	 * @param	epsilon		Perpendicular distance threshold (typically in the range [1..2]).
	 * @return	An array of points defining the simplified polyline.
	 */
	static public function simplify(points:Array<Point>, epsilon:Float = 1):Array<Point> 
	{
		var firstPoint = points[0];
		var lastPoint = points[points.length - 1];
		
		if (points.length < 3) {
			return points;
		}
		
		var index = -1;
		var dist = 0.;
		for (i in 1...points.length - 1) {
			var currDist = distanceToSegment(points[i], firstPoint, lastPoint);
			if (currDist > dist){
				dist = currDist;
				index = i;
			}
		}
		
		if (dist > epsilon){
			// recurse
			var l1 = points.slice(0, index + 1);
			var l2 = points.slice(index);
			var r1 = simplify(l1, epsilon);
			var r2 = simplify(l2, epsilon);
			// concat r2 to r1 minus the end/startpoint that will be the same
			var rs = r1.slice(0, r1.length - 1).concat(r2);
			return rs;
		} else {
			return [firstPoint, lastPoint];
		}
	}

	/** Perpendicular distance from `p` to segment `v`-`w`. */
	inline static public function distanceToSegment(p:Point, v:Point, w:Point) { return Math.sqrt(distanceToSegmentSquared(p, v, w)); }
	
	/** Returns `x` squared. */
	inline static public function sqr(x:Float):Float { return x * x; }
	
	/** Squared distance from `v` to `w`. */
	inline static public function distanceSquared(v:Point, w:Point):Float { return sqr(v.x - w.x) + sqr(v.y - w.y); }

	/** Squared perpendicular distance from `p` to segment `v`-`w`. */
	static public function distanceToSegmentSquared(p:Point, v:Point, w:Point):Float {
		var l2:Float = distanceSquared(v, w);
		if (l2 == 0) return distanceSquared(p, v);
		var t = ((p.x - v.x) * (w.x - v.x) + (p.y - v.y) * (w.y - v.y)) / l2;
		if (t < 0) return distanceSquared(p, v);
		if (t > 1) return distanceSquared(p, w);
		point.setTo(v.x + t * (w.x - v.x), v.y + t * (w.y - v.y));
		return distanceSquared(p, point);
	}
}