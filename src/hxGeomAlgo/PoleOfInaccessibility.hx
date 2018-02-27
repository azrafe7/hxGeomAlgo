/**
 * An algorithm for finding polygon pole of inaccessibility, the most distant internal point from
 * the polygon outline (not to be confused with centroid).
 * 
 * Based on:
 * 
 * @see https://github.com/mapbox/polylabel/commit/64fe157												(JS - by Vladimir Agafonkin)
 * 
 * @author azrafe7
 */

package hxGeomAlgo;


import haxe.ds.ArraySort;
import hxGeomAlgo.Heap.Heapable;
import hxGeomAlgo.PolyTools;


@:expose
class PoleOfInaccessibility
{
  static var SQRT2:Float;
  static function __init__():Void {
    SQRT2 = Math.sqrt(2.0);
  }
  
  static public function calculate(poly:Array<Poly>, precision:Float = 1.0, debug:Bool = false):HxPoint {
    if (poly == null || poly.length <= 0) return HxPoint.EMPTY;
    
    var minX = Math.POSITIVE_INFINITY;
    var minY = Math.POSITIVE_INFINITY;
    var maxX = Math.NEGATIVE_INFINITY;
    var maxY = Math.NEGATIVE_INFINITY;

    // find the bounding box
    for (ring in poly) {
      for (p in ring) {
        if (p.x < minX) minX = p.x;
        if (p.y < minY) minY = p.y;
        if (p.x > maxX) maxX = p.x;
        if (p.y > maxY) maxY = p.y;
      }
    }

    var width = maxX - minX;
    var height = maxY - minY;
    var cellSize = Math.min(width, height);
    var h = cellSize / 2;
    
    
    // a priority queue of cells in order of their "potential" (max distance to polygon)
    var cellQueue = new Heap<Cell>();
    
    if (cellSize == 0.0) return new HxPoint(minX, minY);
    
    // cover polygon with initial cells
    var x = minX;
    var y = minY;
    while (x < maxX) {
      y = minY;
      while (y < maxY) {
        cellQueue.push(new Cell(x + h, y + h, h, poly));
        y += cellSize;
      }
      x += cellSize;
    }

    // take centroid as the first best guess
    var bestCell = getCentroidCell(poly);
    
    // special case for rectangular polygons
    var bboxCell = new Cell(minX + width / 2, minY + height / 2, 0, poly);
    if (bboxCell.d > bestCell.d) bestCell = bboxCell;

    var numProbes = cellQueue.length;

    while (cellQueue.length > 0) {
      // pick the most promising cell from the queue
      var cell = cellQueue.pop();

      // update the best cell if we found a better one
      if (cell.d > bestCell.d) {
        bestCell = cell;
        if (debug) trace('found best ${Math.round(1e4 * cell.d) / 1e4} after ${numProbes} probes');
      }

      // do not drill down further if there's no chance of a better solution
      if (cell.max - bestCell.d <= precision) continue;

      // split the cell into four cells
      h = cell.h / 2;
      cellQueue.push(new Cell(cell.x - h, cell.y - h, h, poly));
      cellQueue.push(new Cell(cell.x + h, cell.y - h, h, poly));
      cellQueue.push(new Cell(cell.x - h, cell.y + h, h, poly));
      cellQueue.push(new Cell(cell.x + h, cell.y + h, h, poly));
      numProbes += 4;
    }

    if (debug) {
      trace('num probes: ' + numProbes);
      trace('best distance: ' + bestCell.d);
    }

    return new HxPoint(bestCell.x, bestCell.y);
  }

  /** Signed distance from point to polygon outline (negative if point is outside) */
  static public function pointToPolygonDist(x:Float, y:Float, poly:Array<Poly>):Float {
    var inside = false;
    var minDistSq = Math.POSITIVE_INFINITY;

    for (k in 0...poly.length) {
      var ring = poly[k];

      var i = 0;
      var len = ring.length;
      var j = len - 1;
      //for (var i = 0, len = ring.length, j = len - 1; i < len; j = i++) {
      while (i < len) {
        var a = ring[i];
        var b = ring[j];

        if (((a.y > y) != (b.y > y)) &&
          (x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x)) inside = !inside;

        minDistSq = Math.min(minDistSq, getSegDistSq(x, y, a, b));
        j = i++;
      }
    }

    return (inside ? 1 : -1) * Math.sqrt(minDistSq);
  }

  /** Get polygon centroid */
  static public function getCentroidCell(poly:Array<Poly>):Cell {
    var area = 0.0;
    var x = 0.0;
    var y = 0.0;
    var points = poly[0];

    var i = 0;
    var len = points.length;
    var j = len - 1;
    //for (var i = 0, len = points.length, j = len - 1; i < len; j = i++) {
    while (i < len) {
      var a = points[i];
      var b = points[j];
      var f = a.x * b.y - b.x * a.y;
      x += (a.x + b.x) * f;
      y += (a.y + b.y) * f;
      area += f * 3;
      i++;
    }
    
    if (area == 0.0) return new Cell(points[0].x, points[0].y, 0, poly);
    return new Cell(x / area, y / area, 0, poly);
  }

  /** Get squared distance from a point to a segment */
  static public function getSegDistSq(px:Float, py:Float, a:HxPoint, b:HxPoint):Float {

    var x = a.x;
    var y = a.y;
    var dx = b.x - x;
    var dy = b.y - y;

    if (dx != 0 || dy != 0) {

      var t = ((px - x) * dx + (py - y) * dy) / (dx * dx + dy * dy);

      if (t > 1) {
        x = b.x;
        y = b.y;

      } else if (t > 0) {
        x += dx * t;
        y += dy * t;
      }
    }

    dx = px - x;
    dy = py - y;

    return dx * dx + dy * dy;
  }
}


@:access(hxGeomAlgo.PoleOfInaccessibility)
private class Cell implements Heapable<Cell>
{
  public var position:Int;
  
  public var x:Float;			// cell center x
  public var y:Float;			// cell center y
  public var h:Float;			// half cell size
  public var d:Null<Float>;	// distance from cell center to polygon
  public var max:Float;		// max distance to polygon within a cell


  public function new(x:Float, y:Float, h:Float, polygon:Array<Poly>) {
    this.x = x;
    this.y = y;
    this.h = h;
    this.d = PoleOfInaccessibility.pointToPolygonDist(x, y, polygon);
    this.max = this.d + this.h * PoleOfInaccessibility.SQRT2;
  }
  
  // compare max
    public function compare(other:Cell):Int {
        var diff = other.max - max;
    return diff < 0 ? -1 : diff > 0 ? 1 : 0;
    }
}
