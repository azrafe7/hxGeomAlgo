/**
 * Hertel-Mehlhorn convex polygonization from arbitrary triangulation.
 * 
 * Based on:
 * 
 * @see https://github.com/ivanfratric/polypartition				(C - by Ivan Fratric)
 * @see http://www.philvaz.com/compgeom								(by Phil Porvaznik)
 * 
 * @author azrafe7
 */

package hxGeomAlgo;


import hxGeomAlgo.PolyTools;


using hxGeomAlgo.PolyTools;


@:expose
class HertelMehlhorn
{
	
	static public var diagonals:Array<{from:HxPoint, to:HxPoint}>;
	
	/**
	 * Merges triangles (defining a triangulated polygon) into a set of convex polygons.
	 * 
	 * @param	triangulation	An array of triangles defining the polygon.
	 * @return	An array of convex polygons being a decomposition of the original polygon.
	 */
	static public function polygonize(triangulation:Array<Tri>):Array<Poly> {
		var res:Array<Poly> = triangulation.concat([]);
		diagonals = [];
		
		var poly:Poly, qoly:Poly, newPoly:Poly;
		var p1:HxPoint, p2:HxPoint, p3:HxPoint;
		var d1:HxPoint, d2:HxPoint;
		var p:HxPoint, q:HxPoint;
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
						q = qoly.at(qolyIt);
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
				
				var d = ( { from:d1, to:d2 } );
				diagonals.push(d);
				
				p = poly.at(polyIt + 2);
				q = qoly.at(qolyIt - 1);
				
				var pTest = [
					poly.at(polyIt),
					q,
					p,
				];
				
				var qTest = [
					qoly.at(qolyIt),
					p,
					q,
				];
				
				if (PolyTools.isRightOrOn(pTest[0], pTest[1], pTest[2])) {
					polyIt++;
					continue;
				}
				
				if (PolyTools.isRightOrOn(qTest[0], qTest[1], qTest[2])) {
					polyIt++;
					continue;
				}
				
				// merge triangles/polys
				newPoly = [];
				var j = polyIt + 1;
				while (poly.wrappedIdx(j) != polyIt) {
					newPoly.push(poly.at(j));
					j++;
				}
				j = qolyIt + 1;
				while (qoly.wrappedIdx(j) != qolyIt) {
					newPoly.push(qoly.at(j));
					j++;
				}
				
				if (PolyTools.isConvex(newPoly)) {
					res.splice(innerIt, 1);
					res[outerIt] = newPoly;
					poly = newPoly;
					
					polyIt = -1;	// restart
				} else {
					polyIt++;
					continue;
				}
				
				polyIt++;
			}
			
			outerIt++;
		}
		
		return res;
	}
}