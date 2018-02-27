package;

import flash.display.Bitmap;
import flash.display.BitmapData;
import flash.display.Graphics;
import flash.display.Sprite;
import flash.display.Stage;
import flash.events.KeyboardEvent;
import flash.filters.GlowFilter;
import flash.geom.Rectangle;
import flash.Lib;
import flash.system.System;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import flash.utils.ByteArray;
import flash.text.TextFieldAutoSize;
#if (openfl && !nme)
import flash.display.PNGEncoderOptions;
#end
import hxGeomAlgo.Debug;

import haxe.Resource;
import haxe.Timer;

import hxPixels.Pixels;

import hxGeomAlgo.Version;
import hxGeomAlgo.EarCut;
import hxGeomAlgo.HxPoint;
import hxGeomAlgo.MarchingSquares;
import hxGeomAlgo.IsoContours;
import hxGeomAlgo.PolyTools;
import hxGeomAlgo.RamerDouglasPeucker;
import hxGeomAlgo.Bayazit;
import hxGeomAlgo.Visibility;
import hxGeomAlgo.PolyTools.Poly;
import hxGeomAlgo.PairDeque;
import hxGeomAlgo.SnoeyinkKeil;
import hxGeomAlgo.CCLabeler;
import hxGeomAlgo.VisvalingamWhyatt;
import hxGeomAlgo.Tess2;
import hxGeomAlgo.HertelMehlhorn;
import hxGeomAlgo.PoleOfInaccessibility;

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
}

class GeomAlgoTest extends Sprite {

  var g:Graphics;
  
  var THICKNESS:Float = .5;
  var COLOR:Int = 0xFF0000;
  var CENTROID_COLOR:Int = 0x00FF00;
  var ALPHA:Float = 1.;
  var X_GAP:Int = 10;
  var Y_GAP:Int = 15;

  var TEXT_COLOR:Int = 0xFFFFFF;
  var TEXT_FONT:String = "_typewriter";
  var TEXT_SIZE:Int = 12;
  var TEXT_OFFSET:Float = -60;
  var TEXT_OUTLINE:GlowFilter = new GlowFilter(0xFF000000, 1, 2, 2, 6);

  var START_POINT:HxPoint = new HxPoint(20, 90);

  var DEFAULT_DRAW_SETTINGS:DrawSettings = {
    showPoints: false,
    showLabels: false,
    showCentroids: false,
    showSteinerPoints: true,
    showReflexPoints: false,
    showArrows: false,
    showPIA: false,
    fill: true,
  };
  
  var X:Float;
  var Y:Float;
  var WIDTH:Int;
  var HEIGHT:Int;

  var originalBMD:BitmapData;
  var originalBitmap:Bitmap;

  var marchingSquares:MarchingSquares;
  var clipRect:Rectangle;
  var perimeter:Array<HxPoint>;

  var simplifiedPolyRDP:Array<HxPoint>;
  var triangulation:Array<Tri>;
  var decomposition:Array<Poly>;

  var color:Int;
  
  var text:TextField;
  var labelBMP:Bitmap;
  
