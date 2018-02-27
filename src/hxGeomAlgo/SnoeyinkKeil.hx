/**
 * Snoeyink-Keil minimum convex polygon decomposition implementation.
 * NOTE: Should work only for SIMPLE polygons (not self-intersecting, without holes).
 * 
 * Based on:
 * 
 * @see http://www.cs.ubc.ca/~snoeyink/demos/convdecomp/MCDDemo.html	(Java - Jack Snoeyink)
 * 
 * Other credits should go to papers/work of: 
 * 
 * J. Mark Keil, Jack Snoeyink: On the Time Bound for Convex Decomposition of Simple Polygons. Int. J. Comput. Geometry Appl. 12(3): 181-192 (2002)
 * @see http://www.cs.ubc.ca/spider/snoeyink/papers/convdecomp.ps.gz	(Snoeyink & Keil)
 * @see http://mnbayazit.com/406/files/OnTheTimeBound-Snoeyink.pdf		(Snoeyink & Keil)
 * 
 * @author azrafe7
 */

package hxGeomAlgo;


import haxe.ds.ArraySort;
import haxe.ds.IntMap.IntMap;
import hxGeomAlgo.PolyTools;
import hxGeomAlgo.SnoeyinkKeil.DecompPoly;


using hxGeomAlgo.PolyTools;


@:expose
class SnoeyinkKeil
{
  
  static private var poly:Poly;		// cw version of simplePoly - used internally

  static public var reversed:Bool;	// true if the _internal_ indices have been reversed

  static public var diagonals:Array<Diagonal>;	// stores diagonals' indices (as found by _decompByDiags())
  
  /** Decomposes `simplePoly` into a minimum number of convex polygons. */
  static public function decomposePoly(simplePoly:Poly):Array<Poly> {
    var res = new Array<Poly>();
    
    var indices = decomposePolyIndices(simplePoly);
    
    for (polyIndices in indices) {
      var currPoly = new Poly();
      res.push(currPoly);
      for (idx in polyIndices) {
        currPoly.push(simplePoly[idx]);
      }
    }
    
    return res;
  }
  
  /** Decomposes `simplePoly` into a minimum number of convex polygons and returns their vertices' indices. */
  static public function decomposePolyIndices(simplePoly:Poly):Array<Array<Int>> {
    var res = new Array<Array<Int>>();
    diagonals = [];
    if (simplePoly.length < 3) return res;

    poly = new Poly();
    for (p in simplePoly) poly.push(new HxPoint(p.x, p.y));
    reversed = poly.makeCW();	// make poly cw (in place)
    
    var i, j, k;
    var n = poly.length;
    var decomp = new DecompPoly(poly);
    decomp.init();
    
    for (l in 3...n) {
      i = decomp.reflexIter();

      while (i + l < n) {
        //trace("reflex: " + i + " vis:" + decomp.visible(i, i + l) + " " + poly.at(i));
        if (decomp.visible(i, k = i + l)) {
          decomp.initPairs(i, k);
          if (decomp.isReflex(k)) {
            for (j in i + 1...k) decomp.typeA(i, j, k);
          } else {
            j = decomp.reflexIter(i + 1);
            while (j < k - 1) {
              decomp.typeA(i, j, k);
              j = decomp.reflexNext(j);
            }
            
            decomp.typeA(i, k - 1, k); // do this, reflex or not.
          }
        }
        
        i = decomp.reflexNext(i);
      }
      
      k = decomp.reflexIter(l);
      while (k < n) {
        
        if (!decomp.isReflex(i = k - l) && decomp.visible(i, k)) {
          decomp.initPairs(i, k);
          decomp.typeB(i, i + 1, k); // do this, reflex or not.
          
          j = decomp.reflexIter(i + 2);
          while (j < k) {
            decomp.typeB(i, j, k);
            j = decomp.reflexNext(j);
          }
        }
        
        k = decomp.reflexNext(k);
      }
    }
    decomp.guard = 3 * n;
    decomp.recoverSolution(0, n - 1);

    res = decomp.decompIndices();
    
    if (reversed) {
      for (poly in res) {
        for (i in 0...poly.length) poly[i] = n - poly[i] - 1;
      }
      for (d in diagonals) {
        var tmp = d.from;
        d.from = n - d.to - 1;
        d.to = n - tmp - 1;
      }
    }
    
    return res;
  }
}


