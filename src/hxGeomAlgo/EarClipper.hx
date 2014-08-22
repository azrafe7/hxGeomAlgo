/**
 * Ear clipping implementation - concave to convex polygon decomposition (Counterclockwise).
 * NOTE: Should work only for SIMPLE polygons (not self-intersecting, without holes).
 * 
 * Based on:
 * 
 * @see http://www.box2d.org/forum/viewtopic.php?f=8&t=463&start=0										(JSFL - by mayobutter)
 * @see http://www.ewjordan.com/earClip/																(Processing - by Eric Jordan)
 * @see http://en.nicoptere.net/?p=16																	(AS3 - by Nicolas Barradeau)
 * @see http://blog.touchmypixel.com/2008/06/making-convex-polygons-from-concave-ones-ear-clipping/		(AS3 - by Tarwin Stroh-Spijer)
 * @see http://headsoft.com.au/																			(C# - by Ben Baker)
 * 
 * @author azrafe7
 */

package hxGeomAlgo;


import hxGeomAlgo.PolyTools;


typedef Tri = Poly;	// assumes Array<HxPoint> of length 3


class EarClipper
{
	
	/** 
	 * Decomposes `poly` into a number of convex polygons 
	 * (by first triangulating and then polygonizing it). 
	 */
	static public function decomposePoly(poly:Poly):Array<Poly> {
		
		var tris:Array<Tri> = triangulate(poly);
		
		return polygonizeTriangles(tris);
	}
	
	/**
	 * Triangulates a polygon.
	 * 
	 * @param	v	Array of points defining the polygon.
	 * @return	An array of Triangle resulting from the triangulation.
	 */
	public static function triangulate(v:Poly):Array<Tri> 
	{
		if (v.length < 3)
			return [];

		var remList:Array<HxPoint> = new Array<HxPoint>().concat(v);
		
		var resultList:Array<Tri> = new Array<Tri>();

		while (remList.length > 3)
		{
			var earIndex:Int = -1;

			for (i in 0...remList.length)
			{
				if (isEar(remList, i))
				{
					earIndex = i;
					break;
				}
			}

			if (earIndex == -1)
				return [];

			var newList:Array<HxPoint> = new Array<HxPoint>().concat(remList);

			newList.splice(earIndex, 1);

			var under:Int = (earIndex == 0 ? remList.length - 1 : earIndex - 1);
			var over:Int = (earIndex == remList.length - 1 ? 0 : earIndex + 1);

			resultList.push(createCCWTri(remList[earIndex], remList[over], remList[under]));

			remList = newList;
		}

		resultList.push(createCCWTri(remList[1], remList[2], remList[0]));

		return resultList;
	}

	/**
	 * Merges triangles (defining a triangulated concave polygon) into a set of convex polygons.
	 * 
	 * @param	triangulation	An array of triangles defining the concave polygon.
	 * @return	An array of convex polygons being a decomposition of the original concave polygon.
	 */
	public static function polygonizeTriangles(triangulation:Array<Tri>):Array<Poly> 
	{
		var polys = new Array<Poly>();

		if (triangulation.length == 0)
		{
			return [];
		}
		else
		{
			var covered = new Array<Bool>();
			for (i in 0...triangulation.length) covered[i] = false;

			var notDone:Bool = true;
			while (notDone)
			{
				var poly:Poly = null;

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
					poly = triangulation[currTri];
					covered[currTri] = true;
					for (i in 0...triangulation.length)
					{
						if (covered[i]) continue;
						var newPoly:Poly = addTriangle(poly, triangulation[i]);
						if (newPoly == null) continue;
						if (PolyTools.isConvex(newPoly))
						{
							poly = newPoly;
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
	private static function isEar(v:Poly, i:Int):Bool
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

		var tri:Tri = createCCWTri(v[i], v[upper], v[lower]);

		for (j in 0...v.length)
		{
			if (!(j == i || j == lower || j == upper))
			{
				if (isPointInsideTri(v[j], tri))
					return false;
			}
		}
		
		return true;
	}
	
	/** Checks if `point` is inside the triangle. */
	static public function isPointInsideTri(point:HxPoint, tri:Tri):Bool
	{
		var vx2:Float = point.x - tri[0].x;
		var vy2:Float = point.y - tri[0].y;
		var vx1:Float = tri[1].x - tri[0].x;
		var vy1:Float = tri[1].y - tri[0].y;
		var vx0:Float = tri[2].x - tri[0].x;
		var vy0:Float = tri[2].y - tri[0].y;

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
	
	static public function createCCWTri(point1:HxPoint, point2:HxPoint, point3:HxPoint):Tri
	{
		var points:Tri = [point1, point2, point3];
		PolyTools.makeCCW(points);
		return points;
	}
	
	/** 
	 * Tries to add a triangle to the polygon.
	 * Assumes bitwise equality of join vertices.
	 * 
	 * @return null if it can't connect properly.
	 */
	static public function addTriangle(poly:Poly, t:Tri):Poly
	{
		// first, find vertices that connect
		var firstP:Int = -1;
		var firstT:Int = -1;
		var secondP:Int = -1;
		var secondT:Int = -1;

		for (i in 0...poly.length)
		{
			if (t[0].x == poly[i].x && t[0].y == poly[i].y)
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
			else if (t[1].x == poly[i].x && t[1].y == poly[i].y)
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
			else if (t[2].x == poly[i].x && t[2].y == poly[i].y)
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
				//trace(t);
				//trace(firstP, firstT, secondP, secondT);
			}
		}

		// fix ordering if first should be last vertex of poly
		if (firstP == 0 && secondP == poly.length - 1)
		{
			firstP = poly.length - 1;
			secondP = 0;
		}

		// didn't find it
		if (secondP == -1)
			return null;

		// find tip index on triangle
		var tipT:Int = 0;
		if (tipT == firstT || tipT == secondT) tipT = 1;
		if (tipT == firstT || tipT == secondT) tipT = 2;

		var newPoints:Array<HxPoint> = new Array<HxPoint>();

		for (i in 0...poly.length)
		{
			newPoints.push(poly[i]);

			if (i == firstP)
				newPoints.push(t[tipT]);
		}

		return newPoints;
	}
}