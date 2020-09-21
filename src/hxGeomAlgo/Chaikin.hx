/**
 * Chaikin curve smoothing implementation.
 *
 * Based on:
 *
 * @see https://sighack.com/post/chaikin-curves	(Java - Manohar Vanga)
 *
 * Other credits should go to papers/work of:
 *
 * Chaikin, G. M. (1974). An algorithm for high-speed curve generation. Computer Graphics and Image Processing, 3(4), 346–349
 * @see https://sci-hub.tw/10.1016/0146-664X(74)90028-8	(George Merrill Chaikin)
 *
 * Wu, L., Yong, J.-H., Zhang, Y.-W., & Zhang, L. (2004). Multi-step Subdivision Algorithm for Chaikin Curves. Lecture Notes in Computer Science, 1232–1238. doi:10.1007/978-3-540-30497-5_188
 * @see https://sci-hub.tw/10.1007/978-3-540-30497-5_188		(Ling Wu, Jun-Hai Yong, You-Wei Zhang, and Li Zhang)
 *
 * @author azrafe7
 */

package hxGeomAlgo;

using hxGeomAlgo.PolyTools;


@:expose
class Chaikin
{

  static function cut(a:HxPoint, b:HxPoint, ratio:Float):Poly
  {
    var res = new Poly();

    res.push(PolyTools.lerpPoints(a, b, ratio));
    res.push(PolyTools.lerpPoints(b, a, ratio));

    return res;
  }

  static public function smooth(poly:Poly, iterations:Int = 3, close:Bool = false, ratio:Float = .25):Poly
  {
    if (iterations <= 0 || poly.length <= 3) return poly;

    var smoothedPoints = new Poly();

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
     *         with a PShape object, do a pairwise iteration
     *         over vertices instead. Same thing.
     */
    for (i in 0...numCorners) {

      // Get the i'th and (i+1)'th vertex to work on that edge.
      var a = poly.at(i);
      var b = poly.at(i + 1);

      // Step 3: Break it using our cut() function
      var n = cut(a, b, ratio);

      /*
       * Now we have to deal with one corner case. In the case
       * of open shapes, the first and last endpoints shouldn't
       * be moved. However, in the case of closed shapes, we
       * cut all edges on both ends.
       */
      if (!close && i == 0) {
        // For the first point of open shapes, ignore vertex A
        smoothedPoints.push(a.clone());
        smoothedPoints.push(n[1].clone());
      } else if (!close && i == numCorners - 1) {
        // For the last point of open shapes, ignore vertex B
        smoothedPoints.push(n[0].clone());
        smoothedPoints.push(b.clone());
      } else {
        // For all other cases (i.e. interior edges of open
        // shapes or edges of closed shapes), add both vertices
        // returned by our chaikin_break() method
        smoothedPoints.push(n[0].clone());
        smoothedPoints.push(n[1].clone());
      }
    }

    return smooth(smoothedPoints, iterations - 1, close, ratio);
  }
}
