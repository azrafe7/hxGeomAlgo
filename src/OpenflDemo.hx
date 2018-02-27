package;

import flash.display.Sprite;
import flash.events.KeyboardEvent;
import flash.system.System;
import flash.display.BitmapData;


class OpenflDemo extends Sprite {
  
  static var assets:Array<String> = [
    "assets/pirate_small.png",
    "assets/super_mario.png",	// from http://www.newgrounds.com/art/view/petelavadigger/super-mario-pixel
    "assets/nazca_monkey.png",
    "assets/small_rect.png",
    "assets/star.png",
    "assets/text.png",
    "assets/transparent.png",
    "assets/opaque_black.png",
    "assets/complex.png",
    "assets/big.png",
    "assets/bord.png",
    "assets/line.png",
    "assets/opaque_white.png",
    "assets/py_figure.png",
    "assets/issue11.png",
    "assets/9x9_holed_square.png",
  ];
  
  static var currAssetIdx:Int = 0;
  static var asset:String;
  static var geomAlgoTest:GeomAlgoTest;
  
  static public function main():Void {
    new OpenflDemo();
  }
  
  public function new() {
    super();
    
    flash.Lib.current.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);

    asset = assets[currAssetIdx];
    geomAlgoTest = new GeomAlgoTest(asset);
    
    flash.Lib.current.addChild(geomAlgoTest);
  }
  
  public function onKeyDown(e:KeyboardEvent):Void 
  {
    if (e.keyCode == 27) {
      quit();
    }
    
    // zoom
    if (e.charCode == "+".code) {
      flash.Lib.current.scaleX *= 1.25;
      flash.Lib.current.scaleY *= 1.25;
    } else if (e.charCode == "-".code) {
      flash.Lib.current.scaleX *= .8;
      flash.Lib.current.scaleY *= .8;
    }	
    
    // screenshot
  #if sys
    if (e.charCode == "s".code) {
      var bounds = geomAlgoTest.getBounds(geomAlgoTest);
      var bmd = new BitmapData(Math.ceil(bounds.right), Math.ceil(bounds.bottom), true, 0);
      bmd.draw(geomAlgoTest);
      GeomAlgoTest.savePNG(bmd, "capture.png");
    }
  #end
    
    var deltaIdx = 0;
    var moveDelta = 12;
    var moveMult = e.shiftKey ? 4 : 1;
    
    moveDelta *= moveMult;
    
    // keys to move camera around and cycle through assets
    if (e.charCode == "j".code || e.charCode == "J".code || e.keyCode == 39) { // right
      geomAlgoTest.x -= moveDelta;
      if (e.ctrlKey) deltaIdx = 1;
    }
    if (e.charCode == "g".code || e.charCode == "G".code || e.keyCode == 37) { // left
      geomAlgoTest.x += moveDelta;
      if (e.ctrlKey) deltaIdx = -1;
    }
    if (e.charCode == "h".code || e.charCode == "H".code || e.keyCode == 40) geomAlgoTest.y -= moveDelta; // down
    if (e.charCode == "y".code || e.charCode == "Y".code || e.keyCode == 38) geomAlgoTest.y += moveDelta; // up
    
    if (e.charCode >= "0".code && e.charCode <= "9".code) {
      currAssetIdx = -1;
      deltaIdx = e.charCode - "0".code + 1;
    }
    
    if (deltaIdx != 0) {
      currAssetIdx = (currAssetIdx + deltaIdx + assets.length) % assets.length;
      
      asset = assets[currAssetIdx];
      flash.Lib.current.removeChild(geomAlgoTest);
      geomAlgoTest = new GeomAlgoTest(asset);
      flash.Lib.current.addChild(geomAlgoTest);
    }
  }

  static public function quit():Void 
  {
    #if (flash || html5)
      System.exit(1);
    #else
      Sys.exit(1);
    #end
  }
}