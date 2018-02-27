/** 
 * PairDeque data structure.
 * 
 * Based on:
 * 
 * @see http://www.cs.ubc.ca/~snoeyink/demos/convdecomp/MCDDemo.html		(Java - by Jack Snoeyink)
 * 
 * This is a hybrid between a stack and a deque, for storing pairs of
 * integers that form non-nested intervals in increasing order, back to
 * front.  It is used in minimum convex decomposition.
 * 
 * It is assumed that pushes come first (perhaps with some pops from
 * pushNarrow) and happen at the front of the deque. Then two independent
 * front and back pointers for popping. Unlike a standard deque, front
 * and back don't interfere: if you pop off one side, the element is
 * still available for the other side.  Thus, this is more like a pair of 
 * stacks that have the same elements in reverse order. 
 * 
 * @author Jack Snoeyink
 * @author azrafe7
 */

package hxGeomAlgo;


class PairDeque {
  private var front:Array<Int>;		// first elements of pair
  private var back:Array<Int>;		// second elements of pair

  // pointers point at the valid element. I.e., if there are none, they 
  // can point off the end of the list.
  public var frontTopIdx(default, null):Int;		// front stack pointer
  public var backTopIdx(default, null):Int;		// back stack pointer
  public var lastIdx(default, null):Int;			// the "high-water mark" for restores

  public function new() { 
    lastIdx = frontTopIdx = -1; 
    backTopIdx = 0; 
    front = new Array<Int>(); 
    back = new Array<Int>(); 
  }

  public function push(i:Int, j:Int) { // we push only onto the front
    if (front.length <= ++frontTopIdx) {	// make room if necessary
      front.push(-1);
      back.push(-1);
    }
    front[frontTopIdx] = i; 
    back[frontTopIdx] = j; 
    lastIdx = frontTopIdx;
  }

  public function pushNarrow(i:Int, j:Int) { 	// no nesting--> frontTopIdx < i && backTopIdx < j
    if ((!isFrontEmpty()) && (i <= frontTop())) return; 	// don't push wider
    while ((!isFrontEmpty()) && (backBottom() >= j)) popFront(); 	// pop until narrower: backTopIdx < j
    push(i, j);
  }

  public function isFrontEmpty():Bool { return frontTopIdx < 0; }
  public function frontHasNext():Bool { return frontTopIdx > 0; }
  public function flush() { lastIdx = frontTopIdx = -1; }
  public function frontTop():Int { 
    if (frontTopIdx < 0) return 0; // NOTE: investigate edge cases where this happens (it shouldn't!)
    return front[frontTopIdx]; }  
  public function frontPeekNext():Int { return front[frontTopIdx - 1]; }  
  public function backBottom():Int { return back[frontTopIdx]; }
  public function popFront():Int { return front[frontTopIdx--]; }
  public function restore() { backTopIdx = 0; frontTopIdx = lastIdx; } // return to high-water mark

  public function isBackEmpty():Bool { return backTopIdx > lastIdx ; }
  public function backHasNext():Bool { return backTopIdx < lastIdx; }
  public function frontBottom():Int { return front[backTopIdx]; }  
  public function backPeekNext():Int { return back[backTopIdx + 1]; }  
  public function backTop():Int { return back[backTopIdx]; }
  public function popBack():Int { return back[backTopIdx++]; }

  public function toString():String {
    var stringBuffer:StringBuf = new StringBuf();
    stringBuffer.add("fp:" + frontTopIdx + ", bp:" + backTopIdx + ", last:" + lastIdx + ": ");
    for (i in 0...lastIdx + 1) stringBuffer.add(front[i] + "," + back[i] + "  ");
    return stringBuffer.toString();
  }
}
