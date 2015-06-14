package hxGeomAlgo;

/**
 * @author azrafe7
 */
class Version
{
	inline public static var major:Int = 0;
	inline public static var minor:Int = 2;
	inline public static var patch:Int = 4;
	
	static public function toString():String 
	{
		return '$major.$minor.$patch';
	}
}