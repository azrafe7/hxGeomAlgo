/**
 * Bayazit polygon decomposition implementation.
 * NOTE: Should work only for SIMPLE polygons (not self-intersecting, without holes).
 * 
 * Based on:
 * 
 * @see http://mnbayazit.com/406/bayazit							(C - by Mark Bayazit)
 * @see http://mnbayazit.com/406/credit
 * @see http://www.dyn4j.org/										(Java - by William Bittle)
 * 
 * Other credits should go to papers/work of: 
 * 
 * @see http://mnbayazit.com/406/files/PolygonDecomp-Keil.pdf		(Keil)
 * @see http://mnbayazit.com/406/files/OnTheTimeBound-Snoeyink.pdf	(Snoeyink & Keil)
 * @see http://www.cs.sfu.ca/~binay/								(Dr. Bhattacharya)
 * 
 * @author azrafe7
 */

package hxGeomAlgo;


import hxGeomAlgo.PolyTools;
import hxPixels.Macro;


using hxGeomAlgo.PolyTools;


@:expose
class HertelMehlhorn
{
	
	static private var poly:Poly;		// cw version of simplePoly - used internally
	static private var reflex:Map<Int, Bool>;		// vertices' indices reflexivity - used internally
	
	static public var reflexVertices:Array<HxPoint> = new Array<HxPoint>();
	static public var steinerPoints:Array<HxPoint> = new Array<HxPoint>();

	static public var reversed:Bool;	// true if the _internal_ indices have been reversed

	/** 
	 * Decomposes `simplePoly` into a near-minimum number of convex polygons. 
	 */
	static public function polygonize(triangulation:Array<Tri>):Array<Poly> {
		var res:Array<Poly> = triangulation.concat([]);
		
		var poly:Poly, qoly:Poly, newPoly:Poly;
		var p1:HxPoint, p2:HxPoint, p3:HxPoint;
		var d1:HxPoint, d2:HxPoint;
		var i11, i12, i21, i22, i13, i23;
		var isDiagonal:Bool;
		
		var outerIt = 0;
		var innerIt = 0;
		while (outerIt < res.length) {
			
			poly = res[outerIt];
			qoly = res[0];
			
			var polyIt = 0;
			var qolyIt = 0;
			while (polyIt < poly.length) {
				d1 = poly.at(polyIt);
				d2 = poly.at(polyIt + 1);
				
				isDiagonal = false;
				
				innerIt = outerIt;
				while (innerIt < res.length) {
					if (innerIt == outerIt) {
						innerIt++;
						continue;
					}
					qoly = res[innerIt];
				
					qolyIt = 0;
					while (qolyIt < qoly.length) {
						var q = qoly.at(qolyIt);
						if (d2.x != q.x || d2.y != q.y) {
							qolyIt++;
							continue;
						}
						q = qoly.at(qolyIt + 1);
						if (d1.x != q.x || d1.y != q.y) {
							qolyIt++;
							continue;
						}
						isDiagonal = true;
						break;
					}
					if (isDiagonal) break;
					innerIt++;
				}
				
				if (!isDiagonal) {
					polyIt++;
					continue;
				}
				
				p2 = poly.at(polyIt);
				p1 = poly.at(polyIt - 1);
				p3 = qoly.at(polyIt + 1);
				if (!PolyTools.isLeft(p1, p2, p3)) {
					polyIt++;
					continue;
				}
				
				p2 = poly.at(polyIt + 1);
				p3 = poly.at(polyIt + 2);
				p1 = qoly.at(polyIt);
				if (!PolyTools.isLeft(p1, p2, p3)) {
					polyIt++;
					continue;
				}
				
				newPoly = [];
				var j = 0;
				while (j != polyIt) {
					newPoly.push(poly.at(j));
					j++;
				}
				j = 0;
				while (j != qolyIt) {
					newPoly.push(qoly.at(j));
					j++;
				}
				
				res.splice(innerIt, 1);
				res[outerIt] = newPoly;
				poly = newPoly;
				
				polyIt = 0;	// restart
			}
			
			outerIt++;
		}
		
		return res;
	}
}