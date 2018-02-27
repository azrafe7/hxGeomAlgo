/**
 * Connected components labeling (8 and 4-connectivity) implementation.
 * 
 * Based on the paper of:
 * 
 * Fu Chang, Chun-jen Chen, Chi-jen Lu: A linear-time component-labeling algorithm using contour tracing technique (2004)
 * 
 * @see http://www.iis.sinica.edu.tw/papers/fchang/1362-F.pdf
 * 
 * @author azrafe7
 */

package hxGeomAlgo;

import hxGeomAlgo.HxPoint;
import hxGeomAlgo.PolyTools.Poly;
import hxPixels.Pixels;


@:expose
enum Connectivity {
  FOUR_CONNECTED;
  EIGHT_CONNECTED;
}


@:expose
class CCLabeler
{
#if js
  static function __init__() {
    PolyTools.exposeEnum(Connectivity);
  }
#end
  
  /** Minimum alpha value to consider a pixel opaque (in the range 1-255). */
  public var alphaThreshold:Int;

  /** Pixels containing the labeling info. */
  public var labelMap:Pixels;
  
  /** Whether to store contours' points while labeling. */
  public var traceContours:Bool;
  
  /** Whether to compute and store components' area (in areaMap) while labeling. */
  public var calcArea:Bool;
  
  /** Type of connectivity to search for. */
  public var connectivity:Connectivity;
  
  /** 
   * Contours' points found while labeling (external contours
   * are in clockwise order, while internal ones are in ccw order).
   */
  public var contours(default, null):Array<Poly>;
  
  /** Count of pixels belonging to the same connected component, indexed by label color (as returned by labelToColor()). */
  public var areaMap(default, null):Map<Int, Int>;
  
  /** Number of connected components found. */
  public var numComponents(default, null):Int;

  
  private var MARKED:Int = 0xFFFFFFFF;
  private var UNLABELED:Int = 0x00000000;
  
  private var searchDir:Array<{dx:Int, dy:Int}> = [
    {dx:  1, dy:  0}, // 0
    {dx:  1, dy:  1}, // 1    +-------x
    {dx:  0, dy:  1}, // 2    | 5 6 7
    {dx: -1, dy:  1}, // 3    | 4 P 0
    {dx: -1, dy:  0}, // 4    | 3 2 1
    {dx: -1, dy: -1}, // 5    y
    {dx:  0, dy: -1}, // 6
    {dx:  1, dy: -1}  // 7
  ];
  
  private var tracingDir:Int = 0;
  private var labelIndex:Int = 0;
  private var contourPoint:HxPoint = new HxPoint();
  private var secondContourPoint:HxPoint = new HxPoint();
  
  private var sourcePixels:Pixels;
  private var markedPixels:Pixels;
  
  private var width:Int;
  private var height:Int;
  
  private var colors:Array<Int> = [];
  private var hue:Float = .60;

  /**
   * Constructor.
   * 
   * @param	pixels			Pixels to use as source for labeling.
   * @param	alphaThreshold  Minimum alpha value to consider a pixel opaque (in the range 1-255).
   * @param	traceContours	Whether to store contours' points while labeling.
   * @param	connectivity	Type of connectivity to search for (defaults to EIGHT_CONNECTED).
   * @param	calcArea		Whether to compute and store components' area (in areaMap) while labeling.
   */
  public function new(pixels:Pixels, alphaThreshold:Int = 1, traceContours:Bool = true, ?connectivity:Connectivity, calcArea:Bool = false)
  {
    setSource(pixels);
    
    this.alphaThreshold = alphaThreshold;
    this.connectivity = connectivity != null ? connectivity : EIGHT_CONNECTED;
    this.traceContours = traceContours;
    this.calcArea = calcArea;
    numComponents = 0;
  }
  
  /** 
   * Updates the Pixels to use as source.
   * 
   * NOTE: If you modifiy your source between calls to run() you may 
   * also want to re-set the source so that the internal representation gets updated too.
   */
  public function setSource(pixels:Pixels)
  {
    this.sourcePixels = pixels;
    
    width = this.sourcePixels.width;
    height = this.sourcePixels.height;
    labelMap = new Pixels(width, height);
    labelMap.format = pixels.format;
    labelMap.fillRect(0, 0, width, height, UNLABELED);
    markedPixels = new Pixels(width, height);
    markedPixels.format = pixels.format;
    markedPixels.fillRect(0, 0, width, height, 0);
  }
  