  public function new(asset:String) {
    super();

    var sprite = new Sprite();
    addChild(sprite);
    g = sprite.graphics;
    g.lineStyle(THICKNESS, color = COLOR, ALPHA);
    originalBMD = openfl.Assets.getBitmapData(asset);
    WIDTH = originalBMD.width;
    HEIGHT = originalBMD.height + 80;
    if (WIDTH < 100) WIDTH = 100;
    if (HEIGHT < 100 + 80) HEIGHT = 100 + 80;

    //  ASSET IMAGE
    var assetTF = getTextField("move: ARROWS/GHJY  |  cycle: CTRL+ARROWS  |  zoom: +/-  |  [" + asset + "]", 0, 5 * TEXT_SIZE);
    trace("\n\n[" + asset + "]\n");
    assetTF.width = flash.Lib.current.stage.stageWidth;
    var fmt = assetTF.getTextFormat();
    fmt.align = TextFormatAlign.LEFT;
    assetTF.setTextFormat(fmt);
    addChild(assetTF);

    //  VERSION
    var versionTF = getTextField("hxGeomAlgo v" + Version.toString(), 0, 5 * TEXT_SIZE);
    versionTF.autoSize = TextFieldAutoSize.LEFT;
    versionTF.x = flash.Lib.current.stage.stageWidth - 140;
    addChild(versionTF);
  
    // ORIGINAL IMAGE
    setSlot(0, 0);
    addChildAt(originalBitmap = new Bitmap(originalBMD), 0);	// add it underneath sprite
    originalBitmap.x = X;
    originalBitmap.y = Y;
    clipRect = originalBMD.rect;
    g.drawRect(originalBitmap.x + clipRect.x, originalBitmap.y + clipRect.y, clipRect.width, clipRect.height);
    addChild(getTextField("Original\n" + originalBMD.width + "x" + originalBMD.height, X, Y));

    // MARCHING SQUARES
    setSlot(0, 1);
    var startTime = Timer.stamp();
    marchingSquares = new MarchingSquares(originalBMD, 1);
    perimeter = marchingSquares.march();
    trace('MarchSqrs     : ${Timer.stamp() - startTime}');
    drawPoly(perimeter, X + clipRect.x, Y + clipRect.y, set({fill:false}));
    // draw perimeter pixels: in green if on solid pixels, in blue if not
    /*var perimeterBitmap = new Bitmap(new BitmapData(WIDTH, HEIGHT, true, 0));
    for (p in perimeter) {
      var isSolid = @:privateAccess marchingSquares.isPixelSolid(Std.int(p.x), Std.int(p.y));
      perimeterBitmap.bitmapData.setPixel32(Std.int(p.x), Std.int(p.y), isSolid ? 0xFF0000FF : 0xFF00FF00);
    }
    perimeterBitmap.x = originalBitmap.x;
    perimeterBitmap.y = originalBitmap.y;
    addChild(perimeterBitmap);*/
    addChild(getTextField("MarchSqrs\n" + perimeter.length + " pts", X, Y));

    // ISOCONTOURS
    setSlot(0, 2);
    
    var customIsoFunction = function (pixels:Pixels, x:Int, y:Int):Float {
      if (IsoContours.isOutOfBounds(pixels, x, y)) return 0;
      else {
        var pixel = pixels.getPixel32(x, y);
        return pixel.R;
      }
    }
    
    var isoContours = new IsoContours(originalBMD);
    startTime = Timer.stamp();
    var contours = isoContours.find(0, true);
    if (asset.indexOf("py_figure") >= 0) {
      isoContours.isoFunction = customIsoFunction;
      contours = /*contours.concat*/(isoContours.find(0x80));
    }
    var pts = 0;
    for (c in contours) pts += c.length;
    trace('IsoContours   : ${Timer.stamp() - startTime}');
    drawPaths(contours, X, Y, DEFAULT_DRAW_SETTINGS);
    addChild(getTextField("IsoContours\n" + pts + " pts\n" + contours.length + " cntrs", X, Y));
  
    // CONNECTED COMPONENTS LABELING
    setSlot(0, 3);
    startTime = Timer.stamp();
    var labeler = new CustomLabeler(originalBMD, 1, true, Connectivity.EIGHT_CONNECTED, true);
    labeler.run();
    trace('CCLabeler     : ${Timer.stamp() - startTime}');
    labelBMP = new Bitmap(new BitmapData(labeler.labelMap.width, labeler.labelMap.height, true, 0));
    addChildAt(labelBMP, 0);
    labelBMP.x = X + clipRect.x;
    labelBMP.y = Y + clipRect.y;
    for (contour in labeler.contours) {
      var isHole = PolyTools.isCCW(contour);
      var color:Int = isHole ? 0xFF00FF00 : 0xFF0000FF;
      
      for (p in contour) {
        labeler.labelMap.setPixel32(Std.int(p.x), Std.int(p.y), color);
      }
    }
    labeler.labelMap.applyToBitmapData(labelBMP.bitmapData);
    addChild(getTextField("CCLabeler\n" + labeler.numComponents + " cmpts\n" + labeler.contours.length + " cntrs", X, Y));

    // RAMER-DOUGLAS-PEUCKER SIMPLIFICATION
    setSlot(0, 4);
    startTime = Timer.stamp();
    simplifiedPolyRDP = RamerDouglasPeucker.simplify(perimeter, 1.5);
    trace('Doug-Peuck    : ${Timer.stamp() - startTime}');
    drawPoly(simplifiedPolyRDP, X + clipRect.x, Y + clipRect.y, set({showPoints:true, fill:false}));
    addChild(getTextField("Doug-Peuck\n" + simplifiedPolyRDP.length + " pts", X, Y));

    // VISVALINGAM-WHYATT SIMPLIFICATION
    setSlot(0, 5);
    startTime = Timer.stamp();
    var simplifiedPolyVW = VisvalingamWhyatt.simplify(perimeter, SimplificationMethod.MaxPoints(simplifiedPolyRDP.length));
    trace('Visv-Whyatt   : ${Timer.stamp() - startTime}');
    drawPoly(simplifiedPolyVW, X + clipRect.x, Y + clipRect.y, set({showPoints:true, fill:false}));
    addChild(getTextField("Visv-Whyatt\n" + simplifiedPolyVW.length + " pts", X, Y));		

    // EARCUT TRIANGULATION
    setSlot(1, 1);
    startTime = Timer.stamp();
    triangulation = EarCut.triangulate(simplifiedPolyRDP);
    trace('ECTriang      : ${Timer.stamp() - startTime}');
    trace("  " + testOrientation(triangulation), testSimple(triangulation), testConvex(triangulation));
    drawPolys(triangulation, X + clipRect.x, Y + clipRect.y, DEFAULT_DRAW_SETTINGS);
    addChild(getTextField("EarCut\nTriang\n" + triangulation.length + " tris", X, Y));

    // EARCUT DECOMPOSITION
    setSlot(1, 2);
    startTime = Timer.stamp();
    decomposition = EarCut.polygonize(triangulation);
    trace('ECDecomp      : ${Timer.stamp() - startTime}');
    trace("  " + testOrientation(decomposition), testSimple(decomposition), testConvex(decomposition));
    drawPolys(decomposition, X + clipRect.x, Y + clipRect.y, set({showCentroids:true}));
    addChild(getTextField("EarCut\nDecomp\n" + decomposition.length + " polys", X, Y));

    // EC + HERTEL-MEHLHORN (DECOMPOSITION)
    setSlot(3, 1);
    startTime = Timer.stamp();
    decomposition = HertelMehlhorn.polygonize(triangulation);
    trace('HMEarCut      : ${Timer.stamp() - startTime}');
    trace("  " + testOrientation(decomposition), testSimple(decomposition), testConvex(decomposition));
    drawPolys(decomposition, X + clipRect.x, Y + clipRect.y, set({showCentroids:true}));
    addChild(getTextField("Hert-Mehl\n(EarCut)\n" + decomposition.length + " polys", X, Y));

    // BAYAZIT DECOMPOSITION
    setSlot(1, 3);
    startTime = Timer.stamp();
    decomposition = Bayazit.decomposePoly(simplifiedPolyRDP);
    trace('BayazDecomp   : ${Timer.stamp() - startTime}');
    trace("  " + testOrientation(decomposition), testSimple(decomposition), testConvex(decomposition));
    drawDecompositionBayazit(decomposition, X + clipRect.x, Y + clipRect.y, set({showCentroids:true}));
    addChild(getTextField("Bayazit\nDecomp\n" + decomposition.length + " polys", X, Y));

    // SNOEYINK-KEIL DECOMPOSITION
    setSlot(1, 4);
    startTime = Timer.stamp();
    decomposition = SnoeyinkKeil.decomposePoly(simplifiedPolyRDP);
    trace('SnoeKeilDecomp: ${Timer.stamp() - startTime}');
    trace("  " + testOrientation(decomposition), testSimple(decomposition), testConvex(decomposition));
    drawPolys(decomposition, X + clipRect.x, Y + clipRect.y, set({showCentroids:true}));
    /*g.lineStyle(THICKNESS, 0xFFFFFF, ALPHA);
    for (d in SnoeyinkKeil.diagonals) {
      var p = simplifiedPolyRDP[d.from];
      var q = simplifiedPolyRDP[d.to];
      g.moveTo(X + p.x, Y + p.y);
      g.lineTo(X + q.x, Y + q.y);
    }
    g.lineStyle(THICKNESS, COLOR, ALPHA);*/
    addChild(getTextField("Snoeyink-Keil\nMin Decomp\n" + decomposition.length + " polys", X, Y));

    // VISIBILITY
    setSlot(1, 5);
    drawPoly(simplifiedPolyRDP, X + clipRect.x, Y + clipRect.y, set({showPoints:true}));
    var origIdx = Std.int(Math.random() * simplifiedPolyRDP.length);
    var origPoint = simplifiedPolyRDP[origIdx];
    // visible points
    startTime = Timer.stamp();
    var visPoints = Visibility.getVisiblePolyFrom(simplifiedPolyRDP, origIdx);
    g.lineStyle(THICKNESS, color = 0xFFFF00);
    drawPoly(visPoints, X + clipRect.x, Y + clipRect.y, set({showPoints:true}));
    // visible vertices
    var visIndices = Visibility.getVisibleIndicesFrom(simplifiedPolyRDP, origIdx);
    var visVertices = [for (i in 0...visIndices.length) simplifiedPolyRDP[visIndices[i]]];
    trace('Visisibility  : ${Timer.stamp() - startTime}');
    g.lineStyle(THICKNESS, color = 0x00FF00);
    drawPoints(visVertices, X + clipRect.x, Y + clipRect.y);
    // draw origPoint
    g.lineStyle(THICKNESS, color = 0x0000FF);
    if (origPoint != null) g.drawCircle(X + origPoint.x + clipRect.x, Y + origPoint.y + clipRect.y, 3);
    addChild(getTextField("Visibility\n" + visVertices.length + " vts\n" + visPoints.length + " pts", X, Y));
    g.lineStyle(THICKNESS, color = COLOR, ALPHA);

    // TESS2 - TRIANGULATION
    setSlot(2, 1);
    var polySize = 3;
    var resultType = ResultType.POLYGONS;
    var flatContours = [for (c in contours) PolyTools.toFloatArray(RamerDouglasPeucker.simplify(c, 1.))];
    startTime = Timer.stamp();
    var res = Tess2.tesselate(flatContours, null, resultType, polySize);
    trace('Tess2Triang   : ${Timer.stamp() - startTime}');
    var polys = Tess2.convertResult(res.vertices, res.elements, resultType, polySize);
    trace("  " + testOrientation(polys), testSimple(polys), testConvex(polys));
    for (p in polys) drawPoly(p, X + clipRect.x, Y + clipRect.y, DEFAULT_DRAW_SETTINGS);
    addChild(getTextField("Tess2\nTriang\n" + res.elementCount + " tris", X, Y));

    // TESS2 + HERTEL-MEHLHORN (DECOMPOSITION)
    setSlot(3, 2);
    startTime = Timer.stamp();
    decomposition = HertelMehlhorn.polygonize(polys);
    trace('HMTess2      : ${Timer.stamp() - startTime}');
    trace("  " + testOrientation(decomposition), testSimple(decomposition), testConvex(decomposition));
    drawPolys(decomposition, X + clipRect.x, Y + clipRect.y, set({showCentroids:true}));
    addChild(getTextField("Hert-Mehl\n(Tess2)\n" + decomposition.length + " polys", X, Y));

    // TESS2 - EXPERIMENTAL DELAUNAY TRIANGULATION
    setSlot(2, 0);
    polySize = 3;
    resultType = ResultType.EXPERIMENTAL_DELAUNAY;
    startTime = Timer.stamp();
    res = Tess2.tesselate(flatContours, null, resultType, polySize);
    trace('Tess2Delaunay : ${Timer.stamp() - startTime}');
    polys = Tess2.convertResult(res.vertices, res.elements, resultType, polySize);
    trace("  " + testOrientation(polys), testSimple(polys), testConvex(polys));
    drawPolys(polys, X + clipRect.x, Y + clipRect.y, DEFAULT_DRAW_SETTINGS);
    addChild(getTextField("Tess2\nExp. Delaunay\n" + res.elementCount + " tris", X, Y));

    // TESS2 + EC (DECOMP)
    setSlot(3, 0);
    startTime = Timer.stamp();
    var polygonized = EarCut.polygonize(polys);
    trace('ECTess2Del   : ${Timer.stamp() - startTime}');
    trace("  " + testOrientation(polys), testSimple(polys), testConvex(polys));
    drawPolys(polygonized, X + clipRect.x, Y + clipRect.y, set({showCentroids:true}));
    addChild(getTextField("EC Decomp\n(Tess2Del)\n" + polygonized.length + " polys", X, Y));

    // TESS2 DELAUNAY + HERTEL-MEHLHORN (DECOMPOSITION)
    setSlot(3, 3);
    startTime = Timer.stamp();
    decomposition = HertelMehlhorn.polygonize(polys);
    trace('HMTess2Del   : ${Timer.stamp() - startTime}');
    trace("  " + testOrientation(decomposition), testSimple(decomposition), testConvex(decomposition));
    drawPolys(decomposition, X + clipRect.x, Y + clipRect.y, set({showCentroids:true}));
    addChild(getTextField("Hert-Mehl\n(Tess2Del)\n" + decomposition.length + " polys", X, Y));

    // TESS2 - DECOMP
    setSlot(2, 2);
    polySize = 24;
    resultType = ResultType.POLYGONS;
    startTime = Timer.stamp();
    res = Tess2.tesselate(flatContours, null, resultType, polySize);
    polys = Tess2.convertResult(res.vertices, res.elements, resultType, polySize);
    trace('Tess2Decomp   : ${Timer.stamp() - startTime}');
    trace("  " + testOrientation(polys), testSimple(polys), testConvex(polys));
    drawPolys(polys, X + clipRect.x, Y + clipRect.y, set({showCentroids:true}));
    addChild(getTextField("Tess2\nDecomp\n" + res.elementCount + " polys", X, Y));

    // TESS2 - CONTOURS
    /*
    setSlot(2, 7);
    resultType = ResultType.BOUNDARY_CONTOURS;
    res = Tess2.tesselate(flatContours, null, resultType, polySize);
    polys = Tess2.convertResult(res.vertices, res.elements, resultType, polySize);
    for (p in polys) drawPoly(p, X + clipRect.x, Y + clipRect.y, DEFAULT_DRAW_SETTINGS);
    addChild(getTextField("Tess2\nContours\n" + res.elementCount + " polys", X, Y));
    */
  
    // setup a ring poly to test Tess2 bool ops
    var radius = originalBMD.width / 2;
    var holeRadius = radius - 25;
    var outerCircle = [];
    var innerCircle = [];
    var cx = originalBMD.width / 2;
    var cy = originalBMD.height / 2;
    var theta = 0.;
    var delta = 2 * Math.PI / 100;
    for (i in 0...100) {
      var cos = Math.cos(theta);
      var sin = Math.sin(theta);
      outerCircle.push(new HxPoint(cx + cos * radius, cy + sin * radius));
      innerCircle.push(new HxPoint(cx + cos * holeRadius, cy + sin * holeRadius));
      theta += delta;
    }
    var flatRing = [PolyTools.toFloatArray(outerCircle), PolyTools.reverseFloatArray(PolyTools.toFloatArray(innerCircle))];
    
    polySize = 3;
    resultType = ResultType.BOUNDARY_CONTOURS;

    // TESS2 - UNION
    setSlot(2, 3);
    startTime = Timer.stamp();
    res = Tess2.union(flatContours, flatRing, resultType, polySize, 2);
    polys = Tess2.convertResult(res.vertices, res.elements, resultType, polySize);
    trace('Tess2Union    : ${Timer.stamp() - startTime}');
    drawPaths(polys, X + clipRect.x, Y + clipRect.y, DEFAULT_DRAW_SETTINGS);
    addChild(getTextField("Tess2\nUnion\n" + res.elementCount + " polys", X, Y));
  
    // PIA - TESS2 UNION
    setSlot(3, 4);
    startTime = Timer.stamp();
    var pia = PoleOfInaccessibility.calculate(polys, 1.0, true);
    trace('PoleOfInaccess: ${Timer.stamp() - startTime}');
    var r = PoleOfInaccessibility.pointToPolygonDist(pia.x, pia.y, polys);
    drawPaths(polys, X + clipRect.x, Y + clipRect.y, DEFAULT_DRAW_SETTINGS);
    drawCircle(pia, X + clipRect.x, Y + clipRect.y, r);
    addChild(getTextField("PIA\n(Tess Union)\nradius:" + r, X, Y));
  
    // TESS2 - INTERSECTION
    setSlot(2, 4);
    startTime = Timer.stamp();
    res = Tess2.intersection(flatContours, flatRing, resultType, polySize, 2);
    polys = Tess2.convertResult(res.vertices, res.elements, resultType, polySize);
    trace('Tess2Intersect: ${Timer.stamp() - startTime}');
    drawPaths(polys, X + clipRect.x, Y + clipRect.y, DEFAULT_DRAW_SETTINGS);
    addChild(getTextField("Tess2\nIntersection\n" + res.elementCount + " polys", X, Y));
  
    // TESS2 - DIFFERENCE
    setSlot(2, 5);
    startTime = Timer.stamp();
    res = Tess2.difference(flatContours, flatRing, resultType, polySize, 2);
    polys = Tess2.convertResult(res.vertices, res.elements, resultType, polySize);
    trace('Tess2Diff     : ${Timer.stamp() - startTime}');
    drawPaths(polys, X + clipRect.x, Y + clipRect.y, DEFAULT_DRAW_SETTINGS);
    addChild(getTextField("Tess2\nDifference\n" + res.elementCount + " polys", X, Y));
    
    //flash.Lib.current.stage.addChild(new openfl.FPS(5, 5, 0xFFFFFF));

    dumpPoly(simplifiedPolyRDP, false);
  
    // Tess2.js-test parsable poly string (https://rawgit.com/azrafe7/tess2.js/master/test/index.html)
    dumpTess2Polys(flatContours);
  
    // test CCW and duplicate points
    trace("\n");
    polys = [perimeter, simplifiedPolyRDP, simplifiedPolyVW, visPoints].concat(labeler.contours).concat(contours);
    var labelerHeaders = [for (i in 0...labeler.contours.length) 'labeler[$i]   '];
    var isoHeaders = [for (i in 0...contours.length) 'isoCntr[$i]   '];
    var headers = ["perimeter    ", "simplifiedRDP", "simplifiedVW ", "visPoints    "].concat(labelerHeaders).concat(isoHeaders);
    for (i in 0...polys.length) {
      var poly = polys[i];
      var name = headers[i];
      var orientation = testOrientation([poly]);
      var hasDups = PolyTools.findDuplicatePoints(poly).length > 0;
      trace('$name (orientation:$orientation, hasDups:$hasDups)');
    }
  }
  
