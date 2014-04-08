package net.azrafe7.geomAlgo;

import flash.geom.Point;

/**
 * ...
 * @author azrafe7
 */
class HomogCoord
{
	public static var INFINITY:HomogCoord = new HomogCoord();
	
	public var x:Float;
	public var y:Float;
	public var w:Float;

	public function new(x:Float = 0, y:Float = 0, w:Float = 1) {
		this.x = x;
		this.y = y;
		this.w = w;
	}
	
	
	public function add(p:HomogCoord):HomogCoord { x += p.x; y += p.y; return this; }
	
	public function sub(p:HomogCoord):HomogCoord { x -= p.x; y -= p.y; return this; }
	
	public function neg():HomogCoord { w = -w; x = -x; y = -y; return this; }
	
	public function mul(m:Float):HomogCoord { w *= m; x *= m; y *= m; return this; }
	
	public function div(m:Float):HomogCoord { w /= m; x /= m; y /= m; return this; }
	
	public function normalize() { return div(length()); }
	
	public function lengthSquared() { return x * x + y * y; }
	
	public function length() { return Math.sqrt(this.lengthSquared()); }

	public function perp():HomogCoord { var tmp:Float = -y; y = x; x = tmp; return this; }
	
	public function dot(p:Point) { return w + x * p.x + y * p.y;}
	
	//public function dot(p:HomogCoord) { return w * p.w + x * p.x + y * p.y; }
	
	public function perpdot(p:HomogCoord) { return x * p.y - y * p.x; }
	
	public function dotperp(p:HomogCoord) { return - x * p.y + y * p.x; }
	
	public function equals(p:HomogCoord) { return (p.w * x == w * p.x) && (p.w * y == w * p.y); }
	
	public function left(p:Point) { return dot(p) > 0; }
	
	public function right(p:Point) { return dot(p) < 0; }

	static public function det(p:HomogCoord, q:HomogCoord, r:HomogCoord) { 
		return p.w * q.perpdot(r) - q.w * p.perpdot(r) + r.w * p.perpdot(q);
	}
	
	static public function ccw(p:HomogCoord, q:HomogCoord, r:HomogCoord) { 
		return det(p, q, r) > 0; 
	}
	
	static public function cw(p:HomogCoord, q:HomogCoord, r:HomogCoord) { 
		return det(p, q, r) < 0; 
	}

	/*
	public java.awt.Point toScreen() { 
		return new java.awt.Point((int) (x/w), (int) (-y/w));
	}
	*/
	public function toPoint():Point { return new Point(x/w, y/w); }
	
	public function meet(p:HomogCoord):HomogCoord {
		return new HomogCoord(p.w * y - w * p.y, w * p.x - p.w * x, x * p.y - y * p.x);
	}
	
	public function meetPoint(p:Point):HomogCoord {
		return new HomogCoord(y - w * p.y, w * p.x - x, x * p.y - y * p.x);
	}
		
	public function toString() { 
		return " (w:" + w + "; x:" + x + ", y:" + y + ")  ";
	}
}