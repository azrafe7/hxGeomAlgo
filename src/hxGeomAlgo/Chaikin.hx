/**
 * Chaikin curve smoothing, recursive implementation.
 *
 * Based on:
 *
 * @see https://sighack.com/post/chaikin-curves	(Java - Manohar Vanga)
 *
 * Other credits should go to papers/work of:
 *
 * Chaikin, G. M. (1974). An algorithm for high-speed curve generation. Computer Graphics and Image Processing, 3(4), 346–349
 * @see https://sci-hub.st/10.1016/0146-664X(74)90028-8	(George Merrill Chaikin)
 *
 * @author azrafe7
 */

package hxGeomAlgo;

using hxGeomAlgo.PolyTools;


@:expose
class Chaikin
{

  static public function smooth(poly:Poly, iterations:Int = 3, close:Bool = false, ratio:Float = .25):Poly
  {
    var smoothedPoints = _smooth(poly, iterations, close, ratio);

    /*
     * Now we have to deal with one corner case. In the case
     * of open shapes, the first and last endpoints shouldn't
     * be moved.
     */
    if (!close && smoothedPoints.length > 2) {
      smoothedPoints[0] = poly[0];
      smoothedPoints[smoothedPoints.length - 1] = poly[poly.length - 1];
    }

    return smoothedPoints;
  }

  static inline function cut(a:HxPoint, b:HxPoint, ratio:Float, newAB:Poly):Void
  {
    newAB[0] = PolyTools.lerpPoints(a, b, ratio);
    newAB[1] = PolyTools.lerpPoints(b, a, ratio);
  }

  static function _smooth(poly:Poly, iterations:Int, close:Bool, ratio:Float):Poly
  {
    if (iterations <= 0 || poly.length <= 2) {
      return poly.copy();
    }

    var smoothedPoints = new Poly();
    var newAB = new Poly();
    newAB.resize(2);

    if (ratio > 0.5) ratio = 1.0 - ratio;

    /*
     * Step 1: Figure out how many corners the shape has
     *         depending on whether it's open or closed.
     */
    var numCorners = poly.length;
    if (!close)
      numCorners -= 1;

    /*
     * Step 2: Since we don't have access to edges directly
     *         do a pairwise iteration over vertices instead.
     *         Same thing.
     */
    for (i in 0...numCorners) {

      // Get the i'th and (i+1)'th vertex to work on that edge.
      var a = poly.at(i);
      var b = poly.at(i + 1);

      // Step 3: Break it using our cut() function
      cut(a, b, ratio, newAB);

      // For all edges add both vertices
      // returned by our cut() method
      smoothedPoints.push(newAB[0]);
      smoothedPoints.push(newAB[1]);
    }

    return _smooth(smoothedPoints, iterations - 1, close, ratio);
  }
}