  public function set(extra:DrawSettings):DrawSettings {
    var newSettings:DrawSettings = {};
    for (f in Reflect.fields(DEFAULT_DRAW_SETTINGS)) {
      Reflect.setField(newSettings, f, Reflect.field(DEFAULT_DRAW_SETTINGS, f));
    }
    for (f in Reflect.fields(extra)) {
      Reflect.setField(newSettings, f, Reflect.field(extra, f));
    }
    return newSettings;
  }
  
  public function testOrientation(polys:Array<Poly>):String {
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
  
  public function testConvex(polys:Array<Poly>):String {
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
  
  public function testSimple(polys:Array<Poly>):String {
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
  #if (sys && (openfl && !nme))
    var ba:ByteArray = bmd.encode(bmd.rect, new PNGEncoderOptions());
    var file:FileOutput = sys.io.File.write(fileName, true);
    file.writeString(ba.toString());
    file.close();
    trace('BitmapData saved as "${fileName}".');
  #end
  }
  
  public function setSlot(row:Int, col:Int):Void 
  {
    X = START_POINT.x + (WIDTH + X_GAP) * col;
    Y = START_POINT.y + (HEIGHT + Y_GAP) * row;
  }
  
  public function dumpTess2Polys(flatContours:Array<Array<Float>>):Void {
    var str = "all polys dump: \n";
    for (poly in flatContours) {
      for (i in 0...poly.length >> 1) {
        str += '${poly[i * 2]} ${poly[i * 2 + 1]}\n';
      }
      str += "\n";
    }
    trace(str);
  }

  public function dumpPoly(poly:Array<HxPoint>, reverse:Bool = false):Void {
    var len = poly.length;
    var str = "poly dump: \n";
    for (i in 0...len) {
      var p = poly[reverse ? len - i - 1 : i];
      str += p.x + "," + p.y + ",";
    }
    trace(str);
  }

  public function drawPoints(points:Array<HxPoint>, x:Float, y:Float, radius:Float = 2):Void 
  {
    for (i in 0...points.length) {
      var p = points[i];
      g.drawCircle(x + p.x, y + p.y, radius);
    }
  }
  
  public function drawCircle(center:HxPoint, x:Float, y:Float, radius:Float):Void {
    if (Math.isFinite(radius)) {
      g.lineStyle(THICKNESS, CENTROID_COLOR);
      g.drawCircle(x + center.x, y + center.y, 1);
      g.drawCircle(x + center.x, y + center.y, radius);
      g.lineStyle(THICKNESS, COLOR);
    }
  }
  
  // Draw arrow head at `q`
  public function drawArrowHead(p:HxPoint, q:HxPoint, x:Float, y:Float, length:Float = 7, angleDeg:Float = 15):Void 
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
    g.lineTo((X + q.x), (Y + q.y));
    g.lineTo(end2.x + x, end2.y + y);
    //g.lineTo(end1.x + x, end1.y + y); // close head
    //g.moveTo((X + q.x), (Y + q.y));
  }
  
  public function drawPointsLabels(points:Array<HxPoint>, x:Float, y:Float):Void 
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
      addChild(label);
      i--;
    }
  }
  
  public function drawPoly(points:Array<HxPoint>, x:Float, y:Float, settings:DrawSettings):Void 
  {
    if (points.length <= 0) return;
    
    // points
    if (settings.showPoints) drawPoints(points, x, y);
    
    // lines
    if (settings.fill) g.beginFill(COLOR, .5);
    g.moveTo(x + points[0].x, y + points[0].y);
    for (i in 1...points.length) {
      var p = points[i];
      g.lineTo(x + p.x, y + p.y);
    }
    g.lineTo(x + points[0].x, y + points[0].y);
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
      g.lineStyle(THICKNESS, COLOR);
    }
  }

  public function drawPaths(paths:Array<Array<HxPoint>>, x:Float, y:Float, settings:DrawSettings):Void 
  {
    if (paths.length <= 0) return;
    
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
    
    if (settings.fill) g.beginFill(COLOR, .5);
    g.drawPath(commands, data, flash.display.GraphicsPathWinding.EVEN_ODD);
    if (settings.fill) g.endFill();

    // PoleOfInaccessibility
    if (settings.showPIA) {
      var p = PoleOfInaccessibility.calculate(paths);
      var r = PoleOfInaccessibility.pointToPolygonDist(p.x, p.y, paths);
      drawCircle(p, x, y, r);
    }
  }

  public function drawPolys(polys:Array<Poly>, x:Float, y:Float, settings:DrawSettings):Void 
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

  public function drawDecompositionBayazit(polys:Array<Poly>, x:Float, y:Float, settings:DrawSettings):Void 
  {
    drawPolys(polys, x, y, settings);
    
    // draw Reflex and Steiner points
    if (settings.showReflexPoints) {
      g.lineStyle(THICKNESS, (COLOR >> 1) | COLOR, ALPHA);
      for (p in Bayazit.reflexVertices) g.drawCircle(x + p.x, y + p.y, 2);
    }
    
    if (settings.showSteinerPoints) {
      g.lineStyle(THICKNESS, (COLOR >> 2) | COLOR, ALPHA);
      for (p in Bayazit.steinerPoints) g.drawCircle(x + p.x, y + p.y, 2);
    }
    g.lineStyle(THICKNESS, COLOR, ALPHA);
  }

  public function getTextField(text:String = "", x:Float, y:Float, ?size:Int):TextField
  {
    var tf:TextField = new TextField();
    var fmt:TextFormat = new TextFormat(TEXT_FONT, null, TEXT_COLOR);
    fmt.align = TextFormatAlign.CENTER;
    fmt.size = size == null ? TEXT_SIZE : size;
    tf.defaultTextFormat = fmt;
    tf.selectable = false;
    tf.x = x;
    tf.y = y + TEXT_OFFSET;
    // Don't apply glow filter on non-flash (not working with current version of openfl)
  #if flash
    tf.filters = [TEXT_OUTLINE];
  #end
    tf.text = text;
    return tf;
  }
}