  /**
   * Labels connected components and writes them in the returned Pixels (also stored in `labelMap`).
   * If `traceContours` has been set, it also saves contours' points in the `contours` variable.
   */
  public function run():Pixels
  {
    contours = new Array<Poly>();
    areaMap = new Map<Int, Int>();
    numComponents = 0;
    labelIndex = 0;
    
    var	isLabeled:Bool;
    var leftLabeledPixel:Int;
    
    var x, y = 0;
    while (y < height) {
      x = 0;
      while (x < width) {
        isLabeled = getPixel32(labelMap, x, y, UNLABELED) != UNLABELED;
        if (isPixelSolid(x, y))
        {
          if (!isLabeled && !isPixelSolid(x, y - 1)) { // external contour
            //trace("external contour @ " + x + "," + y);
            setLabel(x, y, labelToColor(labelIndex));
            isLabeled = true;
            contourTrace(x, y, labelToColor(labelIndex), 7);
            labelIndex++;
          }
          if (!isPixelSolid(x, y + 1) && getPixel32(markedPixels, x, y + 1, MARKED) != MARKED) { // internal contour
            //trace("internal contour @ " + x + "," + y);
            if (!isLabeled) {
              leftLabeledPixel = getPixel32(labelMap, x - 1, y);
              setLabel(x, y, leftLabeledPixel);
              isLabeled = true;
            }
            contourTrace(x, y, getPixel32(labelMap, x, y), 3);
          }
          if (!isLabeled) // internal point not belonging to any contour
          {
            //trace("internal point @ " + x + "," + y);
            leftLabeledPixel = getPixel32(labelMap, x - 1, y);
            setLabel(x, y, leftLabeledPixel);
          }
        }
        x++;
      }
      y++;
    }
    
    numComponents = labelIndex;
    return labelMap;	
  }
  
  /**
   * Traces the contour starting at `x`, `y`.
   * 
   * @param	x			Starting x of the contour
   * @param	y			Starting y of the contour
   * @param	labelColor	Color to use
   * @param	dir			Initial tracing direction
   */
  private function contourTrace(x:Int, y:Int, labelColor:Int, dir:Int)
  {
    var startX:Int = x,
      startY:Int = y,
      poly:Poly = null,
      nextPointExists;
    
    if (traceContours) {
      poly = new Poly();
      poly.push(new HxPoint(x, y));
      contours.push(poly);
    }
    
    contourPoint.setTo(x, y);
    tracingDir = dir;
    //trace(x, y, StringTools.hex(getPixel32(sourcePixels(x, y)), "dir: " + tracingDir);
    var firstPoint = true;
    while (true) {
      nextPointExists = nextOnContour(x, y, contourPoint);
      if (firstPoint) {
        secondContourPoint.setTo(contourPoint.x, contourPoint.y);
        firstPoint = false;
      }
      if (nextPointExists) {
        tracingDir = (tracingDir + 6) % 8;	// update direction
        x = Std.int(contourPoint.x);
        y = Std.int(contourPoint.y);
        //trace(x, y, StringTools.hex(getPixel32(sourcePixels, x, y)), "dir: " + tracingDir);
        if (x == startX && y == startY) { // we're back to starting point
          nextOnContour(x, y, contourPoint);
          
          // break if next point is the same we found with the first call to nextOnContour
          // (which can actually be different based on tracing direction - f.e. in an x-shaped pattern)
          if (contourPoint.x == secondContourPoint.x && contourPoint.y == secondContourPoint.y) {
            break;
          }
        } else { // found next point on contour
          if (traceContours) {
            poly.push(contourPoint.clone());
          }
          setLabel(x, y, labelColor);
        }
      } else { // isolated pixel
        break;
      }
    }
  }
  
