package;

import flash.display.BitmapData;
import flash.display.Graphics;
import flash.display.PNGEncoderOptions;
import flash.display.Sprite;
import flash.filters.GlowFilter;
import flash.text.TextField;
import flash.text.TextFieldAutoSize;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import flash.utils.ByteArray;

import hxGeomAlgo.Bayazit;
import hxGeomAlgo.HxPoint;
import hxGeomAlgo.PoleOfInaccessibility;
import hxGeomAlgo.PolyTools;
import hxGeomAlgo.PolyTools.Poly;

#if (sys)
import sys.io.File;
import sys.io.FileOutput;
#end


typedef DrawSettings = {
  @:optional var showPoints:Bool;
  @:optional var showLabels:Bool;
  @:optional var showCentroids:Bool;
  @:optional var showSteinerPoints:Bool;
  @:optional var showReflexPoints:Bool;
  @:optional var showArrows:Bool;
  @:optional var showPIA:Bool;
  @:optional var fill:Bool;
  @:optional var close:Bool;
  @:optional var color:Int;
}

class DrawUtils {

  static var sprite:Sprite = null;
  static var g:Graphics = null;
  
  static public var THICKNESS:Float = .5;
  static public var COLOR:Int = 0xFF0000;
  static var CENTROID_COLOR:Int = 0x00FF00;
  static public var ALPHA:Float = 1.;

  static var TEXT_COLOR:Int = 0xFFFFFF;
  static var TEXT_FONT:String = "_typewriter";
  static var TEXT_SIZE:Int = 12;
  static var TEXT_OFFSET:Float = 0;
  static var TEXT_OUTLINE:GlowFilter = new GlowFilter(0xFF000000, 1, 2, 2, 6);

  static public var DEFAULT_DRAW_SETTINGS:DrawSettings = {
    showPoints: false,
    showLabels: false,
    showCentroids: false,
    showSteinerPoints: true,
    showReflexPoints: false,
    showArrows: false,
    showPIA: false,
    fill: true,
    close: true,
  };
  
  
  static public function init(sprite:Sprite):Void {
    DrawUtils.sprite = sprite;
    DrawUtils.g = sprite.graphics;
    DrawUtils.g.lineStyle(THICKNESS, COLOR, ALPHA);
  }
  
  static public function config(extra:DrawSettings):DrawSettings {
    var newSettings:DrawSettings = {};
    for (f in Reflect.fields(DEFAULT_DRAW_SETTINGS)) {
      Reflect.setField(newSettings, f, Reflect.field(DEFAULT_DRAW_SETTINGS, f));
    }
    for (f in Reflect.fields(extra)) {
      Reflect.setField(newSettings, f, Reflect.field(extra, f));
    }
    return newSettings;
  }
  
  static public function testOrientation(polys:Array<Poly>):String {
    var res = "none";
    
    for (i in 0...polys.length) {
      var poly = polys[i];
      var orientation = PolyTools.isCCW(poly) ? "CCW" : " CW";
      
      if (i == 0) {
        res = orientation;
      } else if (res != orientation) {
        res = "mixed";
        break;
      }
    }
    
    return res;
  }
  
  static public function testConvex(polys:Array<Poly>):String {
    var res = "none";
    
    for (i in 0...polys.length) {
      var poly = polys[i];
      var convex = PolyTools.isConvex(poly) ? "convex" : "not convex";
      
      if (i == 0) {
        res = convex;
      } else if (res != convex) {
        res = "mixed";
        break;
      }
    }
    
    return res;
  }
  
  static public function testSimple(polys:Array<Poly>):String {
    var res = "none";
    
    for (i in 0...polys.length) {
      var poly = polys[i];
      var convex = PolyTools.isSimple(poly) ? "simple" : "not simple";
      
      if (i == 0) {
        res = convex;
      } else if (res != convex) {
        res = "mixed";
        break;
      }
    }
    
    return res;
  }
  