typedef PixelInfo = {
  var a:Int;
  var r:Int;
  var g:Int;
  var b:Int;
  var h:Float;
  var s:Float;
  var v:Float;
  var l:Float;
}

class CustomLabeler extends CCLabeler 
{
  var pixelInfoMap:Map<Int, PixelInfo>; // cache
  
  public function new(pixels:Pixels, alphaThreshold:Int = 1, traceContours:Bool = true, ?connectivity:Connectivity, calcArea:Bool = false)
  {
    super(pixels, alphaThreshold, traceContours, connectivity, calcArea);
    
    pixelInfoMap = new Map();
  }
  
  override function isPixelSolid(x:Int, y:Int):Bool 
  {
    var pixelColor:Int = getPixel32(sourcePixels, x, y, 0);
    
    var pixelInfo = getPixelInfo(pixelColor);
    
    return (pixelInfo.a > 0); // this could have been more complex (e.g. ` && pixelInfo.h > .5 && pixelInfo.h < .8`)
  }
  
  public function getPixelInfo(color:Int):PixelInfo
  {
    if (pixelInfoMap[color] != null) return pixelInfoMap[color];
    
    var a:Int = (color >> 24) & 0xFF;
    var colMask:Int = a > 0 ? 0xFF : 0;	// fix to force neko to report rgb as 0 when alpha is 0 (to be consistent with flash)
    var r:Int = (color >> 16) & colMask;
    var g:Int = (color >> 8) & colMask;
    var b:Int = color & colMask;

    var info:Dynamic = {a:a, r:r, g:g, b:b};
    
    // hue
    var max:Int = Std.int(Math.max(r, Math.max(g, b)));
    var min:Int = Std.int(Math.min(r, Math.min(g, b)));

    if (max == min) info.h = 0;
    else if (max == r) info.h = (60 * (g - b) / (max - min) + 360) % 360;
    else if (max == g) info.h = (60 * (b - r) / (max - min) + 120);
    else if (max == b) info.h = (60 * (r - g) / (max - min) + 240);

    info.h /= 360;
    
    // saturation
    if (max == 0) info.s = 0;
    else info.s = (max - min) / max;
    
    // value
    info.v = max / 255;
    
    // luminance
    //info.l = (0.2126 * r / 255 + 0.7152 * g / 255 + 0.0722 * b / 255);
    info.l = (0.33333 * r / 255 + 0.33333 * g / 255 + 0.33333 * b / 255);
    
    pixelInfoMap[color] = info;
    
    return info;
  }
}