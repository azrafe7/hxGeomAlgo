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


using hxGeomAlgo.PolyTools;


@:expose
class Bayazit
{
  
  static private var poly:Poly;		// cw version of simplePoly - used internally
  static private var visibility:Map<Int, Array<Int>>;		// maps vertices' indices to visible ones - used internally
  
  static public var reflexVertices:Array<HxPoint>;
  static public var steinerPoints:Array<HxPoint>;

  static public var reversed:Bool;	// true if the _internal_ indices have been reversed

  /** 
   * Decomposes `simplePoly` into a near-minimum number of convex polygons. 
   */
  static public function decomposePoly(simplePoly:Poly):Array<Poly> {
    var res = new Array<Poly>();
    
    reflexVertices = [];
    steinerPoints = [];
    visibility = new Map();
    
    if (simplePoly.length < 3) return res;
    
    poly = new Poly();
    for (p in simplePoly) poly.push(new HxPoint(p.x, p.y));
    reversed = poly.makeCW();	// make poly cw (in place)
    
    _decomposePoly(poly, res);
    
    return res;
  }
  
  /** Used internally by decomposePoly(). */
  static private function _decomposePoly(poly:Poly, polys:Array<Poly>) {
    var upperInt:HxPoint = new HxPoint(), lowerInt:HxPoint = new HxPoint(), 
      p:HxPoint = new HxPoint(), closestVert:HxPoint = new HxPoint();
    var upperDist:Float = 0, lowerDist:Float = 0, d:Float = 0, closestDist:Float = 0;
    var upperIdx:Int = 0, lowerIdx:Int = 0, closestIdx:Int = 0;
    var upperPoly:Poly = new Poly(), lowerPoly:Poly = new Poly();
    
    for (i in 0...poly.length) {
      if (poly.isReflex(i)) {
        visibility[i] = Visibility.getVisibleIndicesFrom(poly, i);
        reflexVertices.push(poly[i]);
        upperDist = lowerDist = Math.POSITIVE_INFINITY;
        for (j in 0...poly.length) {
          if (poly.at(i - 1).isLeft(poly.at(i), poly.at(j)) &&
            poly.at(i - 1).isRightOrOn(poly.at(i), poly.at(j - 1))) // if line intersects with an edge
          {
            p = PolyTools.intersection(poly.at(i - 1), poly.at(i), poly.at(j), poly.at(j - 1)); // find the point of intersection
            if (poly.at(i + 1).isRight(poly.at(i), p)) { // make sure it's inside the poly
              d = poly[i].distanceSquared(p);
              if (d < lowerDist) { // keep only the closest intersection
                lowerDist = d;
                lowerInt = p;
                lowerIdx = j;
              }
            }
          }
          
          if (poly.at(i + 1).isLeft(poly.at(i), poly.at(j + 1)) &&
            poly.at(i + 1).isRightOrOn(poly.at(i), poly.at(j))) 
          {			
            p = PolyTools.intersection(poly.at(i + 1), poly.at(i), poly.at(j), poly.at(j + 1));
            if (poly.at(i - 1).isLeft(poly.at(i), p)) {
              d = poly[i].distanceSquared(p);
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
          //trace('Case 2: Vertex($i), closestIdx($closestIdx), poly.length(${poly.length}), $lowerIdx, $upperIdx');

          if (lowerIdx > upperIdx) {
            upperIdx += poly.length;
          }
          closestDist = Math.POSITIVE_INFINITY;
          for (j in lowerIdx...upperIdx + 1) {
            if (poly.at(i - 1).isLeftOrOn(poly.at(i), poly.at(j))
                && poly.at(i + 1).isRightOrOn(poly.at(i), poly.at(j))) 
            {
              d = poly.at(i).distanceSquared(poly.at(j));
              if (d < closestDist) {
                var ijVisible = visibility[i].indexOf(j % poly.length) >= 0;
                if (ijVisible) {
                  closestDist = d;
                  closestVert = poly.at(j);
                  closestIdx = j % poly.length;
                }
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
}