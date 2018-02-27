/**
 * Marching Squares implementation (Counterclockwise).
 * 
 * Based on:
 * 
 * @see http://devblog.phillipspiess.com/2010/02/23/better-know-an-algorithm-1-marching-squares/	(C# - by Phil Spiess)
 * @see http://www.tomgibara.com/computer-vision/marching-squares									(Java - by Tom Gibara)
 * 
 * @author azrafe7
 */

package hxGeomAlgo;

import hxPixels.Pixels;


enum StepDirection {
  NONE;
  UP;
  LEFT;
  DOWN;
  RIGHT;
}


@:expose
class MarchingSquares
{
  /** Minimum alpha value to consider a pixel opaque (in the range 0-255). */
  public var alphaThreshold:Int;

  private var prevStep:StepDirection = StepDirection.NONE;
  private var nextStep:StepDirection = StepDirection.NONE;
  
  private var pixels:Pixels;
  private var width:Int;
  private var height:Int;
  

  /**
   * Constructor.
   * 
   * @param	pixels			Pixels to use as source.
   * @param	alphaThreshold  Minimum alpha value to consider a pixel opaque (in the range 0-255).
   */
  public function new(pixels:Pixels, alphaThreshold:Int = 1)
  {
    setSource(pixels);
    
    this.alphaThreshold = alphaThreshold;
  }
  
  /** 
   * Updates the Pixels to use as source.
   * 
   * NOTE: If you modifiy your source between calls to march()/walkPerimeter you may 
   * also want to re-set the source so that the internal representation gets updated too.
   */
  public function setSource(pixels:Pixels)
  {
    this.pixels = pixels;
    width = this.pixels.width;
    height = this.pixels.height;
  }
  
  /** 
   * Finds the perimeter.
   * 
   * @param	startPoint	Start from this point (if null it will be calculated automatically).
   * @return	An array containing the points on the perimeter, or an empty array if no perimeter is found.
   */
  public function march(startPoint:HxPoint = null):Array<HxPoint> 
  {
    if (startPoint == null) startPoint = findStartPoint();
    if (startPoint == null) return [];
    
    var perimeter = walkPerimeter(Std.int(startPoint.x), Std.int(startPoint.y));
    
    // remove end point if start == end
    if (perimeter.length > 1 && perimeter[0].equals(perimeter[perimeter.length - 1])) perimeter.pop();
    
    return perimeter;
  }
  
  /** 
   * Finds the first opaque pixel location (starting from top-left corner, or from the specified line). 
   * 
   * @return The first opaque pixel location, or null if not found.
   */
  public function findStartPoint(line:Int = 0):HxPoint {
    var found = false;
    
    for (y in line...height) {
      for (x in 0...width) {
        if (isPixelSolid(x, y)) return new HxPoint(x, y);
      }
    }
    
    return null;
   }
  
  /** 
   * Finds points belonging to the perimeter starting from `startX`, `startY`. 
   * 
   * NOTE: The perimeter (if exists) is guaranteed to be fully contained in the souce boundaries
   * and will start on a solid pixel. The points found when going up or right might be 1px away 
   * from the solid pixels though (see https://github.com/azrafe7/as3GeomAlgo/issues/1#issuecomment-108634264).
   */
  private function walkPerimeter(startX:Int, startY:Int):Array<HxPoint> 
  {
    // clamp to source boundaries
    if (startX < 0) startX = 0;
    if (startX > width) startX = width;
    if (startY < 0) startY = 0;
    if (startY > height) startY = height;

    var lastAddedPoint = new HxPoint(-1, -1);
    var pointList = new Array<HxPoint>();

    var x:Int = startX;
    var y:Int = startY;

    // loop until we return to the starting point
    var done = false;
    while (!done) {
      step(x, y);

      // add perimeter point to return list,
      // but adjusting for out of bounds cases and
      // skipping duplicate points
      var newPoint = new HxPoint(x >= width ? x - 1 : x, y >= height ? y - 1 : y);
      if (!lastAddedPoint.equals(newPoint)) {
        pointList.push(newPoint);
        lastAddedPoint = newPoint;
      }

      switch (nextStep)
      {
        case StepDirection.UP:    y--; 
        case StepDirection.LEFT:  x--; 
        case StepDirection.DOWN:  y++; 
        case StepDirection.RIGHT: x++; 
        default: Debug.assert(false, "Illegal state at point (x: " + x + ", y: " + y + ").");
      }
      
      done = (x == startX && y == startY);
    }

    return pointList;
  }
  
  /** Calculates the next state for pixel at `x`, `y`. */
  private function step(x:Int, y:Int):Void 
  {
    var upLeft = isPixelSolid(x - 1, y - 1);
    var upRight = isPixelSolid(x, y - 1);
    var downLeft = isPixelSolid(x - 1, y);
    var downRight = isPixelSolid(x, y);
    
    // save previous step
    prevStep = nextStep;

    // calc current state
    var state:Int = 0;

    if (upLeft) state |= 1;
    if (upRight) state |= 2;
    if (downLeft) state |= 4;
    if (downRight) state |= 8;

    Debug.assert(state != 0 && state != 15, "Error: point (x: " + x + ", y: " + y + ") doesn't lie on perimeter.");
    
    switch (state)
    {
      case 1, 5, 13: 
        nextStep = StepDirection.UP;
      case 2, 3, 7: 
        nextStep = StepDirection.RIGHT;
      case 4, 12, 14: 
        nextStep = StepDirection.LEFT;
      case 6:
        nextStep = (prevStep == StepDirection.UP ? StepDirection.LEFT : StepDirection.RIGHT);
      case 8, 10, 11: 
        nextStep = StepDirection.DOWN;
      case 9:
        nextStep = (prevStep == StepDirection.RIGHT ? StepDirection.UP : StepDirection.DOWN);
      default: 
        Debug.assert(false, "Illegal state at point (x: " + x + ", y: " + y + ").");
    }
  }
  
  /** 
   * Returns true if the pixel at `x`, `y` is opaque (according to `alphaThreshold`).
   * Override this to use your own logic to identify solid pixels.
   */
  private function isPixelSolid(x:Int, y:Int):Bool {
    return (x >= 0 && y >= 0 && x < width && y < height && (pixels[(y * width + x) << 2]) >= alphaThreshold);
  }
}