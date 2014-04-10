/**
 * Keil polygon decomposition implementation.
 * 
 * Adapted/modified from:
 * 
 * @see http://mnbayazit.com/406/keil								(C - by Mark Bayazit)
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
import net.azrafe7.geomAlgo.PolyTools;
import net.azrafe7.geomAlgo.Keil.EdgeList;


using net.azrafe7.geomAlgo.PolyTools;


class Edge { 
	public var first:Point;
	public var second:Point;
	public function new(p1:Point, p2:Point) {
		first = p1;
		second = p2;
	}
}

typedef EdgeList = Array<Edge>;
typedef Line = Edge;


class Keil
{

	static inline public var MAXINT:Int = 2147483647;
	
	static public function decomposePoly(poly:Poly):EdgeList {
		poly.makeCCW();	// in place
		
		var edges:EdgeList = new EdgeList();
		for (i in 0...poly.length - 1) edges.push(new Edge(new Point(poly[i].x, poly[i].y), new Point(poly[i + 1].x, poly[i + 1].y)));
		edges.push(new Edge(new Point(poly[poly.length-1].x, poly[poly.length-1].y), new Point(poly[0].x, poly[0].y)));
		
		var res:EdgeList = _decomposePoly(poly);
		
		return res;
	}
	
	static private function _decomposePoly(poly:Poly, tab:String = ""):EdgeList {
		var min:EdgeList = new EdgeList(), tmp:EdgeList;
		var nDiags:Int = MAXINT;
		
		//if (poly.length < 3) return min;
		
		//trace(tab + poly);
		for (i in 0...poly.length) {
			if (poly.isReflex(i)) {
				//trace(tab + i + " is reflex");
				for (j in 0...poly.length) {
					//if (i == j) continue;
					if (canSee(poly, i, j)) {
						//trace(tab + i + " can see " + j);
						var left:EdgeList = _decomposePoly(copy(poly, i, j), tab + " ");
						var right:EdgeList = _decomposePoly(copy(poly, j, i), tab + " ");
						//trace(tab + "left: " + left);
						//trace(tab + "right: " + right);
						//tmp = _decomposePoly(left, tab + " ");
						for (e in right) left.push(e);
						if (left.length < nDiags) {
							min = left;
							nDiags = left.length;
							min.push(new Edge(poly.at(i), poly.at(j)));
							//trace(tab + min);
						}
					}
				}
			}
		}
		
		return min;
	}
	
	static public function copy(poly:Poly, i:Int, j:Int):Poly {
		var res:Poly = new Poly();
		
		if (i < j) {
			for (k in i...j + 1) res.push(poly[k]);
		} else {
			for (k in i...poly.length) res.push(poly[k]);
			for (k in 0...j + 1) res.push(poly[k]);
		}
		
		return res;
	}
	
	static public function canSee(poly:Poly, a:Int, b:Int):Bool {
		var dist:Float;
		
		if (poly.at(a + 1).isLeftOrOn(poly.at(a), poly.at(b)) && poly.at(a - 1).isRightOrOn(poly.at(a), poly.at(b))) {
			return false;
		}
		dist = poly.at(a).distanceSquared(poly.at(b));
		for (i in 0...poly.length) { // for each edge
			if (((i + 1) % poly.length) == a || i == a) // ignore incident edges
				continue;
			if (poly.at(a).isLeftOrOn(poly.at(b), poly.at(i + 1)) && poly.at(a).isRightOrOn(poly.at(b), poly.at(i))) { // if diag intersects an edge
				var p = PolyTools.intersection(poly.at(a), poly.at(b), poly.at(i), poly.at(i + 1));
				if (p != null && poly.at(a).distanceSquared(p) < dist) { // if edge is blocking visibility to b
					return false;
				}
			}
		}

		return true;
	}
}