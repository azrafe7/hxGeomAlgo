/**
 * Visibility polygon implementation.
 * NOTE: Should work only for SIMPLE polygons (not self-intersecting, without holes).
 * 
 * Based on:
 * 
 * @see http://www.cs.ubc.ca/~snoeyink/demos/convdecomp/VPDemo.html	(Java - by Jack Snoeyink)
 * 
 * Other credits should go to papers/work of: 
 * 
 * @see http://www.stanford.edu/~tunococ/papers/avis81optimal.pdf	(Avis & Toussaint)
 * 
 * @author azrafe7
 */

package hxGeomAlgo;


import hxGeomAlgo.Debug;
import hxGeomAlgo.HomogCoord;
import hxGeomAlgo.PolyTools;
import hxGeomAlgo.Visibility.VertexType;


using hxGeomAlgo.PolyTools;


/** polygon vertex types:    

      LLID-------------------RLID
      |            	|
      |            	|
  --------LWALL        	RWALL---------
*/
enum VertexType {
  UNKNOWN;
  RIGHT_LID;
  LEFT_LID;
  RIGHT_WALL;
  LEFT_WALL;
}


@:expose
class Visibility
{
  inline static private var NOT_SAVED:Int = -1;
  
  static private var origPoint:HxPoint;										// origin of visibility polygon
  static private var stack:Array<Int> = new Array<Int>();						// stack holds indices of visibility polygon
  static private var vertexType:Array<VertexType> = new Array<VertexType>();	// types of vertices
  static private var stackTop:Int;											// stack pointer to top element
  static private var poly:Poly;												// cw version of simplePoly - used internally
  
  static private var leftLidIdx:Int;
  static private var rightLidIdx:Int;
  
  static public var reversed:Bool;	// true if the _internal_ indices have been reversed
  
  /** Returns an array of indices representing the vertices of `simplePoly` visible from `origIdx`. */
  static public function getVisibleIndicesFrom(simplePoly:Poly, origIdx:Int = 0):Array<Int> {
    var res = new Array<Int>();
    
    poly = new Poly();
    stack.clear();
    vertexType.clear();
    
    if (simplePoly.length <= 0) return res;
    
    // init
    stackTop = -1;
    for (i in 0...simplePoly.length) {
      poly.push(new HxPoint(simplePoly[i].x, simplePoly[i].y));
      stack.push(-1);
      vertexType.push(VertexType.UNKNOWN);
    }
    reversed = poly.makeCW();	// make poly cw (in place)
    if (reversed) {
      origIdx = poly.length - origIdx - 1;
    }
    
    // build
    var edgeJ:HomogCoord;	// during the loops, this is the line p[j-1]->p[j]
    origPoint = poly[origIdx];
    var j:Int = origIdx;
    push(j++, VertexType.RIGHT_WALL);	// origPoint & p[1] on Visible Poly
    do {	// loop always pushes p[j] and increments j.
      push(j++, VertexType.RIGHT_WALL);
      if (j >= poly.length + origIdx) break; 	// we are done.
      edgeJ = poly.at(j - 1).meet(poly.at(j));
      if (edgeJ.left(origPoint)) {
        continue; 	// easiest case: add edge to Visible Poly.
      }
      // else p[j] backtracks, we must determine where
      if (!(edgeJ.left(poly.at(j - 2)))) {	// p[j] is above last Visible Poly edge
        j = exitRightBay(poly, j, poly.at(stack[stackTop]), HomogCoord.INFINITY);
        push(j++, VertexType.RIGHT_LID); 
        continue; 	 // exits bay; push next two
      }
      
      saveLid();	// else p[j] below top edge; becomes lid or pops
      do {	// p[j] hides some of Visible Poly; break loop when can push p[j].
        //trace("do j: " + j + " lid: " + leftLidIdx + " " + rightLidIdx);
        if (origPoint.isLeft(poly.at(stack[stackTop]), poly.at(j))) {	// saved lid ok so far...
          if (poly.at(j).isRight(poly.at(j + 1), origPoint)) j++; 	// continue to hide
          else if (edgeJ.left(poly.at(j + 1))) { 	// or turns up into bay
            j = exitLeftBay(poly, j, poly.at(j), poly.at(leftLidIdx).meet(poly.at(leftLidIdx - 1))) + 1; 
          } else {	// or turns down; put saved lid back & add new Visible Poly edge 
            restoreLid(); 
            push(j++, VertexType.LEFT_WALL); 
            break; 
          }
          edgeJ = poly.at(j - 1).meet(poly.at(j)); 	// loop continues with new j; update edgeJ
        } else	{	// lid is no longer visible
          if (!(edgeJ.left(poly.at(stack[stackTop])))) { 	// entered RBay, must get out
            //if (rightLidIdx != NOT_SAVED) throw "no RLid saved " + leftLidIdx + " " + rightLidIdx;
            j = exitRightBay(poly, j, poly.at(stack[stackTop]), edgeJ.neg()); 	// exits bay;
            push(j++, VertexType.RIGHT_LID); 
            break; 	// found new visible lid to add to Visible Poly.
          } 
          else saveLid(); 	// save new lid from Visible Poly; continue to hide Visible Poly.
        }
      } while (true);
      //trace("exit j: " + j + " lid: " + leftLidIdx + " " + rightLidIdx);
    } while (j < poly.length + origIdx); 	// don't push origin again.
    
    //var s:String = "";
    for (i in 0...stackTop + 1) {
      //s += (stack[i] % poly.length) + Std.string(vertexType[i]) + " ";
      if (vertexType[i] == VertexType.LEFT_WALL || vertexType[i] == VertexType.RIGHT_WALL) {
        var idx = stack[i] % poly.length;
        if (reversed) idx = poly.length - idx - 1;	// reverse indices
        res.push(idx);
      }
    }
    //trace(s);
    
    return res;
  }
  
