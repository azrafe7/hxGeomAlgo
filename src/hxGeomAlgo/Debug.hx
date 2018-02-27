package hxGeomAlgo;

import haxe.PosInfos;


/**
 * @author azrafe7
 */
class Debug
{
  /**
   * Used for sanity-checks throughout the code when in debug mode (or if -D GEOM_CHECKS is passed to the compiler).
   * Should be automatically stripped out by the compiler in release mode (or if -D NO_GEOM_CHECKS is passed to the compiler).
   */
#if ((debug && !NO_GEOM_CHECKS) || GEOM_CHECKS)
  static public function assert(cond:Bool, ?message:String, ?pos:PosInfos) {
    if (!cond) {
      throw pos.fileName + ":" + pos.lineNumber + ": ASSERT FAILED! " + (message != null ? message : "");
    }
  }
#elseif (!debug || NO_GEOM_CHECKS)
  inline static public function assert(cond:Bool, ?message:String, ?pos:PosInfos) {
    return;
  }
#end
}