//https://github.com/mapbox/polylabel/commit/220414f77caebec46d62d5a41301571bf2f85b90
/**
 * Ear clipping implementation - polygon triangulation and triangles polygonization.
 * NOTE: Should work only for non self-intersecting polygons (but holes are supported).
 * 
 * Based on:
 * 
 * @see https://github.com/mapbox/earcut																(JS - by Vladimir Agafonkin)
 * @see http://www.ewjordan.com/earClip/																(Java - by Eric Jordan)
 * 
 * @author azrafe7
 */

package hxGeomAlgo;


import haxe.ds.ArraySort;
import hxGeomAlgo.PolyTools;


@:expose
class PoleOfInaccessibility
{
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
		var cells = [];

		// cover polygon with initial cells
		var x = minX;
		var y = minY;
		while (x < maxX) {
			y = minY;
			while (y < maxY) {
				cells.push(new Cell(x + h, y + h));
				y += cellSize;
			}
			x += cellSize;
		}

		// take centroid as the first best guess
		var bestCell = getCentroidCell(poly[0]);
		bestCell.d = pointToPolygonDist(bestCell.x, bestCell.y, poly);

		var error = h * Math.sqrt(2);
		var numProbes = 0;

		while (true) {
			numProbes += cells.length;

			// calculate cell distances, keeping track of global max distance
			for (i in 0...cells.length) {
				var cell = cells[i];
				cell.d = pointToPolygonDist(cell.x, cell.y, poly);

				if (cell.d > bestCell.d) {
					bestCell = cell;
				}
			}

			if (debug) trace('cells processed: ${cells.length}, best so far ${bestCell.d}, error ${error}');

			if (error <= precision) break;

			h /= 2;

			var childCells = [];
			for (i in 0...cells.length) {
				var cell = cells[i];
				if (cell.d + error <= bestCell.d) continue;

				// if a cell potentially contains a better solution than the current best, subdivide
				childCells.push(new Cell(cell.x - h, cell.y - h));
				childCells.push(new Cell(cell.x + h, cell.y - h));
				childCells.push(new Cell(cell.x - h, cell.y + h));
				childCells.push(new Cell(cell.x + h, cell.y + h));
			}

			cells = childCells;
			error /= 2;
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
	static public function getCentroidCell(points:Poly):Cell {
		var area = 0.0;
		var x = 0.0;
		var y = 0.0;

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
		return new Cell(x / area, y / area);
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


class Cell {
	
	public var x:Float;
	public var y:Float;
	public var d:Null<Float>;


	public function new(x:Float, y:Float) {
		this.x = x;
		this.y = y;
		this.d = null;
	}
}
