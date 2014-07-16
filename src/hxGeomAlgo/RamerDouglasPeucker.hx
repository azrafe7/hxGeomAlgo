/*
 * Copyright (C) Giuseppe Di Mauro (azrafe7) 2013-2014.
 *
 * This file is part of hxGeomAlgo (https://github.com/azrafe7/hxGeomAlgo). 
 * hxGeomAlgo is licensed under the MIT license (http://opensource.org/licenses/MIT) and built upon the work of many developers. 
 * See CREDITS.MD and LICENSE.MD files for more details.
 */

/**
 * Ramer-Douglas-Peucker implementation.
 * 
 * Based on:
 * 
 * @see http://karthaus.nl/rdp/																				(JS - by Marius Karthaus)
 * @see http://stackoverflow.com/questions/849211/shortest-distance-between-a-point-and-a-line-segment		(JS - Grumdrig)
 * 
 * @author azrafe7
 */

package hxGeomAlgo;

import flash.geom.Point;
import hxGeomAlgo.PolyTools;

class RamerDouglasPeucker
{
	/**
	 * Simplify polyline.
	 * 
	 * @param	points		Array of points defining the polyline.
	 * @param	epsilon		Perpendicular distance threshold (typically in the range [1..2]).
	 * @return	An array of points defining the simplified polyline.
	 */
	static public function simplify(points:Array<Point>, epsilon:Float = 1):Array<Point> 
	{
		var firstPoint = points[0];
		var lastPoint = points[points.length - 1];
		
		if (points.length < 3) {
			return points;
		}
		
		var index = -1;
		var dist = 0.;
		for (i in 1...points.length - 1) {
			var currDist = PolyTools.distanceToSegment(points[i], firstPoint, lastPoint);
			if (currDist > dist) {
				dist = currDist;
				index = i;
			}
		}
		
		if (dist > epsilon){
			// recurse
			var l1 = points.slice(0, index + 1);
			var l2 = points.slice(index);
			var r1 = simplify(l1, epsilon);
			var r2 = simplify(l2, epsilon);
			// concat r2 to r1 minus the end/startpoint that will be the same
			var rs = r1.slice(0, r1.length - 1).concat(r2);
			return rs;
		} else {
			return [firstPoint, lastPoint];
		}
	}
}