class DecompPoly {
  public static var INFINITY:Int = 100000;
  public static var BAD:Int = 999990;
  public static var NONE:Int = 0;

  public var guard:Int;

  public var poly:Poly;				// the polygon
  private var n:Int;					// number of vertices
  private var subDecomp:SubDecomp;	// the subproblems in  n x r space

  // for reflexIter
  private var _reflexFirst:Int;	
  private var _reflexNext:Array<Int>;	
  private var _reflexFlag:Array<Bool>;

  // intermediate and final result
  private var _indicesSet:IntMap<Bool> = new IntMap<Bool>();
  private var _polys:Array<Poly> = new Array<Poly>();
  private var _diags:Array<Diagonal> = [];

  
  public function new(poly:Poly) { 
    this.poly = poly;
    n = poly.length;
  }

  public function init() {
    initReflex();
    subDecomp = new SubDecomp(_reflexFlag);
    initVisibility();
    initSubProblems();
  }

  private function initReflex() {
    _reflexFlag = new Array<Bool>();
    _reflexNext = new Array<Int>();

    // init arrays
    for (i in 0...n) {
      _reflexFlag[i] = false;
      _reflexNext[i] = -1;
    }
    
    // find reflex vertices
    var wrap:Int = 0;	
    _reflexFlag[wrap] = true;	// by convention
    var i = n - 1;
    while (i > 0) {
      _reflexFlag[i] = poly.at(i - 1).isRight(poly.at(i), poly.at(wrap));
      wrap = i;
      i--;
    }

    _reflexFirst = n;	// for reflexIter
    i = n - 1;
    while (i >= 0) {
      _reflexNext[i] = _reflexFirst;
      if (isReflex(i)) _reflexFirst = i;
      i--;
    }
    //trace(_reflexNext);
  }

  public function isReflex(i:Int) { return _reflexFlag[i]; }
  
  public function reflexNext(i:Int):Int { return _reflexNext[i]; } 

  /* a cheap iterator through reflex vertices; each vertex knows the
  index of the next reflex vertex. */
  public function reflexIter(?n:Int):Int { // start w/ n or 1st reflex after...
    if (n == null || n <= 0) return _reflexFirst; 
    if (n > _reflexNext.length) return _reflexNext.length;
    return _reflexNext[n - 1];
  }
  
  public function visible(i:Int, j:Int):Bool { return subDecomp.weight(i, j) <  BAD; }

  public function initVisibility() { // initReflex() first
    var visIndices:Array<Int>;
    var i:Int = reflexIter();
    while (i < n) {
      visIndices = Visibility.getVisibleIndicesFrom(poly, i);
      
      while (visIndices.length > 0) {
        var j:Int = visIndices.pop();
        if (j < i) subDecomp.setWeight(j, i, INFINITY);
        else subDecomp.setWeight(i, j, INFINITY);
      }
      
      i = _reflexNext[i];
    }
  }

  private function setAfter(i:Int) { // i reflex
    Debug.assert(isReflex(i), "Non reflex i in setAfter(" + i + ")");
    subDecomp.setWeight(i, i + 1, 0);
    if (visible(i, i + 2)) subDecomp.initWithWeight(i, i + 2, 0, i + 1, i + 1);
  }
  
  private function setBefore(i:Int) { // i reflex
    Debug.assert(isReflex(i), "Non reflex i in setBefore(" + i + ")");
    subDecomp.setWeight(i - 1, i, 0);
    if (visible(i - 2, i))  subDecomp.initWithWeight(i - 2, i, 0, i - 1, i - 1);
  }
  
  public function initSubProblems() { // initVisibility first
    var i:Int;

    i = reflexIter();
    if (i == 0) { setAfter(i); i = _reflexNext[i]; }
    if (i == 1) { subDecomp.setWeight(0, 1, 0); setAfter(i); i = _reflexNext[i]; }
    while (i < n - 2) { setBefore(i); setAfter(i); i = _reflexNext[i]; }
    if (i == n - 2) { setBefore(i); subDecomp.setWeight(i, i + 1, 0); i = _reflexNext[i];}
    if (i == n - 1) { setBefore(i); }
  }

  public function initPairs(i:Int, k:Int) { 
    subDecomp.init(i, k);
  }

