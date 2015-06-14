package hxGeomAlgo;

/**
 * Minimal Point class (auto-converting to/from flash.geom.Point and {x:Float, y:Float}).
 * 
 * @author azrafe7
 */
abstract HxPoint(HxPointData) from HxPointData to HxPointData
{
	public var x(get, set):Float;
	inline private function get_x():Float { return this.x; }
	inline private function set_x(value:Float):Float { return this.x = value; }
	
	public var y(get, set):Float;
	inline private function get_y():Float { return this.y; }
	inline private function set_y(value:Float):Float { return this.y = value; }

	public function new(x:Float=0, y:Float=0) 
	{
		this = new HxPointData(x, y);
	}
	
	public function setTo(newX:Float, newY:Float):Void 
	{
		x = newX;
		y = newY;
	}
	
	@:op(A == B) inline public function equals(p:HxPoint):Bool
	{
		return areEqual(this, p);
	}
	
	@:op(A != B) inline public function notEequals(p:HxPoint):Bool
	{
		return areNotEqual(this, p);
	}
	
	inline public function clone():HxPoint
	{
		return new HxPoint(x, y);
	}
	
	inline public function toString()
	{
		return '(${x}, ${y})';
	}
	
#if (flash || openfl)
	@:from inline static function fromFlashPoint(p:flash.geom.Point)
	{
		return new HxPoint(p.x, p.y);
	}
	
	@:to inline function toFlashPoint()
	{
		return new flash.geom.Point(x, y);
	}
#end

	@:from inline static function fromPointStruct(p:{x:Float, y:Float})
	{
		return new HxPoint(p.x, p.y);
	}
	
	@:to inline function toPointStruct()
	{
		return { x:x, y:y };
	}
	
	inline static public function areEqual(p:HxPoint, q:HxPoint):Bool
	{
		return (p != null && q != null && q.x == p.x && q.y == p.y);
	}	
	
	inline static public function areNotEqual(p:HxPoint, q:HxPoint):Bool
	{
		return !areEqual(p, q);
	}	
}


class HxPointData
{
	public var x:Float;
	public var y:Float;
	
	inline public function new(x:Float=0, y:Float=0)
	{
		this.x = x;
		this.y = y;
	}	
}