  static public function savePNG(bmd:BitmapData, fileName:String) {
  #if (sys)
    var ba:ByteArray = bmd.encode(bmd.rect, new PNGEncoderOptions());
    var file:FileOutput = sys.io.File.write(fileName, true);
    file.writeString(ba.toString());
    file.close();
    trace('BitmapData saved as "${fileName}".');
  #end
  }
  
  static public function dumpPoly(poly:Array<HxPoint>, reverse:Bool = false):Void {
    var len = poly.length;
    var str = "poly dump: ";
    for (i in 0...len) {
      var p = poly[reverse ? len - i - 1 : i];
      str += p.x + "," + p.y + ",";
    }
    trace(str);
  }

  static public function drawPoints(points:Array<HxPoint>, x:Float, y:Float, radius:Float = 2):Void 
  {
    for (i in 0...points.length) {
      var p = points[i];
      g.drawCircle(x + p.x, y + p.y, radius);
    }
  }
  
  static public function drawCircle(center:HxPoint, x:Float, y:Float, radius:Float):Void {
    if (Math.isFinite(radius)) {
      g.lineStyle(THICKNESS, CENTROID_COLOR);
      g.drawCircle(x + center.x, y + center.y, 1);
      g.drawCircle(x + center.x, y + center.y, radius);
      //g.lineStyle(THICKNESS, COLOR);
    }
  }
  
  // Draw arrow head at `q`
  static public function drawArrowHead(p:HxPoint, q:HxPoint, x:Float, y:Float, length:Float = 7, angleDeg:Float = 15):Void 
  {
    var dx = p.x - q.x;
    var dy = p.y - q.y;
    var l = Math.sqrt(dx * dx + dy * dy);
    var cos = Math.cos(Math.PI * angleDeg / 180);
    var sin = Math.sin(Math.PI * angleDeg / 180);
    dx = (dx / l) * length;
    dy = (dy / l) * length;
    var end1 = new HxPoint(q.x + (dx * cos + dy * -sin), q.y + (dx * sin + dy * cos));
    var end2 = new HxPoint(q.x + (dx * cos + dy * sin), q.y + (dx * -sin + dy * cos));
    g.moveTo(end1.x + x, end1.y + y);
    g.lineTo((x + q.x), (y + q.y));
    g.lineTo(end2.x + x, end2.y + y);
    //g.lineTo(end1.x + x, end1.y + y); // close head
    //g.moveTo((X + q.x), (Y + q.y));
  }
  
  static public function drawPointsLabels(points:Array<HxPoint>, x:Float, y:Float):Void 
  {
    var len = points.length;
    var i = len - 1;
    while (i >= 0) {
      var p = points[i];
      var label = getTextField("" + i, 0, 0, Std.int(TEXT_SIZE * .75));
      var fmt = label.getTextFormat();
      fmt.align = TextFormatAlign.LEFT;
      label.setTextFormat(fmt);
      label.x = x + p.x;
      label.y = y + p.y - TEXT_SIZE;
      sprite.addChild(label);
      i--;
    }
  }
  
  static public function drawPoly(points:Array<HxPoint>, x:Float, y:Float, settings:DrawSettings):Void 
  {
    if (points.length <= 0) return;
    
    var color = settings.color != null ? settings.color : COLOR;
    g.lineStyle(THICKNESS, color, ALPHA);
    
    // points
    if (settings.showPoints) drawPoints(points, x, y);
    
    // lines
    if (settings.fill) g.beginFill(color, .5);
    g.moveTo(x + points[0].x, y + points[0].y);
    for (i in 1...points.length) {
      var p = points[i];
      g.lineTo(x + p.x, y + p.y);
    }
    if (settings.close) g.lineTo(x + points[0].x, y + points[0].y);
    if (settings.fill) g.endFill();
    
    if (settings.showArrows) {
      g.lineStyle(THICKNESS, color, ALPHA);
      if (settings.fill) g.beginFill(color, .3);
      for (i in 1...points.length) {
        var p = points[i - 1];
        var q = points[i];
        drawArrowHead(p, q, x, y);
      }
      if (settings.fill) g.endFill();
      g.lineStyle(THICKNESS, color, ALPHA);
    }
    
    // labels
    if (settings.showLabels) drawPointsLabels(points, x, y);
    
    // centroids
    if (settings.showCentroids) {
      var c = PolyTools.getCentroid(points);
      g.lineStyle(THICKNESS, CENTROID_COLOR);
      g.drawCircle(x + c.x, y + c.y, 2);
      //g.lineStyle(THICKNESS, color);
    }
  }