  /** Finds the next point on contour and stores it into `nextPoint` (returns false if no next point exists). */
  private function nextOnContour(x:Int, y:Int, nextPoint:HxPoint):Bool
  {
    var isolatedPixel = true,
      cx, cy,
      numSteps = 8,
      step = 1;
      
    // if we're in FOUR_CONNECTED mode then only even values of `tracingDir` are possible 
    // (i.e. no diagonals and we advance by two)
    if (connectivity == Connectivity.FOUR_CONNECTED) {
      if (tracingDir & 1 == 1) tracingDir = (tracingDir + 1) % 8;
      numSteps = 4;
      step = 2;
    }
    
    var dir = tracingDir;
    
    for (i in 0...numSteps) {
      cx = x + searchDir[tracingDir].dx;
      cy = y + searchDir[tracingDir].dy;
      nextPoint.setTo(cx, cy);
      if (isPixelSolid(cx, cy)) {
        isolatedPixel = false;
        break;
      } else { // set non-solid pixel as marked
        //trace("- " + cx + "," + cy);
        setPixel32(markedPixels, cx, cy, MARKED);
      }
      tracingDir = (tracingDir + step) % 8;
    }
    
    return !isolatedPixel;
  }
  
  /**
   * Maps `label` to a color. 
   * Override this to use your own label-to-color mapping.
   * 
   * NOTE: Avoid using 0x00000000 as a returned value, as it's used 
   * interally to identify unlabeled pixels.
   */
  public function labelToColor(label:Int):Int 
  {
    if (label >= colors.length) {
      colors[label] = 0xFF000000 | getColorFromHSV(hue, .9, 1);
      hue = (hue + .12) % 1.0;
    }
    return colors[label];
  }
  
  /**
   * Override this to have a way to add logic everytime a pixel is labeled.
   */
  private function setLabel(x:Int, y:Int, labelColor:Int):Void 
  {
    setPixel32(labelMap, x, y, labelColor);
  }
  
  /**
   * Returns the 32-bit pixel color at position (`x`, `y`) from `pixels`.
   * If the specified position is out of bounds, `outerValue` is returned.
   */
  private function getPixel32(pixels:Pixels, x:Int, y:Int, outerValue:Int = 0):Int 
  {
    var res = outerValue;
    if (!isOutOfBounds(x, y)) {
      res = pixels.getPixel32(x, y);
    }
    return res;
  }
  
  /**
   * Writes a 32-bit pixel `color` at position (`x`, `y`) in `pixels`.
   * If the specified position is out of bounds nothing is written.
   */
  private function setPixel32(pixels:Pixels, x:Int, y:Int, color:Int):Void
  {
    if (!isOutOfBounds(x, y)) {
      pixels.setPixel32(x, y, color);
      if (calcArea && pixels == labelMap) {
        var a:Null<Int> = areaMap.exists(color) ? areaMap.get(color) : 0;
        areaMap.set(color, a + 1);
      }
    }
  }

  /** 
   * Returns true if the pixel at `x`, `y` is opaque (according to `alphaThreshold`). 
   * Override this to use your own criteria to identify solid pixels.
   */
  private function isPixelSolid(x:Int, y:Int):Bool {
    return (!isOutOfBounds(x, y) && sourcePixels[(y * width + x) << 2] >= alphaThreshold);
  }
  
  inline private function isOutOfBounds(x:Int, y:Int):Bool {
    return (x < 0 || y < 0 || x >= width || y >= height);
  }
  
  private function getColorFromHSV(h:Float, s:Float, v:Float):Int
  {
    h = Std.int(h * 360);
    var hi:Int = Math.floor(h / 60) % 6,
      f:Float = h / 60 - Math.floor(h / 60),
      p:Float = (v * (1 - s)),
      q:Float = (v * (1 - f * s)),
      t:Float = (v * (1 - (1 - f) * s));
    switch (hi)
    {
      case 0: return Std.int(v * 255) << 16 | Std.int(t * 255) << 8 | Std.int(p * 255);
      case 1: return Std.int(q * 255) << 16 | Std.int(v * 255) << 8 | Std.int(p * 255);
      case 2: return Std.int(p * 255) << 16 | Std.int(v * 255) << 8 | Std.int(t * 255);
      case 3: return Std.int(p * 255) << 16 | Std.int(q * 255) << 8 | Std.int(v * 255);
      case 4: return Std.int(t * 255) << 16 | Std.int(p * 255) << 8 | Std.int(v * 255);
      case 5: return Std.int(v * 255) << 16 | Std.int(p * 255) << 8 | Std.int(q * 255);
      default: return 0;
    }
    return 0;
  }
}