  public function recoverSolution(i:Int, k:Int) { 
    var j:Int;
    guard--;
    Debug.assert(guard >= 0, "Can't recover " + i + "," + k);
    if (k - i <= 1) return;
    var pair:PairDeque = subDecomp.pairs(i, k);
    //trace(i, k, pair);
    if (isReflex(i)) {
      j = pair.backTop();
      recoverSolution(j, k);
      if (j - i > 1) {
        if (pair.frontBottom() != pair.backTop()) {
          var pd:PairDeque = subDecomp.pairs(i, j);
          pd.restore();
          while ((!pd.isBackEmpty()) && pair.frontBottom() != pd.frontBottom()) pd.popBack();
          //if (!pd.isBackEmpty()) throw "Emptied pd " + i + "," + j + "," + k + " " + pair.toString();
        }
        recoverSolution(i, j);
      }
    }
    else {
      j = pair.frontTop();
      recoverSolution(i, j);
      if (k - j > 1) {
        if (pair.frontTop() != pair.backBottom()) {
          var pd:PairDeque = subDecomp.pairs(j, k);
          pd.restore();
          while (!pd.isFrontEmpty() && pair.backBottom() != pd.backBottom()) pd.popFront();
          //if (!pd.isFrontEmpty()) throw "Emptied pd " + i + "," + j + "," + k + " " + pair.toString();
        }
        recoverSolution(j, k);
      }
    }
  }

  public function typeA(i:Int, j:Int, k:Int) { /* i reflex; use jk */
    //    System.out.print("\nA "+i+","+j+","+k+":");
    //    assert(reflex(i), "non reflex i in typeA("+i+","+j+","+k+")");
    //    assert(k-i > 1, "too small in typeA("+i+","+j+","+k+")");
    if (!visible(i,j)) return;
    var top:Int = j;
    var w:Int = subDecomp.weight(i, j);
    
    if (k - j > 1) {
      if (!visible(j, k)) return;
      w += subDecomp.weight(j, k) + 1;
    }
    if (j - i > 1) {		// check if must use ij, too.
      var pair:PairDeque = subDecomp.pairs(i, j);
      if (!poly.at(k).isLeft(poly.at(j), poly.at(pair.backTop()))) {
        
        while (pair.backHasNext() && !poly.at(k).isLeft(poly.at(j), poly.at(pair.backPeekNext()))) pair.popBack();
        
        if (!pair.isBackEmpty() && !poly.at(k).isRight(poly.at(i), poly.at(pair.frontBottom()))) top = pair.frontBottom();
        else w++;		// yes, need ij. top = j already
        
      } else w++;		// yes, need ij. top = j already
    }
    update(i, k, w, top, j);
  }

  public function typeB(i:Int, j:Int, k:Int) { /* k reflex, i not. */
    //    System.out.print("\nB "+i+","+j+","+k+":");
    if (!visible(j, k)) return;
    var top:Int = j;
    var w:Int = subDecomp.weight(j, k); 
    
    if (j - i > 1) {
      if (!visible(i, j)) return;
      w += subDecomp.weight(i, j) + 1;
    }
    if (k - j > 1) {		// check if must use jk, too.
      var pair:PairDeque = subDecomp.pairs(j, k);
      if (!poly.at(i).isRight(poly.at(j), poly.at(pair.frontTop()))) {
        
        while (pair.frontHasNext() && !poly.at(i).isRight(poly.at(j), poly.at(pair.frontPeekNext()))) pair.popFront();
        
        if (!pair.isFrontEmpty() && !poly.at(i).isLeft(poly.at(k), poly.at(pair.backBottom()))) top = pair.backBottom();
        else w++;			// yes, use jk. top=j already
        
      } else w++;			// yes, use jk. top=j already
    }
    update(i, k, w, j, top);
  }


  /** 
   * We have a new solution for subprob a,b with weight w, using
   * i,j.  If it is better than previous solutions, we update. 
   * We assume that a < b and i < j.
   */
  public function update(a:Int, b:Int, w:Int, i:Int, j:Int) {
    //trace("update(" + a + "," + b + " w:" + w + " " + i + "," + j + ")");
    var ow:Int = subDecomp.weight(a, b);
    if (w <= ow) {
      var pair:PairDeque = subDecomp.pairs(a, b);
      if (w < ow) { 
        pair.flush(); 
        subDecomp.setWeight(a, b, w); 
      }
      pair.pushNarrow(i, j);
    }
  }