  static public function drawPaths(paths:Array<Array<HxPoint>>, x:Float, y:Float, settings:DrawSettings):Void 
  {
    if (paths.length <= 0) return;
    
    var color = settings.color != null ? settings.color : COLOR;
    
    var data = new flash.Vector();
    var commands = new flash.Vector();

    for (path in paths) {
      var len = path.length;
      
      for (i in 0...len) {
        if (i == 0) commands.push(1); // moveTo
        else commands.push(2); // lineTo
        
        data.push(x + path[i].x);
        data.push(y + path[i].y);
      }
      // close
      if (settings.fill) {
        commands.push(2);
        data.push(x + path[0].x);
        data.push(y + path[0].y);
      }
    }
    
    if (settings.fill) g.beginFill(color, .5);
    g.drawPath(commands, data, flash.display.GraphicsPathWinding.EVEN_ODD);
    if (settings.fill) g.endFill();

    // PoleOfInaccessibility
    if (settings.showPIA) {
      var p = PoleOfInaccessibility.calculate(paths);
      var r = PoleOfInaccessibility.pointToPolygonDist(p.x, p.y, paths);
      drawCircle(p, x, y, r);
    }
  }

  static public function drawPolys(polys:Array<Poly>, x:Float, y:Float, settings:DrawSettings):Void 
  {
    for (poly in polys) {
      drawPoly(poly, x, y, settings);
    }

    // PoleOfInaccessibility
    if (settings.showPIA) {
      var p = PoleOfInaccessibility.calculate(polys);
      var r = PoleOfInaccessibility.pointToPolygonDist(p.x, p.y, polys);
      drawCircle(p, x, y, r);
    }
  }

  static public function drawDecompositionBayazit(polys:Array<Poly>, x:Float, y:Float, settings:DrawSettings):Void 
  {
    drawPolys(polys, x, y, settings);
    
    var color = settings.color != null ? settings.color : COLOR;
    
    // draw Reflex and Steiner points
    if (settings.showReflexPoints) {
      g.lineStyle(THICKNESS, (color >> 1) | color, ALPHA);
      for (p in Bayazit.reflexVertices) g.drawCircle(x + p.x, y + p.y, 2);
    }
    
    if (settings.showSteinerPoints) {
      g.lineStyle(THICKNESS, (color >> 2) | color, ALPHA);
      for (p in Bayazit.steinerPoints) g.drawCircle(x + p.x, y + p.y, 2);
    }
    //g.lineStyle(THICKNESS, COLOR, ALPHA);
  }

  static public function getTextField(text:String = "", x:Float, y:Float, ?size:Int):TextField
  {
    var tf:TextField = new TextField();
    var fmt:TextFormat = new TextFormat(TEXT_FONT, null, TEXT_COLOR);
    //fmt.align = TextFormatAlign.CENTER;
    fmt.size = size == null ? TEXT_SIZE : size;
    tf.autoSize = TextFieldAutoSize.LEFT;
    tf.defaultTextFormat = fmt;
    tf.selectable = false;
    tf.x = x;
    tf.y = y + TEXT_OFFSET;
    tf.filters = [TEXT_OUTLINE];
    tf.text = text;
    return tf;
  }
}
