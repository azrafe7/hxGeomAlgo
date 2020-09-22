/**
 * Chaikin curve smoothing, multi-step implementation.
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

  static public function buildCache(k:Int)
  {
    var pow2_minus1 = Math.pow(2, -1);
    var pow2_minusK_minus1 = Math.pow(2, -k - 1);
    var pow2_minusK = Math.pow(2, -k);
    var pow2_K = Std.int(Math.pow(2, k));

    // exit early if cache is already built for k
    if (F.exists(pow2_K) && F[pow2_K].exists(k)) return;

    for (j in 1...pow2_K + 1) {
      if (!F.exists(j)) {
        F[j] = new Map();
        G[j] = new Map();
        H[j] = new Map();
      }
      if (!F[j].exists(k)) {
        F[j][k] = pow2_minus1 - pow2_minusK_minus1 - (j - 1) * (pow2_minusK - j * Math.pow(2, -2 * k - 1));
        G[j][k] = pow2_minus1 + pow2_minusK_minus1 + (j - 1) * (pow2_minusK - j * Math.pow(2, -2 * k));
        H[j][k] = (j - 1) * j * Math.pow(2, -2 * k - 1);
      }
    }
  }

  /** In-place point scaling. */
  static inline function scale(a:HxPoint, s:Float):HxPoint {
    a.setTo(s * a.x, s * a.y);
    return a;
  }

  /** In-place point sum (`a` will be modified and returned). */
  static inline function add(a:HxPoint, b:HxPoint):HxPoint {
    a.setTo(a.x + b.x, a.y + b.y);
    return a;
  }

  static public function smooth(poly:Poly, iterations:Int = 3, close:Bool = false):Poly
  {
    if (iterations <= 0 || poly.length <= 2) {
      return poly.copy();
    }

    var P0 = poly.copy();
    var k = iterations;
    if (close) {
      P0.push(P0[0]);
      P0.push(P0[1]);
    }

    buildCache(k);

    var smoothedPoints = new Poly();
    var n0 = P0.length - 1;
    var newLength = Std.int(Math.pow(2, k) * n0 - Math.pow(2, k) + 2);
    smoothedPoints.resize(newLength);

    var factor1 = (Math.pow(2, -1) + Math.pow(2, -k - 1));
    var factor2 = (Math.pow(2, -1) - Math.pow(2, -k - 1));

    if (false) {
      P0.push(P0[0]);
      P0.push(P0[1]);
      smoothedPoints[0] = P0[0].clone();
      smoothedPoints[newLength - 1] = P0[n0].clone();
    } else {
      var firstPoint = P0[0].clone().scale(factor1).add(P0[1].clone().scale(factor2));
      smoothedPoints[0] = firstPoint;

      var lastPoint = P0[n0 - 1].clone().scale(factor2).add(P0[n0].clone().scale(factor1));
      smoothedPoints[newLength - 1] = lastPoint;
    }

    var pow2_k = Std.int(Math.pow(2, k));
    for (i in 0...n0 - 1) {
      for (j in 0...pow2_k) {
        var idx = pow2_k * i + j + 1;
        smoothedPoints[idx] = P0[i].clone().scale(F[j + 1][k]).add(P0[i + 1].clone().scale(G[j + 1][k])).add(P0[i + 2].clone().scale(H[j + 1][k]));
      }
    }

    if (close && smoothedPoints.length > 2) {
      smoothedPoints.splice(newLength - 2, 2);
    }
    return smoothedPoints;
  }
}