  // TODO: see how to improve this
  private function _decompByDiags(i:Int, k:Int, outIndices:Array<Array<Int>>, level:Int = 0) {
    //trace('level -> $level');
    
    if (level == 0) {
      _indicesSet.set(0, true);
      _indicesSet.set(poly.length - 1, true);
      //trace("diag " + i + "-" + k + "  " + poly.at(i) + " " + poly.at(k));
    }
    
    var j:Int; 
    var ijReal = true, jkReal = true;
    var nDiags:Int = 0;
    
    if (k - i <= 1) return;
    
    var pair:PairDeque = subDecomp.pairs(i, k);
    if (isReflex(i)) { 
      j = pair.backTop(); 
      ijReal = (pair.frontBottom() == pair.backTop()); 
    } else { 
      j = pair.frontTop(); 
      jkReal = (pair.backBottom() == pair.frontTop()); }

    if (ijReal) {
      _indicesSet.set(i, true);
      _indicesSet.set(j, true);
      _diags.push( { from:i, to:j } );
      //trace("diag " + i + "-" + j + "  " + poly.at(i) + " " + poly.at(j));
      nDiags++;
    }

    if (jkReal) {
      _indicesSet.set(j, true);
      _indicesSet.set(k, true);
      _diags.push( { from:j, to:k } );
      //trace("diag " + j + "-" + k + "  " + poly.at(j) + " " + poly.at(k));
      nDiags++;
    }

    guard--;
    Debug.assert(guard >= 0, "Infinite loop diag " + i + "," + k); 
    
    if (nDiags > 1) {	// add new decomposing poly
      var indices:Array<Int> = [for (k in _indicesSet.keys()) k];
      indices.sort(intCmp);
      
      if (indices.length > 0) {
        outIndices.push(indices);
        _indicesSet = new IntMap<Bool>();
      }
    }

    // if we just found a real i-j diag, follow it first (should fix issue #11)
    if (ijReal && j - i > 1) {
      _decompByDiags(j, k, outIndices, level + 1);
      _decompByDiags(i, j, outIndices, level + 1);
    } else {
      _decompByDiags(i, j, outIndices, level + 1);
      _decompByDiags(j, k, outIndices, level + 1);
    }
  }

  private inline function intCmp(a:Int, b:Int):Int {
    if (a == b) return 0;
    else if (b < a) return 1;
    else return -1;
  }
  
  /** Returns the vertices' indices of each decomposing poly. */
  public function decompIndices():Array<Array<Int>>
  {
    var res = new Array<Array<Int>>();
    guard = 3 * n;
    _decompByDiags(0, poly.length - 1, res);
    SnoeyinkKeil.diagonals = _diags;
    
    return res;
  }
  
  public function toString():String {
    return poly.length + ": " + poly.toString();
  }
}


/** 
 * This class stores all subproblems for a decomposition by dynamic 
 * programming.  
 * It uses an indirect addressing into arrays that have all the
 * reflex vertices first, so that I can allocate only O(nr) space.
 */
class SubDecomp {
  private var wt:Array<Array<Int>>;
  private var pd:Array<Array<PairDeque>>;
  private var rx:Array<Int>;		// indirect index so reflex come first

  public function new(reflex:Array<Bool>) {
    var n = reflex.length, r = 0, j;

    rx = new Array<Int>();

    for (i in 0...n) rx[i] = reflex[i] ? r++ : 0;

    j = r;
    wt = new Array<Array<Int>>();
    pd = new Array<Array<PairDeque>>();
    for (i in 0...n) {
      if (!reflex[i]) rx[i] = j++;
      wt[i] = new Array<Int>();
      pd[i] = new Array<PairDeque>();
      for (k in 0...n) {
        if (i < r || k < r) {
          wt[i][k] = DecompPoly.BAD;
          pd[i][k] = null;
        } else {
          break;
        }
      }
    }
    
    //trace(rx);
  }
  
  public function setWeight(i:Int, j:Int, w:Int) { 
    wt[rx[i]][rx[j]] = w; 
  }
  
  public function weight(i:Int, j:Int):Int { 
    return wt[rx[i]][rx[j]]; 
  }
  
  public function pairs(i:Int, j:Int):PairDeque { 
    return pd[rx[i]][rx[j]]; 
  }
  
  public function init(i:Int, j:Int):PairDeque {
    return pd[rx[i]][rx[j]] = new PairDeque(); 
  }
  
  public function initWithWeight(i:Int, j:Int, w:Int, a:Int, b:Int) {
    setWeight(i, j, w); 
    init(i, j).push(a,b);
  }
}
