package hxGeomAlgo;

/**
 * @author azrafe7
 */
@:expose
class Version
{
  inline public static var major:Int = 0;
  inline public static var minor:Int = 4;
  inline public static var patch:Int = 0;

  static public function toString():String
  {
    return '$major.$minor.$patch';
  }
}