  /** Returns an array of all the points of `simplePoly` visible from `origIdx` (may include points not in `simplePoly`). */
  static public function getVisiblePolyFrom(simplePoly:Poly, origIdx:Int = 0):Poly {
    var indices = getVisibleIndicesFrom(simplePoly, origIdx);
    var res = new Poly();
    
    if (indices.length <= 0) return res;
    
    var q:HomogCoord;
    var last:HxPoint = poly.at(stack[stackTop]);
    var lastPushed:HxPoint = null;
    var lastType:VertexType = VertexType.UNKNOWN;
    var vType:VertexType = UNKNOWN;
    for (i in 0...stackTop + 1) {
      vType = vertexType[i];
      
      if (vType == VertexType.RIGHT_LID) {
        q = origPoint.meet(last).meet(poly.at(stack[i]).meet(poly.at(stack[i + 1])));
        if (lastPushed != null && !lastPushed.equals(last)) {
          res.push(last.clone());
        }
        res.push(q.toPoint());
      } else if (vType == VertexType.LEFT_WALL) {
        q = origPoint.meet(poly.at(stack[i])).meet(poly.at(stack[i - 2]).meet(poly.at(stack[i - 1])));
        res.push(q.toPoint());
      } else {
        if ((vType == VertexType.RIGHT_WALL && lastType == VertexType.RIGHT_LID) || 
          (vType == VertexType.LEFT_LID && lastType == VertexType.RIGHT_LID)) {
          // skip this one
        } else {
          res.push(last.clone());
        }
      }
      lastPushed = res[res.length - 1];
      last = poly.at(stack[i]);
      lastType = vType;
      
      //if (lastPushed.equals(last)) trace("duplicate " + last);
    }
    
    return res;
  }

  /** 
   * Exits from a right bay: proceeds from j, j++, ... until exiting
   * the bay defined to the right of the line from origPoint through
   * point bot to line lid.  Returns j such that (j, j+1) forms a new lid
   * of this bay.  Assumes that poly.at(j) is not left of the line
   * origPoint->bot.  
   */
  static private function exitRightBay(poly:Poly, j:Int, bot:HxPoint, lid:HomogCoord):Int {
    var windingNum:Int = 0;		// winding number
    var mouth:HomogCoord = origPoint.meet(bot);
    var lastLeft:Bool, currLeft:Bool = false;

    while (++j < 3 * poly.length) {
      lastLeft = currLeft; 
      currLeft = mouth.left(poly.at(j));
      
      // if cross ray origPoint->bot, update winding num
      if ((currLeft != lastLeft) && (poly.at(j - 1).isLeft(poly.at(j), origPoint) == currLeft)) { 
        if (!currLeft) windingNum--;
        else if (windingNum++ == 0) { 	// on 0->1 transitions, check window
          var edge:HomogCoord = poly.at(j - 1).meet(poly.at(j));
          if (edge.left(bot) && (!HomogCoord.cw(mouth, edge, lid)))
          return j - 1; 	// j exits window!
        }
      }
    }
    
    Debug.assert(false, "ERROR: We never exited RBay " + bot + " " + lid + " " + windingNum);
    return j;
  } 

  /** 
   * Exits from a left bay: proceeds from j, j++, ... until exiting
   * the bay defined to the right of the line from origPoint through
   * point bot to line lid.  Returns j such that (j, j+1) forms a new lid
   * of this bay.  Assumes that poly.at(j) is not right of the line
   * origPoint->bot.  
   */
  static private function exitLeftBay(poly:Poly, j:Int, bot:HxPoint, lid:HomogCoord):Int {
    var windingNum:Int = 0;		// winding number
    var mouth:HomogCoord = origPoint.meet(bot);
    var lastRight:Bool, currRight:Bool = false;		// called with !right(org,bot,pj)
    
    while (++j < 3 * poly.length) {
      lastRight = currRight; 
      currRight = mouth.right(poly.at(j));
      
      // if cross ray origPoint->bot, update winding num
      if ((currRight != lastRight) && (poly.at(j - 1).isRight(poly.at(j), origPoint) == currRight)) { 
        if (!currRight) windingNum++;
        else if (windingNum-- == 0) { 	// on 0->-1 transitions, check window
          var edge:HomogCoord = poly.at(j - 1).meet(poly.at(j));
          if (edge.right(bot) && (!HomogCoord.cw(mouth, edge, lid)))
          return j - 1; 	// j exits window!
        }
      }
    }
    
    Debug.assert(false, "ERROR: We never exited LBay " + bot + " " + lid + " " + windingNum);
    return j;
  } 

  static private function push(idx:Int, vType:VertexType) {
    stackTop++;
    stack[stackTop] = idx;
    vertexType[stackTop] = vType;
  }
  
  static private function saveLid():Void 
  {
    //trace("saveLid " + stackTop);
    if (vertexType[stackTop] == VertexType.LEFT_WALL) stackTop--; 	// for LEFT_WALL, lid is previous two
    leftLidIdx = stack[stackTop--];
    if (vertexType[stackTop] == VertexType.RIGHT_LID) rightLidIdx = stack[stackTop--]; 	// if not RIGHT_LID, just leave on top().
    else rightLidIdx = NOT_SAVED;
  }

  static private function restoreLid():Void 
  {
    //trace("restoreLid " + leflLidIdx + " " + rightLidIdx);
    if (rightLidIdx != NOT_SAVED) push(rightLidIdx, VertexType.RIGHT_LID); 
    push(leftLidIdx, VertexType.LEFT_LID);
  }
}