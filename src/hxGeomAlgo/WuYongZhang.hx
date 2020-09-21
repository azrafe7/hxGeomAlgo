/**
 * Chaikin curve smoothing multi-step implementation.
 *
 * Based on:
 *
 * Wu, L., Yong, J.-H., Zhang, Y.-W., & Zhang, L. (2004). Multi-step Subdivision Algorithm for Chaikin Curves. Lecture Notes in Computer Science, 1232–1238. doi:10.1007/978-3-540-30497-5_188
 * @see https://sci-hub.tw/10.1007/978-3-540-30497-5_188		(Ling Wu, Jun-Hai Yong, You-Wei Zhang, and Li Zhang)
 *
 * Fabio Roman (2009). Algoritmo di Chaikin e sue evoluzioni.
 * @see http://win.doomitalia.it/varie/chaikin.pdf		(Matlab - Fabio Roman)
 *
 * @author azrafe7
 */

package hxGeomAlgo;

using hxGeomAlgo.PolyTools;
using hxGeomAlgo.WuYongZhang;


@:expose
class WuYongZhang
{

  // cached values
  static var F:Map<Int, Map<Int, Float>> = new Map(); // F(j,k)
  static var G:Map<Int, Map<Int, Float>> = new Map(); // G(j,k)
  static var H:Map<Int, Map<Int, Float>> = new Map(); // H(j,k)

  static function buildCache(k:Int)
  {
    for (j in 1...Std.int(Math.pow(2, k) + 1)) {
      if (!F.exists(j)) {
        F[j] = new Map();
        G[j] = new Map();
        H[j] = new Map();
      }
      F[j][k] = Math.pow(2, -1) - Math.pow(2, -k - 1) - (j - 1) * (Math.pow(2, -k) - j * Math.pow(2, -2 * k - 1));
      G[j][k] = Math.pow(2, -1) + Math.pow(2, -k - 1) + (j - 1) * (Math.pow(2, -k) - j * Math.pow(2, -2 * k));
      H[j][k] = (j - 1) * j * Math.pow(2, -2 * k - 1);
    }
  }

  static inline function scale(a:HxPoint, s:Float):HxPoint {
    return new HxPoint(s * a.x, s * a.y);
  }

  static inline function add(a:HxPoint, b:HxPoint):HxPoint {
    return new HxPoint(a.x + b.x, a.y + b.y);
  }

  static public function smooth(poly:Poly, iterations:Int = 3, close:Bool = false):Poly
  {
    if (iterations <= 0 || poly.length <= 2) return poly;

    var P0 = poly;
    var k = iterations;
    buildCache(k);

    var smoothedPoints = new Poly();
    var n0 = poly.length - 1;
    var newLength = Std.int(Math.pow(2, k) * n0 - Math.pow(2, k) + 2);
    smoothedPoints.resize(newLength);

    var factor1 = (Math.pow(2, -1) + Math.pow(2, -k - 1));
    var factor2 = (Math.pow(2, -1) - Math.pow(2, -k - 1));
    var firstPoint = add(scale(P0[0], factor1), scale(P0[1], factor2));
    smoothedPoints[0] = firstPoint;

    var lastPoint = add(scale(P0[n0 - 1], factor2), scale(P0[n0], factor1));
    smoothedPoints[newLength - 1] = lastPoint;

    for (i in 0...n0-1) {
      for (j in 0...Std.int(Math.pow(2, k))) {
        var idx = Std.int(Math.pow(2, k) * (i) + j + 1);
        smoothedPoints[idx] = P0[i].scale(F[j + 1][k]).add(P0[i + 1].scale(G[j + 1][k])).add(P0[i + 2].scale(H[j + 1][k]));
      }
    }

    return smoothedPoints;
  }
}
