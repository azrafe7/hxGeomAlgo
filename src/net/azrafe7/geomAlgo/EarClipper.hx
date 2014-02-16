/**
 * Ear clipping implementation - concave to convex polygon decomposition (Counterclockwise).
 * NOTE: Should work only for SIMPLE polygons (not self-intersecting, without holes).
 * 
 * Adapted/modified from:
 * 
 * @see http://www.box2d.org/forum/viewtopic.php?f=8&t=463&start=0										(JSFL - by mayobutter)
 * @see http://www.ewjordan.com/earClip/																(Processing - by Eric Jordan)
 * @see http://blog.touchmypixel.com/2008/06/making-convex-polygons-from-concave-ones-ear-clipping/		(AS3 - by Tarwin Stroh-Spijer)
 * @see http://headsoft.com.au/																			(C# - by Ben Baker)
 * 
 * @author azrafe7
 */

package net.azrafe7.geomAlgo;

import flash.geom.Point;

class EarClipper
{

	/**
	 * Triangulates a polygon.
	 * 
	 * @param	v	Array of points defining the polygon.
	 * @return	An array of Triangle resulting from the triangulation.
	 */
	public static function triangulate(v:Array<Point>):Array<Triangle> 
	{
		if (v.length < 3)
			return null;

		var remList:Array<Point> = new Array<Point>().concat(v);
		
		var retList:Array<Triangle> = new Array<Triangle>();

		while (remList.length > 3)
		{
			var earIndex:Int = -1;

			for (i in 0...remList.length)
			{
				if (isEar(i, remList))
				{
					earIndex = i;
					break;
				}
			}

			if (earIndex == -1)
				return null;

			var newList:Array<Point> = new Array<Point>().concat(remList);

			newList.splice(earIndex, 1);

			var under:Int = (earIndex == 0 ? remList.length - 1 : earIndex - 1);
			var over:Int = (earIndex == remList.length - 1 ? 0 : earIndex + 1);

			retList.push(new Triangle(remList[earIndex], remList[over], remList[under]));

			remList = newList;
		}

		retList.push(new Triangle(remList[1], remList[2], remList[0]));

		return retList;
	}

	/**
	 * Merges triangles (defining a triangulated concave polygon) into a set of convex polygons.
	 * 
	 * @param	triangulation	An array of triangles defining the concave polygon.
	 * @return	An array of convex polygons being a decomposition of the original concave polygon.
	 */
	public static function polygonizeTriangles(triangulation:Array<Triangle>):Array<Polygon> 
	{
		var polys:Array<Polygon> = new Array<Polygon>();

		if (triangulation == null)
		{
			return null;
		}
		else
		{
			var covered:Array<Bool> = new Array<Bool>();
			for (i in 0...triangulation.length) covered[i] = false;

			var notDone:Bool = true;
			while (notDone)
			{
				var poly:Polygon = null;

				var currTri:Int = -1;
				for (i in 0...triangulation.length)
				{
					if (covered[i]) continue;
					currTri = i;
					break;
				}
				if (currTri == -1)
				{
					notDone = false;
				}
				else
				{
					poly = new Polygon(triangulation[currTri].points);
					covered[currTri] = true;
					for (i in 0...triangulation.length)
					{
						if (covered[i]) continue;
						var newP:Polygon = poly.addTriangle(triangulation[i]);
						if (newP == null) continue;
						if (newP.isConvex())
						{
							poly = newP;
							covered[i] = true;
						}
					}

					polys.push(poly);
				}
			}
		}

		return polys;
	}

	/** Checks if vertex `i` is the tip of an ear. */
	public static function isEar(i:Int, v:Array<Point>):Bool
	{
		var dx0 = 0., dy0 = 0., dx1 = 0., dy1 = 0.;

		if (i >= v.length || i < 0 || v.length < 3)
			return false;

		var upper:Int = i + 1;
		var lower:Int = i - 1;

		if (i == 0)
		{
			dx0 = v[0].x - v[v.length - 1].x;
			dy0 = v[0].y - v[v.length - 1].y;
			dx1 = v[1].x - v[0].x;
			dy1 = v[1].y - v[0].y;
			lower = v.length - 1;
		}
		else if (i == v.length - 1)
		{
			dx0 = v[i].x - v[i - 1].x;
			dy0 = v[i].y - v[i - 1].y;
			dx1 = v[0].x - v[i].x;
			dy1 = v[0].y - v[i].y;
			upper = 0;
		}
		else
		{
			dx0 = v[i].x - v[i - 1].x;
			dy0 = v[i].y - v[i - 1].y;
			dx1 = v[i + 1].x - v[i].x;
			dy1 = v[i + 1].y - v[i].y;
		}

		var cross:Float = (dx0 * dy1) - (dx1 * dy0);

		if (cross > 0) return false;

		var tri:Triangle = new Triangle(v[i], v[upper], v[lower]);

		for (j in 0...v.length)
		{
			if (!(j == i || j == lower || j == upper))
			{
				if (tri.isPointInside(v[j]))
					return false;
			}
		}
		
		return true;
	}
}


class Triangle
{
	public var points:Array<Point> = null;

