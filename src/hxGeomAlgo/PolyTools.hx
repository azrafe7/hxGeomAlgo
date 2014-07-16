/*
 * Copyright (C) Giuseppe Di Mauro (azrafe7) 2013-2014.
 *
 * This file is part of hxGeomAlgo (https://github.com/azrafe7/hxGeomAlgo). 
 * hxGeomAlgo is licensed under the MIT license (http://opensource.org/licenses/MIT) and built upon the work of many developers. 
 * See CREDITS.MD and LICENSE.MD files for more details.
 */

/**
 * Collection of functions to make working with Point and Poly easier.
 * 
 * Some of these have been based on:
 * 
 * @see http://mnbayazit.com/406/bayazit																	(C - by Mark Bayazit)
 * @see http://stackoverflow.com/questions/849211/shortest-distance-between-a-point-and-a-line-segment		(JS - Grumdrig)
 * 
 * @author azrafe7
 */

package hxGeomAlgo;

import flash.geom.Point;


typedef Poly = Array<Point>;


class PolyTools
{
	static private var point:Point = new Point();	// used internally
	
	static public var zero:Point = new Point(0, 0);
	
	static public var EPSILON:Float = .00000001;

	
	/** Returns true if `poly` is counterclockwise (assumes y axis pointing down). */
	static public function isCCW(poly:Poly):Bool {
		var br:Int = 0;

		// find bottom right point
		for (i in 1...poly.length) {
			if (poly[i].y > poly[br].y || (poly[i].y == poly[br].y && poly[i].x > poly[br].x)) {
				br = i;
			}
		}

		return isRight(at(poly, br - 1), at(poly, br), at(poly, br + 1));
	}
	
	/** Makes `poly` counterclockwise (in place). Returns true if reversed. */
	static public function makeCCW(poly:Poly):Bool {
		var reversed = false;
		
		// reverse poly if not counterlockwise
		if (!isCCW(poly)) {
			poly.reverse();
			reversed = true;
		}
		
		return reversed;
	}
	
	/** Makes `poly` clockwise (in place). Returns true if reversed. */
	static public function makeCW(poly:Poly):Bool {
		var reversed = false;
		
		// reverse poly if counterlockwise
		if (isCCW(poly)) {
			poly.reverse();
			reversed = true;
		}
		
		return reversed;
	}
	
	/** 
	 * Assuming the polygon is simple (not self-intersecting), checks if it is convex.
	 **/
	static public function isConvex(poly:Poly):Bool
	{
		var isPositive:Null<Bool> = null;

		for (i in 0...poly.length) {
			var lower:Int = (i == 0 ? poly.length - 1 : i - 1);
			var middle:Int = i;
			var upper:Int = (i == poly.length - 1 ? 0 : i + 1);
			var dx0:Float = poly[middle].x - poly[lower].x;
			var dy0:Float = poly[middle].y - poly[lower].y;
			var dx1:Float = poly[upper].x - poly[middle].x;
			var dy1:Float = poly[upper].y - poly[middle].y;
			var cross:Float = dx0 * dy1 - dx1 * dy0;
			
			// cross product should have same sign
			// for each vertex if poly is convex.
			var newIsPositive:Bool = (cross > 0 ? true : false);

			if (cross == 0) continue;	// handle collinear case
			
			if (isPositive == null)
				isPositive = newIsPositive;
			else if (isPositive != newIsPositive) {
				return false;
			}
		}

		return true;
	}

	/** 
	 * Checks if the polygon is simple (not self-intersecting).
	 **/
	static public function isSimple(poly:Poly):Bool
	{
		var len:Int = poly.length;
		
		if (len<=3) return true;

		for (i in 0...len) {
			// first segment
			var p0:Int = i;
			var p1:Int = i == len - 1 ? 0 : i + 1;
			
			for (j in i + 1...len) {
				// second segment
				var q0:Int = j;
				var q1:Int = j == len - 1 ? 0 : j + 1;
				
				// check for intersection between segment p and segment q.
				// if the intersection point exists and is different from the endpoints,
				// then the poly is not simple
				var intersection:Point = segmentIntersect(poly[p0], poly[p1], poly[q0], poly[q1]);
				if (intersection != null
					&& !(intersection.equals(poly[p0]) || intersection.equals(poly[p1]))
					&& !(intersection.equals(poly[q0]) || intersection.equals(poly[q1])))
				{
					return false;
				}
			}	
		}

		return true;
	}

