package;

import flash.display.Sprite;
import flash.events.Event;
import flash.events.KeyboardEvent;
import flash.events.MouseEvent;
import flash.system.System;
import flash.display.BitmapData;
import flash.text.TextField;
import hxGeomAlgo.HxPoint;
import hxGeomAlgo.PoleOfInaccessibility;

import hxGeomAlgo.PolyTools.Poly;

import DrawUtils.*;

using hxGeomAlgo.PolyTools;


typedef PolyState = {
  var poly:Poly;
  @:optional var color:Int;
}


class Test extends Sprite {
  
  var color:Int;
  var poly:Poly = [];
  
  var polys:Array<PolyState> = [];
  var resPolys:Array<PolyState> = [];
  
  var closed:Bool = false;
  var justClosed:Bool = false;
  
  var readyToCalc:Bool = false;
  var processed:Bool = false;
  
  var mouse:HxPoint = new HxPoint();
  
  var info:TextField;
  var infoText:String;
  
  var overlaySprite:Sprite;
  
  static public function main():Void {
    flash.Lib.current.addChild(new Test());
  }
  
  public function new() {
    super();
    
    flash.Lib.current.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
    flash.Lib.current.stage.addEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
    flash.Lib.current.stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
    flash.Lib.current.stage.addEventListener(Event.ENTER_FRAME, onEnterFrame);
    
    DrawUtils.init(this);
    
    addChild(overlaySprite = new Sprite());
    addChild(info = getTextField("xxxx", 20, 20));
    //drawCircle(new HxPoint(20, 20), 0, 0, 30);
  }
  
  public function reset():Void {
    poly = [];
    polys = [];
    resPolys = [];
    closed = justClosed = false;
    readyToCalc = false;
    processed = false;
  }
  
  
  public function onEnterFrame(e):Void {
    graphics.clear();
    
    // set color for curr poly
    color = COLOR >> (8 * polys.length);
    graphics.lineStyle(THICKNESS, color, ALPHA);

    info.text = 'Mouse: ${mouse.x}, ${mouse.y} (resPolys: ${resPolys.length})';
    
    // curr poly
    drawPoly(poly, 0, 0, config( { showPoints:true, fill:justClosed, close:closed, color:color } ));
    
    // mouse segment
    if (!closed && poly.length > 0) {
      drawPoly([poly[poly.length - 1], mouse], 0, 0, config( { showPoints:true, fill:false, close:closed, color:color } ));
    }
    
    // push closed poly to polys
    if (justClosed) {
      polys.push( { poly:poly.concat([]), color:color } );
      poly = [];
      closed = justClosed = false;
    }
    
    // draw completed polys
    for (p in polys) {
      drawPoly(p.poly, 0, 0, config( { showPoints:true, fill:true, close:true, color:p.color } ));
    }
    
    readyToCalc = polys.length == 2;
    
    // process input
    if (readyToCalc && !processed) {
      resPolys = [];
      overlaySprite.removeChildren();
      
      var res = polys[0].poly.clip(polys[1].poly);
      
      for (i in 0...res.length) {
        resPolys.push( { poly:res[i], color:COLOR >> (8 * i) } );
        
        var pia = PoleOfInaccessibility.calculate([res[i]]);
        //overlaySprite.addChild(getTextField("" + i, pia.x, pia.y));
        overlaySprite.graphics.lineStyle(THICKNESS, COLOR >> (8 * i), 1);
        overlaySprite.graphics.drawCircle(pia.x, pia.y, 4);
      }
      
      trace(res.length);
      
      /*
      polys[1].poly.reverse();
      res = polys[0].poly.clip(polys[1].poly);
      
      resPolys.push({poly:res});
      */
      
      processed = true;
    }
    
    // draw processed polys
    for (i in 0...resPolys.length) {
      var p = resPolys[i];
      
      var labels = false;
      //if (i == resPolys.length - 1) labels = true;
      
      drawPoly(p.poly, 300, 0, config( { showPoints:true, fill:true, close:true, color:p.color, showLabels:labels } ));
      overlaySprite.x = 300;
    }
    
  }
  
  public function onMouseMove(e:MouseEvent):Void {
    mouse.x = e.stageX;
    mouse.y = e.stageY;
  }
  
  public function onMouseDown(e:MouseEvent):Void {
    poly.push(mouse.clone());
  }
  
  public function onKeyDown(e:KeyboardEvent):Void 
  {
    if (e.keyCode == 27) {
      quit();
    }
    
    // remove last poly
    if (e.charCode == "1".code) {
      polys.pop();
      processed = false;
    }
    
    // close
    if (e.charCode == " ".code) {
      if (poly.length > 1) {
        closed = justClosed = true;
      }
    }
    
    // reset
    if (e.charCode == "r".code) {
      reset();
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
      var bounds = getBounds(geomAlgoTest);
      var bmd = new BitmapData(Math.ceil(bounds.right), Math.ceil(bounds.bottom), true, 0);
      bmd.draw(this);
      DrawUtils.savePNG(bmd, "capture.png");
    }
  #end
    
    var deltaIdx = 0;
    var moveDelta = 12;
    var moveMult = e.shiftKey ? 4 : 1;
    
    moveDelta *= moveMult;
    
    // keys to move camera around and cycle through assets
    if (e.charCode == "j".code || e.charCode == "J".code || e.keyCode == 39) { // right
      this.x -= moveDelta;
      if (e.ctrlKey) deltaIdx = 1;
    }
    if (e.charCode == "g".code || e.charCode == "G".code || e.keyCode == 37) { // left
      this.x += moveDelta;
      if (e.ctrlKey) deltaIdx = -1;
    }
    if (e.charCode == "h".code || e.charCode == "H".code || e.keyCode == 40) this.y -= moveDelta; // down
    if (e.charCode == "y".code || e.charCode == "Y".code || e.keyCode == 38) this.y += moveDelta; // up
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