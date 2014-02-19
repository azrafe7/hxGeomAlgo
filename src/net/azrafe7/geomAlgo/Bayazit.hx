/**
 * Bayazit polygon decomposition implementation.
 * NOTE: Should work only for SIMPLE polygons (not self-intersecting, without holes).
 * 
 * Adapted/modified from:
 * 
 * @see http://mnbayazit.com/406/bayazit							(C - by Mark Bayazit)
 * 
 * Other credits should go to papers/work of: 
 * 
 * @see http://mnbayazit.com/406/files/PolygonDecomp-Keil.pdf		(Keil)
 * @see http://mnbayazit.com/406/files/OnTheTimeBound-Snoeyink.pdf	(Snoeyink & Keil)
 * @see http://www.cs.sfu.ca/~binay/								(Dr. Bhattacharya)
 * 
 * @author azrafe7
 */

package net.azrafe7.geomAlgo;

import flash.geom.Point;

typedef Poly = Array<Point>;


class Bayazit
{
	static public var EPSILON:Float = .00000001;
	
	static public var reflexVertices:Array<Point> = new Array<Point>();
	static public var steinerPoints:Array<Point> = new Array<Point>();

	/** Decomposes `poly` into a near-minimum number of convex polygons. */
	static public function decomposePoly(poly:Poly):Array<Poly> {
		var res = new Array<Poly>();
		
		makeCCW(poly);	// in place
		
		clear(reflexVertices);
		clear(steinerPoints);
		
		_decomposePoly(poly, res);
		
		return res;
	}
	