	/**
	 * Returns the intersection point between segments p0-p1 and q0-q1. Null if no intersection is found.
	 */
	static public function segmentIntersect(p0:Point, p1:Point, q0:Point, q1:Point):Point 
	{
		var intersectionPoint:Point;
		var a1:Float, a2:Float;
		var b1:Float, b2:Float;
		var c1:Float, c2:Float;
	 
		a1 = p1.y - p0.y;
		b1 = p0.x - p1.x;
		c1 = p1.x * p0.y - p0.x * p1.y;
		a2 = q1.y - q0.y;
		b2 = q0.x - q1.x;
		c2 = q1.x * q0.y - q0.x * q1.y;
	 
		var denom:Float = a1 * b2 - a2 * b1;
		if (denom == 0){
			return null;
		}
		
		intersectionPoint = new Point();
		intersectionPoint.x = (b1 * c2 - b2 * c1) / denom;
		intersectionPoint.y = (a2 * c1 - a1 * c2) / denom;
	 
		// check to see if distance between intersection and endpoints
		// is longer than actual segments.
		// return null otherwise.
		if (Point.distance(intersectionPoint, p1) > Point.distance(p0, p1)) return null;
		if (Point.distance(intersectionPoint, p0) > Point.distance(p0, p1)) return null;
		if (Point.distance(intersectionPoint, q1) > Point.distance(q0, q1)) return null;
		if (Point.distance(intersectionPoint, q0) > Point.distance(q0, q1)) return null;
		
		return intersectionPoint;
	}
	
	/**
	 * Returns indices of duplicate points in `poly` (or null if none are found).
	 */
	static public function findDuplicatePoints(poly:Poly):Array<Int> 
	{
		var len:Int = poly.length;
		if (len <= 1) return null;
		var res = new Array<Int>();
		
		for (i in 0...len) {
			for (j in i + 1...len) {
				if (poly[i].equals(poly[j])) res.push(j);
			}
		}
		
		return res.length != 0 ? res : null;
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
	
	/** Gets the side (signed area) of `p` relative to the line extending `a`-`b` (> 0 -> left, < 0 -> right, == 0 -> collinear). */
	static inline public function side(p:Point, a:Point, b:Point):Float
	{
		return (((a.x - p.x) * (b.y - p.y)) - ((b.x - p.x) * (a.y - p.y)));
	}
	
	/** Returns true if `p` is on the left of the line extending `a`-`b`. */
	static inline public function isLeft(p:Point, a:Point, b:Point):Bool
	{
		return side(p, a, b) > 0;
	}
	
	/** Returns true if `p` is on the left or collinear to the line extending `a`-`b`. */
	static inline public function isLeftOrOn(p:Point, a:Point, b:Point):Bool
	{
		return side(p, a, b) >= 0;
	}
	
	/** Returns true if `p` is on the right of the line extending `a`-`b`. */
	static inline public function isRight(p:Point, a:Point, b:Point):Bool
	{
		return side(p, a, b) < 0;
	}
	
	/** Returns true if `p` is on the right or collinear to the line extending `a`-`b`. */
	static inline public function isRightOrOn(p:Point, a:Point, b:Point):Bool
	{
		return side(p, a, b) <= 0;
	}
	
	/** Returns true if the specified triangle is degenerate (collinear points). */
	static inline public function isCollinear(p:Point, a:Point, b:Point):Bool
	{
		return side(p, a, b) == 0;
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
		return new HomogCoord(p.y - q.y, q.x - p.x, p.x * q.y - p.y * q.x);
	}
	
	/** Dot product. */
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