	public function new(point1:Point, point2:Point, point3:Point)
	{
		var dx1:Float = point2.x - point1.x;
		var dx2:Float = point3.x - point1.x;
		var dy1:Float = point2.y - point1.y;
		var dy2:Float = point3.y - point1.y;
		var cross:Float = (dx1 * dy2) - (dx2 * dy1);

		var ccw:Bool = (cross > 0);

		points = new Array<Point>();

		if (ccw)
		{
			points.push(new Point(point1.x, point1.y));
			points.push(new Point(point2.x, point2.y));
			points.push(new Point(point3.x, point3.y));
		}
		else
		{
			points.push(new Point(point1.x, point1.y));
			points.push(new Point(point3.x, point3.y));
			points.push(new Point(point2.x, point2.y));
		}
	}

	/** Checks if `point` is inside the triangle. */
	public function isPointInside(point:Point):Bool
	{
		var vx2:Float = point.x - points[0].x;
		var vy2:Float = point.y - points[0].y;
		var vx1:Float = points[1].x - points[0].x;
		var vy1:Float = points[1].y - points[0].y;
		var vx0:Float = points[2].x - points[0].x;
		var vy0:Float = points[2].y - points[0].y;

		var dot00:Float = vx0 * vx0 + vy0 * vy0;
		var dot01:Float = vx0 * vx1 + vy0 * vy1;
		var dot02:Float = vx0 * vx2 + vy0 * vy2;
		var dot11:Float = vx1 * vx1 + vy1 * vy1;
		var dot12:Float = vx1 * vx2 + vy1 * vy2;
		var invDenom:Float = 1.0 / (dot00 * dot11 - dot01 * dot01);
		var u:Float = (dot11 * dot02 - dot01 * dot12) * invDenom;
		var v:Float = (dot00 * dot12 - dot01 * dot02) * invDenom;

		return ((u > 0) && (v > 0) && (u + v < 1));
	}
}


class Polygon
{
	public var points:Array<Point> = null;

	public function new(?points:Array<Point> = null)
	{
		this.points = points != null ? points : new Array<Point>();
	}

	/** Assuming the polygon is simple, checks if it is convex. */
	public function isConvex():Bool
	{
		var isPositive:Bool = false;

		for (i in 0...points.length)
		{
			var lower:Int = (i == 0 ? points.length - 1 : i - 1);
			var middle:Int = i;
			var upper:Int = (i == points.length - 1 ? 0 : i + 1);
			var dx0:Float = points[middle].x - points[lower].x;
			var dy0:Float = points[middle].y - points[lower].y;
			var dx1:Float = points[upper].x - points[middle].x;
			var dy1:Float = points[upper].y - points[middle].y;
			var cross:Float = dx0 * dy1 - dx1 * dy0;
			
			// cross product should have same sign
			// for each vertex if poly is convex.
			var newIsP:Bool = (cross > 0 ? true : false);

			if (i == 0)
				isPositive = newIsP;
			else if (isPositive != newIsP)
				return false;
		}

		return true;
	}

	/** 
	 * Tries to add a triangle to the polygon.
	 * Assumes bitwise equality of join vertices.
	 * 
	 * @return null if it can't connect properly.
	 */
	public function addTriangle(t:Triangle):Polygon
	{
		// first, find vertices that connect
		var firstP:Int = -1;
		var firstT:Int = -1;
		var secondP:Int = -1;
		var secondT:Int = -1;

		for (i in 0...points.length)
		{
			if (t.points[0].x == this.points[i].x && t.points[0].y == this.points[i].y)
			{
				if (firstP == -1)
				{
					firstP = i; firstT = 0;
				}
				else
				{
					secondP = i; secondT = 0;
				}
			}
			else if (t.points[1].x == this.points[i].x && t.points[1].y == this.points[i].y)
			{
				if (firstP == -1)
				{
					firstP = i; firstT = 1;
				}
				else
				{
					secondP = i; secondT = 1;
				}
			}
			else if (t.points[2].x == this.points[i].x && t.points[2].y == this.points[i].y)
			{
				if (firstP == -1)
				{
					firstP = i; firstT = 2;
				}
				else
				{
					secondP = i; secondT = 2;
				}
			}
			else
			{
				//println(t.PointList[0].X+" "+t.PointList[0].y+" "+t.PointList[1].X+" "+t.PointList[1].y+" "+t.PointList[2].X+" "+t.PointList[2].y);
				//println(x[0]+" "+y[0]+" "+x[1]+" "+y[1]);
			}
		}

		// fix ordering if first should be last vertex of poly
		if (firstP == 0 && secondP == points.length - 1)
		{
			firstP = points.length - 1;
			secondP = 0;
		}

		// didn't find it
		if (secondP == -1)
			return null;

		// find tip index on triangle
		var tipT:Int = 0;
		if (tipT == firstT || tipT == secondT) tipT = 1;
		if (tipT == firstT || tipT == secondT) tipT = 2;

		var newPoints:Array<Point> = new Array<Point>();

		for (i in 0...points.length)
		{
			newPoints.push(points[i]);

			if (i == firstP)
				newPoints.push(t.points[tipT]);
		}

		return new Polygon(newPoints);
	}
}
