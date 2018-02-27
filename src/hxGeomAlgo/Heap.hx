/**
 * Heap implementation.
 * 
 * Based on:
 * 
 * @see http://en.wikipedia.org/wiki/Binary_heap 		(Binary Heap) 
 * @see https://github.com/jonasmalacofilho/dheap		(Haxe - Jonas Malaco Filho)
 * 
 * @author azrafe7
 */

package hxGeomAlgo;

import hxGeomAlgo.Debug;


/** Heap elements must implement this interface. */
interface Heapable<T> {
  
  /** Used internally by Heap. Do not modify. */
  var position:Int;
  
  /** 
   * Returns the result of comparing `this` to `other`, where the result is expected to be:
   *    less than zero if `this` < `other`
   *    equal to zero if `this` == `other`
   *    greater than zero if `this` > `other`
   */
  function compare(other:T):Int;
}


/** 
 * Heap implementation (over Array).
 * 
 * Note: depending on the compare function (i.e. if it's ascending or descending),
 * it will act as a MinHeap or MaxHeap (meaning that `pop()` will return the smallest 
 * or the largest element respectively).
 * 
 * @author azrafe7
 */
class Heap<T:Heapable<T>>
{
  private var data:Array<T>;
  
  public function new():Void 
  {
    data = new Array<T>();
  }
  
  /** Number of elements in the Heap. */
  public var length(default, null):Int = 0;
  
  /** Inserts `obj` into the Heap. */
  public function push(obj:T):Void 
  {
    var i = length;
    set(obj, i);
    length++;
    if (length > 1) bubbleUp(i);
  }
  
  /** Returns the root element (i.e. the smallest or largest, depending on compare()) and removes it from the Heap. Or null if the Heap is empty. */
    public function pop():T
    {
        if (length == 0) return null;
        
        var res = data[0];
        var len = length;
        var lastObj = data[len - 1];
    data[len - 1] = null;
    length--;
    if (len > 1) {
            set(lastObj, 0);
            bubbleDown(0);
        }
    
        return res;
    }
    
  /** Returns the root element (i.e. the smallest or largest, depending on compare()) without removing it from the Heap. Or null if the Heap is empty. */
  public function top():T
  {
    return length > 0 ? data[0] : null;
  }
  
  /** Removes `obj` from the Heap. Checks for correctness are only done in debug. */
    public function remove(obj:T):Int
    {
        var pos = obj.position;
    Debug.assert((pos >= 0 && pos < length), "Object not found.");
    Debug.assert(data[pos] == obj, '`obj` and retrieved object at $pos don\'t match.');
    
        var len = length;
        var lastObj = data[len - 1];
    data[len - 1] = null;
    length--;
    if (pos != len - 1) {
            set(lastObj, pos);
            lastObj.compare(obj) < 0 ? bubbleUp(pos) : bubbleDown(pos);
        }
        return pos;
    }
    
  inline public function clear():Void 
  {
  #if (flash || js)
    untyped data.length = 0;
  #else
    data.splice(0, length);
  #end
    length = 0;
  }
  
    private function bubbleDown(i:Int):Void
    {
        var left = leftOf(i);
        var right = rightOf(i);
        var curr = i;
        if (left < length && data[left].compare(data[curr]) < 0) curr = left;
        if (right < length && data[right].compare(data[curr]) < 0) curr = right;
        if (curr != i) {
            swap(curr, i);
            bubbleDown(curr);
        }
    }
    
  private function bubbleUp(i:Int):Void
  {
    while (i > 0 && !(data[i].compare(data[parentOf(i)]) > 0)) {
      var parent = parentOf(i);
      swap(parent, i);
      i = parent;
    }
  }
  
  public function validate():Void 
  {
    if (length > 0) _validate(0);
  }
  
  public function toArray():Array<T>
  {
    return [].concat(data);
  }
  
  private function _validate(i:Int):Void
  {
    var len = length;
    var left = leftOf(i);
    var right = rightOf(i);
    
    if (left < len) {
      Debug.assert(data[i].compare(data[left]) <= 0, 'Broken heap invariant (parent@$i > leftChild@$left).');
      _validate(leftOf(i));
    }
    if (right < len) {
      Debug.assert(data[i].compare(data[right]) <= 0, 'Broken heap invariant (parent@$i > rightChild@$right).');
      _validate(rightOf(i));
    }
  }
  
  private function set(obj:T, index:Int):Void
  {
    data[index] = obj;
    obj.position = index;
  }
  
  inline private function leftOf(i:Int):Int
  {
    return  2 * i + 1;
  }
  
  inline private function rightOf(i:Int):Int
  {
    return  2 * i + 2;
  }
  
  inline private function parentOf(i:Int):Int
  {
    return (i - 1) >> 1;
  }
  
  inline private function swap(i:Int, j:Int):Void
  {
    var temp = data[i];
    set(data[j], i);
    set(temp, j);
  }
}