	/** Used internally by decomposePoly(). */
	static private function _decomposePoly(poly:Poly, polys:Array<Poly>) {
		var upperInt:Point = new Point(), lowerInt:Point = new Point(), 
			p:Point = new Point(), closestVert:Point = new Point();
		var upperDist:Float = 0, lowerDist:Float = 0, d:Float = 0, closestDist:Float = 0;
		var upperIdx:Int = 0, lowerIdx:Int = 0, closestIdx:Int = 0;
		var upperPoly:Poly = new Poly(), lowerPoly:Poly = new Poly();
		
		for (i in 0...poly.length) {
			if (isReflex(poly, i)) {
				reflexVertices.push(poly[i]);
				upperDist = lowerDist = Math.POSITIVE_INFINITY;
				for (j in 0...poly.length) {
					if (left(at(poly, i - 1), at(poly, i), at(poly, j)) &&
						rightOn(at(poly, i - 1), at(poly, i), at(poly, j - 1))) // if line intersects with an edge
					{
						p = intersection(at(poly, i - 1), at(poly, i), at(poly, j), at(poly, j - 1)); // find the point of intersection
						if (right(at(poly, i + 1), at(poly, i), p)) { // make sure it's inside the poly
							d = distanceSquared(poly[i], p);
							if (d < lowerDist) { // keep only the closest intersection
								lowerDist = d;
								lowerInt = p;
								lowerIdx = j;
							}
						}
					}
					
					if (left(at(poly, i + 1), at(poly, i), at(poly, j + 1))
							&& rightOn(at(poly, i + 1), at(poly, i), at(poly, j))) 
					{			
						p = intersection(at(poly, i + 1), at(poly, i), at(poly, j), at(poly, j + 1));
						if (left(at(poly, i - 1), at(poly, i), p)) {
							d = distanceSquared(poly[i], p);
							if (d < upperDist) {
								upperDist = d;
								upperInt = p;
								upperIdx = j;
							}
						}
					}
				}
				
				// if there are no vertices to connect to, choose a point in the middle
				if (lowerIdx == (upperIdx + 1) % poly.length) {

					//trace('Case 1: Vertex($i), lowerIdx($lowerIdx), upperIdx($upperIdx), poly.length(${poly.length})');
					
					p.x = (lowerInt.x + upperInt.x) / 2;
					p.y = (lowerInt.y + upperInt.y) / 2;
					steinerPoints.push(p);
					
					if (i < upperIdx) {
						for (k in i...upperIdx + 1) lowerPoly.push(poly[k]);
						lowerPoly.push(p);
						upperPoly.push(p);
						if (lowerIdx != 0) for (k in lowerIdx...poly.length) upperPoly.push(poly[k]);
						for (k in 0...i + 1) upperPoly.push(poly[k]);
					} else {
						if (i != 0) for (k in i...poly.length) lowerPoly.push(poly[k]);
						for (k in 0...upperIdx + 1) lowerPoly.push(poly[k]);
						lowerPoly.push(p);
						upperPoly.push(p);
						for (k in lowerIdx...i + 1) upperPoly.push(poly[k]);
					}
					
				} else {
					
					// connect to the closest point within the triangle
					//trace('Case 2: Vertex($i), closestIdx($closestIdx), poly.length(${poly.length})');

					if (lowerIdx > upperIdx) {
						upperIdx += poly.length;
					}
					closestDist = Math.POSITIVE_INFINITY;
					for (j in lowerIdx...upperIdx + 1) {
						if (leftOn(at(poly, i - 1), at(poly, i), at(poly, j))
								&& rightOn(at(poly, i + 1), at(poly, i), at(poly, j))) 
						{
							d = distanceSquared(at(poly, i), at(poly, j));
							if (d < closestDist) {
								closestDist = d;
								closestVert = at(poly, j);
								closestIdx = j % poly.length;
							}
						}
					}

					if (i < closestIdx) {
						for (k in i...closestIdx + 1) lowerPoly.push(poly[k]);
						if (closestIdx != 0) for (k in closestIdx...poly.length) upperPoly.push(poly[k]);
						for (k in 0...i + 1) upperPoly.push(poly[k]);
					} else {
						if (i != 0) for (k in i...poly.length) lowerPoly.push(poly[k]);
						for (k in 0...closestIdx + 1) lowerPoly.push(poly[k]);
						for (k in closestIdx...i + 1) upperPoly.push(poly[k]);
					}
				}

				// solve smallest poly first
				if (lowerPoly.length < upperPoly.length) {
					_decomposePoly(lowerPoly, polys);
					_decomposePoly(upperPoly, polys);
				} else {
					_decomposePoly(upperPoly, polys);
					_decomposePoly(lowerPoly, polys);
				}
				return;
			}
		}
		polys.push(poly);
	}
	
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
		if (!left(at(poly, br - 1), at(poly, br), at(poly, br + 1))) {
			poly.reverse();
		}
	}
	
	/** Finds the intersection point between lines extending the segments `p1`-`p2` and `q1`-`q2`. Returns null if they're parallel. */
	static public function intersection(p1:Point, p2:Point, q1:Point, q2:Point):Point 
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
		return res;
	}
	
	/** Returns true if `poly` vertex at idx is a reflex vertex. */
	static public function isReflex(poly:Poly, idx:Int):Bool 
	{
		return right(at(poly, idx - 1), at(poly, idx), at(poly, idx + 1));
	}
	
	/** Gets `poly` vertex at `idx` (wrapping around if needed). */
	static inline public function at(poly:Poly, idx:Int):Point 
	{
		var len:Int = poly.length;
		while (idx < 0) idx += len;
		return poly[idx % len];
	}
	
	static inline public function area(a:Point, b:Point, c:Point):Float
	{
		return (((b.x - a.x) * (c.y - a.y)) - ((c.x - a.x) * (b.y - a.y)));
	}
	
	static inline public function left(a:Point, b:Point, c:Point):Bool
	{
		return area(a, b, c) > 0;
	}
	
	static inline public function leftOn(a:Point, b:Point, c:Point):Bool
	{
		return area(a, b, c) >= 0;
	}
	
	static inline public function right(a:Point, b:Point, c:Point):Bool
	{
		return area(a, b, c) < 0;
	}
	
	static inline public function rightOn(a:Point, b:Point, c:Point):Bool
	{
		return area(a, b, c) <= 0;
	}
	
	/** Returns true if the specified triangle is degenerate (collinear points). */
	static inline public function collinear(a:Point, b:Point, c:Point):Bool
	{
		return area(a, b, c) == 0;
	}
	
	/** Returns the square of distance between `a` and `b`. */
	static inline public function distanceSquared(a:Point, b:Point):Float
	{
		var dx:Float = b.x - a.x;
		var dy:Float = b.y - a.y;
		return dx * dx + dy * dy;
	}
	
	/** Returns true a ~= b (i.e. a is within EPSILON distance from `b`). */
	static inline public function eq(a:Float, b:Float):Bool 
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