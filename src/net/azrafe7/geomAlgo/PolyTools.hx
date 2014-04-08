/**
 * Collection of functions to make working with Point and Poly easier.
 * 
 * Some of these have been adapted/modified from:
 * 
 * @see http://mnbayazit.com/406/bayazit																	(C - by Mark Bayazit)
 * @see http://stackoverflow.com/questions/849211/shortest-distance-between-a-point-and-a-line-segment		(JS - Grumdrig)
 * 
 * @author azrafe7
 */

package net.azrafe7.geomAlgo;

import flash.geom.Point;


typedef Poly = Array<Point>;


class PolyTools
{
	static private var point:Point = new Point();	// used internally
	
	static public var zero:Point = new Point(0, 0);
	
	static public var EPSILON:Float = .00000001;

	
	/** Makes `poly` counterclockwise (in place). */
	static public function makeCCW(poly:Poly):Void {
		var br:Int = 0;

		// find bottom right point
		for (i in 1...poly.length) {
			if (poly[i].y < poly[br].y || (poly[i].y == poly[br].y && poly[i].x > poly[br].x)) {
				br = i;
			}
		}

		// reverse poly if clockwise
		if (!isLeft(at(poly, br - 1), at(poly, br), at(poly, br + 1))) {
			poly.reverse();
		}
	}
	
	/** Finds the intersection point between lines extending the segments `p1`-`p2` and `q1`-`q2`. Returns null if they're parallel. */
	@:noUsing static public function intersection(p1:Point, p2:Point, q1:Point, q2:Point):Point 
	{
		var res:Point = null;
		var a1 = p2.y - p1.y;
		var b1 = p1.x - p2.x;
		var c1 = a1 * p1.x + b1 * p1.y;
		var a2 = q2.y - q1.y;
		var b2 = q1.x - q2.x;
		var c2 = a2 * q1.x + b2 * q1.y;
		var det = a1 * b2 - a2 * b1;
		if (!eq(det, 0)) { // lines are not parallel
			res = new Point();
			res.x = (b2 * c1 - b1 * c2) / det;
			res.y = (a1 * c2 - a2 * c1) / det;
		}
		if (res == null) {
			trace("parallel");
		}
		return res;
	}
	
	/** Returns true if `poly` vertex at idx is a reflex vertex. */
	static public function isReflex(poly:Poly, idx:Int):Bool 
	{
		return isRight(at(poly, idx - 1), at(poly, idx), at(poly, idx + 1));
	}
	
	/** Gets `poly` vertex at `idx` (wrapping around if needed). */
	static inline public function at(poly:Poly, idx:Int):Point 
	{
		var len:Int = poly.length;
		while (idx < 0) idx += len;
		return poly[idx % len];
	}
	
	/** Gets the winding of `p` relative to the directed line `a`-`b` (< 0 -> left, > 0 -> right, == 0 -> collinear). */
	static inline public function winding(p:Point, a:Point, b:Point):Float
	{
		return (((b.x - a.x) * (p.y - a.y)) - ((p.x - a.x) * (b.y - a.y)));
	}
	
	/** Returns true if `p` is on the left of the directed line `a`-`b`. */
	static inline public function isLeft(p:Point, a:Point, b:Point):Bool
	{
		return winding(p, a, b) > 0;
	}
	
	/** Returns true if `p` is on the left or collinear to the directed line `a`-`b`. */
	static inline public function isLeftOrOn(p:Point, a:Point, b:Point):Bool
	{
		return winding(p, a, b) >= 0;
	}
	
	/** Returns true if `p` is on the right of the directed line `a`-`b`. */
	static inline public function isRight(p:Point, a:Point, b:Point):Bool
	{
		return winding(p, a, b) < 0;
	}
	
	/** Returns true if `p` is on the right or collinear to the directed line `a`-`b`. */
	static inline public function isRightOrOn(p:Point, a:Point, b:Point):Bool
	{
		return winding(p, a, b) <= 0;
	}
	
	/** Returns true if the specified triangle is degenerate (collinear points). */
	static inline public function isCollinear(p:Point, a:Point, b:Point):Bool
	{
		return winding(p, a, b) == 0;
	}
	
	/** Perpendicular distance from `p` to line segment `v`-`w`. */
	inline static public function distanceToSegment(p:Point, v:Point, w:Point) { return Math.sqrt(distanceToSegmentSquared(p, v, w)); }
	
	/** Squared distance from `v` to `w`. */
	inline static public function distanceSquared(v:Point, w:Point):Float { return sqr(v.x - w.x) + sqr(v.y - w.y); }

	/** Squared perpendicular distance from `p` to line segment `v`-`w`. */
	static public function distanceToSegmentSquared(p:Point, v:Point, w:Point):Float {
		var l2:Float = distanceSquared(v, w);
		if (l2 == 0) return distanceSquared(p, v);
		var t = ((p.x - v.x) * (w.x - v.x) + (p.y - v.y) * (w.y - v.y)) / l2;
		if (t < 0) return distanceSquared(p, v);
		if (t > 1) return distanceSquared(p, w);
		point.setTo(v.x + t * (w.x - v.x), v.y + t * (w.y - v.y));
		return distanceSquared(p, point);
	}
	
	
	static public function meet(p:Point, q:Point):HomogCoord 
	{
		return new HomogCoord(p.y - q.y, p.x - q.x, p.x * q.y - p.y * q.x);
	}
	
	static public function dot(p:Point, q:Point):Float 
	{
		return p.x * q.x + p.y * q.y;
	}
	
	/** Returns `x` squared. */
	@:noUsing inline static public function sqr(x:Float):Float { return x * x; }
	
	/** Returns true if `a` is _acceptably_ equal to `b` (i.e. `a` is within EPSILON distance from `b`). */
	@:noUsing static inline public function eq(a:Float, b:Float):Bool 
	{
		return Math.abs(a - b) <= EPSILON;
	}
	
	/** Empties an array of its contents. */
	static inline public function clear<T>(array:Array<T>)
	{
#if (cpp || php)
		array.splice(0, array.length);
#else
		untyped array.length = 0;
#end
	}
}